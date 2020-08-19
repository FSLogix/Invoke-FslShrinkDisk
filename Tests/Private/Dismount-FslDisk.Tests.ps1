BeforeAll {

    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Dismount-FslDisk" {

    BeforeAll{
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
        $Path = 'Testdrive:\NotPath'
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
        $imPath = 'Testdrive:\NotImage'
    }


    Context "Input" {
        BeforeAll {
            Mock -CommandName Dismount-DiskImage -MockWith { $null }
            Mock -CommandName Remove-Item -MockWith { $null }
        }



        It "Takes input via param" {
            Dismount-FslDisk -Path $Path -ImagePath $imPath -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Dismount-FslDisk -Path $Path -ImagePath $imPath -Passthru -ErrorAction Stop | Select-Object -ExpandProperty MountRemoved | Should -Be $true
        }

        It "Takes input via pipeline" {
            $Path | Dismount-FslDisk -ImagePath $imPath -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            [PSCustomObject]@{
                Path       = $Path
                ImagePath  = $imPath
            } | Dismount-FslDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }
    }

    Context "Function Logic" {
        BeforeAll {
            Mock -CommandName Dismount-DiskImage -MockWith { $null }
            Mock -CommandName Remove-Item -MockWith { $null }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
            $param = @{
                Path        = $Path
                ImagePath   = $imPath
                Passthru    = $true
                ErrorAction = 'Stop'
            }
        }

        It "It Reports Mount removed as true" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty MountRemoved | Should -Be $true
        }

        It "It Reports Directory removed as true" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty DirectoryRemoved | Should -Be $true
        }

        It "It writes verbose line if successful" {
            $verBoseOut = Dismount-FslDisk -Path $Path -ImagePath $imPath -Verbose -ErrorAction Stop 4>&1
            $verBoseOut | Should -Be "Dismounted $imPath"
        }

    }

    Context "Output error Directory" {

        BeforeAll {
            Mock -CommandName Dismount-DiskImage -MockWith { $null }
            Mock -CommandName Remove-Item -MockWith { Write-Error 'RemoveMock' }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
            $param = @{
                Path        = $Path
                ImagePath   = $imPath
                Passthru    = $true
                ErrorAction = 'SilentlyContinue'
            }
        }

        It "It Reports Directory removed as false" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty DirectoryRemoved | Should -Be $false
        }
    }

    Context "Output error Mount" {

        BeforeAll {
            Mock -CommandName Dismount-DiskImage -MockWith { Write-Error 'DismountMock' }
            Mock -CommandName Remove-Item -MockWith { $null }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
            $param = @{
                Path        = $Path
                ImagePath   = $imPath
                Passthru    = $true
                ErrorAction = 'SilentlyContinue'
            }
        }

        It "It Reports Mount removed as false" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty MountRemoved | Should -Be $false
        }
    }
}