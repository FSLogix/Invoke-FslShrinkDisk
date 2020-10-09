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
    [int]$ThrottleLimit = 8,

    [Parameter(
        ValuefromPipelineByPropertyName = $true
    )]
    [ValidateRange(0,1)]
    [double]$RatioFreeSpace = 0.05
)

BEGIN {
    Set-StrictMode -Version Latest
    #Requires -RunAsAdministrator

    #Test-FslDependencies
Function Test-FslDependencies {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [System.String[]]$Name
    )
    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
    }
    PROCESS {

        Foreach ($svc in $Name) {
            $svcObject = Get-Service -Name $svc

            If ($svcObject.Status -eq "Running") { Return }

            If ($svcObject.StartType -eq "Disabled") {
                Write-Warning ("[{0}] Setting Service to Manual" -f $svcObject.DisplayName)
                Set-Service -Name $svc -StartupType Manual | Out-Null
            }

            Start-Service -Name $svc | Out-Null

            if ((Get-Service -Name $svc).Status -ne 'Running') {
                Write-Error "Can not start $svcObject.DisplayName"
            }
        }
    }
    END {

    }
}

    #Invoke-Parallel - This is used to support powershell 5.x - if and when PoSh 7 and above become standard, move to ForEach-Object
function Invoke-Parallel {
    <#
    .SYNOPSIS
        Function to control parallel processing using runspaces

    .DESCRIPTION
        Function to control parallel processing using runspaces

            Note that each runspace will not have access to variables and commands loaded in your session or in other runspaces by default.
            This behaviour can be changed with parameters.

    .PARAMETER ScriptFile
        File to run against all input objects.  Must include parameter to take in the input object, or use $args.  Optionally, include parameter to take in parameter.  Example: C:\script.ps1

    .PARAMETER ScriptBlock
        Scriptblock to run against all computers.

        You may use $Using:<Variable> language in PowerShell 3 and later.

            The parameter block is added for you, allowing behaviour similar to foreach-object:
                Refer to the input object as $_.
                Refer to the parameter parameter as $parameter

    .PARAMETER InputObject
        Run script against these specified objects.

    .PARAMETER Parameter
        This object is passed to every script block.  You can use it to pass information to the script block; for example, the path to a logging folder

            Reference this object as $parameter if using the scriptblock parameterset.

    .PARAMETER ImportVariables
        If specified, get user session variables and add them to the initial session state

    .PARAMETER ImportModules
        If specified, get loaded modules and pssnapins, add them to the initial session state

    .PARAMETER Throttle
        Maximum number of threads to run at a single time.

    .PARAMETER SleepTimer
        Milliseconds to sleep after checking for completed runspaces and in a few other spots.  I would not recommend dropping below 200 or increasing above 500

    .PARAMETER RunspaceTimeout
        Maximum time in seconds a single thread can run.  If execution of your code takes longer than this, it is disposed.  Default: 0 (seconds)

        WARNING:  Using this parameter requires that maxQueue be set to throttle (it will be by default) for accurate timing.  Details here:
        http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430

    .PARAMETER NoCloseOnTimeout
        Do not dispose of timed out tasks or attempt to close the runspace if threads have timed out. This will prevent the script from hanging in certain situations where threads become non-responsive, at the expense of leaking memory within the PowerShell host.

    .PARAMETER MaxQueue
        Maximum number of powershell instances to add to runspace pool.  If this is higher than $throttle, $timeout will be inaccurate

        If this is equal or less than throttle, there will be a performance impact

        The default value is $throttle times 3, if $runspaceTimeout is not specified
        The default value is $throttle, if $runspaceTimeout is specified

    .PARAMETER LogFile
        Path to a file where we can log results, including run time for each thread, whether it completes, completes with errors, or times out.

    .PARAMETER AppendLog
        Append to existing log

    .PARAMETER Quiet
        Disable progress bar

    .EXAMPLE
        Each example uses Test-ForPacs.ps1 which includes the following code:
            param($computer)

            if(test-connection $computer -count 1 -quiet -BufferSize 16){
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=1;
                    Kodak=$(
                        if((test-path "\\$computer\c$\users\public\desktop\Kodak Direct View Pacs.url") -or (test-path "\\$computer\c$\documents and settings\all users\desktop\Kodak Direct View Pacs.url") ){"1"}else{"0"}
                    )
                }
            }
            else{
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=0;
                    Kodak="NA"
                }
            }

            $object

    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject $(get-content C:\pcs.txt) -runspaceTimeout 10 -throttle 10

            Pulls list of PCs from C:\pcs.txt,
            Runs Test-ForPacs against each
            If any query takes longer than 10 seconds, it is disposed
            Only run 10 threads at a time

    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject c-is-ts-91, c-is-ts-95

            Runs against c-is-ts-91, c-is-ts-95 (-computername)
            Runs Test-ForPacs against each

    .EXAMPLE
        $stuff = [pscustomobject] @{
            ContentFile = "windows\system32\drivers\etc\hosts"
            Logfile = "C:\temp\log.txt"
        }

        $computers | Invoke-Parallel -parameter $stuff {
            $contentFile = join-path "\\$_\c$" $parameter.contentfile
            Get-Content $contentFile |
                set-content $parameter.logfile
        }

        This example uses the parameter argument.  This parameter is a single object.  To pass multiple items into the script block, we create a custom object (using a PowerShell v3 language) with properties we want to pass in.

        Inside the script block, $parameter is used to reference this parameter object.  This example sets a content file, gets content from that file, and sets it to a predefined log file.

    .EXAMPLE
        $test = 5
        1..2 | Invoke-Parallel -ImportVariables {$_ * $test}

        Add variables from the current session to the session state.  Without -ImportVariables $Test would not be accessible

    .EXAMPLE
        $test = 5
        1..2 | Invoke-Parallel {$_ * $Using:test}

        Reference a variable from the current session with the $Using:<Variable> syntax.  Requires PowerShell 3 or later. Note that -ImportVariables parameter is no longer necessary.

    .FUNCTIONALITY
        PowerShell Language

    .NOTES
        Credit to Boe Prox for the base runspace code and $Using implementation
            http://learn-powershell.net/2012/05/10/speedy-network-information-query-using-powershell/
            http://gallery.technet.microsoft.com/scriptcenter/Speedy-Network-Information-5b1406fb#content
            https://github.com/proxb/PoshRSJob/

        Credit to T Bryce Yehl for the Quiet and NoCloseOnTimeout implementations

        Credit to Sergei Vorobev for the many ideas and contributions that have improved functionality, reliability, and ease of use

    .LINK
        https://github.com/RamblingCookieMonster/Invoke-Parallel
    #>
    [cmdletbinding(DefaultParameterSetName = 'ScriptBlock')]
    Param (
        [Parameter(Mandatory = $false, position = 0, ParameterSetName = 'ScriptBlock')]
        [System.Management.Automation.ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory = $false, ParameterSetName = 'ScriptFile')]
        [ValidateScript( { Test-Path $_ -pathtype leaf })]
        $ScriptFile,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('CN', '__Server', 'IPAddress', 'Server', 'ComputerName')]
        [PSObject]$InputObject,

        [PSObject]$Parameter,

        [switch]$ImportVariables,
        [switch]$ImportModules,
        [switch]$ImportFunctions,

        [int]$Throttle = 20,
        [int]$SleepTimer = 200,
        [int]$RunspaceTimeout = 0,
        [switch]$NoCloseOnTimeout = $false,
        [int]$MaxQueue,

        [validatescript( { Test-Path (Split-Path $_ -parent) })]
        [switch] $AppendLog = $false,
        [string]$LogFile,

        [switch] $Quiet = $false
    )
    begin {
        #No max queue specified?  Estimate one.
        #We use the script scope to resolve an odd PowerShell 2 issue where MaxQueue isn't seen later in the function
        if ( -not $PSBoundParameters.ContainsKey('MaxQueue') ) {
            if ($RunspaceTimeout -ne 0) { $script:MaxQueue = $Throttle }
            else { $script:MaxQueue = $Throttle * 3 }
        }
        else {
            $script:MaxQueue = $MaxQueue
        }
        $ProgressId = Get-Random
        Write-Verbose "Throttle: '$throttle' SleepTimer '$sleepTimer' runSpaceTimeout '$runspaceTimeout' maxQueue '$maxQueue' logFile '$logFile'"

        #If they want to import variables or modules, create a clean runspace, get loaded items, use those to exclude items
        if ($ImportVariables -or $ImportModules -or $ImportFunctions) {
            $StandardUserEnv = [powershell]::Create().addscript( {

                    #Get modules, snapins, functions in this clean runspace
                    $Modules = Get-Module | Select-Object -ExpandProperty Name
                    $Snapins = Get-PSSnapin | Select-Object -ExpandProperty Name
                    $Functions = Get-ChildItem function:\ | Select-Object -ExpandProperty Name

                    #Get variables in this clean runspace
                    #Called last to get vars like $? into session
                    $Variables = Get-Variable | Select-Object -ExpandProperty Name

                    #Return a hashtable where we can access each.
                    @{
                        Variables = $Variables
                        Modules   = $Modules
                        Snapins   = $Snapins
                        Functions = $Functions
                    }
                }, $true).invoke()[0]

            if ($ImportVariables) {
                #Exclude common parameters, bound parameters, and automatic variables
                Function _temp { [cmdletbinding(SupportsShouldProcess = $True)] param() }
                $VariablesToExclude = @( (Get-Command _temp | Select-Object -ExpandProperty parameters).Keys + $PSBoundParameters.Keys + $StandardUserEnv.Variables )
                Write-Verbose "Excluding variables $( ($VariablesToExclude | Sort-Object ) -join ", ")"

                # we don't use 'Get-Variable -Exclude', because it uses regexps.
                # One of the veriables that we pass is '$?'.
                # There could be other variables with such problems.
                # Scope 2 required if we move to a real module
                $UserVariables = @( Get-Variable | Where-Object { -not ($VariablesToExclude -contains $_.Name) } )
                Write-Verbose "Found variables to import: $( ($UserVariables | Select-Object -expandproperty Name | Sort-Object ) -join ", " | Out-String).`n"
            }
            if ($ImportModules) {
                $UserModules = @( Get-Module | Where-Object { $StandardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue) } | Select-Object -ExpandProperty Path )
                $UserSnapins = @( Get-PSSnapin | Select-Object -ExpandProperty Name | Where-Object { $StandardUserEnv.Snapins -notcontains $_ } )
            }
            if ($ImportFunctions) {
                $UserFunctions = @( Get-ChildItem function:\ | Where-Object { $StandardUserEnv.Functions -notcontains $_.Name } )
            }
        }

        #region functions
        Function Get-RunspaceData {
            [cmdletbinding()]
            param( [switch]$Wait )
            #loop through runspaces
            #if $wait is specified, keep looping until all complete
            Do {
                #set more to false for tracking completion
                $more = $false

                #Progress bar if we have inputobject count (bound parameter)
                if (-not $Quiet) {
                    Write-Progress -Id $ProgressId -Activity "Running Query" -Status "Starting threads"`
                        -CurrentOperation "$startedCount threads defined - $totalCount input objects - $script:completedCount input objects processed"`
                        -PercentComplete $( Try { $script:completedCount / $totalCount * 100 } Catch { 0 } )
                }

                #run through each runspace.
                Foreach ($runspace in $runspaces) {

                    #get the duration - inaccurate
                    $currentdate = Get-Date
                    $runtime = $currentdate - $runspace.startTime
                    $runMin = [math]::Round( $runtime.totalminutes , 2 )

                    #set up log object
                    $log = "" | Select-Object Date, Action, Runtime, Status, Details
                    $log.Action = "Removing:'$($runspace.object)'"
                    $log.Date = $currentdate
                    $log.Runtime = "$runMin minutes"

                    #If runspace completed, end invoke, dispose, recycle, counter++
                    If ($runspace.Runspace.isCompleted) {

                        $script:completedCount++

                        #check if there were errors
                        if ($runspace.powershell.Streams.Error.Count -gt 0) {
                            #set the logging info and move the file to completed
                            $log.status = "CompletedWithErrors"
                            Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                            foreach ($ErrorRecord in $runspace.powershell.Streams.Error) {
                                Write-Error -ErrorRecord $ErrorRecord
                            }
                        }
                        else {
                            #add logging details and cleanup
                            $log.status = "Completed"
                            Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                        }

                        #everything is logged, clean up the runspace
                        $runspace.powershell.EndInvoke($runspace.Runspace)
                        $runspace.powershell.dispose()
                        $runspace.Runspace = $null
                        $runspace.powershell = $null
                    }
                    #If runtime exceeds max, dispose the runspace
                    ElseIf ( $runspaceTimeout -ne 0 -and $runtime.totalseconds -gt $runspaceTimeout) {
                        $script:completedCount++
                        $timedOutTasks = $true

                        #add logging details and cleanup
                        $log.status = "TimedOut"
                        Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                        Write-Error "Runspace timed out at $($runtime.totalseconds) seconds for the object:`n$($runspace.object | out-string)"

                        #Depending on how it hangs, we could still get stuck here as dispose calls a synchronous method on the powershell instance
                        if (!$noCloseOnTimeout) { $runspace.powershell.dispose() }
                        $runspace.Runspace = $null
                        $runspace.powershell = $null
                        $completedCount++
                    }

                    #If runspace isn't null set more to true
                    ElseIf ($runspace.Runspace -ne $null ) {
                        $log = $null
                        $more = $true
                    }

                    #log the results if a log file was indicated
                    if ($logFile -and $log) {
                        ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1] | out-file $LogFile -append
                    }
                }

                #Clean out unused runspace jobs
                $temphash = $runspaces.clone()
                $temphash | Where-Object { $_.runspace -eq $Null } | ForEach-Object {
                    $Runspaces.remove($_)
                }

                #sleep for a bit if we will loop again
                if ($PSBoundParameters['Wait']) { Start-Sleep -milliseconds $SleepTimer }

                #Loop again only if -wait parameter and there are more runspaces to process
            } while ($more -and $PSBoundParameters['Wait'])

            #End of runspace function
        }
        #endregion functions

        #region Init

        if ($PSCmdlet.ParameterSetName -eq 'ScriptFile') {
            $ScriptBlock = [scriptblock]::Create( $(Get-Content $ScriptFile | out-string) )
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
            #Start building parameter names for the param block
            [string[]]$ParamsToAdd = '$_'
            if ( $PSBoundParameters.ContainsKey('Parameter') ) {
                $ParamsToAdd += '$Parameter'
            }

            $UsingVariableData = $Null

            # This code enables $Using support through the AST.
            # This is entirely from  Boe Prox, and his https://github.com/proxb/PoshRSJob module; all credit to Boe!

            if ($PSVersionTable.PSVersion.Major -gt 2) {
                #Extract using references
                $UsingVariables = $ScriptBlock.ast.FindAll( { $args[0] -is [System.Management.Automation.Language.UsingExpressionAst] }, $True)

                If ($UsingVariables) {
                    $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
                    ForEach ($Ast in $UsingVariables) {
                        [void]$list.Add($Ast.SubExpression)
                    }

                    $UsingVar = $UsingVariables | Group-Object -Property SubExpression | ForEach-Object { $_.Group | Select-Object -First 1 }

                    #Extract the name, value, and create replacements for each
                    $UsingVariableData = ForEach ($Var in $UsingVar) {
                        try {
                            $Value = Get-Variable -Name $Var.SubExpression.VariablePath.UserPath -ErrorAction Stop
                            [pscustomobject]@{
                                Name       = $Var.SubExpression.Extent.Text
                                Value      = $Value.Value
                                NewName    = ('$__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                                NewVarName = ('__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                            }
                        }
                        catch {
                            Write-Error "$($Var.SubExpression.Extent.Text) is not a valid Using: variable!"
                        }
                    }
                    $ParamsToAdd += $UsingVariableData | Select-Object -ExpandProperty NewName -Unique

                    $NewParams = $UsingVariableData.NewName -join ', '
                    $Tuple = [Tuple]::Create($list, $NewParams)
                    $bindingFlags = [Reflection.BindingFlags]"Default,NonPublic,Instance"
                    $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl', $bindingFlags))

                    $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast, @($Tuple))

                    $ScriptBlock = [scriptblock]::Create($StringScriptBlock)

                    Write-Verbose $StringScriptBlock
                }
            }

            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($ParamsToAdd -Join ", "))`r`n" + $Scriptblock.ToString())
        }
        else {
            Throw "Must provide ScriptBlock or ScriptFile"; Break
        }

        Write-Debug "`$ScriptBlock: $($ScriptBlock | Out-String)"
        Write-Verbose "Creating runspace pool and session states"

        #If specified, add variables and modules/snapins to session state
        $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        if ($ImportVariables -and $UserVariables.count -gt 0) {
            foreach ($Variable in $UserVariables) {
                $sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )
            }
        }
        if ($ImportModules) {
            if ($UserModules.count -gt 0) {
                foreach ($ModulePath in $UserModules) {
                    $sessionstate.ImportPSModule($ModulePath)
                }
            }
            if ($UserSnapins.count -gt 0) {
                foreach ($PSSnapin in $UserSnapins) {
                    [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
                }
            }
        }
        if ($ImportFunctions -and $UserFunctions.count -gt 0) {
            foreach ($FunctionDef in $UserFunctions) {
                $sessionstate.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionDef.Name, $FunctionDef.ScriptBlock))
            }
        }

        #Create runspace pool
        $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
        $runspacepool.Open()

        Write-Verbose "Creating empty collection to hold runspace jobs"
        $Script:runspaces = New-Object System.Collections.ArrayList

        #If inputObject is bound get a total count and set bound to true
        $bound = $PSBoundParameters.keys -contains "InputObject"
        if (-not $bound) {
            [System.Collections.ArrayList]$allObjects = @()
        }

        #Set up log file if specified
        if ( $LogFile -and (-not (Test-Path $LogFile) -or $AppendLog -eq $false)) {
            New-Item -ItemType file -Path $logFile -Force | Out-Null
            ("" | Select-Object -Property Date, Action, Runtime, Status, Details | ConvertTo-Csv -NoTypeInformation -Delimiter ";")[0] | Out-File $LogFile
        }

        #write initial log entry
        $log = "" | Select-Object -Property Date, Action, Runtime, Status, Details
        $log.Date = Get-Date
        $log.Action = "Batch processing started"
        $log.Runtime = $null
        $log.Status = "Started"
        $log.Details = $null
        if ($logFile) {
            ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1] | Out-File $LogFile -Append
        }
        $timedOutTasks = $false
        #endregion INIT
    }
    process {
        #add piped objects to all objects or set all objects to bound input object parameter
        if ($bound) {
            $allObjects = $InputObject
        }
        else {
            [void]$allObjects.add( $InputObject )
        }
    }
    end {
        #Use Try/Finally to catch Ctrl+C and clean up.
        try {
            #counts for progress
            $totalCount = $allObjects.count
            $script:completedCount = 0
            $startedCount = 0
            foreach ($object in $allObjects) {
                #region add scripts to runspace pool
                #Create the powershell instance, set verbose if needed, supply the scriptblock and parameters
                $powershell = [powershell]::Create()

                if ($VerbosePreference -eq 'Continue') {
                    [void]$PowerShell.AddScript( { $VerbosePreference = 'Continue' })
                }

                [void]$PowerShell.AddScript($ScriptBlock).AddArgument($object)

                if ($parameter) {
                    [void]$PowerShell.AddArgument($parameter)
                }

                # $Using support from Boe Prox
                if ($UsingVariableData) {
                    Foreach ($UsingVariable in $UsingVariableData) {
                        Write-Verbose "Adding $($UsingVariable.Name) with value: $($UsingVariable.Value)"
                        [void]$PowerShell.AddArgument($UsingVariable.Value)
                    }
                }

                #Add the runspace into the powershell instance
                $powershell.RunspacePool = $runspacepool

                #Create a temporary collection for each runspace
                $temp = "" | Select-Object PowerShell, StartTime, object, Runspace
                $temp.PowerShell = $powershell
                $temp.StartTime = Get-Date
                $temp.object = $object

                #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
                $temp.Runspace = $powershell.BeginInvoke()
                $startedCount++

                #Add the temp tracking info to $runspaces collection
                Write-Verbose ( "Adding {0} to collection at {1}" -f $temp.object, $temp.starttime.tostring() )
                $runspaces.Add($temp) | Out-Null

                #loop through existing runspaces one time
                Get-RunspaceData

                #If we have more running than max queue (used to control timeout accuracy)
                #Script scope resolves odd PowerShell 2 issue
                $firstRun = $true
                while ($runspaces.count -ge $Script:MaxQueue) {
                    #give verbose output
                    if ($firstRun) {
                        Write-Verbose "$($runspaces.count) items running - exceeded $Script:MaxQueue limit."
                    }
                    $firstRun = $false

                    #run get-runspace data and sleep for a short while
                    Get-RunspaceData
                    Start-Sleep -Milliseconds $sleepTimer
                }
                #endregion add scripts to runspace pool
            }
            Write-Verbose ( "Finish processing the remaining runspace jobs: {0}" -f ( @($runspaces | Where-Object { $_.Runspace -ne $Null }).Count) )

            Get-RunspaceData -wait
            if (-not $quiet) {
                Write-Progress -Id $ProgressId -Activity "Running Query" -Status "Starting threads" -Completed
            }
        }
        finally {
            #Close the runspace pool, unless we specified no close on timeout and something timed out
            if ( ($timedOutTasks -eq $false) -or ( ($timedOutTasks -eq $true) -and ($noCloseOnTimeout -eq $false) ) ) {
                Write-Verbose "Closing the runspace pool"
                $runspacepool.close()
            }
            #collect garbage
            [gc]::Collect()
        }
    }
}

    #Mount-FslDisk
function Mount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [alias('FullName')]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [Int]$TimeOut = 3,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        try {
            # Mount the disk without a drive letter and get it's info, Mount-DiskImage is used to remove reliance on Hyper-V tools
            $mountedDisk = Mount-DiskImage -ImagePath $Path -NoDriveLetter -PassThru -ErrorAction Stop
        }
        catch {
            $e = $error[0]
            Write-Error "Failed to mount disk - `"$e`""
            return
        }


        $diskNumber = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($diskNumber -eq $false -and $timespan -gt (Get-Date)) {
            Start-Sleep 0.1
            try {
                $mountedDisk = Get-DiskImage -ImagePath $Path
                if ($mountedDisk.Number) {
                    $diskNumber = $true
                }
            }
            catch {
                $diskNumber = $false
            }

        }

        if ($diskNumber -eq $false) {
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error 'Could not dismount Disk Due to no Disknumber'
            }
            Write-Error 'Cannot get mount information'
            return
        }

        $partitionType = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($partitionType -eq $false -and $timespan -gt (Get-Date)) {

            try {
                $allPartition = Get-Partition -DiskNumber $mountedDisk.Number -ErrorAction Stop

                if ($allPartition.Type -contains 'Basic') {
                    $partitionType = $true
                    $partition = $allPartition | Where-Object -Property 'Type' -EQ -Value 'Basic'
                }
            }
            catch {
                if (($allPartition | Measure-Object).Count -gt 0) {
                    $partition = $allPartition | Select-Object -Last 1
                    $partitionType = $true
                }
                else{

                    $partitionType = $false
                }

            }
            Start-Sleep 0.1
        }

        if ($partitionType -eq $false) {
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error 'Could not dismount disk with no partition'
            }
            Write-Error 'Cannot get partition information'
            return
        }

        # Assign vhd to a random path in temp folder so we don't have to worry about free drive letters which can be horrible
        # New-Guid not used here for PoSh 3 compatibility
        $tempGUID = [guid]::NewGuid().ToString()
        $mountPath = Join-Path $Env:Temp ('FSLogixMnt-' + $tempGUID)

        try {
            # Create directory which we will mount too
            New-Item -Path $mountPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch {
            $e = $error[0]
            # Cleanup
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error "Could not dismount disk when no folder could be created - `"$e`""
            }
            Write-Error "Failed to create mounting directory - `"$e`""
            return
        }

        try {
            $addPartitionAccessPathParams = @{
                DiskNumber      = $mountedDisk.Number
                PartitionNumber = $partition.PartitionNumber
                AccessPath      = $mountPath
                ErrorAction     = 'Stop'
            }

            Add-PartitionAccessPath @addPartitionAccessPathParams
        }
        catch {
            $e = $error[0]
            # Cleanup
            Remove-Item -Path $mountPath -Force -Recurse -ErrorAction SilentlyContinue
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error "Could not dismount disk when no junction point could be created - `"$e`""
            }
            Write-Error "Failed to create junction point to - `"$e`""
            return
        }

        if ($PassThru) {
            # Create output required for piping to Dismount-FslDisk
            $output = [PSCustomObject]@{
                Path       = $mountPath
                DiskNumber = $mountedDisk.Number
                ImagePath  = $mountedDisk.ImagePath
                PartitionNumber = $partition.PartitionNumber
            }
            Write-Output $output
        }
        Write-Verbose "Mounted $Path to $mountPath"
    } #Process
    END {

    } #End
}  #function Mount-FslDisk

    #Dismount-FslDisk
function Dismount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]$ImagePath,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$Timeout = 120
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        $mountRemoved = $false
        $directoryRemoved = $false

        # Reverse the tasks from Mount-FslDisk

        $timeStampDirectory = (Get-Date).AddSeconds(20)

        while ((Get-Date) -lt $timeStampDirectory -and $directoryRemoved -ne $true) {
            try {
                Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop | Out-Null
                $directoryRemoved = $true
            }
            catch {
                $directoryRemoved = $false
            }
        }
        if (Test-Path $Path) {
            Write-Warning "Failed to delete temp mount directory $Path"
        }


        $timeStampDismount = (Get-Date).AddSeconds($Timeout)
        while ((Get-Date) -lt $timeStampDismount -and $mountRemoved -ne $true) {
            try {
                Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop | Out-Null
                #double/triple check disk is dismounted due to disk manager service being a pain.

                try {
                    $image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop

                    switch ($image.Attached) {
                        $null { $mountRemoved = $false ; Start-Sleep 0.1; break }
                        $true { $mountRemoved = $false ; break}
                        $false { $mountRemoved = $true ; break }
                        Default { $mountRemoved = $false }
                    }
                }
                catch {
                    $mountRemoved = $false
                }
            }
            catch {
                $mountRemoved = $false
            }
        }
        if ($mountRemoved -ne $true) {
            Write-Error "Failed to dismount disk $ImagePath"
        }

        If ($PassThru) {
            $output = [PSCustomObject]@{
                MountRemoved         = $mountRemoved
                DirectoryRemoved     = $directoryRemoved
            }
            Write-Output $output
        }
        if ($directoryRemoved -and $mountRemoved) {
            Write-Verbose "Dismounted $ImagePath"
        }

    } #Process
    END { } #End
}  #function Dismount-FslDisk

    #Optimize-OneDisk
function Optimize-OneDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.IO.FileInfo]$Disk,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$DeleteOlderThanDays,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$IgnoreLessThanGB,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [double]$RatioFreeSpace = 0.05,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$MountTimeout = 30,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$LogFilePath = "$env:TEMP\FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH-mm-ss).csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [switch]$Passthru

    )

    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
        $hyperv = $false
    } # Begin
    PROCESS {
        #In case there are disks left mounted let's try to clean up.
        Dismount-DiskImage -ImagePath $Disk.FullName -ErrorAction SilentlyContinue

        #Get start time for logfile
        $startTime = Get-Date
        if ( $IgnoreLessThanGB ) {
            $IgnoreLessThanBytes = $IgnoreLessThanGB * 1024 * 1024 * 1024
        }

        #Grab size of disk being processed
        $originalSize = $Disk.Length

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below, these can be overridden as I need to.  Calclations to be done in the output function, raw data goes in.
        $PSDefaultParameterValues = @{
            "Write-VhdOutput:Path"         = $LogFilePath
            "Write-VhdOutput:StartTime"    = $startTime
            "Write-VhdOutput:Name"         = $Disk.Name
            "Write-VhdOutput:DiskState"    = $null
            "Write-VhdOutput:OriginalSize" = $originalSize
            "Write-VhdOutput:FinalSize"    = $originalSize
            "Write-VhdOutput:FullName"     = $Disk.FullName
            "Write-VhdOutput:Passthru"     = $Passthru
        }

        #Check it is a disk
        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            Write-VhdOutput -DiskState 'File Is Not a Virtual Hard Disk format with extension vhd or vhdx' -EndTime (Get-Date)
            return
        }

        #If it's older than x days delete disk
        If ( $DeleteOlderThanDays ) {
            #Last Access time isn't always reliable if diff disks are used so lets be safe and use the most recent of access and write
            $mostRecent = $Disk.LastAccessTime, $Disk.LastWriteTime | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            if ($mostRecent -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    Write-VhdOutput -DiskState "Deleted" -FinalSize 0 -EndTime (Get-Date)
                }
                catch {
                    Write-VhdOutput -DiskState 'Disk Deletion Failed' -EndTime (Get-Date)
                }
                return
            }
        }

        #As disks take time to process, if you have a lot of disks, it may not be worth shrinking the small onesBytes
        if ( $IgnoreLessThanGB -and $originalSize -lt $IgnoreLessThanBytes ) {
            Write-VhdOutput -DiskState 'Ignored' -EndTime (Get-Date)
            return
        }

        #Initial disk Mount
        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -TimeOut 30 -PassThru -ErrorAction Stop
        }
        catch {
            $err = $error[0]
            Write-VhdOutput -DiskState $err -EndTime (Get-Date)
            return
        }

        #Grabbing partition info can fail when the client is under heavy load so.......
        $timespan = (Get-Date).AddSeconds(120)
        $partInfo = $null
        while (($partInfo | Measure-Object).Count -lt 1 -and $timespan -gt (Get-Date)) {
            try {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction Stop | Where-Object -Property 'Type' -EQ -Value 'Basic' -ErrorAction Stop
            }
            catch {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction SilentlyContinue | Select-Object -Last 1
            }
            Start-Sleep 0.1
        }

        if (($partInfo | Measure-Object).Count -eq 0) {
            $mount | DisMount-FslDisk
            Write-VhdOutput -DiskState 'No Partition Information - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            return
        }

        $timespan = (Get-Date).AddSeconds(120)
        $defrag = $false
        while ($defrag -eq $false -and $timespan -gt (Get-Date)) {
            try {
                Get-Volume -Partition $partInfo -ErrorAction Stop | Optimize-Volume -ErrorAction Stop
                $defrag = $true
            }
            catch {
                try {
                    Get-Volume -ErrorAction Stop | Where-Object {
                        $_.UniqueId -like "*$($partInfo.Guid)*"
                        -or $_.Path -Like "*$($partInfo.Guid)*"
                        -or $_.ObjectId -Like "*$($partInfo.Guid)*" } | Optimize-Volume -ErrorAction Stop
                    $defrag = $true
                }
                catch {
                    $defrag = $false
                    Start-Sleep 0.1
                }
                $defrag = $false
            }
        }

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        $partSize = $false
        $timespan = (Get-Date).AddSeconds(30)
        while ($partSize -eq $false -and $timespan -gt (Get-Date)) {
            try {
                $partitionsize = $partInfo | Get-PartitionSupportedSize -ErrorAction Stop
                $sizeMax = $partitionsize.SizeMax
                $partSize = $true
            }
            catch {
                try {
                    $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -PartitionNumber $mount.PartitionNumber -ErrorAction Stop
                    $sizeMax = $partitionsize.SizeMax
                    $partSize = $true
                }
                catch {
                    $partSize = $false
                    Start-Sleep 0.1
                }
                $partSize = $false

            }
        }

        if ($partSize -eq $false) {
            #$partInfo | Export-Clixml -Path "$env:TEMP\ForJim-$($Disk.Name).xml"
            Write-VhdOutput -DiskState 'No Partition Supported Size Info - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        #If you can't shrink the partition much, you can't reclaim a lot of space, so skipping if it's not worth it. Otherwise shink partition and dismount disk

        if ( $partitionsize.SizeMin -gt $disk.Length ) {
            Write-VhdOutput -DiskState "SkippedAlreadyMinimum" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        if (($partitionsize.SizeMin / $disk.Length) -gt (1 - $RatioFreeSpace) ) {
            Write-VhdOutput -DiskState "LessThan$(100*$RatioFreeSpace)%FreeInsideDisk" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {

            #In some cases you can't do the partition shrink to the min so increasing by 100 MB each time till it shrinks
            $i = 0
            $resize = $false
            $targetSize = $partitionsize.SizeMin
            $sizeBytesIncrement = 100 * 1024 * 1024

            while ($i -le 5 -and $resize -eq $false) {
                try {
                    Resize-Partition -InputObject $partInfo -Size $targetSize -ErrorAction Stop
                    $resize = $true
                }
                catch {
                    $resize = $false
                    $targetSize = $targetSize + $sizeBytesIncrement
                    $i++
                }
                finally {
                    Start-Sleep 1
                }
            }

            #Whatever happens now we need to dismount

            if ($resize -eq $false) {
                Write-VhdOutput -DiskState "PartitionShrinkFailed" -EndTime (Get-Date)
                $mount | DisMount-FslDisk
                return
            }
        }

        $mount | DisMount-FslDisk

        #Change the disk size and grab the new size

        $retries = 0
        $success = $false
        #Diskpart is a little erratic and can fail occasionally, so stuck it in a loop.
        while ($retries -lt 30 -and $success -ne $true) {

            $tempFileName = "$env:TEMP\FslDiskPart$($Disk.Name).txt"

            #Let's put diskpart into a function just so I can use Pester to Mock it
            function invoke-diskpart ($Path) {
                #diskpart needs you to write a txt file so you can automate it, because apparently it's 1989.
                #A better way would be to use optimize-vhd from the Hyper-V module,
                #   but that only comes along with installing the actual role, which needs CPU virtualisation extensions present,
                #   which is a PITA in cloud and virtualised environments where you can't do Hyper-V.
                #MaybeDo, use hyper-V module if it's there if not use diskpart? two code paths to do the same thing probably not smart though, it would be a way to solve localisation issues.
                Set-Content -Path $Path -Value "SELECT VDISK FILE=`'$($Disk.FullName)`'"
                Add-Content -Path $Path -Value 'attach vdisk readonly'
                Add-Content -Path $Path -Value 'COMPACT VDISK'
                Add-Content -Path $Path -Value 'detach vdisk'
                $result = DISKPART /s $Path
                Write-Output $result
            }

            $diskPartResult = invoke-diskpart -Path $tempFileName

            #diskpart doesn't return an object (1989 remember) so we have to parse the text output.
            if ($diskPartResult -contains 'DiskPart successfully compacted the virtual disk file.') {
                $finalSize = Get-ChildItem $Disk.FullName | Select-Object -ExpandProperty Length
                $success = $true
                Remove-Item $tempFileName
            }
            else {
                Set-Content -Path "$env:TEMP\FslDiskPartError$($Disk.Name)-$retries.log" -Value $diskPartResult
                $retries++
                #if DiskPart fails, try, try again.
            }
            Start-Sleep 1
        }

        If ($success -ne $true) {
            Write-VhdOutput -DiskState "DiskShrinkFailed" -EndTime (Get-Date)
            Remove-Item $tempFileName
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {
            #Now we need to reinflate the partition to its previous size
            try {
                $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber | Where-Object -Property 'Type' -EQ -Value 'Basic'
                Resize-Partition -InputObject $partInfo -Size $sizeMax -ErrorAction Stop
                $paramWriteVhdOutput = @{
                    DiskState = "Success"
                    FinalSize = $finalSize
                    EndTime   = Get-Date
                }
                Write-VhdOutput @paramWriteVhdOutput
            }
            catch {
                Write-VhdOutput -DiskState "PartitionSizeRestoreFailed" -EndTime (Get-Date)
                return
            }
            finally {
                $mount | DisMount-FslDisk
            }
        }


        $paramWriteVhdOutput = @{
            DiskState = "Success"
            FinalSize = $finalSize
            EndTime   = Get-Date
        }
        Write-VhdOutput @paramWriteVhdOutput
    } #Process
    END { } #End
}  #function Optimize-OneDisk

    #Write Output to file and optionally to pipeline
function Write-VhdOutput {
    [CmdletBinding()]

    Param (
        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Path,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Name,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$DiskState,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$OriginalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FinalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FullName,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$StartTime,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$EndTime,

        [Parameter(
            Mandatory = $true
        )]
        [Switch]$Passthru
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        #unit conversion and calculation should happen in output function
        $output = [PSCustomObject]@{
            Name             = $Name
            StartTime        = $StartTime.ToLongTimeString()
            EndTime          = $EndTime.ToLongTimeString()
            'ElapsedTime(s)' = [math]::Round(($EndTime - $StartTime).TotalSeconds, 1)
            DiskState        = $DiskState
            OriginalSizeGB   = [math]::Round( $OriginalSize / 1GB, 2 )
            FinalSizeGB      = [math]::Round( $FinalSize / 1GB, 2 )
            SpaceSavedGB     = [math]::Round( ($OriginalSize - $FinalSize) / 1GB, 2 )
            FullName         = $FullName
        }

        if ($Passthru) {
            Write-Output $output
        }
        $success = $False
        $retries = 0
        while ($retries -lt 10 -and $success -ne $true) {
            try {
                $output | Export-Csv -Path $Path -NoClobber -Append -ErrorAction Stop -NoTypeInformation
                $success = $true
            }
            catch {
                $retries++
            }
            Start-Sleep 1
        }


    } #Process
    END { } #End
}  #function Write-VhdOutput.ps1

    $servicesToTest = 'defragsvc', 'vds'
    try{
        $servicesToTest | Test-FslDependencies -ErrorAction Stop
    }
    catch{
        $err = $error[0]
        Write-Error $err
        return
    }
    $numberOfCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

    If (($ThrottleLimit / 2) -gt $numberOfCores) {

        $ThrottleLimit = $numberOfCores * 2
        Write-Warning "Number of threads set to double the number of cores - $ThrottleLimit"
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

    $diskList = $diskList | Where-Object { $_.Name -ne "Merge.vhdx" -and $_.Name -ne "RW.vhdx" }

    #If we can't find and files with the extension vhd or vhdx quit
    if ( ($diskList | Measure-Object).count -eq 0 ) {
        Write-Warning "No files to process in $Path"
        return
    }

    $scriptblockForEachObject = {

        #ForEach-Object -Parallel doesn't seem to want to import functions, so defining them twice, good job this is automated.

        #Mount-FslDisk
function Mount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [alias('FullName')]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true
        )]
        [Int]$TimeOut = 3,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        try {
            # Mount the disk without a drive letter and get it's info, Mount-DiskImage is used to remove reliance on Hyper-V tools
            $mountedDisk = Mount-DiskImage -ImagePath $Path -NoDriveLetter -PassThru -ErrorAction Stop
        }
        catch {
            $e = $error[0]
            Write-Error "Failed to mount disk - `"$e`""
            return
        }


        $diskNumber = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($diskNumber -eq $false -and $timespan -gt (Get-Date)) {
            Start-Sleep 0.1
            try {
                $mountedDisk = Get-DiskImage -ImagePath $Path
                if ($mountedDisk.Number) {
                    $diskNumber = $true
                }
            }
            catch {
                $diskNumber = $false
            }

        }

        if ($diskNumber -eq $false) {
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error 'Could not dismount Disk Due to no Disknumber'
            }
            Write-Error 'Cannot get mount information'
            return
        }

        $partitionType = $false
        $timespan = (Get-Date).AddSeconds($TimeOut)
        while ($partitionType -eq $false -and $timespan -gt (Get-Date)) {

            try {
                $allPartition = Get-Partition -DiskNumber $mountedDisk.Number -ErrorAction Stop

                if ($allPartition.Type -contains 'Basic') {
                    $partitionType = $true
                    $partition = $allPartition | Where-Object -Property 'Type' -EQ -Value 'Basic'
                }
            }
            catch {
                if (($allPartition | Measure-Object).Count -gt 0) {
                    $partition = $allPartition | Select-Object -Last 1
                    $partitionType = $true
                }
                else{

                    $partitionType = $false
                }

            }
            Start-Sleep 0.1
        }

        if ($partitionType -eq $false) {
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error 'Could not dismount disk with no partition'
            }
            Write-Error 'Cannot get partition information'
            return
        }

        # Assign vhd to a random path in temp folder so we don't have to worry about free drive letters which can be horrible
        # New-Guid not used here for PoSh 3 compatibility
        $tempGUID = [guid]::NewGuid().ToString()
        $mountPath = Join-Path $Env:Temp ('FSLogixMnt-' + $tempGUID)

        try {
            # Create directory which we will mount too
            New-Item -Path $mountPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch {
            $e = $error[0]
            # Cleanup
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error "Could not dismount disk when no folder could be created - `"$e`""
            }
            Write-Error "Failed to create mounting directory - `"$e`""
            return
        }

        try {
            $addPartitionAccessPathParams = @{
                DiskNumber      = $mountedDisk.Number
                PartitionNumber = $partition.PartitionNumber
                AccessPath      = $mountPath
                ErrorAction     = 'Stop'
            }

            Add-PartitionAccessPath @addPartitionAccessPathParams
        }
        catch {
            $e = $error[0]
            # Cleanup
            Remove-Item -Path $mountPath -Force -Recurse -ErrorAction SilentlyContinue
            try { $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue }
            catch {
                Write-Error "Could not dismount disk when no junction point could be created - `"$e`""
            }
            Write-Error "Failed to create junction point to - `"$e`""
            return
        }

        if ($PassThru) {
            # Create output required for piping to Dismount-FslDisk
            $output = [PSCustomObject]@{
                Path       = $mountPath
                DiskNumber = $mountedDisk.Number
                ImagePath  = $mountedDisk.ImagePath
                PartitionNumber = $partition.PartitionNumber
            }
            Write-Output $output
        }
        Write-Verbose "Mounted $Path to $mountPath"
    } #Process
    END {

    } #End
}  #function Mount-FslDisk
        #Dismount-FslDisk
function Dismount-FslDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]$ImagePath,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$Timeout = 120
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    } # Begin
    PROCESS {

        $mountRemoved = $false
        $directoryRemoved = $false

        # Reverse the tasks from Mount-FslDisk

        $timeStampDirectory = (Get-Date).AddSeconds(20)

        while ((Get-Date) -lt $timeStampDirectory -and $directoryRemoved -ne $true) {
            try {
                Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop | Out-Null
                $directoryRemoved = $true
            }
            catch {
                $directoryRemoved = $false
            }
        }
        if (Test-Path $Path) {
            Write-Warning "Failed to delete temp mount directory $Path"
        }


        $timeStampDismount = (Get-Date).AddSeconds($Timeout)
        while ((Get-Date) -lt $timeStampDismount -and $mountRemoved -ne $true) {
            try {
                Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop | Out-Null
                #double/triple check disk is dismounted due to disk manager service being a pain.

                try {
                    $image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop

                    switch ($image.Attached) {
                        $null { $mountRemoved = $false ; Start-Sleep 0.1; break }
                        $true { $mountRemoved = $false ; break}
                        $false { $mountRemoved = $true ; break }
                        Default { $mountRemoved = $false }
                    }
                }
                catch {
                    $mountRemoved = $false
                }
            }
            catch {
                $mountRemoved = $false
            }
        }
        if ($mountRemoved -ne $true) {
            Write-Error "Failed to dismount disk $ImagePath"
        }

        If ($PassThru) {
            $output = [PSCustomObject]@{
                MountRemoved         = $mountRemoved
                DirectoryRemoved     = $directoryRemoved
            }
            Write-Output $output
        }
        if ($directoryRemoved -and $mountRemoved) {
            Write-Verbose "Dismounted $ImagePath"
        }

    } #Process
    END { } #End
}  #function Dismount-FslDisk
        #Optimize-OneDisk
function Optimize-OneDisk {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.IO.FileInfo]$Disk,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$DeleteOlderThanDays,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Int]$IgnoreLessThanGB,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [double]$RatioFreeSpace = 0.05,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$MountTimeout = 30,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$LogFilePath = "$env:TEMP\FslShrinkDisk $(Get-Date -Format yyyy-MM-dd` HH-mm-ss).csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [switch]$Passthru

    )

    BEGIN {
        #Requires -RunAsAdministrator
        Set-StrictMode -Version Latest
        $hyperv = $false
    } # Begin
    PROCESS {
        #In case there are disks left mounted let's try to clean up.
        Dismount-DiskImage -ImagePath $Disk.FullName -ErrorAction SilentlyContinue

        #Get start time for logfile
        $startTime = Get-Date
        if ( $IgnoreLessThanGB ) {
            $IgnoreLessThanBytes = $IgnoreLessThanGB * 1024 * 1024 * 1024
        }

        #Grab size of disk being processed
        $originalSize = $Disk.Length

        #Set default parameter values for the Write-VhdOutput command to prevent repeating code below, these can be overridden as I need to.  Calclations to be done in the output function, raw data goes in.
        $PSDefaultParameterValues = @{
            "Write-VhdOutput:Path"         = $LogFilePath
            "Write-VhdOutput:StartTime"    = $startTime
            "Write-VhdOutput:Name"         = $Disk.Name
            "Write-VhdOutput:DiskState"    = $null
            "Write-VhdOutput:OriginalSize" = $originalSize
            "Write-VhdOutput:FinalSize"    = $originalSize
            "Write-VhdOutput:FullName"     = $Disk.FullName
            "Write-VhdOutput:Passthru"     = $Passthru
        }

        #Check it is a disk
        if ($Disk.Extension -ne '.vhd' -and $Disk.Extension -ne '.vhdx' ) {
            Write-VhdOutput -DiskState 'File Is Not a Virtual Hard Disk format with extension vhd or vhdx' -EndTime (Get-Date)
            return
        }

        #If it's older than x days delete disk
        If ( $DeleteOlderThanDays ) {
            #Last Access time isn't always reliable if diff disks are used so lets be safe and use the most recent of access and write
            $mostRecent = $Disk.LastAccessTime, $Disk.LastWriteTime | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            if ($mostRecent -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) {
                try {
                    Remove-Item $Disk.FullName -ErrorAction Stop -Force
                    Write-VhdOutput -DiskState "Deleted" -FinalSize 0 -EndTime (Get-Date)
                }
                catch {
                    Write-VhdOutput -DiskState 'Disk Deletion Failed' -EndTime (Get-Date)
                }
                return
            }
        }

        #As disks take time to process, if you have a lot of disks, it may not be worth shrinking the small onesBytes
        if ( $IgnoreLessThanGB -and $originalSize -lt $IgnoreLessThanBytes ) {
            Write-VhdOutput -DiskState 'Ignored' -EndTime (Get-Date)
            return
        }

        #Initial disk Mount
        try {
            $mount = Mount-FslDisk -Path $Disk.FullName -TimeOut 30 -PassThru -ErrorAction Stop
        }
        catch {
            $err = $error[0]
            Write-VhdOutput -DiskState $err -EndTime (Get-Date)
            return
        }

        #Grabbing partition info can fail when the client is under heavy load so.......
        $timespan = (Get-Date).AddSeconds(120)
        $partInfo = $null
        while (($partInfo | Measure-Object).Count -lt 1 -and $timespan -gt (Get-Date)) {
            try {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction Stop | Where-Object -Property 'Type' -EQ -Value 'Basic' -ErrorAction Stop
            }
            catch {
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber -ErrorAction SilentlyContinue | Select-Object -Last 1
            }
            Start-Sleep 0.1
        }

        if (($partInfo | Measure-Object).Count -eq 0) {
            $mount | DisMount-FslDisk
            Write-VhdOutput -DiskState 'No Partition Information - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            return
        }

        $timespan = (Get-Date).AddSeconds(120)
        $defrag = $false
        while ($defrag -eq $false -and $timespan -gt (Get-Date)) {
            try {
                Get-Volume -Partition $partInfo -ErrorAction Stop | Optimize-Volume -ErrorAction Stop
                $defrag = $true
            }
            catch {
                try {
                    Get-Volume -ErrorAction Stop | Where-Object {
                        $_.UniqueId -like "*$($partInfo.Guid)*"
                        -or $_.Path -Like "*$($partInfo.Guid)*"
                        -or $_.ObjectId -Like "*$($partInfo.Guid)*" } | Optimize-Volume -ErrorAction Stop
                    $defrag = $true
                }
                catch {
                    $defrag = $false
                    Start-Sleep 0.1
                }
                $defrag = $false
            }
        }

        #Grab partition information so we know what size to shrink the partition to and what to re-enlarge it to.  This helps optimise-vhd work at it's best
        $partSize = $false
        $timespan = (Get-Date).AddSeconds(30)
        while ($partSize -eq $false -and $timespan -gt (Get-Date)) {
            try {
                $partitionsize = $partInfo | Get-PartitionSupportedSize -ErrorAction Stop
                $sizeMax = $partitionsize.SizeMax
                $partSize = $true
            }
            catch {
                try {
                    $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber -PartitionNumber $mount.PartitionNumber -ErrorAction Stop
                    $sizeMax = $partitionsize.SizeMax
                    $partSize = $true
                }
                catch {
                    $partSize = $false
                    Start-Sleep 0.1
                }
                $partSize = $false

            }
        }

        if ($partSize -eq $false) {
            #$partInfo | Export-Clixml -Path "$env:TEMP\ForJim-$($Disk.Name).xml"
            Write-VhdOutput -DiskState 'No Partition Supported Size Info - The Windows Disk SubSystem did not respond in a timely fashion try increasing number of cores or decreasing threads by using the ThrottleLimit parameter' -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        #If you can't shrink the partition much, you can't reclaim a lot of space, so skipping if it's not worth it. Otherwise shink partition and dismount disk

        if ( $partitionsize.SizeMin -gt $disk.Length ) {
            Write-VhdOutput -DiskState "SkippedAlreadyMinimum" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }


        if (($partitionsize.SizeMin / $disk.Length) -gt (1 - $RatioFreeSpace) ) {
            Write-VhdOutput -DiskState "LessThan$(100*$RatioFreeSpace)%FreeInsideDisk" -EndTime (Get-Date)
            $mount | DisMount-FslDisk
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {

            #In some cases you can't do the partition shrink to the min so increasing by 100 MB each time till it shrinks
            $i = 0
            $resize = $false
            $targetSize = $partitionsize.SizeMin
            $sizeBytesIncrement = 100 * 1024 * 1024

            while ($i -le 5 -and $resize -eq $false) {
                try {
                    Resize-Partition -InputObject $partInfo -Size $targetSize -ErrorAction Stop
                    $resize = $true
                }
                catch {
                    $resize = $false
                    $targetSize = $targetSize + $sizeBytesIncrement
                    $i++
                }
                finally {
                    Start-Sleep 1
                }
            }

            #Whatever happens now we need to dismount

            if ($resize -eq $false) {
                Write-VhdOutput -DiskState "PartitionShrinkFailed" -EndTime (Get-Date)
                $mount | DisMount-FslDisk
                return
            }
        }

        $mount | DisMount-FslDisk

        #Change the disk size and grab the new size

        $retries = 0
        $success = $false
        #Diskpart is a little erratic and can fail occasionally, so stuck it in a loop.
        while ($retries -lt 30 -and $success -ne $true) {

            $tempFileName = "$env:TEMP\FslDiskPart$($Disk.Name).txt"

            #Let's put diskpart into a function just so I can use Pester to Mock it
            function invoke-diskpart ($Path) {
                #diskpart needs you to write a txt file so you can automate it, because apparently it's 1989.
                #A better way would be to use optimize-vhd from the Hyper-V module,
                #   but that only comes along with installing the actual role, which needs CPU virtualisation extensions present,
                #   which is a PITA in cloud and virtualised environments where you can't do Hyper-V.
                #MaybeDo, use hyper-V module if it's there if not use diskpart? two code paths to do the same thing probably not smart though, it would be a way to solve localisation issues.
                Set-Content -Path $Path -Value "SELECT VDISK FILE=`'$($Disk.FullName)`'"
                Add-Content -Path $Path -Value 'attach vdisk readonly'
                Add-Content -Path $Path -Value 'COMPACT VDISK'
                Add-Content -Path $Path -Value 'detach vdisk'
                $result = DISKPART /s $Path
                Write-Output $result
            }

            $diskPartResult = invoke-diskpart -Path $tempFileName

            #diskpart doesn't return an object (1989 remember) so we have to parse the text output.
            if ($diskPartResult -contains 'DiskPart successfully compacted the virtual disk file.') {
                $finalSize = Get-ChildItem $Disk.FullName | Select-Object -ExpandProperty Length
                $success = $true
                Remove-Item $tempFileName
            }
            else {
                Set-Content -Path "$env:TEMP\FslDiskPartError$($Disk.Name)-$retries.log" -Value $diskPartResult
                $retries++
                #if DiskPart fails, try, try again.
            }
            Start-Sleep 1
        }

        If ($success -ne $true) {
            Write-VhdOutput -DiskState "DiskShrinkFailed" -EndTime (Get-Date)
            Remove-Item $tempFileName
            return
        }

        #If I decide to add Hyper-V module support, I'll need this code later
        if ($hyperv -eq $true) {
            #Now we need to reinflate the partition to its previous size
            try {
                $mount = Mount-FslDisk -Path $Disk.FullName -PassThru
                $partInfo = Get-Partition -DiskNumber $mount.DiskNumber | Where-Object -Property 'Type' -EQ -Value 'Basic'
                Resize-Partition -InputObject $partInfo -Size $sizeMax -ErrorAction Stop
                $paramWriteVhdOutput = @{
                    DiskState = "Success"
                    FinalSize = $finalSize
                    EndTime   = Get-Date
                }
                Write-VhdOutput @paramWriteVhdOutput
            }
            catch {
                Write-VhdOutput -DiskState "PartitionSizeRestoreFailed" -EndTime (Get-Date)
                return
            }
            finally {
                $mount | DisMount-FslDisk
            }
        }


        $paramWriteVhdOutput = @{
            DiskState = "Success"
            FinalSize = $finalSize
            EndTime   = Get-Date
        }
        Write-VhdOutput @paramWriteVhdOutput
    } #Process
    END { } #End
}  #function Optimize-OneDisk
        #Write Output to file and optionally to pipeline
function Write-VhdOutput {
    [CmdletBinding()]

    Param (
        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Path,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$Name,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$DiskState,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$OriginalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FinalSize,

        [Parameter(
            Mandatory = $true
        )]
        [System.String]$FullName,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$StartTime,

        [Parameter(
            Mandatory = $true
        )]
        [datetime]$EndTime,

        [Parameter(
            Mandatory = $true
        )]
        [Switch]$Passthru
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        #unit conversion and calculation should happen in output function
        $output = [PSCustomObject]@{
            Name             = $Name
            StartTime        = $StartTime.ToLongTimeString()
            EndTime          = $EndTime.ToLongTimeString()
            'ElapsedTime(s)' = [math]::Round(($EndTime - $StartTime).TotalSeconds, 1)
            DiskState        = $DiskState
            OriginalSizeGB   = [math]::Round( $OriginalSize / 1GB, 2 )
            FinalSizeGB      = [math]::Round( $FinalSize / 1GB, 2 )
            SpaceSavedGB     = [math]::Round( ($OriginalSize - $FinalSize) / 1GB, 2 )
            FullName         = $FullName
        }

        if ($Passthru) {
            Write-Output $output
        }
        $success = $False
        $retries = 0
        while ($retries -lt 10 -and $success -ne $true) {
            try {
                $output | Export-Csv -Path $Path -NoClobber -Append -ErrorAction Stop -NoTypeInformation
                $success = $true
            }
            catch {
                $retries++
            }
            Start-Sleep 1
        }


    } #Process
    END { } #End
}  #function Write-VhdOutput.ps1

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
