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
        [Switch]$PassThru,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [datetime]$SetLastWriteTime,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$Timeout = 120
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        $mountRemoved = $false
        $directoryRemoved = $false

        # Reverse the tasks from Mount-FslDisk

        $timeStampDirectory = (Get-Date).AddSeconds(20)

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


        $timeStampDismount = (Get-Date).AddSeconds($Timeout)
        while ((Get-Date) -lt $timeStampDismount -and $mountRemoved -ne $true) {
            try {
                Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop | Out-Null
                #double/triple check disk is dismounted due to disk manager service being a pain.

                try {
                    $image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop

                    switch ($image.Attached) {
                        $null { $mountRemoved = $false ; Start-Sleep 0.1; break }
                        $true { $mountRemoved = $false ; break}
                        $false { $mountRemoved = $true ; break }
                        Default { $mountRemoved = $false }
                    }
                }
                catch {
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

        if ($mountRemoved -and $SetLastWriteTime) {
            try{
                (Get-Item $ImagePath -ErrorAction Stop).LastWriteTimeUtc = $SetLastWriteTime
            }
            catch{
                Write-Warning 'Failed to set Last Write time'
            }
        }

        if ($directoryRemoved -and $mountRemoved) {
            Write-Verbose "Dismounted $ImagePath"
        }

    } #Process
    END { } #End
}  #function Dismount-FslDisk