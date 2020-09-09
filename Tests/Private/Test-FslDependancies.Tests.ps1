BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Test-FslDependancies" {

    Context "Input" {
        BeforeAll {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{
                    Status          = "Running"
                    StartupType     = "Disabled"
                }
            }

            Mock -CommandName Set-Service -MockWith {
                $null
            }

            Mock -CommandName Start-Service -MockWith {
                $null
            }

            Mock -CommandName Get-CimInstance -MockWith {
                [PSCustomObject]@{
                    NumberOfCores       = 1
                }
            }
        }

        It "Takes input via param" {
            Test-FslDependancies -Service NullService | Should -be 1
        }

        It "Takes input via pipeline" {
            "NullService" | Test-FslDependancies | Should -be 1
        }
    }
}