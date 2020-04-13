$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $($sut.Trimend('.ps1'))" {

    It "Does not error" {

        $param = @{
            Path           = "TestDrive:\ICareNot.csv"
            Name           = 'Jim.vhdx'
            DiskState      = 'Amazing'
            OriginalSizeGB = 40
            FinalSizeGB    = 1
            SpaceSavedGB   = 39
            FullName       = "TestDrive:\Jim.vhdx"
            Passthru       = $true
        }
        Write-VhdOutput @param -ErrorAction Stop
    }

}