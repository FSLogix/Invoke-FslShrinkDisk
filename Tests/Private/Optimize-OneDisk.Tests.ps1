[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
Param()

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

Describe "Describing Optimize-OneDisk" {

    BeforeAll {
        Copy-Item "$here\Tests\LanguageResultsForDiskPart\English.txt" "Testdrive:\notdisk.vhdx"
        Copy-Item "$here\Tests\LanguageResultsForDiskPart\English.txt" "Testdrive:\SizeDelete.vhdx"
        Copy-Item "$here\Tests\LanguageResultsForDiskPart\English.txt" "Testdrive:\DeleteFail.vhdx"
        $disk = Get-ChildItem "Testdrive:\notdisk.vhdx"
        $deleteFail = Get-ChildItem "Testdrive:\DeleteFail.vhdx"
        $notDisk = New-Item testdrive:\fakeextension.vhdx.txt | Get-ChildItem
        $IgnoreLessThanGB = $null
        $LogFilePath = 'TestDrive:\log.csv'
        $guid = '129c832f-846f-4937-bb64-2d456d2c7d04'
        $SizeMax = 4668260352
        $SizeMin = 1
        $english = Get-Content "$here\Tests\LanguageResultsForDiskPart\English.txt"
        $french = Get-Content "$here\Tests\LanguageResultsForDiskPart\French.txt"
        $spanish = Get-Content "$here\Tests\LanguageResultsForDiskPart\Spanish.txt"
        $german = Get-Content "$here\Tests\LanguageResultsForDiskPart\German.txt"

        Mock -CommandName Mount-FslDisk -MockWith { [PSCustomObject]@{
                Path            = 'TestDrive:\nothere.vhdx'
                DiskNumber      = 4
                ImagePath       = 'Testdrive:\nopath'
                PartitionNumber = 1
            }
        }
        Mock -CommandName Get-PartitionSupportedSize -MockWith { [PSCustomObject]@{
                SizeMin = $SizeMin
                SizeMax = $SizeMax
            }
        }
        Mock -CommandName Get-ChildItem -MockWith { $disk }
        Mock -CommandName Remove-Item -MockWith { $null }
        Mock -CommandName Resize-Partition -MockWith { $null } -ParameterFilter { $Size -ne $SizeMax }
        Mock -CommandName Resize-Partition -MockWith { $null }
        Mock -CommandName DisMount-FslDisk -MockWith { $null }
        Mock -CommandName Start-Sleep -MockWith { $null }
        Mock -CommandName invoke-diskpart -MockWith { $english }
        Mock -CommandName Get-Partition -MockWith { [PSCustomObject]@{
                Type = 'Basic'
                Guid = $guid
            } }
        Mock -CommandName Get-Volume -MockWith { [PSCustomObject]@{
                UniqueId = $guid
                ObjectId = $guid
            }
        }
        Mock -CommandName Optimize-Volume -MockWith { $null }

    }

    Context "Input" {
        BeforeAll {

            $paramShrinkOneDisk = @{
                Disk                = $notdisk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
        }

        It "Takes input via param" {
            Optimize-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty Name | Should -Be 'fakeextension.vhdx.txt'
        }

        It "Takes input via pipeline for disk" {

            $paramShrinkOneDisk = @{
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            $notdisk | Optimize-OneDisk @paramShrinkOneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            $pipeShrinkOneDisk = [pscustomobject]@{
                Disk                = $notdisk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }
            $pipeShrinkOneDisk | Optimize-OneDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }

    }

    Context "Works in Other Languages" {
        BeforeAll {
            Mock -CommandName Get-Partition -MockWith { [PSCustomObject]@{
                    Type            = 'Basic'
                    Guid            = $guid
                    DiskNumber      = 6
                    PartitionNumber = 8
                } }
            Mock -CommandName Get-PartitionSupportedSize -MockWith {
                [PSCustomObject]@{
                    SizeMin = $SizeMin
                    SizeMax = $SizeMax
                }
            }
            Mock -CommandName Get-Volume -MockWith { [PSCustomObject]@{
                    Path     = $guid
                    UniqueId = $guid
                    ObjectId = $guid
                } }
            Mock -CommandName Optimize-Volume -MockWith { 'test' }
        }

        It "Works in French" {
            Mock -CommandName invoke-diskpart -MockWith { $french }
            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                Passthru            = $true
                GeneralTimeout      = 60
            }
            Optimize-OneDisk @paramShrinkOneDisk | Select-Object -ExpandProperty DiskState | Should -Be 'No Shrink Achieved'
        }

        It "Works in Spanish" {
            Mock -CommandName invoke-diskpart -MockWith { $spanish }
            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                Passthru            = $true
                GeneralTimeout      = 60
            }
            Optimize-OneDisk @paramShrinkOneDisk | Select-Object -ExpandProperty DiskState | Should -Be 'No Shrink Achieved'
        }

        It "Works in German" {
            Mock -CommandName invoke-diskpart -MockWith { $german }
            $paramShrinkOneDisk = @{
                Disk                = $Disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                Passthru            = $true
                GeneralTimeout      = 60
            }
            Optimize-OneDisk @paramShrinkOneDisk | Select-Object -ExpandProperty DiskState | Should -Be 'No Shrink Achieved'
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

            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'File Is Not a Virtual Hard Disk format with extension vhd or vhdx'
        }
    }

    Context "Disk Deleted" {

        It "Deletes a small disk" {

            $paramShrinkOneDisk = @{
                Disk                = $deleteFail
                DeleteOlderThanDays = 1
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                GeneralTimeout      = 1
            }

            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be 'Disk Deleted'
        }

        It "Analyzes a small disk deletion" {

            $paramShrinkOneDisk = @{
                Disk                = $deleteFail
                DeleteOlderThanDays = 1
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
                GeneralTimeout      = 1
                Analyze             = $true
            }

            $result = Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop
            $result.DiskState | Should -Be 'Analyze'
            $result.FinalSizeGB | Should -Be 0

        }
    }

    Context "Disk Deletion Failed" {

        It "Gives right output when no deletion" {

            $disk.LastAccessTime = (Get-Date).AddDays(-2)

            Mock -CommandName Remove-Item -MockWith { Write-Error 'Nope' }

            $paramShrinkOneDisk = @{
                Disk                = $disk
                DeleteOlderThanDays = 1
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                RatioFreeSpace      = 0.2
            }

            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty DiskState | Should -Be 'Disk Deletion Failed'
        }
    }

    Context "Too Small" {

        It "Gives right output disk is too small" {
            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = 5
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
            }

            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "Disk Ignored as it is smaller than*"
        }

        It "Gives right output disk is too small" {
            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = 5
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                Analyze          = $true
            }

            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "Disk Ignored as it is smaller than*"
        }
    }

    Context "Initial Disk Mount" {

        It "Gives right output when disk fails to mount" {
            $errtxt = 'Disk in use'
            Mock -CommandName Mount-FslDisk -MockWith { Write-Error $errtxt }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be $errtxt
        }
    }

    Context "No Partition" {

        It "Gives right output when No Partition" {

            Mock -CommandName Get-Partition -MockWith { Write-Error 'Nope' }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "No Partition Information*"
        }
    }

    Context "Defrag Disk" {

        It "Gives right output when defragmentation of the disk failed" {

            Mock -CommandName Optimize-Volume -MockWith { Write-Error 'NoDefrag' }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be 'Defragmentation of the disk failed'
        }
    }

    Context "Partition Size" {

        It "Gives right output when no Supported Size Info for partition" {

            Mock -CommandName Get-PartitionSupportedSize -MockWith { Write-Error 'NoPartSize' }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 2
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "No Supported Size Info for partition - Disk may be corrupt*"
        }
    }

    Context "Skipped already min" {

        It "Skips Disk if size is current minimum" {

            Mock -CommandName Get-PartitionSupportedSize -MockWith { [PSCustomObject]@{
                    SizeMin = 1048576
                    SizeMax = $SizeMax
                }
            }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be 'Skipped - Disk Already at Minimum Size'
        }
    }

    Context "Less than ratio free" {

        It "Skips Disk if Ratio of free space isn't enough to justify shrink" {

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 1
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "Less Than *% Free Inside Disk"
        }
    }

    Context "DiskPart Failed" {

        It "Gives right output when Diskpart doesn't shrink disk" {
            Mock -CommandName invoke-diskpart -MockWith { $null }
            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.1
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -BeLike "Disk Shrink Failed"
        }
    }

    Context "Did not shrink" {

        It "Doesn't say success if no shrink happened" {

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be "No Shrink Achieved"
        }
    }

    Context "Analyze"{
        It "Returns Analyze in the Object" -Tag 'Current' {
            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
                Analyze = $true
            }
            Optimize-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be "Analyze"
        }
    }

    Context "Output" {
        BeforeAll {

            Mock -CommandName Get-ChildItem -MockWith { [PSCustomObject]@{
                    Length = 1
                }
            }

            $paramShrinkOneDisk = @{
                Disk             = $Disk
                IgnoreLessThanGB = $IgnoreLessThanGB
                LogFilePath      = $LogFilePath
                RatioFreeSpace   = 0.2
                GeneralTimeout   = 1
            }

        }

        It "Gives right output when Shink Successful" {
            Optimize-OneDisk @paramShrinkOneDisk -LogFilePath $LogFilePath -Passthru -Disk $Disk -ErrorAction Stop |
            Select-Object -ExpandProperty DiskState |
            Should -Be 'Success'
        }

        It "Gives right output when Analyze Successful" {
            Optimize-OneDisk @paramShrinkOneDisk -LogFilePath $LogFilePath -Passthru -Disk $Disk -ErrorAction Stop -Analyze |
            Select-Object -ExpandProperty DiskState |
            Should -Be 'Analyze'
        }

        It "Saves correct information in a csv" {
            Optimize-OneDisk @paramShrinkOneDisk -Disk $Disk -ErrorAction Stop -LogFilePath 'TestDrive:\OutputTest.csv'
            Import-Csv 'TestDrive:\OutputTest.csv' | Select-Object -ExpandProperty DiskState | Should -Be 'Success'
        }

        It "Appends information in a csv" {
            Optimize-OneDisk @paramShrinkOneDisk -ErrorAction Stop -LogFilePath 'TestDrive:\AppendTest.csv' -Disk $Disk
            Optimize-OneDisk @paramShrinkOneDisk -ErrorAction Stop -LogFilePath 'TestDrive:\AppendTest.csv' -Disk $NotDisk
            Import-Csv 'TestDrive:\AppendTest.csv' | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2
        }
    }
}
