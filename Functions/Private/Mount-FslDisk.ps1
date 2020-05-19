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
            ValuefromPipelineByPropertyName = $true
        )]
        # FSLogix Disk Partition number is 1, vhd(x)s created with MS tools have their main partition number as 2
        [System.String]$PartitionNumber = 1,

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
            # Don't remove get-diskimage it's needed as mount doesn't give back the full object in certain circumstances
            $mountedDisk = Mount-DiskImage -ImagePath $Path -NoDriveLetter -PassThru -ErrorAction Stop | Get-DiskImage
        }
        catch {
            Write-Error "Failed to mount disk $Path"
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
            Write-Error "Failed to create mounting directory $mountPath"
            # Cleanup
            $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            return
        }

        try {
            $addPartitionAccessPathParams = @{
                DiskNumber      = $mountedDisk.Number
                PartitionNumber = $PartitionNumber
                AccessPath      = $mountPath
                ErrorAction     = 'Stop'
            }

            Add-PartitionAccessPath @addPartitionAccessPathParams
        }
        catch {
            Write-Error "Failed to create junction point to $mountPath"
            # Cleanup
            Remove-Item -Path $mountPath -Force -Recurse -ErrorAction SilentlyContinue
            $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            return
        }

        if ($PassThru) {
            # Create output required for piping to Dismount-FslDisk
            $output = [PSCustomObject]@{
                Path       = $mountPath
                DiskNumber = $mountedDisk.Number
                ImagePath  = $mountedDisk.ImagePath
            }
            Write-Output $output
        }
        Write-Verbose "Mounted $Path to $mountPath"
    } #Process
    END {

    } #End
}  #function Mount-FslDisk