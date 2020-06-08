BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"
}

Describe "Describing Mount-FslDisk" {

    BeforeAll{
        $Path = 'TestDrive:\ThisDoesNotExist.vhdx'

        Mock -CommandName Mount-DiskImage -MockWith {
            [pscustomobject]@{
                Attached              = $True
                BlockSize             = 33554432
                DevicePath            = '\\.\PhysicalDrive4'
                FileSize              = 4668260352
                ImagePath             = $Path
                LogicalSectorSize     = 512
                Number                = 4
                Size                  = 31457280000
                StorageType           = 3
                PSComputerName        = $null
                CimClass              = 'ROOT/Microsoft/Windows/Storage:MSFT_DiskImage'
                CimInstanceProperties = '{ Attached, BlockSize, DevicePath, FileSize… }'
                CimSystemProperties   = 'Microsoft.Management.Infrastructure.CimSystemProperties'
                PSTypeName            = 'Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Storage/MSFT_DiskImage'
            }
        }
        Mock -CommandName Get-DiskImage -MockWith {
            [pscustomobject]@{
                Attached          = $True
                BlockSize         = 33554432
                DevicePath        = '\\.\PhysicalDrive4'
                FileSize          = 4668260352
                ImagePath         = $Path
                LogicalSectorSize = 512
                Number            = 4
                Size              = 31457280000
                StorageType       = 3
                PSComputerName    = $null
                PSTypeName        = 'Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Storage/MSFT_DiskImage'
            }
        }
        Mock -CommandName Get-Partition -MockWith {
            [pscustomobject]@{
                PartitionNumber = 1
                Offset          = 0
                Type            = 'Basic'
                Size            = 31457280000
                PSComputerName  = $null
                PSTypeName      = 'Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Storage/MSFT_Partition'
            }
        }
    }

    Context "Input" {

        BeforeAll {
            Mock -CommandName New-Item -MockWith { $null }
            Mock -CommandName Dismount-DiskImage -MockWith { $null }
            Mock -CommandName Add-PartitionAccessPath -MockWith { $null }
            Mock -CommandName Remove-Item -MockWith { $null }
            Mock -CommandName Join-Path -MockWith { 'TestDrive:\mountHere' }
        }

        It "Takes input via param" {
            Mount-FslDisk -Path $Path -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Mount-FslDisk -Path $Path -Passthru -ErrorAction Stop | Select-Object -ExpandProperty ImagePath | Should -Be $Path
        }

        It "Takes input via param Alias" {
            Mount-FslDisk -FullName $Path -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via pipeline" {
            $Path | Mount-FslDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            [PSCustomObject]@{
                Path = $Path
            } | Mount-FslDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline alias" {
            [PSCustomObject]@{
                FullName = $Path
            } | Mount-FslDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input positionally" {
            Mount-FslDisk $Path -ErrorAction Stop | Should -BeNullOrEmpty
        }
    }

    Context "Logic" {

        BeforeAll {
            Mock -CommandName New-Item -MockWith { $null }
            Mock -CommandName Dismount-DiskImage -MockWith { $null }
            Mock -CommandName Add-PartitionAccessPath -MockWith { $null }
            Mock -CommandName Remove-Item -MockWith { $null }
            Mock -CommandName Join-Path -MockWith { 'TestDrive:\mountHere' }
        }


        It "It produces a mount path" {
            Mount-FslDisk -Path $Path -Passthru -ErrorAction Stop | Select-Object -ExpandProperty ImagePath | Should -Be $path
        }

        It "It produces a disknumber" {
            Mount-FslDisk -Path $Path -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskNumber | Should -Be 4
        }

        It "It produces a Path" {
            Mount-FslDisk -Path $Path -Passthru -ErrorAction Stop | Select-Object -ExpandProperty Path | Should -Be 'TestDrive:\mountHere'
        }
    }
}