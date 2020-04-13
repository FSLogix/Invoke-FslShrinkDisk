$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "D:\PoShCode\GitHub\Invoke-FslShrinkDisk\Functions\Private\Shrink-OneDisk.ps1"

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

        It "Takes input via param with passthru" {
            $arrange = Shrink-OneDisk @paramShrinkOneDisk -Passthru -ErrorAction Stop | Select-Object -ExpandProperty Name
            $arrange | Should -Be 'NotDisk.vhdx'
        }
    }
}