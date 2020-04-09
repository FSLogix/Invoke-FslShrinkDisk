$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $sut.Trimend('.ps1')" {
    Context "Input" {

        $Path = 'TestDrive:\ThisDoesNotExist.vhdx'
        #New-Item -ItemType Directory -Path 'TestDrive:\mountHere'

        Mock -CommandName Mount-DiskImage -MockWith { [pscustomobject]@{
            Imagepath = $Path
            Number = 4
        } }
        Mock -CommandName Get-DiskImage -MockWith { $null }
        Mock -CommandName New-Item -MockWith { $null }
        Mock -CommandName Dismount-DiskImage -MockWith { $null }
        Mock -CommandName Add-PartitionAccessPath -MockWith { $null }
        Mock -CommandName Remove-Item -MockWith { $null }
        Mock -CommandName Join-Path -MockWith { 'TestDrive:\mountHere' }

        It "Takes input via param" {
            Mount-FslDisk -Path $Path -ErrorAction Stop | Should -BeNullOrEmpty     
        }

        It "Takes input via paramwith passthru" {
            Mount-FslDisk -Path $Path -Passthru -ErrorAction Stop | Should -BeNullOrEmpty
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
}