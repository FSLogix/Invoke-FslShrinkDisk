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
        [System.String]$OriginalSizeGB,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FinalSizeGB,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$SpaceSavedGB,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FullName,

        [Parameter(
            Mandatory = $true
        )]
        [Switch]$Passthru
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        $output = [PSCustomObject]@{
            Name           = $Name
            DiskState      = $DiskState
            OriginalSizeGB = $OriginalSizeGB
            FinalSizeGB    = $FinalSizeGB
            SpaceSavedGB   = $SpaceSavedGB
            FullName       = $FullName
        }

        if ($Passthru) {
            Write-Output $output
        }
        $success = $False
        $retries = 0
        while ($retries -lt 10 -and $success -ne $true) {
            try{
                $output | Export-Csv -Path $Path -NoClobber -Append -ErrorAction Stop
                $success = $true
            }
            catch{
                $retries++
            }
            Start-Sleep 1
        }


    } #Process
    END { } #End
}  #function Write-VhdOutput.ps1