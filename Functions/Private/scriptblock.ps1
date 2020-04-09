Param ( $disk )

$PSDefaultParameterValues = @{ "Write-Log:Path" = $LogFilePath }

switch ($true) {
    $DeleteOlderThanDays {
        if ($disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) { 
            try {
                Remove-Item -ErrorAction Stop
            }
            catch {
                Write-Log -Level Error "Could Not Delete $disk"
            }
        }
        break 
    }
    $IgnoreLessThanGB {
        if ($disk.size -lt $IgnoreLessThanGB) {
            Write-Log "$disk smaller than $IgnoreLessThanGB no action taken"
            break
        }
    }
    Default {
        try {
            $mount = Mount-FslDisk -Path $disk -PassThru

            Remove-FslMultiOst -Path $mount.Path

            $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber

            if ($partitionsize.SizeMin / $partitionsize.SizeMax -lt 0.8 ) {
                Resize-Partition -DiskNumber $mount.DiskNumber -Size $n.SizeMin 
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
                Write-Log "$disk not resized due to insufficient free space"
            }
        }
        catch {
            $error[0] | Write-Log
            Write-Log -Level Error "Could not resize $disk"
        }                
    }
}