function Mount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [alias('FullName')]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [Int]$TimeOut = 3,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        try {
            # Mount the disk without a drive letter and get it's info, Mount-DiskImage is used to remove reliance on Hyper-V tools
            $mountedDisk = Mount-DiskImage -ImagePath $Path -NoDriveLetter -PassThru -ErrorAction Stop
        }
        catch {
            $e = $error[0]
            Write-Error "Failed to mount disk - $($e.ToString())"
            return
        }

        $diskNumber = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($diskNumber -eq $false -and $timespan -gt (Get-Date)) {
            Start-Sleep 0.1
            try {
                $mountedDisk = Get-DiskImage -ImagePath $Path
                if ($mountedDisk.Number) {
                    $diskNumber = $true
                }
            }
            catch {
                $diskNumber = $false
            }

        }

        if ($diskNumber -eq $false) {
            try {
                $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            }
            catch {
                Write-Error 'Could not dismount Disk Due to no Disknumber'
            }
            Write-Error 'Cannot get mount information'
            return
        }

        $partitionType = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($partitionType -eq $false -and $timespan -gt (Get-Date)) {

            try {
                $allPartition = Get-Partition -DiskNumber $mountedDisk.Number -ErrorAction Stop

                if ($allPartition.Type -contains 'Basic' -or $allPartition.Type -eq 'IFS') {
                    $partitionType = $true
                    $partition = $allPartition | Where-Object { $_.Type -eq 'Basic' -or $_.Type -eq 'IFS' }
                }
            }
            catch {
                if (($allPartition | Measure-Object).Count -gt 0) {
                    $partition = $allPartition | Select-Object -Last 1
                    $partitionType = $true
                }
                else{
                    $partitionType = $false
                }

            }
            Start-Sleep 0.1
        }

        if ($partitionType -eq $false) {
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error 'Could not dismount disk with no partition'
            }
            Write-Error 'Cannot get partition information'
            return
        }

        # Assign vhd to a random path in temp folder so we don't have to worry about free drive letters which can be horrible
        # New-Guid not used here for PoSh 3 compatibility
        $tempGUID = [guid]::NewGuid().ToString()
        $mountPath = Join-Path $Env:Temp ('FSLogixMnt-' + $tempGUID)

        try {
            # Create directory which we will mount too
            New-Item -Path $mountPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch {
            $err = $error[0]
            # Cleanup
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                $err = $error[0]
                Write-Error "Could not dismount disk when no folder could be created - $($err.ToString())"
            }
            Write-Error "Failed to create mounting directory - $($err.ToString())"
            return
        }

        try {
            $addPartitionAccessPathParams = @{
                DiskNumber      = $mountedDisk.Number
                PartitionNumber = $partition.PartitionNumber
                AccessPath      = $mountPath
                ErrorAction     = 'Stop'
            }

            Add-PartitionAccessPath @addPartitionAccessPathParams
        }
        catch {
            $err = $error[0]
            # Cleanup
            Remove-Item -Path $mountPath -Force -Recurse -ErrorAction SilentlyContinue
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                $err = $error[0]
                Write-Error "Could not dismount disk when no junction point could be created - $($err.ToString())"
            }

            Write-Error "Failed to create junction point to - $($err.ToString())"
            return
        }

        if ($PassThru) {
            # Create output required for piping to Dismount-FslDisk
            $output = [PSCustomObject]@{
                Path       = $mountPath
                DiskNumber = $mountedDisk.Number
                ImagePath  = $mountedDisk.ImagePath
                PartitionNumber = $partition.PartitionNumber
            }
            Write-Output $output
        }
        Write-Verbose "Mounted $Path to $mountPath"
    } #Process
    END {

    } #End
}  #function Mount-FslDisk