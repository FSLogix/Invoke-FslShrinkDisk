$targetPath = 'C:\TestVHD'

Remove-Item $targetPath -Recurse -Force

New-Item -ItemType Directory $targetPath

Measure-Command -Expression {

    foreach ($num in (1..500)) {
        $folderName = 'User' + $num

        $folder = Join-Path $targetPath $folderName

        New-Item -ItemType Directory $folder

        $fileName = '-filename ' + "$folder\$folderName.vhdx"
        $label = '-label ' + $folderName

        Start-Process -FilePath "C:\Program Files\FSLogix\Apps\frx.exe" -ArgumentList 'create-vhd', $fileName, '-size-mbs 1024', $label -NoNewWindow
        Start-Sleep 1
    }

}