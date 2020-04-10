$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $($sut.Trimend('.ps1'))" {

    $Path = 'Testdrive:\NotPath'
    $diskNum = 4
    $imPath = 'Testdrive:\NotImage'

    Context "Input" {

        Mock -CommandName Remove-PartitionAccessPath -MockWith { $null }
        Mock -CommandName Dismount-DiskImage -MockWith { $null }
        Mock -CommandName Remove-Item -MockWith { $null }

        It "Takes input via param" {
            Dismount-FslDisk -Path $Path -DiskNumber $diskNum -ImagePath $imPath -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via param with passthru" {
            Dismount-FslDisk -Path $Path -DiskNumber $diskNum -ImagePath $imPath -Passthru -ErrorAction Stop | Select-Object -ExpandProperty MountRemoved | Should -Be $true
        }

        It "Takes input via pipeline" {
            $Path | Dismount-FslDisk -DiskNumber $diskNum -ImagePath $imPath -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via pipeline" {
            $diskNum | Dismount-FslDisk -Path $Path -ImagePath $imPath -ErrorAction Stop | Should -BeNullOrEmpty
        }

        It "Takes input via named pipeline" {
            [PSCustomObject]@{
                Path       = $Path
                DiskNumber = $diskNum
                ImagePath  = $imPath
            } | Dismount-FslDisk -ErrorAction Stop | Should -BeNullOrEmpty
        }
    }

    Context "Function Logic" {

        Mock -CommandName Remove-PartitionAccessPath -MockWith { $null }
        Mock -CommandName Dismount-DiskImage -MockWith { $null }
        Mock -CommandName Remove-Item -MockWith { $null }

        $param = @{
            Path        = $Path
            DiskNumber  = $diskNum
            ImagePath   = $imPath
            Passthru    = $true
            ErrorAction = 'Stop'
        }
        It "It Reports Junction removed as true" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty JunctionPointRemoved | Should -Be $true
        }

        It "It Reports Mount removed as true" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty MountRemoved | Should -Be $true
        }

        It "It Reports Directory removed as true" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty DirectoryRemoved | Should -Be $true
        }

        It "It writes verbose line if successful" {
            $verBoseOut = Dismount-FslDisk -Path $Path -DiskNumber $diskNum -ImagePath $imPath -Verbose -ErrorAction Stop 4>&1
            $verBoseOut | Should -Be "Dismounted $imPath"
        }

    }

    Context "Output error Directory" {

        Mock -CommandName Remove-PartitionAccessPath -MockWith { $null }
        Mock -CommandName Dismount-DiskImage -MockWith { $null }
        Mock -CommandName Remove-Item -MockWith { Write-Error 'RemoveMock' }

        $param = @{
            Path        = $Path
            DiskNumber  = $diskNum
            ImagePath   = $imPath
            Passthru    = $true
            ErrorAction = 'SilentlyContinue'
        }

        It "It Reports Directory removed as false" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty DirectoryRemoved | Should -Be $false
        }
    }

    Context "Output error Mount" {

        Mock -CommandName Remove-PartitionAccessPath -MockWith { $null }
        Mock -CommandName Dismount-DiskImage -MockWith { Write-Error 'DismountMock' }
        Mock -CommandName Remove-Item -MockWith { $null }

        $param = @{
            Path        = $Path
            DiskNumber  = $diskNum
            ImagePath   = $imPath
            Passthru    = $true
            ErrorAction = 'SilentlyContinue'
        }

        It "It Reports Mount removed as false" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty MountRemoved | Should -Be $false
        }
    }

    Context "Output error Junction" {

        Mock -CommandName Remove-PartitionAccessPath -MockWith { Write-Error 'JunctionMock' }
        Mock -CommandName Dismount-DiskImage -MockWith { $null }
        Mock -CommandName Remove-Item -MockWith { $null }

        $param = @{
            Path        = $Path
            DiskNumber  = $diskNum
            ImagePath   = $imPath
            Passthru    = $true
            ErrorAction = 'SilentlyContinue'
        }

        It "It Reports Junction removed as false" {
            Dismount-FslDisk @param | Select-Object -ExpandProperty JunctionPointRemoved | Should -Be $false
        }
    }
}