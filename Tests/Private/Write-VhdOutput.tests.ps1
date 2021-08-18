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
        $path1 = 'TestDrive:\ICareNot1.csv'
        Write-VhdOutput @param -JSONFormat -Path $path1 | Out-Null
        (Get-Content $path1 | Measure-Object).Count | Should -Be 1
    }

    It 'Appends to a json File' {
        $path2 = 'TestDrive:\ICareNot2.csv'
        Write-VhdOutput @param -JSONFormat -Path $path2 | Out-Null
        Write-VhdOutput @param -JSONFormat -Path $path2 | Out-Null
        (Get-Content $path2 | Measure-Object).Count | Should -Be 2
    }

    It 'Appends to a csv File' {
        $path3 = 'TestDrive:\ICareNot3.csv'
        Write-VhdOutput @param -Path $path3 | Out-Null
        Write-VhdOutput @param -Path $path3 | Out-Null
        (Get-Content $path3 | Measure-Object).Count | Should -Be 3
    }

    It 'Take less than a second to run' {
        (Measure-Command { Write-VhdOutput @param | Out-Null }).TotalSeconds | Should -BeLessThan 1
    }

}