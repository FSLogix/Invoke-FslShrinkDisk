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
        [int]$GeneralTimeout = 120,

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

        #Diskpart will output the system language to the console if it can, otherwise default to english, I've found 4 languages it can use as output (including english) there may be more
        $diskPartLang = 'DiskPart successfully compacted the virtual disk file.',
        'DiskPart a correctement compacté le fichier de disque virtuel.',
        'DiskPart compactó correctamente el archivo de disco virtual.',
        'Die Datei für virtuelle Datenträger wurde von DiskPart erfolgreich komprimiert.'

    } # Begin
    PROCESS {
        #In case there are disks left mounted let's try to clean up.
        Dismount-DiskImage -ImagePath $Disk.FullName -ErrorAction SilentlyContinue

        #Get start time for logfile
        $startTime = Get-Date
        if ( $IgnoreLessThanGB ) {
            $IgnoreLessThanBytes = $IgnoreLessThanGB * 1024 * 1024 * 1024
        }

        #Grab size of disk being processed
        $originalSize = $Disk.Length

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below, these can be overridden as I need to.  Calclations to be done in the output function, raw data goes in.
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
            Write-VhdOutput -DiskState 'File Is Not a Virtual Hard Disk format with extension vhd or vhdx' -EndTime (Get-Date)
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
                    Write-VhdOutput -DiskState 'Disk Deletion Failed' -EndTime (Get-Date)
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
            $mount = Mount-FslDisk -Path $Disk.FullName -TimeOut $MountTimeout -PassThru -ErrorAction Stop
        }
        catch {
            $err = $error[0]
            Write-VhdOutput -DiskState $err -EndTime (Get-Date)
            return
        }

        #Grabbing partition info can fail when the client is under heavy load so.......
        $timespan = (Get-Date).AddSeconds($GeneralTimeout)
        $partInfo = $null
        while (($partInfo | Measure-Object).Count -lt 1 -and $timespan -gt (Get-Date)) {
            try {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction Stop | Where-Object { $_.Type -eq 'Basic' -or $_.Type -eq 'IFS' } -ErrorAction Stop
                if ($partinfo.Type -eq 'IFS') {
                    Write-Warning 'Disk is not created by FSLogix, this tool is designed for FSLogix disks'
                }
            }
            catch {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction SilentlyContinue | Select-Object -Last 1
            }
            Start-Sleep 0.1
        }

        if (($partInfo | Measure-Object).Count -eq 0) {
            $mount | DisMount-FslDisk
            Write-VhdOutput -DiskState 'No Partition Information - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            return
        }

        #Try and defragment the disk
        $timespan = (Get-Date).AddSeconds($GeneralTimeout)
        $defrag = $false
        while ($defrag -eq $false -and $timespan -gt (Get-Date)) {
            try {
                $vol = Get-Volume -Partition $partInfo -ErrorAction Stop
                $vol | Optimize-Volume -ErrorAction Stop
                $defrag = $true
            }
            catch {
                try {
                    $volObjId = Get-Volume -ErrorAction Stop | Where-Object {
                        $_.UniqueId -like "*$($partInfo.Guid)*" -or
                        $_.Path -Like "*$($partInfo.Guid)*" -or
                        $_.ObjectId -Like "*$($partInfo.Guid)*" } | Select-Object -Property 'ObjectId'

                    Optimize-Volume -ObjectId $volObjId.ObjectId -ErrorAction Stop | Out-Null

                    $defrag = $true
                }
                catch {
                    $defrag = $false
                    Start-Sleep 0.1
                }
            }
        }

        if ($defrag -eq $false) {
            Write-VhdOutput -DiskState 'Defragmentation of the disk failed' -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        $partSize = $false
        $timespan = (Get-Date).AddSeconds($GeneralTimeout)
        while ($partSize -eq $false -and $timespan -gt (Get-Date)) {
            try {
                $partitionsize = $partInfo | Get-PartitionSupportedSize -ErrorAction Stop
                $partSize = $true
            }
            catch {
                $e = $error[0]
                if ($e.ToString() -like "Cannot shrink a partition containing a volume with errors*") {
                    Get-Volume -Partition $partInfo -ErrorAction SilentlyContinue | Repair-Volume | Out-Null
                }

                try {
                    $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -PartitionNumber $mount.PartitionNumber -ErrorAction Stop
                    $partSize = $true
                }
                catch {
                    $partSize = $false
                    Start-Sleep 0.1
                }
            }
        }

        if ($partSize -eq $false) {
            #$partInfo | Export-Clixml -Path "$env:TEMP\ForJim-$($Disk.Name).xml"
            Write-VhdOutput -DiskState 'No Supported Size Info for partition - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
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

        $mount | DisMount-FslDisk

        #Change the disk size and grab the new size

        $success = $false
        #Diskpart is a little erratic and can fail occasionally, so stuck it in a loop.

        $timespan = (Get-Date).AddSeconds($GeneralTimeout)
        while ($success -ne $true -and $timespan -gt (Get-Date)) {

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
            $diskPartFlag = $false

            #using the success lines for different languages defined in the begin block test for success
            foreach ($langString in $diskPartLang) {
                if ($diskPartResult -contains $langString) {
                    $diskPartFlag = $true
                }
            }

            if ($diskPartFlag) {
                $finalSize = Get-ChildItem $Disk.FullName | Select-Object -ExpandProperty Length
                $success = $true
                Remove-Item $tempFileName
            }
            else {
                Set-Content -Path "$env:TEMP\FslDiskPartError$($Disk.Name)-$retries.log" -Value $diskPartResult
                #if DiskPart fails, try, try again.
            }
            Start-Sleep 1
        }

        If ($success -ne $true) {
            Write-VhdOutput -DiskState "DiskShrinkFailed" -EndTime (Get-Date)
            Remove-Item $tempFileName
            return
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