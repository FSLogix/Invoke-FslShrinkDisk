function Remove-PathFromDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            ParameterSetName = 'Custom',
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [System.String[]]$CustomPath,

        [Parameter(
            ParameterSetName = 'Office',
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet("All", "Outlook", "Activation", "FileCache", "OneDrive", "OneNote", "OneNote_UWP", "OutlookPersonalization", "SharePoint", "Skype", "Teams")]
        [System.String[]]$OfficeComponent
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        switch ($PSCmdlet.ParameterSetName) {
            'Office' {
                if ($OfficeComponent -contains "All") {
                    $OfficeComponent = @("Outlook", "Activation", "FileCache", "OneDrive", "OneNote", "OneNote_UWP", "OutlookPersonalization", "SharePoint", "Skype", "Teams")
                }

                foreach ($part in $OfficeComponent) {
                    switch ($part) {
                        "Outlook" { Remove-PathFromDisk -CustomPath ; break }
                        "Activation" { Remove-PathFromDisk -CustomPath ; break }
                        "FileCache" { Remove-PathFromDisk -CustomPath ; break }
                        "OneDrive" { Remove-PathFromDisk -CustomPath ; break }
                        "OneNote" { Remove-PathFromDisk -CustomPath ; break }
                        "OneNote_UWP" { Remove-PathFromDisk -CustomPath ; break }
                        "OutlookPersonalization" { Remove-PathFromDisk -CustomPath ; break }
                        "SharePoint" { Remove-PathFromDisk -CustomPath ; break }
                        "Skype" { Remove-PathFromDisk -CustomPath ; break }
                        "Teams" { Remove-PathFromDisk -CustomPath ; break }
                        Default { }
                    }
                }
            }
            'Custom' {
                foreach ($path in $CustomPath) {
                    try {
                        Remove-Item -Path $path -Force -Confirm:$false
                    }
                    catch {
                        Write-Warning "Failed to delete $path"
                    }

                }
            }
            Default {}
        }

    } #Process
    END { } #End
}  #function