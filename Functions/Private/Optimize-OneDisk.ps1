function Optimize-OneDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.IO.FileInfo]$Disk,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$DeleteOlderThanDays,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$IgnoreLessThanGB,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [double]$RatioFreeSpace = 0.05,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$MountTimeout = 30,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$LogFilePath = "$env:TEMP\FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH-mm-ss).csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [switch]$Passthru

    )

    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
        $hyperv = $false
    } # Begin
    PROCESS {
        $startTime = Get-Date
        if ( $IgnoreLessThanGB ) {
            $IgnoreLessThanBytes = $IgnoreLessThanGB * 1024 * 1024 * 1024
        }

        #Grab size of disk being porcessed
        $originalSize = $Disk.Length

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below, these can be overridden as I need to.
        $PSDefaultParameterValues = @{
            "Write-VhdOutput:Path"         = $LogFilePath
            "Write-VhdOutput:StartTime"    = $startTime
            "Write-VhdOutput:Name"         = $Disk.Name
            "Write-VhdOutput:DiskState"    = $null
            "Write-VhdOutput:OriginalSize" = $originalSize
            "Write-VhdOutput:FinalSize"    = $originalSize
            "Write-VhdOutput:FullName"     = $Disk.FullName
            "Write-VhdOutput:Passthru"     = $Passthru
        }

        #Check it is a disk
        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            Write-VhdOutput -DiskState 'FileIsNotDiskFormat' -EndTime (Get-Date)
            return
        }

        #If it's older than x days delete disk
        If ( $DeleteOlderThanDays ) {
            #Last Access time isn't always reliable if diff disks are used so lets be safe and use the most recent of access and write
            $mostRecent = $Disk.LastAccessTime, $Disk.LastWriteTime | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            if ($mostRecent -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    Write-VhdOutput -DiskState "Deleted" -FinalSize 0 -EndTime (Get-Date)
                }
                catch {
                    Write-VhdOutput -DiskState 'DiskDeletionFailed' -EndTime (Get-Date)
                }
                return
            }
        }

        #As disks take time to process, if you have a lot of disks, it may not be worth shrinking the small onesBytes
        if ( $IgnoreLessThanGB -and $originalSize -lt $IgnoreLessThanBytes ) {
            Write-VhdOutput -DiskState 'Ignored' -EndTime (Get-Date)
            return
        }

        #Initial disk Mount

        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -TimeOut 30 -PassThru -ErrorAction Stop
        }
        catch {
            $err = $error[0]
            Write-VhdOutput -DiskState $err -EndTime (Get-Date)
            return
        }

        $timespan = (Get-Date).AddSeconds(120)
        $partInfo = $null
        while (($partInfo | Measure-Object).Count -lt 1 -and $timespan -gt (Get-Date)) {
            try {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction Stop | Where-Object -Property 'Type' -EQ -Value 'Basic' -ErrorAction Stop
            }
            catch {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction SilentlyContinue | Select-Object -Last 1
            }
            Start-Sleep 0.1
        }

        if (($partInfo | Measure-Object).Count -eq 0) {
            $mount | DisMount-FslDisk
            Write-VhdOutput -DiskState 'The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            return
        }

        Get-Volume -Partition $partInfo | Optimize-Volume

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        $partSize = $false
        $timespan = (Get-Date).AddSeconds(30)
        while ($partSize -eq $false -and $timespan -gt (Get-Date)) {
            try {
                $partitionsize = Get-PartitionSupportedSize -InputObject $partInfo -ErrorAction Stop
                $sizeMax = $partitionsize.SizeMax
                $partSize = $true
            }
            catch {
                $partSize = $false
                Start-Sleep 0.1
            }
        }

        if ($partSize -eq $false) {
            Write-VhdOutput -DiskState 'No Partition Supported Size Info' -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        #If you can't shrink the partition much, you can't reclaim a lot of space, so skipping if it's not worth it. Otherwise shink partition and dismount disk

        if ( $partitionsize.SizeMin -gt $disk.Length ) {
            Write-VhdOutput -DiskState "SkippedAlreadyMinimum" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        if (($partitionsize.SizeMin / $disk.Length) -gt (1 - $RatioFreeSpace) ) {
            Write-VhdOutput -DiskState "LessThan$(100*$RatioFreeSpace)%FreeInsideDisk" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {

            #In some cases you can't do the partition shrink to the min so increasing by 100 MB each time till it shrinks
            $i = 0
            $resize = $false
            $targetSize = $partitionsize.SizeMin
            $sizeBytesIncrement = 100 * 1024 * 1024

            while ($i -le 5 -and $resize -eq $false) {

                try {
                    Resize-Partition -InputObject $partInfo -Size $targetSize -ErrorAction Stop
                    $resize = $true
                }
                catch {
                    $resize = $false
                    $targetSize = $targetSize + $sizeBytesIncrement
                    $i++
                }
                finally {
                    Start-Sleep 1
                }
            }

            #Whatever happens now we need to dismount

            if ($resize -eq $false) {
                Write-VhdOutput -DiskState "PartitionShrinkFailed" -EndTime (Get-Date)
                $mount | DisMount-FslDisk
                return
            }
        }

        $mount | DisMount-FslDisk

        #Change the disk size and grab the new size

        $retries = 0
        $success = $false
        #Diskpart is a little erratic and can fail occasionally, so stuck it in a loop.
        while ($retries -lt 30 -and $success -ne $true) {

            $tempFileName = "$env:TEMP\FslDiskPart$($Disk.Name).txt"

            #Let's put diskpart into a function just so I can use Pester to Mock it
            function invoke-diskpart ($Path) {
                #diskpart needs you to write a txt file so you can automate it, because apparently it's 1989.
                #A better way would be to use optimize-vhd from the Hyper-V module,
                #   but that only comes along with installing the actual role, which needs CPU virtualisation extensions present,
                #   which is a PITA in cloud and virtualised environments where you can't do Hyper-V.
                #MaybeDo, use hyper-V module if it's there if not use diskpart? two code paths to do the same thing probably not smart though, it would be a way to solve localisation issues.
                Set-Content -Path $Path -Value "SELECT VDISK FILE=`'$($Disk.FullName)`'"
                Add-Content -Path $Path -Value 'attach vdisk readonly'
                Add-Content -Path $Path -Value 'COMPACT VDISK'
                Add-Content -Path $Path -Value 'detach vdisk'
                $result = DISKPART /s $Path
                Write-Output $result
            }

            $diskPartResult = invoke-diskpart -Path $tempFileName

            #diskpart doesn't return an object (1989 remember) so we have to parse the text output.
            if ($diskPartResult -contains 'DiskPart successfully compacted the virtual disk file.') {
                $finalSize = Get-ChildItem $Disk.FullName | Select-Object -ExpandProperty Length
                $success = $true
                Remove-Item $tempFileName
            }
            else {
                Set-Content -Path "$env:TEMP\FslDiskPartError$($Disk.Name)-$retries.log" -Value $diskPartResult
                $retries++
                #if DiskPart fails, try, try again.
            }
            Start-Sleep 1
        }

        If ($success -ne $true) {
            Write-VhdOutput -DiskState "DiskShrinkFailed" -EndTime (Get-Date)
            Remove-Item $tempFileName
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {
            #Now we need to reinflate the partition to its previous size
            try {
                $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber | Where-Object -Property 'Type' -EQ -Value 'Basic'
                Resize-Partition -InputObject $partInfo -Size $sizeMax -ErrorAction Stop
                $paramWriteVhdOutput = @{
                    DiskState = "Success"
                    FinalSize = $finalSize
                    EndTime   = Get-Date
                }
                Write-VhdOutput @paramWriteVhdOutput
            }
            catch {
                Write-VhdOutput -DiskState "PartitionSizeRestoreFailed" -EndTime (Get-Date)
                return
            }
            finally {
                $mount | DisMount-FslDisk
            }
        }


        $paramWriteVhdOutput = @{
            DiskState = "Success"
            FinalSize = $finalSize
            EndTime   = Get-Date
        }
        Write-VhdOutput @paramWriteVhdOutput
    } #Process
    END { } #End
}  #function Optimize-OneDisk