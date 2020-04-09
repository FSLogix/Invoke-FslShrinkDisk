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
        [System.String]$LogFilePath
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #requires -Module Hyper-V
        #Write-Log
        function Write-Log {
            <#
        .SYNOPSIS

        Single function to enable logging to file.
        .DESCRIPTION

        The Log file can be output to any directory. A single log entry looks like this:
        2018-01-30 14:40:35 INFO:    'My log text'

        Log entries can be Info, Warn, Error or Debug

        The function takes pipeline input and you can even pipe exceptions straight to the function for automatic logging.

        The $PSDefaultParameterValues built-in Variable can be used to conveniently set the path and/or JSONformat switch at the top of the script:

        $PSDefaultParameterValues = @{"Write-Log:Path" = 'C:\YourPathHere'}

        $PSDefaultParameterValues = @{"Write-Log:JSONformat" = $true}

        .PARAMETER Message

        This is the body of the log line and should contain the information you wish to log.
        .PARAMETER Level

        One of four logging levels: INFO, WARN, ERROR or DEBUG.  This is an optional parameter and defaults to INFO
        .PARAMETER Path

        The path where you want the log file to be created.  This is an optional parameter and defaults to "$env:temp\PowershellScript.log"
        .PARAMETER StartNew

        This will blank any current log in the path, it should be used at the start of a script when you don't want to append to an existing log.
        .PARAMETER Exception

        Used to pass a powershell exception to the logging function for automatic logging
        .PARAMETER JSONFormat

        Used to change the logging format from human readable to machine readable format, this will be a single line like the example format below:
        In this format the timestamp will include a much more granular time which will also include timezone information.

        {"TimeStamp":"2018-02-01T12:01:24.8908638+00:00","Level":"Warn","Message":"My message"}

        .EXAMPLE
        Write-Log -StartNew
        Starts a new logfile in the default location

        .EXAMPLE
        Write-Log -StartNew -Path c:\logs\new.log
        Starts a new logfile in the specified location

        .EXAMPLE
        Write-Log 'This is some information'
        Appends a new information line to the log.

        .EXAMPLE
        Write-Log -level warning 'This is a warning'
        Appends a new warning line to the log.

        .EXAMPLE
        Write-Log -level Error 'This is an Error'
        Appends a new Error line to the log.

        .EXAMPLE
        Write-Log -Exception $error[0]
        Appends a new Error line to the log with the message being the contents of the exception message.

        .EXAMPLE
        $error[0] | Write-Log
        Appends a new Error line to the log with the message being the contents of the exception message.

        .EXAMPLE
        'My log message' | Write-Log
        Appends a new Info line to the log with the message being the contents of the string.

        .EXAMPLE
        Write-Log 'My log message' -JSONFormat
        Appends a new Info line to the log with the message. The line will be in JSONFormat.
    #>

            [CmdletBinding(DefaultParametersetName = "LOG")]
            Param (
                [Parameter(Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = 'LOG',
                    Position = 0)]
                [ValidateNotNullOrEmpty()]
                [string]$Message,

                [Parameter(Mandatory = $false,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = 'LOG',
                    Position = 1 )]
                [ValidateSet('Error', 'Warning', 'Info', 'Debug')]
                [string]$Level = "Info",

                [Parameter(Mandatory = $false,
                    ValueFromPipelineByPropertyName = $true,
                    Position = 2)]
                [string]$Path = "$env:temp\PowershellScript.log",

                [Parameter(Mandatory = $false,
                    ValueFromPipelineByPropertyName = $true)]
                [switch]$JSONFormat,

                [Parameter(Mandatory = $false,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = 'STARTNEW')]
                [switch]$StartNew,

                [Parameter(Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = 'EXCEPTION')]
                [System.Management.Automation.ErrorRecord]$Exception
            )

            BEGIN {
                Set-StrictMode -version Latest #Enforces most strict best practice.
            }

            PROCESS {
                #Switch on parameter set
                switch ($PSCmdlet.ParameterSetName) {
                    LOG {
                        #Get human readable date
                        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                        switch ( $Level ) {
                            'Info' { $LevelText = "INFO:   "; break }
                            'Error' { $LevelText = "ERROR:  "; break }
                            'Warning' { $LevelText = "WARNING:"; break }
                            'Debug' { $LevelText = "DEBUG:  "; break }
                        }

                        if ($JSONFormat) {
                            #Build an object so we can later convert it
                            $logObject = [PSCustomObject]@{
                                TimeStamp = Get-Date -Format o  #Get machine readable date
                                Level     = $Level
                                Message   = $Message
                            }
                            $logmessage = $logObject | ConvertTo-Json -Compress #Convert to a single line of JSON
                        }
                        else {
                            $logmessage = "$FormattedDate $LevelText $Message" #Build human readable line
                        }

                        $logmessage | Add-Content -Path $Path #write the line to a file
                        Write-Verbose $logmessage #Only verbose line in the function

                    } #LOG

                    EXCEPTION {
                        #Splat parameters
                        $WriteLogParams = @{
                            Level      = 'Error'
                            Message    = $Exception.Exception.Message
                            Path       = $Path
                            JSONFormat = $JSONFormat
                        }
                        Write-Log @WriteLogParams #Call itself to keep code clean
                        break

                    } #EXCEPTION

                    STARTNEW {
                        if (Test-Path $Path) {
                            Remove-Item $Path -Force
                        }
                        #Splat parameters
                        $WriteLogParams = @{
                            Level      = 'Info'
                            Message    = 'Starting Logfile'
                            Path       = $Path
                            JSONFormat = $JSONFormat
                        }
                        Write-Log @WriteLogParams
                        break

                    } #STARTNEW

                } #switch Parameter Set
            }

            END {
            }
        } #function
        #Invoke-Parallel
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
                [ValidateScript( {Test-Path $_ -pathtype leaf})]
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

                [validatescript( {Test-Path (Split-Path $_ -parent)})]
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
                        }).invoke()[0]

                    if ($ImportVariables) {
                        #Exclude common parameters, bound parameters, and automatic variables
                        Function _temp {[cmdletbinding(SupportsShouldProcess = $True)] param() }
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
                        $UserModules = @( Get-Module | Where-Object {$StandardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue)} | Select-Object -ExpandProperty Path )
                        $UserSnapins = @( Get-PSSnapin | Select-Object -ExpandProperty Name | Where-Object {$StandardUserEnv.Snapins -notcontains $_ } )
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
                                -PercentComplete $( Try { $script:completedCount / $totalCount * 100 } Catch {0} )
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
                        $UsingVariables = $ScriptBlock.ast.FindAll( {$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]}, $True)

                        If ($UsingVariables) {
                            $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
                            ForEach ($Ast in $UsingVariables) {
                                [void]$list.Add($Ast.SubExpression)
                            }

                            $UsingVar = $UsingVariables | Group-Object -Property SubExpression | ForEach-Object {$_.Group | Select-Object -First 1}

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
                            [void]$PowerShell.AddScript( {$VerbosePreference = 'Continue'})
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
                    Write-Verbose ( "Finish processing the remaining runspace jobs: {0}" -f ( @($runspaces | Where-Object {$_.Runspace -ne $Null}).Count) )

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
                    ValuefromPipelineByPropertyName = $true
                )]
                [Switch]$PassThru
            )

            BEGIN {
                Set-StrictMode -Version Latest
            } # Begin
            PROCESS {

                # FSLogix Disk Partition Number this won't work with vhds created with MS tools as their main partition number is 2
                $partitionNumber = 1

                try {
                    # Mount the disk without a drive letter and get it's info, Mount-DiskImage is used to remove reliance on Hyper-V tools
                    $mountedDisk = Mount-DiskImage -ImagePath $Path -NoDriveLetter -PassThru -ErrorAction Stop | Get-DiskImage -ErrorAction Stop
                }
                catch {
                    Write-Error "Failed to mount disk $Path"
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
                    Write-Error "Failed to create mounting directory $mountPath"
                    # Cleanup
                    $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
                    return
                }

                try {

                    $addPartitionAccessPathParams = @{
                        DiskNumber      = $mountedDisk.Number
                        PartitionNumber = $partitionNumber
                        AccessPath      = $mountPath
                        ErrorAction     = 'Stop'
                    }

                    Add-PartitionAccessPath @addPartitionAccessPathParams
                }
                catch {
                    Write-Error "Failed to create junction point to $mountPath"
                    # Cleanup
                    Remove-Item -Path $mountPath -ErrorAction SilentlyContinue
                    $mountedDisk | Dismount-DiskImage -ErrorAction SilentlyContinue
                    return
                }

                if ($PassThru) {
                    # Create output required for piping to Dismount-FslDisk
                    $output = [PSCustomObject]@{
                        Path       = $mountPath
                        DiskNumber = $mountedDisk.Number
                        ImagePath  = $mountedDisk.ImagePath
                    }
                    Write-Output $output
                }
                Write-Verbose "Mounted $Path"
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
                    ValuefromPipeline = $true,
                    Mandatory = $true
                )]
                [int16]$DiskNumber,

                [Parameter(
                    ValuefromPipelineByPropertyName = $true,
                    Mandatory = $true
                )]
                [String]$ImagePath,

                [Parameter(
                    ValuefromPipelineByPropertyName = $true
                )]
                [Switch]$PassThru    
            )

            BEGIN {
                Set-StrictMode -Version Latest
            } # Begin
            PROCESS {

                # FSLogix Disk Partition Number this won't work with vhds created with MS tools as their main partition number is 2
                $partitionNumber = 1

                if ($PassThru) {
                    $junctionPointRemoved = $false
                    $mountRemoved = $false
                    $directoryRemoved = $false
                }

                # Reverse the three tasks from Mount-FslDisk
                try {
                    Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $partitionNumber -AccessPath $Path -ErrorAction Stop | Out-Null
                    $junctionPointRemoved = $true
                }
                catch {
                    Write-Error "Failed to remove the junction point to $Path"
                }

                try {
                    Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop  | Out-Null
                    $mountRemoved = $true
                }
                catch {
                    Write-Error "Failed to dismount disk $ImagePath"
                }

                try {
                    Remove-Item -Path $Path -ErrorAction Stop  | Out-Null
                    $directoryRemoved = $true
                }
                catch {
                    Write-Error "Failed to delete temp mount directory $Path"
                }

                If ($PassThru) {
                    $output = [PSCustomObject]@{
                        JunctionPointRemoved = $junctionPointRemoved
                        MountRemoved         = $mountRemoved
                        DirectoryRemoved     = $directoryRemoved
                    }
                    Write-Output $output
                }
                Write-Verbose "Dismounted $ImagePath"
            } #Process
            END {} #End
        }  #function Dismount-FslDisk
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

                    $count = $ost | Measure-Object 

                    if ($count.Count -gt 1) {

                        $mailboxes = $ost.BaseName.trimend('(', ')', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0') | Group-Object | Select-Object -ExpandProperty Name

                        foreach ($mailbox in $mailboxes) {
                            $mailboxOst = $ost | Where-Object {$_.BaseName.StartsWith($mailbox)}

                            $count = $mailboxOst | Measure-Object

                            #Write-Log  "Found $count ost files for $mailbox"

                            if ($count -gt 1) {

                                $ostDelNum = $count - 1
                                #Write-Log "Deleting $ostDelNum ost files"
                                try {
                                    $latestOst = $mailboxOst | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                                    $mailboxOst | Where-Object {$_.Name -ne $latestOst.Name} | Remove-Item -Force -ErrorAction Stop
                                }
                                catch {
                                    #Write-log -level Error "Failed to delete ost files in $vhd for $mailbox"
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
            END {} #End
        }  #function Remove-FslMultiOst

        $PSDefaultParameterValues = @{ "Write-Log:Path" = $LogFilePath }

        $usableThreads = (Get-Ciminstance Win32_processor).ThreadCount - 2
        If ($usableThreads -le 2) { $usableThreads = 2 }
    } # Begin
    PROCESS {
        
        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found"
            break
        }

        if ($Recurse) {
            $listing = Get-ChildItem $Path -Recurse 
        }
        else {
            $listing = Get-ChildItem $Path
        }

        $diskList = $listing | Where-Object { $_.extension -in ".vhd", ".vhdx" }
        

        if ( ($diskList | Measure-Object).count -eq 0 ) {
            Write-Warning "No files to process"
        }


        $scriptblock = {

            Param ( $disk )

            $PSDefaultParameterValues = @{ "Write-Log:Path" = $LogFilePath }

            switch ($true) {
                $DeleteOlderThanDays {
                    if ($disk.LastAccessTime -lt (Get-Date).AddDays(-$DeleteOlderThanDays) ) { 
                        try {
                            Remove-Item -ErrorAction Stop
                        }
                        catch {
                            Write-Log -Level Error "Could Not Delete $disk"
                        }
                    }
                    break 
                }
                $IgnoreLessThanGB {
                    if ($disk.size -lt $IgnoreLessThanGB) {
                        Write-Log "$disk smaller than $IgnoreLessThanGB no action taken"
                        break
                    }
                }
                Default {
                    try {
                        $mount = Mount-FslDisk -Path $disk -PassThru

                        Remove-FslMultiOst -Path $mount.Path

                        $partitionsize = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber

                        if ($partitionsize.SizeMin / $partitionsize.SizeMax -lt 0.8 ) {
                            Resize-Partition -DiskNumber $mount.DiskNumber -Size $n.SizeMin 
                            $mount | DisMount-FslDisk
                            Resize-VHD $disk -ToMinimumSize
                            Optimize-VHD $disk
                            #Resize-VHD $Disk -SizeBytes 62914560000
                            $mount = Mount-FslDisk -Path $disk -PassThru
                            $partitionInfo = Get-PartitionSupportedSize -DiskNumber $mount.DiskNumber
                            Resize-Partition -DiskNumber $mount.DiskNumber -Size $partitionInfo.SizeMax
                            $mount | DisMount-FslDisk
                        }
                        else {
                            $mount | DisMount-FslDisk
                            Write-Log "$disk not resized due to insufficient free space"
                        }
                    }
                    catch {
                        $error[0] | Write-Log
                        Write-Log -Level Error "Could not resize $disk"
                    }                
                }
            }
        } #Scriptblock

        $diskList | Invoke-Parallel -ScriptBlock $scriptblock -Throttle $usableThreads -ImportFunctions -ImportVariables -ImportModules

    } #Process
    END {} #End
}  #function Invoke-FslShrinkDisk