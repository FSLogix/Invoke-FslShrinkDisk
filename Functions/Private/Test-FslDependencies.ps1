Function Test-FslDependencies {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [System.String[]]$Name
    )
    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
    }
    PROCESS {

        Foreach ($svc in $Name) {
            $svcObject = Get-Service -Name $svc

            If ($svcObject.Status -eq "Running") { Return }

            If ($svcObject.StartType -eq "Disabled") {
                Write-Warning ("[{0}] Setting Service to Manual" -f $svcObject.DisplayName)
                Set-Service -Name $svc -StartupType Manual | Out-Null
            }

            Start-Service -Name $svc | Out-Null

            if ((Get-Service -Name $svc).Status -ne 'Running') {
                Write-Error "Can not start $svcObject.DisplayName"
            }
        }
    }
    END {

    }
}