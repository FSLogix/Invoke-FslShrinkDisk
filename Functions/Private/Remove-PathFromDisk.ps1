function Remove-PathFromDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$CustomPath,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet("All", "Outlook", "Activation", "FileCache", "OneDrive", "OneNote", "OneNote_UWP", "OutlookPersonalization", "SharePoint", "Skype", "Teams")]
        [System.String[]]$OfficeComponent
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

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
    } #Process
    END { } #End
}  #function