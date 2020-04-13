$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

#Import functions so they can be used or mocked
. "$here\Functions\Private\Write-VhdOutput.ps1"
. "$here\Functions\Private\Mount-FslDisk.ps1"
. "$here\Functions\Private\Dismount-FslDisk.ps1"

Describe "Describing $($sut.Trimend('.ps1'))" {

    $disk = New-Item testdrive:\fakedisk.vhdx | Get-ChildItem
    $notDisk = New-Item testdrive:\fakeextension.vhdx.txt | Get-ChildItem

    $DeleteOlderThanDays = 90
    $IgnoreLessThanGB = $null
    $LogFilePath = 'TestDrive:\log.csv'

    Mock -CommandName Mount-FslDisk -MockWith { [PSCustomObject]@{
            Path       = 'TestDrive:\nothere.vhdx'
            DiskNumber = 4
            ImagePath  = 'Testdrive:\nopath'
        }
    }
    Mock -CommandName Get-PartitionSupportedSize -MockWith { [PSCustomObject]@{
            SizeMin = 3379200645
            SizeMax = 4668260352
        }
    }
    Mock -CommandName Get-ChildItem -MockWith { 'TestDrive:\NotDisk.vhdx' | Get-ChildItem }
    Mock -CommandName Remove-Item -MockWith { $null }
    Mock -CommandName Resize-Partition -MockWith { $null }
    Mock -CommandName DisMount-FslDisk -MockWith { $null }
    Mock -CommandName Optimize-VHD -MockWith { $null }

    Context "Input" {

        $paramShrinkOneDisk = @{
            Disk                = $disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Takes input via param" {
            Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty Name | Should -Be 'NotDisk.vhdx'
        }

        It "Takes input via pipeline for disk" {

            $paramShrinkOneDisk = @{
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                Partition           = 1
            }
            $disk | Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            $pipeShrinkOneDisk = [pscustomobject]@{
                Disk                = $disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                Partition           = 1
            }
            $pipeShrinkOneDisk | Shrink-OneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

    }

    Context "Failed delete" {

        Mock -CommandName Remove-Item -MockWith { Write-Error 'Nope' }

        $paramShrinkOneDisk = @{
            Disk                = $disk
            DeleteOlderThanDays = 0
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }


        It "Gives right output when no deletion" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'DiskDeletionFailed'
        }
    }

    Context "Not Disk" {

        $paramShrinkOneDisk = @{
            Disk                = $notDisk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Gives right output when not disk" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'FileIsNotDiskFormat'
        }
    }

    Context "Too Small" {

        $paramShrinkOneDisk = @{
            Disk                = $Disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = 5
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Gives right output disk is too small" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'Ignored'
        }
    }

    Context "Locked" {

        Mock -CommandName Mount-FslDisk -MockWith { Write-Error 'Disk in use' }

        $paramShrinkOneDisk = @{
            Disk                = $Disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Gives right output when disk is Locked" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'DiskLocked'
        }
    }

    Context "No Partition" {

        Mock -CommandName Get-PartitionSupportedSize -MockWith { Write-Error 'nope' }

        $paramShrinkOneDisk = @{
            Disk                = $Disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Gives right output when No Partition" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'NoPartitionInfo'
        }
    }

    Context "Shrink Partition Fail" {

        Mock -CommandName Resize-Partition -MockWith { Write-Error 'nope' }

        $paramShrinkOneDisk = @{
            Disk                = $Disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0.2
            Partition           = 1
        }

        It "Gives right output when Shrink Partition Fail" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'PartitionShrinkFailed'
        }
    }

    Context "No Partition Space" {

        $paramShrinkOneDisk = @{
            Disk                = $Disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            RatioFreeSpace      = 0
            Partition           = 1
        }

        It "Gives right output when No Partition Space" {
            $out = Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState
            $out | Should -Be $true
        }
    }
}
