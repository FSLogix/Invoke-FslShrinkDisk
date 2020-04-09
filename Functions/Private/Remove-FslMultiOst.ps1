function Remove-FslMultiOst {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Path
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {
        #Write-Log  "Getting ost files from $Path"
        $ost = Get-ChildItem -Path (Join-Path $Path *.ost)
        if ($null -eq $ost) {
            #Write-log -level Warn "Did not find any ost files in $Path"
            #$ostDelNum = 0
        }
        else {

            $count = ($ost | Measure-Object).Count

            if ($count -gt 1) {

                $mailboxes = $ost.BaseName.trimend('(', ')', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0') | Group-Object | Select-Object -ExpandProperty Name

                foreach ($mailbox in $mailboxes) {
                    $mailboxOst = $ost | Where-Object { $_.BaseName.StartsWith($mailbox) }

                    $count = ($mailboxOst | Measure-Object).Count

                    #Write-Log  "Found $count ost files for $mailbox"

                    if ($count -gt 1) {

                        $ostDelNum = $count - 1
                        #Write-Log "Deleting $ostDelNum ost files"
                        try {
                            $latestOst = $mailboxOst | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                            $mailboxOst | Where-Object { $_.Name -ne $latestOst.Name } | Remove-Item -Force -ErrorAction Stop
                        }
                        catch {
                            Write-Warning "Did not delete orphaned ost file(s)"
                        }
                    }
                    else {
                        #Write-Log "Only One ost file found for $mailbox. No action taken"
                        $ostDelNum = 0
                    }

                }
            }
        }
    } #Process
    END { } #End
}  #function Remove-FslMultiOst