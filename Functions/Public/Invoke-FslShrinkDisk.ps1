function Invoke-FslShrinkDisk {

    <#
        .SYNOPSIS
        Shrinks FSLogix Profile or O365 dynamically expanding disk(s).

        .DESCRIPTION
        FSLogix profile and O365 virtual hard disks are in the vhd or vhdx format. By default the disks created will be in Dynamically Expanding format rather than Fixed.  This script does not support reducing the size of a Fixed file format.

        Dynamically Expanding disks do not natively shrink when the volume of data within them reduces, they stay at the 'High water mark' of historical data volume within them.

        THis means that Enterprises can wish to reclaim whitespace inside the disks to



        .PARAMETER Name
        Specifies the file name.

        .PARAMETER Extension
        Specifies the extension. "Txt" is the default.

        .INPUTS
        None. You cannot pipe objects to Add-Extension.

        .OUTPUTS
        System.String. Add-Extension returns a string with the extension or file name.

        .EXAMPLE
        C:\PS> extension -name "File"
        File.txt

        .EXAMPLE
        C:\PS> extension -name "File" -extension "doc"
        File.doc

        .EXAMPLE
        C:\PS> extension "File" "doc"
        File.doc

        .LINK
        Online version: http://www.fabrikam.com/extension.html

        .LINK
        Set-Item
    #>

    [CmdletBinding()]

    Param (

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [double]$IgnoreLessThanGB = 0,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$DeleteOlderThanDays,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Recurse,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$LogFilePath = "$env:TEMP\FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH-mm-ss).csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [switch]$PassThru,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$ThrottleLimit
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator

        #Invoke-Parallel - This is used to support powershell 5.x - if and when PoSh 7 and above become standard, move to ForEach-Object
        . Functions\Private\Invoke-Parallel.ps1
        #Mount-FslDisk
        . Functions\Private\Mount-FslDisk.ps1
        #Dismount-FslDisk
        . Functions\Private\Dismount-FslDisk.ps1
        #Shrink single disk
        . Functions\Private\Shrink-OneDisk.ps1
        #Write Output to file and optionally to pipeline
        . Functions\Private\Write-VhdOutput.ps1

        #Grab number (n) of threads available from local machine and set number of threads to n-2 with a mimimum of 2 threads.
        if (-not $ThrottleLimit) {
            $ThrottleLimit = (Get-Ciminstance Win32_processor).ThreadCount - 2
            If ($ThrottleLimit -le 2) { $ThrottleLimit = 2 }
        }

    } # Begin
    PROCESS {

        #Check that the path is valid
        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found"
            break
        }

        #Get a list of Virtual Hard Disk files depending on the recurse parameter
        if ($Recurse) {
            $diskList = Get-ChildItem -File -Filter *.vhd* -Path $Path -Recurse
        }
        else {
            $diskList = Get-ChildItem -File -Filter *.vhd* -Path $Path
        }

        #If we can't find and files with the extension vhd or vhdx quit
        if ( ($diskList | Measure-Object).count -eq 0 ) {
            Write-Warning "No files to process in $Path"
            break
        }

        $scriptblockInvokeParallel = {

            Param ( $disk )

            $paramShrinkOneDisk = @{
                Disk                = $disk
                DeleteOlderThanDays = $DeleteOlderThanDays
                IgnoreLessThanGB    = $IgnoreLessThanGB
                LogFilePath         = $LogFilePath
                PassThru            = $PassThru
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk

        } #Scriptblock

        $scriptblockForEachObject = {

            #Invoke-Parallel - This is used to support powershell 5.x - if and when PoSh 7 and above become standard, move to ForEach-Object
            . Functions\Private\Invoke-Parallel.ps1
            #Mount-FslDisk
            . Functions\Private\Mount-FslDisk.ps1
            #Dismount-FslDisk
            . Functions\Private\Dismount-FslDisk.ps1
            #Shrink single disk
            . Functions\Private\Shrink-OneDisk.ps1
            #Write Output to file and optionally to pipeline
            . Functions\Private\Write-VhdOutput.ps1

            $paramShrinkOneDisk = @{
                Disk                = $_
                DeleteOlderThanDays = $using:DeleteOlderThanDays
                IgnoreLessThanGB    = $using:IgnoreLessThanGB
                LogFilePath         = $using:LogFilePath
                PassThru            = $using:PassThru
                RatioFreeSpace      = 0.2
            }
            Shrink-OneDisk @paramShrinkOneDisk

        } #Scriptblock

        if ($PSVersionTable.PSVersion -ge 7) {
            $diskList | ForEach-Object -Parallel $scriptblockForEachObject -ThrottleLimit $ThrottleLimit
        }
        else {
            $diskList | Invoke-Parallel -ScriptBlock $scriptblockInvokeParallel -Throttle $ThrottleLimit -ImportFunctions -ImportVariables -ImportModules
        }



    } #Process
    END { } #End
}  #function Invoke-FslShrinkDisk