function Dismount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [int16]$DiskNumber,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]$ImagePath,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        # FSLogix Disk Partition Number this won't work with vhds created with MS tools as their main partition number is 2
        $partitionNumber = 1

        if ($PassThru) {
            $junctionPointRemoved = $false
            $mountRemoved = $false
            $directoryRemoved = $false
        }

        # Reverse the three tasks from Mount-FslDisk
        $junctionPointRemoved = $false
        $timeStampPart = (Get-Date).AddSeconds(10)

        while ((Get-Date) -lt $timeStampPart -and $junctionPointRemoved -ne $true) {
            try {
                Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $partitionNumber -AccessPath $Path -ErrorAction Stop | Out-Null
                $junctionPointRemoved = $true
            }
            catch {
                $junctionPointRemoved = $false
                Write-Warning "Failed to remove the junction point to $Path"
            }
        }

        $mountRemoved = $false
        $timeStampDismount = (Get-Date).AddSeconds(10)

        while ((Get-Date) -lt $timeStampDismount -and $mountRemoved -ne $true) {
            try {
                Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop | Out-Null
                $mountRemoved = $true
            }
            catch {
                $mountRemoved = $false
                Write-Error "Failed to dismount disk $ImagePath"
            }
        }

        $directoryRemoved = $false
        $timeStampDirectory = (Get-Date).AddSeconds(10)

        while ((Get-Date) -lt $timeStampDirectory -and $directoryRemoved -ne $true) {
            try {
                Remove-Item -Path $Path -ErrorAction Stop | Out-Null
                $directoryRemoved = $true
            }
            catch {
                Write-Warning "Failed to delete temp mount directory $Path"
                $directoryRemoved = $false
            }
        }

        If ($PassThru) {
            $output = [PSCustomObject]@{
                JunctionPointRemoved = $junctionPointRemoved
                MountRemoved         = $mountRemoved
                DirectoryRemoved     = $directoryRemoved
            }
            Write-Output $output
        }

        if ($directoryRemoved -and $mountRemoved -and $junctionPointRemoved) {
            Write-Verbose "Dismounted $ImagePath"
        }

    } #Process
    END { } #End
}  #function Dismount-FslDisk