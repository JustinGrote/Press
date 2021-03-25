using namespace System.IO
function Get-Version {
    [CmdletBinding()]
    param(
        [String]$ProjectPath = $PressSetting.BuildEnvironment.ProjectPath,
        [Version]$GitVersionVersion = '5.6.6'
    )

    if (-not (Test-Path "$ProjectPath/.config/dotnet-tools.json")) {
        $dotnetNewManifestStatus = dotnet new tool-manifest
        if ($dotnetNewManifestStatus -ne 'The template "Dotnet local tool manifest file" was created successfully.') {
            throw "There was an error creating a dotnet tool manifest: $dotnetNewManifestStatus"
        }
    }

    [String]$dotnetToolRestoreStatus = dotnet tool restore *>&1
    $dotnetToolMatch = "*Tool 'gitversion.tool' (version '$GitVersionVersion') was restored.*"
    if ($dotnetToolRestoreStatus -notlike $dotnetToolMatch) {
        throw 'GitVersion dotnet tool was not found. Ensure you have a .NET manifest'
    }

    #Reference Dotnet Local Tool directly rather than trying to go through .NET EXE
    #This appears to be an issue where dotnet is installed but the tools aren't added to the path for Linux
    # $GitVersionExe = "$HOME/.dotnet/tools/dotnet-gitversion"
    $DotNetExe = "dotnet"
    [String[]]$GitVersionParams = 'gitversion','/nofetch'
    if (-not (
            $ProjectPath -and 
            (Test-Path (
                    Join-Path $ProjectPath 'GitVersion.yml' 
                )) 
        )) {
        #Use the Press Builtin
        $GitVersionConfigPath = Resolve-Path (Join-Path $MyInvocation.MyCommand.Module.ModuleBase '.\GitVersion.default.yml')
        $GitVersionParams += '/config'
        $GitVersionParams += $GitVersionConfigPath
    }

    try {
        $GitVersionOutput = & $DotNetExe @GitVersionParams
        if (-not $GitVersionOutput) { throw 'GitVersion returned no output. Are you sure it ran successfully?' }
        if ($LASTEXITCODE -ne 0) { throw "GitVersion returned exit code $LASTEXITCODE. Output:`n$GitVersionOutput" }

        #Since GitVersion doesn't return error exit codes, we look for error text in the output
        if ($GitVersionOutput -match '^[ERROR|INFO] \[') { throw "An error occured when running GitVersion.exe in $buildRoot" }
        $GitVersionInfo = $GitVersionOutput | ConvertFrom-Json -ErrorAction stop

        if ($DebugPreference -eq 'Continue') {
            & $GitVersionExe @GitVersionParams '/diag' *>&1 | Write-Debug
        }

        $GitVersionResult = $GitVersionInfo | 
            Select-Object branchname,majorminorpatch,prereleaselabel,semver,fullsemver,legacysemverpadded | 
            Format-Table |
            Out-String
        Write-Verbose "Gitversion Result: $GitVersionResult"

        if ($PressSetting.BuildEnvironment.BuildOutput) {
            #Dont use versioned folder
            #TODO: Potentially put this back
            # $PressSetting.BuildModuleOutput = [io.path]::Combine($PressSetting.BuildEnvironment.BuildOutput,$PressSetting.BuildEnvironment.ProjectName,$PressSetting.Version)
            $PressSetting.BuildModuleOutput = [io.path]::Combine($PressSetting.BuildEnvironment.BuildOutput,$PressSetting.BuildEnvironment.ProjectName)
        }
    } catch {
        Write-Warning "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is below...`r`n$GitVersionOutput"
        & $GitVersionexe /diag
        throw 'Exiting due to failed Gitversion execution'
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
}