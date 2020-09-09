Function Test-FslDependencies {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName="ServiceName",
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [System.String[]]$Service,

        [Parameter(
            Mandatory=$true,
            Position = 1,
            ParameterSetName = "ServiceObject",
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [System.ServiceProcess.ServiceController]$InputObject
    )
    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
    }
    PROCESS {
        If ($PSCmdlet.ParameterSetName -eq "ServiceObject") {
            Test-FslDependencies -Service $InputObject.Name
            Break
        }

        Foreach ($svc in $Service) {
            $svcObject = Get-Service -Name $svc

            If ($svcObject.Status -eq "Running") { Return }

            If ($svcObject.StartType -eq "Disabled") {
                Write-Warning ("[{0}] Setting Service to Manual" -f $svcObject.DisplayName)
                Set-Service -Name $svc -StartupType Manual
            }

            Start-Service -Name $svc
        }
    }
    END {
        $cores = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty NumberOfCores

        Write-Output $cores
    }
}