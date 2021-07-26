BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Write-VhdOutput" {

    BeforeAll {
        $time = Get-Date
        $path = 'TestDrive:\ICareNot.csv'
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
        $param = @{
            Path         = $path
            Name         = 'Jim.vhdx'
            DiskState    = 'TooBig'
            OriginalSize = 40 * 1024 * 1024 * 1024
            FinalSize    = 1 * 1024 * 1024 * 1024
            FullName     = "TestDrive:\Jim.vhdx"
            Passthru     = $true
            Starttime    = $time
            EndTime      = $time.AddSeconds(20)
        }
    }

    It "Does not error" {
        Write-VhdOutput @param -ErrorAction Stop
    }

    It 'Calculates Elapsed time' {
        $r = Write-VhdOutput @param
        $r.'ElapsedTime(s)' | Should -Be 20
    }

    It 'Calculates Space Reduction' {
        $r = Write-VhdOutput @param
        $r.SpaceSavedGB | Should -Be 39
    }

    It 'Creates a csv' {
        Write-VhdOutput @param | Out-Null
        Test-Path $path | Should -BeTrue
    }

    It 'Creates a json File' {
        Write-VhdOutput @param -JSONFormat | Out-Null
        (Get-Content $path | Measure-Object).Count | Should -Be 1
    }

    It 'Take less than a second to run' {
        (Measure-Command { Write-VhdOutput @param | Out-Null }).TotalSeconds | Should -BeLessThan 1
    }

}