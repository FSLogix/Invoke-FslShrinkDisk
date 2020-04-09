$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $sut.Trimend('.ps1')" {
    Context "Input" {

        It "Takes input via param" {
            Remove-FslMultiOst -Path $td | Should -BeNullOrEmpty     
        }
        It "Takes input via pipeline" {
            $td | Remove-FslMultiOst | Should -BeNullOrEmpty     
        }
        It "Takes input via named pipeline" {
            [PSCustomObject]@{
                Path = $td
            } | Remove-FslMultiOst | Should -BeNullOrEmpty     
        }
        It "Takes input positionally" {
            Remove-FslMultiOst $td | Should -BeNullOrEmpty     
        }
    }
}