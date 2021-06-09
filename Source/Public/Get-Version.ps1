using namespace System.IO
function Get-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][String]$ProjectPath,
        [Version]$GitVersionVersion = '5.6.6',
        [String]$GitVersionConfigPath = $(Resolve-Path (Join-Path $MyInvocation.MyCommand.Module.ModuleBase '.\GitVersion.default.yml'))
    )

    Write-Verbose "Using Gitversion Configuration $GitVersionConfigPath"
    $gitCommand = Get-Command -CommandType Application -Name 'git'
    if (-not $gitCommand) {
        throw 'git was not found in your path. Ensure git is installed and can be found.'
    }
    if (-not (Test-Path "$ProjectPath\.git")) {
        throw "No Git repository (.git folder) found in $ProjectPath. Please specify a folder with a git repository"
    }

    if (-not (Test-Path "$ProjectPath\.config\dotnet-tools.json")) {
        [String]$dotnetNewManifestStatus = & dotnet new tool-manifest -o $ProjectPath *>&1
        if ($dotnetNewManifestStatus -notlike '*was created successfully*') {
            throw "There was an error creating a dotnet tool manifest: $dotnetNewManifestStatus"
        }
        if (-not (Get-Item "$ProjectPath\.config\dotnet-tools.json")) {
            throw "The manifest command completed successfully but $ProjectPath\.config\dotnet-tools.json still could not be found. This is probably a bug."
        }
    }

    #TODO: Direct Json check maybe?
    [String]$gitVersionToolCheck = & dotnet tool list
    if ($gitVersionToolCheck -notlike "*gitversion.tool*$GitVersionVersion*") {
        & dotnet tool uninstall gitversion.tool | Out-Null
        [String]$gitversionInstall = & dotnet tool install gitversion.tool --version $GitVersionVersion
        if ($gitVersionInstall -notlike '*gitversion.tool*was successfully installed*') {
            throw "Failed to install gitversion local tool with dotnet: $gitVersionInstall"
        }
    }
    #Output from a command is String in Windows and Object[] in Linux. Cast to string to normalize.
    [String]$dotnetToolRestoreStatus = & dotnet tool restore *>&1
    $dotnetToolMatch = "*Tool 'gitversion.tool' (version '$GitVersionVersion') was restored.*"
    if ($dotnetToolRestoreStatus -notlike $dotnetToolMatch) {
        throw "GitVersion dotnet tool was not found. Ensure you have a .NET manifest. Message: $dotnetToolRestoreStatus"
    }

    #Reference Dotnet Local Tool directly rather than trying to go through .NET EXE
    #This appears to be an issue where dotnet is installed but the tools aren't added to the path for Linux
    # $GitVersionExe = "$HOME\.dotnet\tools/dotnet-gitversion"
    $DotNetExe = "dotnet"
    [String[]]$GitVersionParams = 'gitversion',$ProjectPath,'/nofetch'
    if (-not (
            $ProjectPath -and
            (Test-Path (
                    Join-Path $ProjectPath 'GitVersion.yml'
                ))
        )) {
        #Use the Press Builtin
        $GitVersionParams += '/config'
        $GitVersionParams += $GitVersionConfigPath
    }

    try {
        if ($DebugPreference -eq 'Continue') {
            $GitVersionParams += '/diag'
        }
        [String[]]$GitVersionOutput = & $DotNetExe @GitVersionParams *>&1

        if (-not $GitVersionOutput) { throw 'GitVersion returned no output. Are you sure it ran successfully?' }
        if ($LASTEXITCODE -ne 0) {
            if ($GitVersionOutput -like '*GitVersion.GitVersionException: No commits found on the current branch*') {
                #TODO: Auto-version calc maybe?
                throw 'There are no commits on your current git branch. Please make at least one commit before trying to calculate the version'
            }
            throw "GitVersion returned exit code $LASTEXITCODE. Output:`n$GitVersionOutput"
        }

        #Split Diagnostic Messages from Regex
        $i = 0
        foreach ($lineItem in $GitVersionOutput) {
            if ($GitVersionOutput[$i] -eq '{') {
                break
            }
            $i++
        }
        if ($i -ne 0) {
            [String[]]$diagMessages = $GitVersionOutput[0..($i - 1)]
            $diagMessages | Write-Debug
        }

        #Should not normally get this far if there are errors
        if ($diagMessages -match 'ERROR \[') {
            throw "An error occured when running GitVersion.exe in $ProjectPath. Diag Message: `n$diagMessages"
        }

        #There is some trailing debug info sometimes
        $jsonResult = $GitVersionOutput[$i..($GitVersionOutput.count - 1)] |
            Where-Object { $_ -notmatch 'Info.+Done writing' }

        $GitVersionInfo = $jsonResult | ConvertFrom-Json -ErrorAction stop

        #Fixup prerelease tag for Powershell modules
        if ($GitVersionInfo.NuGetPreReleaseTagV2 -match '[-.]') {
            Write-Verbose 'Detected invalid characters for Powershell Gallery Prerelease Tag. Fixing it up.'
            $GitVersionInfo.NuGetPreReleaseTagV2 = $GitVersionInfo.NuGetPreReleaseTagV2 -replace '[\-\.]',''
            $GitVersionInfo.NuGetVersionV2 = ($GitVersionInfo.MajorMinorPatch,$GitVersionInfo.NuGetPreReleaseTagV2).Where{$PSItem} -join '-'
        }

        $GitVersionResult = $GitVersionInfo |
            Select-Object BranchName, MajorMinorPatch, NuGetVersionV2, NuGetPreReleaseTagV2 |
            Format-List |
            Out-String
        Write-Verbose "Gitversion Result: `n$($GitVersionResult | Format-List | Out-String)"
    } catch {
        throw "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is below...`r`n$GitVersionOutput"
    } finally {
        #Restore the tag if it was present
        #TODO: Evaluate if this is still necessary
        # if ($currentTag) {
        #     write-build DarkYellow "Task $($task.name) - Restoring tag $currentTag."
        #     git tag $currentTag -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        # }
    }

    return $GitVersionInfo

    # #GA release detection
    # if ($BranchName -eq 'master') {
    #     $Script:IsGARelease = $true
    #     $Script:ProjectVersion = $ProjectBuildVersion
    # } else {
    #     #The regex strips all hypens but the first one. This shouldn't be necessary per NuGet spec but Update-ModuleManifest fails on it.
    #     $SCRIPT:ProjectPreReleaseVersion = $GitVersionInfo.nugetversion -replace '(?<=-.*)[-]'
    #     $SCRIPT:ProjectVersion = $ProjectPreReleaseVersion
    #     $SCRIPT:ProjectPreReleaseTag = $SCRIPT:ProjectPreReleaseVersion.split('-')[1]
    # }

    # write-build Green "Task $($task.name)` - Calculated Project Version: $ProjectVersion"

    # #Tag the release if this is a GA build
    # if ($BranchName -match '^(master|releases?[/-])') {
    #     write-build Green "Task $($task.name)` - In Master/Release branch, adding release tag v$ProjectVersion to this build"

    #     $SCRIPT:isTagRelease = $true
    #     if ($BranchName -eq 'master') {
    #         write-build Green "Task $($task.name)` - In Master branch, marking for General Availability publish"
    #         [Switch]$SCRIPT:IsGARelease = $true
    #     }
    # }

    # #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    # $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    # if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    # $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    # write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
}   # write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
}