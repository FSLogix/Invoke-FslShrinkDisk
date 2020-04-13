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
        $originalSizeGB = [math]::Round($Disk.Length/1GB, 2)

        $PSDefaultParameterValues = @{"Write-VhdOutput:Path" = $LogFilePath }
        $PSDefaultParameterValues = @{"Write-VhdOutput:Name" = $Disk.Name }
        $PSDefaultParameterValues = @{"Write-VhdOutput:OriginalSizeGB" = $originalSizeGB }
        $PSDefaultParameterValues = @{"Write-VhdOutput:FinalSizeGB" = $originalSizeGB }
        $PSDefaultParameterValues = @{"Write-VhdOutput:SpaceSavedGB" = 0 }
        $PSDefaultParameterValues = @{"Write-VhdOutput:FullName" = $Disk.FullName }
        $PSDefaultParameterValues = @{"Write-VhdOutput:Passthru" = $Passthru }

        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            Write-VhdOutput -DiskState 'FileIsNotDiskFormat'
            break
        }


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

        if ( $IgnoreLessThanGB -and $originalSizeGB -lt $IgnoreLessThanGB ) {
            Write-VhdOutput -DiskState 'Ignored'
            break
        }

        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru -ErrorAction Stop
        }
        catch {
            Write-VhdOutput -DiskState 'DiskLocked'
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
            Write-VhdOutput -DiskState 'NoPartitionInfo'
            break
        }

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

        try {
            #This is the only command we need from the Hyper-V module
            Optimize-VHD -Path $Disk.FullName -Mode Full
            $finalSize = Get-ChildItem $Disk.FullName | Select-Object -Expandproperty Length
        }
        catch {
            Write-VhdOutput -DiskState "DiskShrinkFailed"
            break
        }

        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
            Resize-Partition -DiskNumber $mount.DiskNumber -Size $sizeMax -PartitionNumber $PartitionNumber -ErrorAction Stop
            $finalSizeGB = [math]::Round($finalSize/1GB, 2)
            Write-VhdOutput -DiskState "Success" -FinalSizeGB $finalSizeGB -SpaceSavedGB $originalSizeGB - $finalSizeGB
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