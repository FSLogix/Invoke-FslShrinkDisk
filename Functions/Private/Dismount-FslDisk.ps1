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
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        $mountRemoved = $false
        $directoryRemoved = $false

        # Reverse the tasks from Mount-FslDisk

        $timeStampDirectory = (Get-Date).AddSeconds(10)

        while ((Get-Date) -lt $timeStampDirectory -and $directoryRemoved -ne $true) {
            try {
                Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop | Out-Null
                $directoryRemoved = $true
            }
            catch {
                $directoryRemoved = $false
            }
        }
        if (Test-Path $Path) {
            Write-Warning "Failed to delete temp mount directory $Path"
        }


        $timeStampDismount = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $timeStampDismount -and $mountRemoved -ne $true) {
            try {
                Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop | Out-Null
                #double check disk is dismounted due to disk manager dervice being a pain.
                if (-not ((Get-DiskImage -ImagePath $ImagePath).Attached)) {
                    $mountRemoved = $true
                }
                else {
                    $mountRemoved = $false
                }
            }
            catch {
                $mountRemoved = $false
            }
        }
        if ($mountRemoved -ne $true) {
            Write-Error "Failed to dismount disk $ImagePath"
        }

        If ($PassThru) {
            $output = [PSCustomObject]@{
                MountRemoved         = $mountRemoved
                DirectoryRemoved     = $directoryRemoved
            }
            Write-Output $output
        }
        if ($directoryRemoved -and $mountRemoved) {
            Write-Verbose "Dismounted $ImagePath"
        }

    } #Process
    END { } #End
}  #function Dismount-FslDisk