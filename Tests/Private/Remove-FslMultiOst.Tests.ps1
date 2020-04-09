$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $sut.Trimend('.ps1')" {
        $td = 'Testdrive:\'
    Context "Input" {

        New-Item -Path Testdrive:\mailbox.ost

        It "Takes input via param" {
            Remove-FslMultiOst -Path Testdrive:\mailbox.ost | Should -BeNullOrEmpty     
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

    Context "Logic" {
        New-Item -Path "$td\mailbox.ost"

        
        It "It removes 1 file" {
            New-Item -Path "$td\mailbox(1).ost"
            Remove-FslMultiOst $td
            (Get-ChildItem 'Testdrive:\' | Measure-Object).Count | should -Be 1
        }
    }
}