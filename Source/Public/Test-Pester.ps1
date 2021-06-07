using namespace System.Management.Automation
function Test-Pester {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        #Root path to search for tests to run
        [Parameter(Mandatory, ParameterSetName = 'Default')][String]$Path,
        #Path where the coverage files should be output. Defaults to the build output path.
        [Parameter(Mandatory, ParameterSetName = 'Default')][String]$OutputPath,
        #A PesterConfiguration hashtable to use instead of the intelligent defaults. For advanced usage only.
        [Parameter(ParameterSetName = 'Configuration')][hashtable]$Configuration,
        #Run the result as a separate job, useful if testing modules with assemblies since they cannot be removed from
        #state. This is different than '-AsJob' because -AsJob typically drops to a job and this just runs it in a job
        [Switch]$InJob,
        #Run the job in Windows Powershell 5.1, if available. It will warn and proceed if it is not available (e.g. on Linux)
        [Switch]$UseWindowsPowershell,
        #No Write-Host Output, just produce the passthru and output file
        [Switch]$Quiet
    )
    #Load Pester Just-In-Time style, cannot use a requires because of module compilation
    #TODO: Allow Pester Version to be customizable
    Get-Module Pester -ErrorAction SilentlyContinue | Where-Object Version -LT '5.2.0' | Remove-Module -Force
    Import-Module Pester -MinimumVersion '5.2.0' -PassThru | Write-Verbose

    #FIXME: Allow for custom configurations once we figure out how to serialize them into a job. For now we just do a hashtable
    # if ($Configuration) { throw [NotSupportedException]'Custom Pester Configurations temporarily disabled while sorting out best way to run them in isolated job' }
    if (-not $Configuration) {
        $Configuration = @{
            Output     = @{
                Verbosity = 'Detailed'
            }
            Run        = @{
                PassThru = $true
                Path     = $Path
                #Exclude the output folder in case we dcopied any tests there to avoid duplicate testing. This should generally only matter for "meta" like Press
                #FIXME: Specify just the directory instead of a path search when https://github.com/pester/Pester/issues/1575 is fixed
                # ExcludePath = [String[]](Get-ChildItem -Recurse $OutputPath -Include '*.Tests.ps1')
            }
            TestResult = @{
                Enabled    = $true
                OutputPath = "$OutputPath/TEST-Results.xml"
            }
        }
        #If we are in vscode, add the VSCodeMarkers
        if ($host.name -match 'Visual Studio Code') {
            Write-Host -Fore Green '===Detected Visual Studio Code, Displaying Pester Test Links==='
            $Configuration.Debug = @{
                ShowNavigationMarkers = $true
            }
        }
    }

    if ($Quiet) {
        $Configuration.Output.Verbosity = 'None'
    }

    #Validate the configuration before we pass it to the job
    try {
        [void][PesterConfiguration]::new($Configuration)
    } catch [MethodInvocationException] {
        if ($PSItem.FullyQualifiedErrorId -eq 'NullReferenceException') {
            throw 'An invalid Pester Configuration was provided. An entry was present that doesnt match the Pester configuration schema. Check for typos and make sure that all entries match what is in [PesterConfiguration]::Default'
        }
    }

    #Workaround for PesterConfiguration/hashtables not serializing correctly
    #Reference: https://github.com/pester/Pester/issues/1977
    $configurationJson = $Configuration | ConvertTo-Json -Compress
    $TestResults = if ($InJob) {
        $StartJobParams = @{
            ScriptBlock = {
                #Workaround for PSIC Bug
                #Reference: https://github.com/PowerShell/vscode-powershell/issues/3399
                $winPSUserModPath = "$HOME/Documents/WindowsPowershell/Modules"
                if (
                    $PSEdition -eq 'Desktop' -and
                    (Test-Path $winPSUserModPath) -and
                    $ENV:PSModulePath.split([IO.Path]::PathSeparator) -notcontains $(Resolve-Path $winPSUserModPath)
                ) {
                    $ENV:PSModulePath = $(Resolve-Path $winPSUserModPath), $ENV:PSModulePath -join [IO.Path]::PathSeparator
                }

                #Require a modern version of Pester on 5.1
                try {
                    #TODO: Centralize the Pester Dependency version
                    Import-Module -Name Pester -MinimumVersion 5.2.0
                } catch {
                    #TODO: Search for it in pwsh folders or via virtual environment
                    throw 'You must have Pester 5.2 or greater installed in your Windows Powershell 5.1 session. Hint: Install-Module Pester -MinimumVersion 5.2.0 -Scope CurrentUser'
                }
                Set-Location $USING:PWD
                $configuration = [PesterConfiguration]$($USING:configurationJson | ConvertFrom-Json)
                Invoke-Pester -Configuration $configuration
            }
        }

        if ($UseWindowsPowershell) {
            try {
                Get-Command powershell.exe -ErrorAction stop
            } catch {
                Write-Error [NotSupportedException]'Test-Pester: -UseWindowsPowershell was specified but Powershell 5.1 is not available on this system.'
                return
            }
            $StartJobParams.PSVersion = '5.1'
        }

        Start-Job @StartJobParams | Receive-Job -Wait
    } else {
        Invoke-Pester -Configuration $Configuration
    }

    if ($Configuration.Run.PassThru) {
        if ($TestResults.Result -ne 'Passed') {
            throw "Failed $($TestResults.FailedCount) tests"
        }
    }


    Write-Output $TestResults
}