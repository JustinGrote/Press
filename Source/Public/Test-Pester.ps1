function Test-Pester {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        #Path where the Pester tests are located
        [Parameter(Mandatory,ParameterSetName = 'Default')][String]$Path,
        #Path where the coverage files should be output. Defaults to the build output path.
        [Parameter(Mandatory,ParameterSetName = 'Default')][String]$OutputPath,
        #A PesterConfiguration to use instead of the intelligent defaults. For advanced usage only.
        [Parameter(ParameterSetName = 'Configuration')]$Configuration
    )
    #Load Pester Just-In-Time style, cannot use a requires because of module compilation
    Get-Module pester -ErrorAction SilentlyContinue | Where-Object version -LT '5.0.0' | Remove-Module -Force
    Import-Module Pester -MinimumVersion '5.0.0' | Write-Verbose
    #We can't do this in the param block because pester and its classes may not be loaded yet.
    [PesterConfiguration]$Configuration = $Configuration

    #FIXME: Allow for custom configurations once we figure out how to serialize them into a job
    if ($Configuration) { throw [NotSupportedException]'Custom Pester Configurations temporarily disabled while sorting out best way to run them in isolated job' }
    if (-not $Configuration) {
        $Configuration = @{}
        #If we are in vscode, add the VSCodeMarkers
        if ($host.name -match 'Visual Studio Code') {
            Write-Host -Fore Green '===Detected Visual Studio Code, Displaying Pester Test Links==='
            $Configuration.Debug.ShowNavigationMarkers = $true
        }
        $Configuration.Output.Verbosity = 'Detailed'
        $Configuration.Run.PassThru = $true
        $Configuration.Run.Path = $Path
        $Configuration.CodeCoverage.Enabled = $false
        $Configuration.CodeCoverage.OutputPath = "$OutputPath/CodeCoverage.xml"
        $Configuration.TestResult.Enabled = $true
        $Configuration.TestResult.OutputPath = "$OutputPath/TEST-Results.xml"
        #Exclude the output folder in case we dcopied any tests there to avoid duplicate testing. This should generally only matter for "meta" like PowerForge
        #FIXME: Specify just the directory instead of a path search when https://github.com/pester/Pester/issues/1575 is fixed
        $Configuration.Run.ExcludePath = [String[]](Get-ChildItem -Recurse $OutputPath -Include '*.Tests.ps1')

    }

    $TestResults = Invoke-Pester -Configuration $Configuration

    if ($TestResults.Result -ne 'Passed') {
        throw "Failed $($TestResults.FailedCount) tests"
    }
    return $TestResults
}