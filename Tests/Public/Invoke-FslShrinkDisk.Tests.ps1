BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace '\.Tests\.', '.'
    $here = $here | Split-Path -Parent | Split-Path -Parent
    $public = Join-Path $here 'Functions\Public'
    $script = Get-Content "$public\$sut"
    $tstdrvPath = Join-Path $public "TempInvoke-FslShrinkDisk.ps1"
    Set-Content 'function Invoke-FslShrinkDisk {' -Path $tstdrvPath
    Add-Content -Path $tstdrvPath $script
    Add-Content -Path $tstdrvPath '}'
    . "$here\Functions\Private\Invoke-Parallel.ps1"
    . "$here\Functions\Private\Mount-FslDisk.ps1"
    . "$here\Functions\Private\Dismount-FslDisk.ps1"
    . "$here\Functions\Private\Optimize-OneDisk.ps1"
    . "$here\Functions\Private\Write-VhdOutput.ps1"
    . "$here\Functions\Private\Test-FslDependencies.ps1"
    . $tstdrvPath
}

Describe 'Invoke-FslShrinkDisk' {
    BeforeAll {
        $time = [datetime]'12:00'
        $out = [PSCustomObject]@{
            Path         = 'TestDrive:\log.csv'
            StartTime    = $time
            EndTime      = $time.AddSeconds(30)
            Name         = 'FakeDisk.vhd'
            DiskState    = 'Success'
            OriginalSize = 20 * 1024 * 1024 * 1024
            FinalSize    = 3 * 1024 * 1024 * 1024
            FullName     = 'TestDrive:\FakeDisk.vhd'
            Passthru     = $true
        }
        Mock -CommandName Mount-FslDisk -MockWith {
            [PSCustomObject]@{
                Path       = 'TestDrive:\Temp\FSlogixMnt-38abe060-2cb4-4cf2-94f3-19128901a9f6'
                DiskNumber = 3
                ImagePath  = 'TestDrive:\FakeDisk.vhd'
            }
        }
        Mock -CommandName Get-CimInstance -MockWith {
            [PSCustomObject]@{
                NumberOfLogicalProcessors = 4
            }
        }
        Mock -CommandName Get-ChildItem -MockWith {
            [PSCustomObject]@{
                FullName = 'TestDrive:\FakeDisk.vhd'
                Name     = 'FakeDisk.vhd'
            }
        }
        Mock -CommandName Get-Item -MockWith {
            [PSCustomObject]@{
                Attributes = 'Archive'
            }
        }
        Mock -CommandName Test-FslDependencies -MockWith { $null }
        Mock -CommandName Dismount-FslDisk -MockWith { $null }
        Mock -CommandName Write-VhdOutput -MockWith { $null }
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Optimize-OneDisk -MockWith { $out }
        Mock -CommandName Invoke-Parallel -MockWith { $out }
        Mock -CommandName ForEach-Object -MockWith { $out }
    }

    It "Does not error" {
        Invoke-FslShrinkDisk -Path 'TestDrive:\FakeDisk.vhd' -ErrorAction Stop
    }
    It "Copes with Throttlelimit too high" {
        $result = Invoke-FslShrinkDisk -Path 'TestDrive:\FakeDisk.vhd' -PassThru -ThrottleLimit 64
        $result.DiskState | Should -Be 'Success'
    }
    It "Copes with Throttlelimit too low" {
        $result = Invoke-FslShrinkDisk -Path 'TestDrive:\FakeDisk.vhd' -PassThru -ThrottleLimit 1
        $result.DiskState | Should -Be 'Success'
    }
    It "Corrects logfile extension" {
        $result = Invoke-FslShrinkDisk -Path 'TestDrive:\FakeDisk.vhd' -PassThru -JSONFormat
        $result.DiskState | Should -Be 'Success'
    }
    It "Recursiveky searches" {
        $result = Invoke-FslShrinkDisk -Path 'TestDrive:\FakeDisk.vhd' -PassThru -Recurse
        $result.DiskState | Should -Be 'Success'
    }
}