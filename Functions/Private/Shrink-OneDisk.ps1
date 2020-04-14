function Shrink-OneDisk {
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
        [double]$RatioFreeSpace = 0.2,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$PartitionNumber = 1,

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
    } # Begin
    PROCESS {
        #Grab size of disk being porcessed
        $originalSizeGB = [math]::Round( $Disk.Length/1GB, 2 )

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below, these can be overridden as I need to.
        $PSDefaultParameterValues = @{
            "Write-VhdOutput:Path"           = $LogFilePath
            "Write-VhdOutput:Name"           = $Disk.Name
            "Write-VhdOutput:DiskState"      = $null
            "Write-VhdOutput:OriginalSizeGB" = $originalSizeGB
            "Write-VhdOutput:FinalSizeGB"    = $originalSizeGB
            "Write-VhdOutput:SpaceSavedGB"   = 0
            "Write-VhdOutput:FullName"       = $Disk.FullName
            "Write-VhdOutput:Passthru"       = $Passthru
        }

        #Check it is a disk
        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            Write-VhdOutput -DiskState 'FileIsNotDiskFormat'
            return
        }

        #If it's older than x days delete disk
        If ( $DeleteOlderThanDays ) {
            if ($Disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    Write-VhdOutput -DiskState "Deleted" -FinalSizeGB 0 -SpaceSavedGB $originalSizeGB
                }
                catch {
                    Write-VhdOutput -DiskState 'DiskDeletionFailed'
                }
                return
            }
        }

        #As disks take time to process, if you have a lot of disks, it may not be worth shrinking the small ones
        if ( $IgnoreLessThanGB -and $originalSizeGB -lt $IgnoreLessThanGB ) {
            Write-VhdOutput -DiskState 'Ignored'
            return
        }

        #Initial disk Mount
        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru -ErrorAction Stop
        }
        catch {
            Write-VhdOutput -DiskState 'DiskLocked'
            return
        }

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        try {
            $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -ErrorAction Stop
            $sizeMax = $partitionsize.SizeMax
        }
        catch {
            Write-VhdOutput -DiskState 'NoPartitionInfo'
            return
        }

        #If you can't shrink the partition much, you can't reclain a lot of space, so skipping if it's not worth it. Otherwise shink partition and dismount disk
        if (($partitionsize.SizeMin / $sizeMax) -lt (1 - $RatioFreeSpace) ) {
            try {
                Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionsize.SizeMin -PartitionNumber $PartitionNumber -ErrorAction Stop
                $mount | DisMount-FslDisk -ErrorAction SilentlyContinue
            }
            catch {
                $mount | DisMount-FslDisk
                Write-VhdOutput -DiskState "PartitionShrinkFailed"
                return
            }

        }
        else {
            Write-VhdOutput -DiskState "LessThan$(100*$RatioFreeSpace)%FreeInsideDisk"
            $mount | DisMount-FslDisk
            return
        }

        #Change the disk size and grab the new size



        $retries = 0
        $success = $false
        #Diskpart is a little erratic and can fail occasionally, so stuck it in a loop.
        while ($retries -lt 30 -and $success -ne $true) {

            $tempFileName = "$env:TEMP\FslDiskPart$($Disk.Name).txt"

            #Let's put diskpart into a function just so I can use Pester to Mock it
            function invoke-diskpart ($Path) {
                #diskpart needs you to write a txt file so you can automate it, because apparently it's 1989.
                #A better way would be to use optimize-disk from the Hyper-V module,
                #   but that only comes along with installing the actual role, which needs CPU virtualisation extensions present,
                #   which is a PITA in cloud and virtualised environments where you can't do Hyper-V.
                #MaybeDo, use hyper-V module if it's there if not use diskpart? two code paths to do the same thing probably not smart though
                Set-Content -Path $Path -Value "SELECT VDISK FILE=$($Disk.FullName)"
                Add-Content -Path $Path -Value 'COMPACT VDISK'
                $result = DISKPART /s $Path
                Write-Output $result
            }

            $diskPartResult = invoke-diskpart -Path $tempFileName

            #diskpart doesn't return an object (1989 remember) so we have to parse the text output.
            if ($diskPartResult -contains 'DiskPart successfully compacted the virtual disk file.') {
                $finalSize = Get-ChildItem $Disk.FullName | Select-Object -Expandproperty Length
                $finalSizeGB = [math]::Round( $finalSize/1GB, 2 )
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
            Write-VhdOutput -DiskState "DiskShrinkFailed"
            Remove-Item $tempFileName
            return
        }

        #Now we need to reinflate the partition to its previous size
        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
            Resize-Partition -DiskNumber $mount.DiskNumber -Size $sizeMax -PartitionNumber $PartitionNumber -ErrorAction Stop
            $paramWriteVhdOutput = @{
                DiskState    = "Success"
                FinalSizeGB  = $finalSizeGB
                SpaceSavedGB = $originalSizeGB - $finalSizeGB
            }
            Write-VhdOutput @paramWriteVhdOutput
        }
        catch {
            Write-VhdOutput -DiskState "PartitionSizeRestoreFailed"
            return
        }
        finally {
            $mount | DisMount-FslDisk
        }
    } #Process
    END { } #End
}  #function Shrink-OneDisk