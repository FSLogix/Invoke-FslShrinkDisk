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

$p = @{
    FunctionsFolder = 'D:\PoShCode\GitHub\Invoke-FslShrinkDisk\Functions\Private'
    ReleaseFile     = 'D:\PoShCode\GitHub\Invoke-FslShrinkDisk\Invoke-FslShrinkDisk.ps1'
    ControlScript   = 'D:\PoShCode\GitHub\Invoke-FslShrinkDisk\Functions\Public\Invoke-FslShrinkDisk.ps1'
}

Add-FslRelease @p