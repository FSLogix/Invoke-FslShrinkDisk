$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$funcType = Split-Path $here -Leaf
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here | Split-Path -Parent | Split-Path -Parent
. "$here\Functions\$funcType\$sut"

Describe "Describing $sut.Trimend('.ps1')" {
    Context "Input" {

        $Path = 'TestDrive:\ThisDoesNotExist.vhdx'

        Mock -CommandName Mount-DiskImage  { $null }
        Mock -CommandName Get-DiskImage  { $null }
        Mock -CommandName New-Item  { $null }
        Mock -CommandName Dismount-DiskImage  { $null }
        Mock -CommandName Add-PartitionAccessPath  { $null }
        Mock -CommandName Remove-Item  { $null }

        It "Takes input via param" {
            Mount-FslDisk -Path $Path | Should -BeNullOrEmpty     
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