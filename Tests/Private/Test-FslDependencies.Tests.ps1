BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Test-FslDependencies" {

    BeforeAll {
        Mock -CommandName Set-Service -MockWith {
            $null
        }
        Mock -CommandName Start-Service -MockWith {
            $null
        }
    }

    Context "Input" {
        BeforeAll {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{
                    Status      = "Running"
                    StartupType = "Disabled"
                }
            }
        }

        It "Takes input via param" {
            Test-FslDependencies -Service NullService | Should -BeNullOrEmpty
        }

        It "Takes input via pipeline" {
            "NullService" | Test-FslDependencies | Should -BeNullOrEmpty
        }

        It "Takes multiple services as parameter input" {
            Test-FslDependencies -Service "NullService", 'NotService' | Should -BeNullOrEmpty
        }

        It "Takes multiple services as pipeline input" {
            "NullService", 'NotService' | Test-FslDependencies | Should -BeNullOrEmpty
        }
    }

    Context "Logic" {
        BeforeAll {
            Mock -CommandName Get-Service -MockWith {
                [PSCustomObject]@{
                    Status      = "Stopped"
                    StartType = "Disabled"
                }
            }
        }

        It "Sets to manual" {

            Test-FslDependencies -Service NullService | Should -BeNullOrEmpty
        }
    }
}