function Write-VhdOutput {
    [CmdletBinding()]

    Param (
        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Path,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Name,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$DiskState,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$OriginalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FinalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FullName,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$StartTime,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$EndTime,

        [Parameter(
            Mandatory = $true
        )]
        [Switch]$Passthru
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        #unit conversion and calculation should happen in output function
        $output = [PSCustomObject]@{
            Name             = $Name
            StartTime        = $StartTime.ToLongTimeString()
            EndTime          = $EndTime.ToLongTimeString()
            'ElapsedTime(s)' = [math]::Round(($EndTime - $StartTime).TotalSeconds, 1)
            DiskState        = $DiskState
            OriginalSizeGB   = [math]::Round( $OriginalSize / 1GB, 2 )
            FinalSizeGB      = [math]::Round( $FinalSize / 1GB, 2 )
            SpaceSavedGB     = [math]::Round( ($OriginalSize - $FinalSize) / 1GB, 2 )
            FullName         = $FullName
        }

        if ($Passthru) {
            Write-Output $output
        }
        $success = $False
        $retries = 0
        while ($retries -lt 10 -and $success -ne $true) {
            try {
                $output | Export-Csv -Path $Path -NoClobber -Append -ErrorAction Stop -NoTypeInformation
                $success = $true
            }
            catch {
                $retries++
            }
            Start-Sleep 1
        }


    } #Process
    END { } #End
}  #function Write-VhdOutput.ps1