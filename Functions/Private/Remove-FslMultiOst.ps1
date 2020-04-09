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

        If (-not (Test-Path $Path)) {
            Write-Error "Cannot validate $Path exists"
            break
        }

        #Write-Log  "Getting ost files from $Path"
        $ost = Get-ChildItem -Path (Join-Path $Path *.ost)
        if ($null -eq $ost) {
            Write-Warning "Did not find any ost files in $Path"
            break
        }
        else {

            $count = ($ost | Measure-Object).Count

            #do nothing if only one ost
            if ($count -le 1) { break }

            $mailboxes = $ost.BaseName.trimend('(', ')', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0') | Group-Object | Select-Object -ExpandProperty Name

            foreach ($mailbox in $mailboxes) {
                $mailboxOst = $ost | Where-Object { $_.BaseName.StartsWith($mailbox) }

                $count = ($mailboxOst | Measure-Object).Count

                #do nothing if only one ost for this mailbox
                if ($count -le 1) { break }

                try {
                    $latestOst = $mailboxOst | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                    $mailboxOst | Where-Object { $_.Name -ne $latestOst.Name } | Remove-Item -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning "Did not delete the orphaned ost file(s)"
                }
                
                
            }
        }
    } #Process
    END { } #End
}  #function Remove-FslMultiOst