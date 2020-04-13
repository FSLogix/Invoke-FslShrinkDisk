function Invoke-FslShrinkDisk {
    [CmdletBinding()]

    Param (

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$IgnoreLessThanGB = 5,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$DeleteOlderThanDays,

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
        [switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -Module Hyper-V
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
        $usableThreads = (Get-Ciminstance Win32_processor).ThreadCount - 2
        If ($usableThreads -le 2) { $usableThreads = 2 }

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

        $scriptblock = {

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

        $diskList | Invoke-Parallel -ScriptBlock $scriptblock -Throttle $usableThreads -ImportFunctions -ImportVariables -ImportModules

    } #Process
    END { } #End
}  #function Invoke-FslShrinkDisk