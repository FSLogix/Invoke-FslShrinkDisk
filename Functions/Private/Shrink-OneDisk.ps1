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
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [Int]$IgnoreLessThanGB,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [double]$RatioFreeSpace = 0.2,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [double]$PartitionNumber = 1
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -Module Hyper-V
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {
        $originalSizeGB = $Disk.Length/1GB
        $output = [PSCustomObject]@{
            Name           = $Disk.Name
            DiskState      = $null
            OriginalSizeGB = $originalSizeGB
            FinalSizeGB    = $originalSizeGB
            SpaceSavedGB   = 0
            FullName       = $Disk.FullName
        }

        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            $output.DiskState = 'FileIsNotDiskFormat'
            Write-Output $output
            break
        }


        If ( $DeleteOlderThanDays ) {
            if ($Disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    $output.DiskState = 'Deleted'
                    $output.FinalSizeGB = 0
                    $output.SpaceSavedGB = $originalSizeGB - $output.FinalSizeGB
                }
                catch {
                    $output.DiskState = 'DiskDeletionFailed'
                    Write-Output $output
                }
                break
            }
        }

        if ( $IgnoreLessThanGB -and $originalSizeGB -lt $IgnoreLessThanGB ) {
            $output.DiskState = 'Ignored'
            Write-Output $output
            break
        }

        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru -ErrorAction Stop
        }
        catch {
            $output.DiskState = 'DiskLocked'
            Write-Output $output
            break
        }

        #Check for orphaned ost files inside disks
        $profileDiskOstPath = Join-Path $mount.Path 'Profile\AppData\Local\Microsoft\Outlook'
        $officeDiskOstPath = Join-Path $mount.Path 'ODFC\Outlook'
        switch ($true) {
            { Test-Path $profileDiskOstPath } {
                Remove-FslMultiOst $profileDiskOstPath
                break
            }
            { Test-Path $officeDiskOstPath } {
                Remove-FslMultiOst $profileDiskOstPath
                break
            }
        }

        try {
            $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -ErrorAction Stop
            $sizeMax = $partitionsize.SizeMax
        }
        catch {
            $output.DiskState = 'NoPartitionInfo'
            Write-Output $output
            break
        }

        if ($partitionsize.SizeMin / $sizeMax -lt $RatioFreeSpace ) {
            try {
                Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionsize.SizeMin -PartitionNumber $PartitionNumber -ErrorAction Stop
            }
            catch {
                $output.DiskState = "PartitionShrinkFailed"
                Write-Output $output
                break
            }
            finally {
                $mount | DisMount-FslDisk
            }

        }
        else {
            $output.DiskState = "LessThan$(100*$RatioFreeSpace)%InsideDisk"
            Write-Output $output
            $mount | DisMount-FslDisk
            break
        }

        try {
            #This is the only command we need from the Hyper-V module
            Optimize-VHD -Path $Disk.FullName -Mode Full
            $finalSize = Get-ChildItem $Disk.FullName | Select-Object -Expandproperty Length
        }
        catch {
            $output.DiskState = "DiskShrinkFailed"
            Write-Output $output
            break
        }

        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
            Resize-Partition -DiskNumber $mount.DiskNumber -Size $sizeMax -PartitionNumber $PartitionNumber -ErrorAction Stop
            $output.DiskState = "Success"
            $output.FinalSizeGB = $finalSize/1GB
            $output.SpaceSavedGB = $originalSizeGB - $output.FinalSizeGB
            Write-Output $output
        }
        catch {
            $output.DiskState = "PartitionExpandFailed"
            Write-Output $output
            break
        }
        finally {
            $mount | DisMount-FslDisk
        }
    } #Process
    END { } #End
}  #function Shrink-OneDisk