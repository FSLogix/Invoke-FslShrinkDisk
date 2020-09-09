BeforeAll {

    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Write-VhdOutput" {

    BeforeAll {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
        $param = @{
            Path           = "TestDrive:\ICareNot.csv"
            Name           = 'Jim.vhdx'
            DiskState      = 'Amazing'
            OriginalSize = 40 * 1024  * 1024 * 1024
            FinalSize   = 1 * 1024  * 1024 * 1024
            FullName       = "TestDrive:\Jim.vhdx"
            Passthru       = $true
            Starttime      = Get-Date
            EndTime        = Get-Date.AddSeconds(20)
        }
    }

    It "Does not error" {

        Write-VhdOutput @param -ErrorAction Stop
    }

    It 'Calculates Elapsed time' {
        $r = Write-VhdOutput @param
        $r.'ElapsedTime(s)' | Should -Be 20
    }

    It 'Calculates Elapsed time' {
        $r = Write-VhdOutput @param
        $r.'ElapsedTime(s)' | Should -Be 39
    }

}