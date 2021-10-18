function Add-FslDbEntry {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [datetime]$StartTime,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [datetime]$EndTime,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [datetime]$TimeElasped,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        $TotalTimeTaken,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int64]$TotalOriginalSize,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int64]$TotalFinalSize,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int64]$TotalSpaceSaved,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int64]$AverageMaxDiskSize,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$NumberOfDisks,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$NumberOfErrors,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$TopError,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$WindowsProductName,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$WindowsVersion,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [guid]$CustGuid,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$Domain,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$UserName,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$FullName,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$WindowsRegisteredOrganization,
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.Object]$DiskLog,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$SqlServer = 'tcp:shrinkdisk.database.windows.net',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$InitialCatalog = 'ShrinkRuns',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$SummaryTable = 'Summary',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$DiskTable = 'DiskData'

    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        $debugConn = $false
        if ($debugConn) {
            $connString = "Server=tcp:$SqlServer,1433;Initial Catalog=$InitialCatalog;Persist Security Info=True"
            $cred = Get-Credential -Message "Enter your SQL Auth credentials"
            $cred.Password.MakeReadOnly()
            $sqlcred = New-Object -TypeName System.Data.SqlClient.SqlCredential -ArgumentList $cred.UserName, $cred.Password
            $sqlcc = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList  $connString, $sqlcred
            $sc = New-Object -TypeName Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList  $sqlcc
            $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $sc
            $db = $srv.Databases["$InitialCatalog"]
            $table = $db.Tables["$SummaryTable"]
        }

        $sqlSummary = [PSCustomObject][Ordered]@{
            StartTime                     = $StartTime
            EndTime                       = $EndTime
            TimeElasped                   = $TimeElasped
            TotalTimeTaken                = $TotalTimeTaken
            TotalOriginalSize             = $TotalOriginalSize
            TotalFinalSize                = $TotalFinalSize
            TotalSpaceSaved               = $TotalSpaceSaved
            AverageMaxDiskSize            = $AverageMaxDiskSize
            NumberOfDisks                 = $NumberOfDisks
            NumberOfErrors                = $NumberOfErrors
            TopError                      = $TopError
            WindowsProductName            = $WindowsProductName
            WindowsVersion                = $WindowsVersion
            CustGuid                      = $CustGuid
            Domain                        = $Domain
            UserName                      = $UserName
            FullName                      = $FullName
            WindowsRegisteredOrganization = $WindowsRegisteredOrganization
        }

        Write-SqlTableData -InputData $summary -InputObject $table -Verbose -Passthru


    } #Process
    END {} #End
}  #function Add-FslDbEntry