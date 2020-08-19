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
            $e = $error[0]
            Write-Error "Failed to mount disk - `"$e`""
            return
        }

        if (-not $mountedDisk.Number){
            $number = $false
            $timespan = (Get-Date).AddSeconds(15)
            while ($number -eq $false -and $timespan -gt (Get-Date)) {
                Start-Sleep 0.1
                $mountedDisk = Get-DiskImage -ImagePath $Path
                if ($mountedDisk.Number){
                    $number = $true
                }
            }
        }

        if (-not $mountedDisk.Number) {
            Write-Error 'Cannot get mount information'
            return
        }

        try {
            # Get the first basic partition. Disks created with powershell will have a Reserved partition followed by the Basic
            # partition. Those created with frx.exe will just have a single Basic partition.
            $partition = Get-Partition -DiskNumber $mountedDisk.Number | Where-Object -Property 'Type' -eq -Value 'Basic'
        }
        catch {
            $e = $error[0]
            # Cleanup
            $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            Write-Error "Failed to read partition information for disk - `"$e`""
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
            $e = $error[0]
            # Cleanup
            $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            Write-Error "Failed to create mounting directory - `"$e`""
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
            $e = $error[0]
            # Cleanup
            Remove-Item -Path $mountPath -Force -Recurse -ErrorAction SilentlyContinue
            $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
            Write-Error "Failed to create junction point to - `"$e`""
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