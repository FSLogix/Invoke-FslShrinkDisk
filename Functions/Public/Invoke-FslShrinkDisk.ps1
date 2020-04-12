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
        [System.String]$LogFilePath,

        [Parameter(
            ValuefromPipelineByPropertyName = $true #ToDo
        )]
        [switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #requires -Module Hyper-V
        #Requires -RunAsAdministrator
        #Write-Log
        . Functions\Private\Write-Log.ps1
        #Invoke-Parallel - This is used to support powershell 5.x - if and when PoSh 7 and above become standard, move to ForEach-Object
        . Functions\Private\Invoke-Parallel.ps1
        #Mount-FslDisk
        . Functions\Private\Mount-FslDisk.ps1
        #Dismount-FslDisk
        . Functions\Private\Dismount-FslDisk.ps1
        #Remove Orphan Ost
        . Functions\Private\Remove-FslMultiOst.ps1
        #Scriptblock control function
        . Functions\Private\scriptblock.ps1

        #Set default log path for all future logging events, to save typing
        $PSDefaultParameterValues = @{ "Write-Log:Path" = $LogFilePath }

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
            $listing = Get-ChildItem -File -Filter *.vhd* -Path $Path -Recurse
        }
        else {
            $listing = Get-ChildItem -File -Filter *.vhd* -Path $Path
        }

        #filtering twice as the above filter would alse give use jim.vhd.txt as a result to process. unlikely, but might be worth it
        #MaybeDo speed this up/remove second check
        $diskList = $listing | Where-Object { $_.extension -in ".vhd", ".vhdx" }

        #If we can't find and files with the extension vhd or vhdx quit
        if ( ($diskList | Measure-Object).count -eq 0 ) {
            Write-Warning "No files to process in $Path"
            break
        }

        $scriptblock = {


        } #Scriptblock

        $diskList | Invoke-Parallel -ScriptBlock $scriptblock -Throttle $usableThreads -ImportFunctions -ImportVariables -ImportModules

    } #Process
    END { } #End
}  #function Invoke-FslShrinkDisk