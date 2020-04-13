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
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
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
        [string]$LogFilePath = "FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH:mm:ss).log",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [switch]$Passthru

    )

    BEGIN {
        #Requires -Module Hyper-V
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {
        #Grab size of disk being porcessed
        $originalSizeGB = [math]::Round( $Disk.Length/1GB, 2 )

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below
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
            break
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
                break
            }
        }

        #As disks take time to process, if you have a lot of disks, it may not be worth shrinking the small ones
        if ( $IgnoreLessThanGB -and $originalSizeGB -lt $IgnoreLessThanGB ) {
            Write-VhdOutput -DiskState 'Ignored'
            break
        }

        #Initial disk Mount
        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru -ErrorAction Stop
        }
        catch {
            Write-VhdOutput -DiskState 'DiskLocked'
            break
        }

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        try {
            $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -ErrorAction Stop
            $sizeMax = $partitionsize.SizeMax
        }
        catch {
            Write-VhdOutput -DiskState 'NoPartitionInfo'
            break
        }

        #If you can't shrink the partition much, you can't reclain a lot of space, so skipping if it's not worth it. Otherwise shink partition and dismount disk
        if ($partitionsize.SizeMin / $sizeMax -lt $RatioFreeSpace ) {
            try {
                Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionsize.SizeMin -PartitionNumber $PartitionNumber -ErrorAction Stop
            }
            catch {
                Write-VhdOutput -DiskState "PartitionShrinkFailed"
                break
            }
            finally {
                $mount | DisMount-FslDisk
            }

        }
        else {
            Write-VhdOutput -DiskState "LessThan$(100*$RatioFreeSpace)%InsideDisk"
            $mount | DisMount-FslDisk
            break
        }

        #Change the disk size and grab it's size
        try {
            #This is the only command we need from the Hyper-V module
            Optimize-VHD -Path $Disk.FullName -Mode Full
            $finalSize = Get-ChildItem $Disk.FullName | Select-Object -Expandproperty Length
            $finalSizeGB = [math]::Round( $finalSize/1GB, 2 )
        }
        catch {
            Write-VhdOutput -DiskState "DiskShrinkFailed"
            break
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
            Write-VhdOutput -DiskState "PartitionExpandFailed"
            break
        }
        finally {
            $mount | DisMount-FslDisk
        }
    } #Process
    END { } #End
}  #function Shrink-OneDisk