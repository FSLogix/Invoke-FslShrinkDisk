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
        $TimeElasped,
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
        [string]$TopError,
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
        [string]$SqlServer = 'shrinkdisk.database.windows.net',

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
        [string]$DiskTable = 'DiskData',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$TimeOut = 30

    )

    BEGIN {
        #Requires -Modules SqlServer
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        #TODO Remove
        $pw = Get-Content D:\JimM\pw.txt
        $un = Get-Content D:\JimM\un.txt

        $password = ConvertTo-SecureString $pw -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $un, $password

        $connString = "Server=tcp:$SqlServer,1433;Initial Catalog=$InitialCatalog;Persist Security Info=True"
        #$cred = Get-Credential -Message "Enter your SQL Auth credentials"
        $cred.Password.MakeReadOnly()
        $sqlcred = New-Object -TypeName System.Data.SqlClient.SqlCredential -ArgumentList $cred.UserName, $cred.Password
        $sqlcc = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList  $connString, $sqlcred
        $sc = New-Object -TypeName Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList  $sqlcc
        $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $sc

        $timespan = (Get-Date).AddSeconds($timeout)
        $dbConnection = $false
        while ($dbConnection -eq $false -and (Get-Date) -lt $timespan) {
            try {
                $db = $srv.Databases[$InitialCatalog]
                $dbConnection = $true
            }
            catch {
                Start-Sleep 0.1
            }
        }
        $SummaryTableObj = $db.Tables[$SummaryTable]
        $DiskTableObj = $db.Tables[$DiskTable]

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

        $summaryInsert = Write-SqlTableData -InputData $sqlSummary -InputObject $SummaryTableObj -Passthru

        if ($DiskLog) {
            $runId = $summaryInsert | Read-SqlTableData | Where-Object { $_.CustGuid -eq $CustGuid } | Sort-Object -Property RunId | Select-Object -Last 1 -ExpandProperty RunId
            $diskData = $DiskLog | Select-Object -Property *, @{Name = 'RunId'; Expression = { [int]$runId } }
            $diskDataOrdered = $diskData | ForEach-Object {
                #Powershell has put properties in memory efficient order, but we need them in the right order for insertion to sql
                $out = [PSCustomObject][Ordered]@{
                    Name         = $_.Name
                    StartTime    = $_.StartTime
                    EndTime      = $_.EndTime
                    ElapsedTime  = $_.ElapsedTime
                    DiskState    = $_.DiskState
                    OriginalSize = $_.OriginalSize
                    FinalSize    = $_.FinalSize
                    MaxSize      = $_.MaxSize
                    SpaceSaved   = $_.SpaceSaved
                    FullName     = $_.FullName
                    RunId        = [int]$_.RunId
                }
                $out
            }
            Write-SqlTableData -InputData $diskDataOrdered -InputObject $DiskTableObj
        }

    } #Process
    END {} #End
}  #function Add-FslDbEntry