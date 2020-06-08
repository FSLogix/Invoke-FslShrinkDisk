BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $funcType = Split-Path $here -Leaf
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    . "$here\Functions\$funcType\$sut"

    #Import functions so they can be used or mocked
    . "$here\Functions\Private\Write-VhdOutput.ps1"
    . "$here\Functions\Private\Mount-FslDisk.ps1"
    . "$here\Functions\Private\Dismount-FslDisk.ps1"

    #Adding enpty function so that the mock works
    function invoke-diskpart ($Path) {

    }

}



Describe "Describing $($sut.Trimend('.ps1'))" {

    BeforeAll {
        $disk = New-Item testdrive:\fakedisk.vhdx | Get-ChildItem
        $notDisk = New-Item testdrive:\fakeextension.vhdx.txt | Get-ChildItem
        $DeleteOlderThanDays = 90
        $IgnoreLessThanGB = $null
        $LogFilePath = 'TestDrive:\log.csv'
        $SizeMax = 4668260352

        Mock -CommandName Mount-FslDisk -MockWith { [PSCustomObject]@{
                Path       = 'TestDrive:\nothere.vhdx'
                DiskNumber = 4
                ImagePath  = 'Testdrive:\nopath'
            }
        }
        Mock -CommandName Get-PartitionSupportedSize -MockWith { [PSCustomObject]@{
                SizeMin = 3379200645
                SizeMax = $SizeMax
            }
        }
        Mock -CommandName Get-ChildItem -MockWith { $disk }
        Mock -CommandName Remove-Item -MockWith { $null }
        Mock -CommandName Resize-Partition -MockWith { $null } -ParameterFilter { $Size -ne $SizeMax }
        Mock -CommandName Resize-Partition -MockWith { $null }
        Mock -CommandName DisMount-FslDisk -MockWith { $null }
        Mock -CommandName Start-Sleep -MockWith { $null }
    }



    Context "Input" {
        BeforeAll{
            $paramShrinkOneDisk = @{
                Disk                = $notdisk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
        }

        It "Takes input via param" {
            Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty Name | Should -Be 'fakeextension.vhdx.txt'
        }

        It "Takes input via pipeline for disk" {

            $paramShrinkOneDisk = @{
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            $notdisk | Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            $pipeShrinkOneDisk = [pscustomobject]@{
                Disk                = $notdisk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            $pipeShrinkOneDisk | Shrink-OneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

    }

    Context "Failed delete" {

        BeforeAll {
            Mock -CommandName Remove-Item -MockWith { Write-Error 'Nope' }
            Mock -CommandName Get-Partition -MockWith { $null }
            Mock -CommandName Get-Volume -MockWith { $null }
            Mock -CommandName Optimize-Volume -MockWith { $null }

            $disk.LastAccessTime = (Get-Date).AddDays(-2)

            $paramShrinkOneDisk = @{
                Disk                = $disk
                DeleteOlderThanDays = 1
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
        }

        It "Gives right output when no deletion" -Skip {
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'DiskDeletionFailed'
        }
    }

    Context "Not Disk" {

        It "Gives right output when not disk" {
            $paramShrinkOneDisk = @{
                Disk                = $notDisk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }

            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'FileIsNotDiskFormat'
        }
    }

    Context "Too Small" {

        It "Gives right output disk is too small" {
            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = 5
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }

            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'Ignored'
        }
    }

    Context "Locked" {

        It "Gives right output when disk is Locked" {
            Mock -CommandName Mount-FslDisk -MockWith { Write-Error 'Disk in use' }

            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'DiskLocked'
        }
    }

    Context "No Partition" {

        It "Gives right output when No Partition" -Skip {
            Mock -CommandName Get-PartitionSupportedSize -MockWith { Write-Error 'Nope' }
            Mock -CommandName Get-Partition -MockWith { $null }
            Mock -CommandName Get-Volume -MockWith { $null }
            Mock -CommandName Optimize-Volume -MockWith { $null }

            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'NoPartitionInfo'
        }
    }

    Context "Shrink Partition Fail" {

        It "Gives right output when Shrink Partition Fail" -Skip {

            Mock -CommandName Resize-Partition -MockWith { Write-Error 'Nope' } -ParameterFilter { $Size -ne $SizeMax }

            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'PartitionShrinkFailed'
        }
    }

    Context "No Partition Space" {

        It "Gives right output when No Partition Space" -Skip {
            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.5
            }

            $out = Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState
            $out | Should -Be LessThan$(100*$paramShrinkOneDisk.RatioFreeSpace)%FreeInsideDisk
        }
    }

    Context "Shrink Disk Fail" {

        It "Gives right output when Shrink Disk Fail" -Skip {

            Mock -CommandName invoke-diskpart -MockWith { $null }

            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'DiskShrinkFailed'
        }
    }

    Context "Restore Partition size Fail" {

        It "Gives right output when estore Partition size Fail" -Skip {
            Mock -CommandName Resize-Partition -MockWith { Write-Error 'nope' } -ParameterFilter { $Size -eq $SizeMax }
            Mock -CommandName invoke-diskpart -MockWith { , 'DiskPart successfully compacted the virtual disk file.' }

            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'PartitionSizeRestoreFailed'
        }
    }

    Context "Output" {
        BeforeAll{
            Mock -CommandName Resize-Partition -MockWith { $null } -ParameterFilter { $Size -eq $SizeMax }
            Mock -CommandName invoke-diskpart -MockWith { , 'DiskPart successfully compacted the virtual disk file.' }

            $paramShrinkOneDisk = @{
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                RatioFreeSpace      = 0.2
            }

        }

        It "Gives right output when Shink Successful" -Skip {
            Shrink-OneDisk @paramShrinkOneDisk -LogFilePath $LogFilePath -Passthru -Disk $Disk -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'Success'
        }

        It "Saves correct information in a csv" -Skip {
            Shrink-OneDisk @paramShrinkOneDisk -Disk $Disk -ErrorAction Stop -LogFilePath 'TestDrive:\OutputTest.csv'
            Import-Csv 'TestDrive:\OutputTest.csv' | Select-Object -ExpandProperty DiskState | Should -Be 'Success'
        }

        It "Appends information in a csv" -Skip {
            Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop -LogFilePath 'TestDrive:\AppendTest.csv' -Disk $Disk
            Shrink-OneDisk @paramShrinkOneDisk -ErrorAction Stop -LogFilePath 'TestDrive:\AppendTest.csv' -Disk $NotDisk
            Import-Csv 'TestDrive:\AppendTest.csv' | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2
        }
    }
}
