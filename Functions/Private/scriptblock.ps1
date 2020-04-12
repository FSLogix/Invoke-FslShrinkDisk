function diskactions {

    Param ( $disk )

    $PSDefaultParameterValues = @{ "Write-Log:Path" = $LogFilePath }

    #$originalSize = #ToDo

    switch ($true) {
        $DeleteOlderThanDays {
            if ($disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item -ErrorAction Stop
                    <#
                $logParam = @{
                    $action       = 'Delete'
                    $level        = 'Info'
                    $message      = "$disk was deleted as it was older than $DeleteOlderThanDays days"
                    $originalSize =
                    $finalSize = 0
                    $spaceSaved   = $originalSize - $finalSize
                }
                Write-Log @logParam
                #>
                }
                catch {
                    <#
                $action = 'Delete'
                $level = 'Error'
                $message = "$disk was not deleted"
                $originalSize =
                $finalSize =
                $spaceSaved = $originalSize - $finalSize
                #>
                    #Write-Log -Level Error "Could Not Delete $disk"
                }
            }
            break
        }
        $IgnoreLessThanGB {
            if ($disk.size -lt $IgnoreLessThanGB) {
                #$action = 'Ignore'
                #Write-Log "$disk smaller than $IgnoreLessThanGB no action taken"
                break
            }
        }
        Default {
            try {
                $mount = Mount-FslDisk -Path $disk -PassThru

                Remove-FslMultiOst -Path $mount.Path

                $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber

                if ($partitionsize.SizeMin / $partitionsize.SizeMax -lt 0.8 ) {
                    Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionsize.SizeMin
                    $mount | DisMount-FslDisk
                    Resize-VHD $disk -ToMinimumSize
                    Optimize-VHD $disk
                    #Resize-VHD $Disk -SizeBytes 62914560000
                    $mount = Mount-FslDisk -Path $disk -PassThru
                    $partitionInfo = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber
                    Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionInfo.SizeMax
                    $mount | DisMount-FslDisk
                }
                else {
                    $mount | DisMount-FslDisk
                    Write-Log "$disk not resized due to insufficient free space inside disk"
                }
            }
            catch {
                $error[0] | Write-Log
                Write-Log -Level Error "Could not resize $disk"
            }
        }
    }
}