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
        [Int]$RatioFreeSpace = 0.2
    )

    BEGIN {
        Set-StrictMode -Version Latest
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


        If ( $DeleteOlderThanDays ) {
            if ($Disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    $output.DiskState = 'Deleted'
                    $output.FinalSizeGB = 0
                    $output.SpaceSavedGB = $originalSizeGB - $output.FinalSizeGB
                }
                catch {
                    $output.DiskState = 'DeletionFailed'
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

        if (Test-Path 'odfc') {
            Remove-FslMultiOst -Path $mount.Path
        }

        if (Test-Path 'Profile') {
            Remove-FslMultiOst -Path $mount.Path
        }


        $mount | Dismount-FslDisk







    } #Process
    END { } #End
}  #function Shrink-OneDisk