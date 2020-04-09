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

    Context "Logic" {
  
        New-Item -Path "$td\my.email.ost" -Force

        It "It doesn't do anything if only 1 ost" {
            Remove-FslMultiOst $td
            (Get-ChildItem $td).Name | should -Be "my.email.ost"
        }

        It "It removes 1 file" {
            New-Item -Path "$td\my.email(1).ost" -Force
            Remove-FslMultiOst $td
            (Get-ChildItem $td).Name | should -Be "my.email(1).ost"
        }

        It "It removes many files" {
            foreach ($i in 1..101) {
                New-Item -Path "$td\my.email($i).ost" -Force
            }            
            Remove-FslMultiOst $td
            (Get-ChildItem $td).Name | should -Be "my.email(101).ost"
        }

        It "It copes with 2 mailboxes" {
            New-Item -Path "$td\my.email.ost" -Force
            New-Item -Path "$td\my.shared.email.ost" -Force
            Remove-FslMultiOst $td
            (Get-ChildItem $td | Measure-Object).Count | should -Be 2
        }

        It "It copes with 2 mailboxes and removes files" {
            New-Item -Path "$td\my.email.ost" -Force
            New-Item -Path "$td\my.email(4).ost" -Force
            New-Item -Path "$td\my.shared.email.ost" -Force
            New-Item -Path "$td\my.shared.email(789).ost" -Force
            Remove-FslMultiOst $td
            (Get-ChildItem $td | Measure-Object).Count | should -Be 2
        }

        It "It copes with 2 mailboxes with extra files and leaves the two recent mailboxes" {
            New-Item -Path "$td\my.email.ost" -Force
            New-Item -Path "$td\my.email(4).ost" -Force
            New-Item -Path "$td\my.shared.email.ost" -Force
            New-Item -Path "$td\my.shared.email(789).ost" -Force
            Remove-FslMultiOst $td
            (Get-ChildItem $td).Name | Group-Object | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2
        }   
    }

    Context "Output" {
        It "It doesn't find the path and errors" {
            { Remove-FslMultiOst -Path $td\NotThere -ErrorAction Stop } | Should -Throw
        }

        It "It doesn't find any ost files and warns" {
            Remove-Item TestDrive:\*.ost
            { Remove-FslMultiOst -Path $td -WarningAction Stop } | Should -Throw
        }
    }

    Context "For Mocking" {
        Mock -CommandName Remove-Item { Write-Error 'Blah' }

        It "Warns if can't delete" {
            New-Item -Path "$td\my.email.ost" -Force
            New-Item -Path "$td\my.email(4).ost" -Force
            
            { Remove-FslMultiOst -Path $td -WarningAction Stop } | Should -Throw
        }
    }
}