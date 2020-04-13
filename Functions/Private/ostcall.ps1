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