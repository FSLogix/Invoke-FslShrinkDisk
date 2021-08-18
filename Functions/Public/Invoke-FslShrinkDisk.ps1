<#
        .SYNOPSIS
        Shrinks FSLogix Profile and O365 dynamically expanding disk(s).

        .DESCRIPTION
        FSLogix profile and O365 virtual hard disks are in the vhd or vhdx file format. By default, the disks created will be in Dynamically Expanding format rather than Fixed format.  This script does not support reducing the size of a Fixed file format.

        Dynamically Expanding disks do not natively shrink when the volume of data within them reduces, they stay at the 'High water mark' of historical data volume within them.

        This means that Enterprises can wish to reclaim whitespace inside the disks to keep cost down if the storage is cloud based, or make sure they don’t exceed capacity limits if storage is on-premises.

        This Script is designed to work at Enterprise scale to reduce the size of thousands of disks in the shortest time possible.
        This script can be run from any machine in your environment it does not need to be run from a file server hosting the disks.  It does not need the Hyper-V role installed.
        Powershell version 5.x and 7 and above are supported for this script. It needs to be run as administrator due to the requirement for mounting disks to the OS where the script is run.
        This tool is multi-threaded and will take advantage of multiple CPU cores on the machine from which you run the script.  It is not advised to run more than 2x the threads of your available cores on your machine.  You could also use the number of threads to throttle the load on your storage.
        Reducing the size of a virtual hard disk is a storage intensive activity.  The activity is more in file system metadata operations than pure IOPS, so make sure your storage controllers can handle the load.  The storage load occurs on the location where the disks are stored not on the machine where the script is run from.   I advise running the script out of hours if possible, to avoid impacting other users on the storage.
        With the intention of reducing the storage load to the minimum possible, you can configure the script to only shrink the disks where you will see the most benefit.  You can delete disks which have not been accessed in x number of days previously (configurable).  Deletion of disks is not enabled by default.  By default the script will not run on any disk with less than 5% whitespace inside (configurable).  The script can optionally also not run on disks smaller than xGB (configurable) as it’s possible that even a large % of whitespace in small disks won’t result in a large capacity reclamation, but even shrinking a small amount of capacity will cause storage load.
        The script will output a csv in the following format:

        "Name","DiskState","OriginalSizeGB","FinalSizeGB","SpaceSavedGB","FullName"
        "Profile_user1.vhdx","Success","4.35","3.22","1.13",\\Server\Share\ Profile_user1.vhdx "
        "Profile_user2.vhdx","Success","4.75","3.12","1.63",\\Server\Share\ Profile_user2.vhdx

        Possible Information values for DiskState are as follows:
        Success				Disk has been successfully processed and shrunk
        Ignored				Disk was less than the size configured in -IgnoreLessThanGB parameter
        Deleted				Disk was last accessed before the number of days configured in the -DeleteOlderThanDays parameter and was successfully deleted
        DiskLocked			Disk could not be mounted due to being in use
        LessThan(x)%FreeInsideDisk	Disk contained less whitespace than configured in -RatioFreeSpace parameter and was ignored for processing

        Possible Error values for DiskState are as follows:
        FileIsNotDiskFormat		Disk file extension was not vhd or vhdx
        DiskDeletionFailed		Disk was last accessed before the number of days configured in the -DeleteOlderThanDays parameter and was not successfully deleted
        NoPartitionInfo			Could not get partition information for partition 1 from the disk
        PartitionShrinkFailed		Failed to Optimize partition as part of the disk processing
        DiskShrinkFailed		Could not shrink Disk
        PartitionSizeRestoreFailed 	Failed to Restore partition as part of the disk processing

        If the diskstate shows an error value from the list above, manual intervention may be required to make the disk usable again.

        If you inspect your environment you will probably see that there are a few disks that are consuming a lot of capacity targeting these by using the minimum disk size configuration would be a good step.  To grab a list of disks and their sizes from a share you could use this oneliner by replacing <yourshare> with the path to the share containing the disks.
        Get-ChildItem -Path <yourshare> -Filter "*.vhd*" -Recurse -File | Select-Object Name, @{n = 'SizeInGB'; e = {[math]::round($_.length/1GB,2)}}
        All this oneliner does is gather the names and sizes of the virtual hard disks from your share.  To export this information to a file readable by excel, use the following replacing both <yourshare> and < yourcsvfile.csv>.  You can then open the csv file in excel.
        Get-ChildItem -Path <yourshare> -Filter "*.vhd*" -Recurse -File | Select-Object Name, @{n = 'SizeInGB'; e = {[math]::round($_.length/1GB,2)}} | Export-Csv -Path < yourcsvfile.csv>

        .NOTES
        Whilst I work for Microsoft and used to work for FSLogix, this is not officially released software from either company.  This is purely a personal project designed to help the community.  If you require support for this tool please raise an issue on the GitHub repository linked below

        .PARAMETER Path
        The path to the folder/share containing the disks. You can also directly specify a single disk. UNC paths are supported.

        .PARAMETER Recurse
        Gets the disks in the specified locations and in all child items of the locations

        .PARAMETER IgnoreLessThanGB
        The disk size in GB under which the script will not process the file.

        .PARAMETER DeleteOlderThanDays
        If a disk ‘last access time’ is older than todays date minus this value, the disk will be deleted from the share.  This is a permanent action.

        .PARAMETER LogFilePath
        All disk actions will be saved in a csv file for admin reference.  The default location for this csv file is the user’s temp directory.  The default filename is in the following format: FslShrinkDisk 2020-04-14 19-36-19.csv

        .PARAMETER PassThru
        Returns an object representing the item with which you are working. By default, this cmdlet does not generate any pipeline output.

        .PARAMETER ThrottleLimit
        Specifies the number of disks that will be processed at a time. Further disks in the queue will wait till a previous disk has finished up to a maximum of the ThrottleLimit.  The  default value is 8.

        .PARAMETER RatioFreeSpace
        The minimum percentage of white space in the disk before processing will start as a decimal between 0 and 1 eg 0.2 is 20% 0.65 is 65%. The Default is 0.05.  This means that if the available size reduction is less than 5%, then no action will be taken.  To try and shrink all files no matter how little the gain set this to 0.

        .INPUTS
        You can pipe the path into the command which is recognised by type, you can also pipe any parameter by name. It will also take the path positionally

        .OUTPUTS
        This script outputs a csv file with the result of the disk processing.  It will optionally produce a custom object with the same information

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path c:\Profile_user1.vhdx
	    This shrinks a single disk on the local file system

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse
	    This shrinks all disks in the specified share recursively

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -IgnoreLessThanGB 3
        This shrinks all disks in the specified share recursively, except for files under 3GB in size which it ignores.

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -DeleteOlderThanDays 90
        This shrinks all disks in the specified share recursively and deletes disks which were not accessed within the last 90 days.

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -LogFilePath C:\MyLogFile.csv
        This shrinks all disks in the specified share recursively and changes the default log file location to C:\MyLogFile.csv

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -PassThru
        Name:			Profile_user1.vhdx
        DiskState:		Success
        OriginalSizeGB:		4.35
        FinalSizeGB:		3.22
        SpaceSavedGB:		1.13
        FullName:		\\Server\Share\ Profile_user1.vhdx
        This shrinks all disks in the specified share recursively and passes the result of the disk processing to the pipeline as an object.

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -ThrottleLimit 20
        This shrinks all disks in the specified share recursively increasing the number of threads used to 20 from the default 8.

        .EXAMPLE
        C:\PS> Invoke-FslShrinkDisk -Path \\server\share -Recurse -RatioFreeSpace 0.3
	    This shrinks all disks in the specified share recursively while not processing disks which have less than 30% whitespace instead of the default 15%.

        .LINK
        https://github.com/FSLogix/Invoke-FslShrinkDisk/

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
    [int]$ThrottleLimit,

    [Parameter(
        ValuefromPipelineByPropertyName = $true
    )]
    [ValidateRange(0, 1)]
    [double]$RatioFreeSpace = 0.05,

    [Parameter(
        ValuefromPipelineByPropertyName = $true
    )]
    [Switch]$JSONFormat
)

BEGIN {
    Set-StrictMode -Version Latest
    #Requires -RunAsAdministrator
    #Requires -Version 5.1

    #Test-FslDependencies
    . .\Functions\Private\Test-FslDependencies.ps1

    #Invoke-Parallel - This is used to support powershell 5.x - if and when PoSh 7 and above become standard, move to ForEach-Object
    . .\Functions\Private\Invoke-Parallel.ps1

    #Mount-FslDisk
    . .\Functions\Private\Mount-FslDisk.ps1

    #Dismount-FslDisk
    . .\Functions\Private\Dismount-FslDisk.ps1

    #Optimize-OneDisk
    . .\Functions\Private\Optimize-OneDisk.ps1

    #Write Output to file and optionally to pipeline
    . .\Functions\Private\Write-VhdOutput.ps1

    $servicesToTest = 'defragsvc', 'vds', 'smphost'
    try {
        $servicesToTest | Test-FslDependencies -ErrorAction Stop
    }
    catch {
        $err = $error[0]
        Write-Error $err
        return
    }

    $numberOfCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

    switch ($true) {
        (-not ($ThrottleLimit)) {
            $ThrottleLimit = $numberOfCores * 2
            Write-Information "Throttle limit set to $ThrottleLimit"
            break
        }
        (($ThrottleLimit / 2) -gt $numberOfCores) {
            $ThrottleLimit = $numberOfCores * 2
            Write-Warning "Number of threads (ThrottleLimit) has been reduced to double the number of cores - $ThrottleLimit"
            break
        }
        ($ThrottleLimit -lt $numberOfCores) {
            Write-Information "Number of threads (ThrotttleLimit) can be used on this system to speed up processing"
        }
        ($ThrottleLimit -le 4 ) {
            Write-Warning "Number of threads($ThrottleLimit) in use on this machine is low, increase cores/threads to increase processing speeed"
        }
        Default {}
    }


    if (Test-Path $LogFilePath) {
        $pth = Get-Item $LogFilePath
        if ($pth.Attributes = 'Directory') {
            $LogFilePath = Join-Path $LogFilePath "FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH-mm-ss).csv"
        }
    }

    if ($JSONFormat -and ($logfilePath.EndsWith('.csv'))) {
        $LogFilePath.Replace('.csv', '.json')
    }

} # Begin
PROCESS {

    #Check that the path is valid
    if (-not (Test-Path $Path)) {
        Write-Error "$Path not found"
        return
    }

    #Get a list of Virtual Hard Disk files depending on the recurse parameter
    if ($Recurse) {
        $diskList = Get-ChildItem -File -Filter *.vhd? -Path $Path -Recurse
    }
    else {
        $diskList = Get-ChildItem -File -Filter *.vhd? -Path $Path
    }

    #Todo check if vhd is possible with Cloud Cache
    $diskList = $diskList | Where-Object { $_.Name -ne "Merge.vhdx" -and $_.Name -ne "RW.vhdx" }

    #If we can't find and files with the extension vhd or vhdx quit
    if ( ($diskList | Measure-Object).count -eq 0 ) {
        Write-Warning "No files to process in $Path"
        return
    }

    $scriptblockForEachObject = {

        #ForEach-Object -Parallel doesn't seem to want to import functions, so defining them twice, good job this is automated.

        #Mount-FslDisk
        . .\Functions\Private\Mount-FslDisk.ps1
        #Dismount-FslDisk
        . .\Functions\Private\Dismount-FslDisk.ps1
        #Optimize-OneDisk
        . .\Functions\Private\Optimize-OneDisk.ps1
        #Write Output to file and optionally to pipeline
        . .\Functions\Private\Write-VhdOutput.ps1

        $paramOptimizeOneDisk = @{
            Disk                = $_
            DeleteOlderThanDays = $using:DeleteOlderThanDays
            IgnoreLessThanGB    = $using:IgnoreLessThanGB
            LogFilePath         = $using:LogFilePath
            PassThru            = $using:PassThru
            RatioFreeSpace      = $using:RatioFreeSpace
        }
        Optimize-OneDisk @paramOptimizeOneDisk

    } #Scriptblock

    $scriptblockInvokeParallel = {

        $disk = $_

        $paramOptimizeOneDisk = @{
            Disk                = $disk
            DeleteOlderThanDays = $DeleteOlderThanDays
            IgnoreLessThanGB    = $IgnoreLessThanGB
            LogFilePath         = $LogFilePath
            PassThru            = $PassThru
            RatioFreeSpace      = $RatioFreeSpace
        }
        Optimize-OneDisk @paramOptimizeOneDisk

    } #Scriptblock

    if ($PSVersionTable.PSVersion -ge [version]"7.0") {
        $diskList | ForEach-Object -Parallel $scriptblockForEachObject -ThrottleLimit $ThrottleLimit
    }
    else {
        $diskList | Invoke-Parallel -ScriptBlock $scriptblockInvokeParallel -Throttle $ThrottleLimit -ImportFunctions -ImportVariables -ImportModules
    }

} #Process
END { } #End