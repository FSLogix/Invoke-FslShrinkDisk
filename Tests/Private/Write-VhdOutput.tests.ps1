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
            OriginalSizeGB = 40
            FinalSizeGB    = 1
            FullName       = "TestDrive:\Jim.vhdx"
            Passthru       = $true
            Starttime      = Get-Date
            EndTime        = Get-Date.AddSeconds(20)
        }
    }

    It "Does not error" {

        Write-VhdOutput @param -ErrorAction Stop
    }

    It Calculates time {

    }

}