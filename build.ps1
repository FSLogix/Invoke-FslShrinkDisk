#DO NOT USE THIS EXCEPT FOR CREATING THE FINAL SCRIPT


function Add-FslRelease {
    [cmdletbinding()]
    param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$FunctionsFolder = '.\Functions',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ReleaseFile,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ControlScript
    )

    $ctrlScript = Get-Content -Path $ControlScript

    $funcs = Get-ChildItem $FunctionsFolder -File | Where-Object { $_.Name -ne $ControlScript }

    foreach ($funcName in $funcs) {

        $pattern = "#$($funcName.BaseName)"
        $pattern = ". .\Functions\Private\$($funcName.BaseName)"
        $actualFunc = Get-Content $funcName.FullName

        $ctrlScript = $ctrlScript | Foreach-Object {

            if ($_ -like "*$pattern*" ) {
                $actualFunc
            }
            else {
                $_
            }
        }
    }
    $ctrlScript | Set-Content $ReleaseFile
}
$path = 'C:\PoShCode\Invoke-FslShrinkDisk'
$p = @{
    
    FunctionsFolder = Join-Path $path 'Functions\Private'
    ReleaseFile     = Join-Path $path 'Invoke-FslShrinkDisk.ps1'
    ControlScript   = Join-Path $path 'Functions\Public\Invoke-FslShrinkDisk.ps1'
}

Add-FslRelease @p