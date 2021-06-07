#requires -module Press

$commonParams = @{
    Verbose = ($VerbosePreference -eq 'continue')
}

Enter-Build {
    #TODO: Make this faster by not relying on PSGetv2
    #TODO: Make this a separate task and have incremental build support
    $RequireModuleScript = try {
        Get-InstalledScript 'Install-RequiredModule' -ErrorAction Stop
    } catch {
        Install-Script -Force -AcceptLicense Install-RequiredModule -PassThru -ErrorAction Stop
    }
    #TODO: Move this to settings

    $ProgressPreference = 'SilentlyContinue'

    #Install Press Prererquisites
    $InstallRequiredModuleScript = Join-Path $RequireModuleScript.InstalledLocation 'Install-RequiredModule.ps1'
    $PressRequiredModuleManifest = "$PSScriptRoot\Config\RequiredModules.psd1"
    $ImportedModules = . $InstallRequiredModuleScript -RequiredModulesFile $PressRequiredModuleManifest -Import -ErrorAction Stop -WarningAction SilentlyContinue -Confirm:$false

    $SCRIPT:PressSetting = Get-PressSetting -ConfigBase $BuildRoot

    #TODO: Move this to PSSetting
    $customModuleManifest = "$BuildRoot/.config/RequiredModules.psd1"
    if (Test-Path $customModuleManifest) {
        Write-Verbose "Custom Required Modules detected at $customModuleManifest, loading..."
        $ImportedModules = . $InstallRequiredModuleScript -RequiredModulesFile $customModuleManifest -Import -ErrorAction Stop -WarningAction SilentlyContinue -Confirm:$false
    }

    New-Item -ItemType Directory -Path $PressSetting.Build.OutDir -Force | Out-Null

}

Task Press.Version @{
    Inputs  = {
        #Calculate a new version on every commit. Ignore for Github Actions due to PRs
        if (-not $ENV:GITHUB_ACTIONS) {
            Join-Path "$BuildRoot\.git\refs\heads\" $PressSetting.BuildEnvironment.BranchName
            Get-ChildItem "$BuildRoot\.git\refs\tags\"
        }
        #META: Gitversion Config
        #FIXME: This should probably be in settings
        [String]$SCRIPT:GitVersionConfig = ''
        if ($PressSetting.General.ModuleName -eq 'Press') {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.General.SrcRootDir 'GitVersion.default.yml'
        }

        #TODO: Move to Settings
        $GitVersionConfigPath = Join-Path $PressSetting.General.SrcRootDir 'Gitversion.yml'
        if (Test-Path $GitVersionConfigPath) {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.General.SrcRootDir 'Gitversion.yml'
        }

        #Gitversion config is optional but we want to detect changes if it exists
        if ($GitVersionConfig) {
            Get-Item $GitVersionConfig -ErrorAction SilentlyContinue
        }

        #Include default gitversion config as well
        Resolve-Path $PSScriptRoot\GitVersion.default.yml
    }
    Outputs = {
        "$($PressSetting.Build.OutDir)\.gitversion"
    }
    Jobs    = {
        $pressVersionParams = $commonParams.Clone()
        if ($SCRIPT:GitVersionConfig) {
            $pressVersionParams.GitVersionConfigPath = $SCRIPT:GitVersionConfig
        }

        $SCRIPT:GitVersionInfo = Get-PressVersion @pressVersionParams -ProjectPath $buildRoot
        $SCRIPT:GitVersionInfo | ConvertTo-Json > $Outputs
    }
}

Task Press.Clean {
    Invoke-PressClean -BuildOutputPath $PressSetting.Build.OutDir -BuildProjectName $PressSetting.General.ModuleName @commonParams
}

Task Press.Test.Pester @{
    Inputs  = { [String[]](Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir) }
    Outputs = { Join-Path $PressSetting.Build.OutDir 'TEST-Results.xml' }
    Jobs    = {
        $TestPressPesterParams = @{
            InJob      = $true
            Path       = $PressSetting.General.ProjectRoot
            OutputPath = $PressSetting.Build.OutDir
        }

        $pesterResult = Test-PressPester @TestPressPesterParams

        Assert $pesterResult 'No Pester Result produced'
    }
}

Task Press.Test.Pester.WindowsPowershell @{
    If      = {
        $pscommand = (Get-Command powershell.exe -ErrorAction SilentlyContinue)
        [Version]$requiredVersion = [Version](Import-PowerShellDataFile $PressSetting.General.ModuleManifestPath).PowershellVersion

        $pscommand -and -not ($requiredVersion -ge '6.0.0')
    }
    Inputs  = { [String[]](Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir) }
    Outputs = { Join-Path $PressSetting.Build.OutDir 'TEST-Results.xml' }
    Jobs    = {
        $TestPressPesterParams = @{
            InJob                = $true
            Path                 = $PressSetting.General.ProjectRoot
            OutputPath           = $PressSetting.Build.OutDir
            UseWindowsPowershell = $true
        }
        $pesterResult = Test-PressPester @TestPressPesterParams

        Test-PressPester @TestPressPesterParams

        Assert $pesterResult 'No Pester Result produced'
    }
}


#TODO: Inputs/Outputs
Task Press.ReleaseNotes Press.SetModuleVersion, {
    #TODO: Replace OutDir with ReleaseNotes or Changelog Specific PSSetting
    $Version = Get-Content (Join-Path $PressSetting.Build.OutDir '.gitversion')
    | ConvertFrom-Json
    | ForEach-Object NuGetVersionV2

    Build-PressReleaseNotes @commonParams -Path $PressSetting.General.ProjectRoot -Destination (Join-Path $PressSetting.Build.OutDir 'RELEASENOTES.MD') -Version $Version
}

#TODO: Inputs/Outputs
Task Press.SetReleaseNotes Press.ReleaseNotes, {
    $ModuleOutManifest = (Get-Item "$($PressSetting.Build.ModuleOutDir)\*.psd1")
    #TODO: Replace with specific PSSetting for modulemanifest
    [String]$ReleaseNotes = (Import-PowerShellDataFile $ModuleOutManifest).PrivateData.PSData.ReleaseNotes
    #TODO: Replace OutDir with ReleaseNotes or Changelog Specific PSSetting
    [String]$newReleaseNotes = Get-Content -Raw (Join-Path $PressSetting.Build.OutDir 'RELEASENOTES.MD')

    #Quirk: Update-ModuleManifest strips line feeds so we need to do the same when comparing
    #TODO: Better way to compare maybe?
    $ReleaseNotesCompare = [text.encoding]::UTF8.GetBytes($ReleaseNotes) | Where-Object { $_ -notin 10,13 }
    $ReleaseNotesNewCompare = [text.encoding]::UTF8.GetBytes($newReleaseNotes) | Where-Object { $_ -notin 10,13 }
    if (-not $ReleaseNotes -or (Compare-Object $ReleaseNotesCompare $ReleaseNotesNewCompare)) {
        #BUG: Do not use update-modulemanifest because https://github.com/PowerShell/PowerShellGetv2/issues/294
        BuildHelpers\Update-Metadata -Path $ModuleOutManifest -Property ReleaseNotes -Value $newReleaseNotes.Trim()
    }
}

#FIXME: Implement non-press version
Task Press.CopyModuleFiles @{
    Inputs  = {
        Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir
    }
    Outputs = {
        $buildItems = Get-ChildItem -File -Recurse $PressSetting.Build.ModuleOutDir
        if ($buildItems) { $buildItems } else { 'EmptyBuildOutputFolder' }
    }
    #(Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    Jobs    = {
        Remove-BuildItem $PressSetting.Build.ModuleOutDir

        $copyResult = Copy-PressModuleFiles @commonParams `
            -Destination $PressSetting.Build.ModuleOutDir `
            -PSModuleManifest $PressSetting.BuildEnvironment.PSModuleManifest

        $PressSetting.OutputModuleManifest = $copyResult.OutputModuleManifest
    }
}



Task Press.SetModuleVersion {
    $SCRIPT:GitVersionInfo = Get-Content -Raw "$($PressSetting.Build.OutDir)\.gitversion" | ConvertFrom-Json
    Set-PressVersion @commonParams -Version $GitVersionInfo.MajorMinorPatch -PreRelease $GitVersionInfo.NuGetPreReleaseTagV2 -Path (Get-Item "$($PressSetting.Build.ModuleOutDir)\*.psd1")
    if ($ENV:GITHUB_ACTIONS) {
        "::set-output name=version::$($SCRIPT:GitVersionInfo.MajorMinorPatch)"
        "::set-output name=nugetVersion::$($SCRIPT:GitVersionInfo.NugetVersionV2)"
        #TODO: Move elsewhere?
        "::set-output name=moduleName::$(Split-Path $PressSetting.General.ModuleName -Leaf)"
    }
}

Task Press.UpdatePublicFunctions {
    Update-PressPublicFunctions @commonParams -Path (Get-Item "$($PressSetting.Build.ModuleOutDir)\*.psd1") -PublicFunctionPath $(Join-Path $PressSetting.General.SrcRootDir 'Public')
}

Task Press.Package.Zip @{
    Inputs  = {
        Get-ChildItem -File -Recurse $PressSetting.Build.ModuleOutDir
        #Get-Item (Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    }
    Outputs = {
        $SCRIPT:GitVersionInfo = Get-Content -Raw "$($PressSetting.Build.OutDir)\.gitversion" | ConvertFrom-Json
        [String]$ZipFileName = $PressSetting.General.ModuleName + '.' + $SCRIPT:GitVersionInfo.NugetVersionV2 + '.zip'
        [String](Join-Path $PressSetting.Build.OutDir $ZipFileName)
    }
    Jobs    = {
        Remove-Item "$(Split-Path $Outputs)\*.zip"
        Compress-PressModule -Path $Inputs -Destination $Outputs
    }
}

Task Press.Package.Nuget @{
    Inputs  = {
        Get-ChildItem -File -Recurse $PressSetting.Build.ModuleOutDir
        Get-ChildItem -File -Recurse "$($PressSetting.Build.OutDir)\.gitversion"
        #Get-Item (Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    }
    Outputs = {
        # [String]$ZipFileName = $PressSetting.BuildEnvironment.ProjectName + '.' + $SCRIPT:GitVersionInfo.NugetVersionV2 + '.zip'
        # [String](Join-Path $PressSetting.BuildEnvironment.BuildOutput $ZipFileName)
        $nugetPackageName = $PressSetting.General.ModuleName + '.' + (Get-Content -Raw "$($PressSetting.Build.OutDir)\.gitversion" | ConvertFrom-Json).NugetVersionV2 + '.nupkg'

        "$($PressSetting.Build.OutDir)\$nugetPackageName"
    }
    Jobs    = {
        Remove-Item "$(Split-Path $Outputs)\*.nupkg"
        New-PressNugetPackage @commonParams -Path $PressSetting.Build.ModuleOutDir -Destination $PressSetting.Build.OutDir
    }
}

Task Press.UpdateGitHubRelease {
    if (-not $ENV:GITHUB_ACTIONS) {
        throw 'This task is only meant to be run inside Github Actions. You can still use Update-PressGithubRelease manually'
    }
    $VerbosePreference = 'continue'
    $ModuleOutManifest = (Get-Item "$($PressSetting.Build.ModuleOutDir)\*.psd1")
    [String[]]$ArtifactPaths = (Get-Item "$($PressSetting.Build.OutDir)\*.zip","$($PressSetting.Build.OutDir)\*.nupkg")
    $Owner,$Repository = $ENV:GITHUB_REPOSITORY -split '/'
    $Manifest = Import-PowerShellDataFile -Path $ModuleOutManifest
    $updateGHRParams = @{
        Owner        = $Owner
        Repository   = $Repository
        AccessToken  = $ENV:GITHUB_TOKEN
        Version      = $Manifest.ModuleVersion
        Body         = $Manifest.PrivateData.PSData.ReleaseNotes
        ArtifactPath = $ArtifactPaths
    }
    Update-PressGithubRelease @updateGHRParams
}

#region MetaTasks
Task Press.Build @(
    'Press.Version'
    'Press.CopyModuleFiles'
    'Press.SetModuleVersion'
    'Press.UpdatePublicFunctions'
    'Press.SetReleaseNotes'
)


task Press.Package @(
    'Press.Package.Zip'
    'Press.Package.Nuget'
)
task Press.Test @(
    'Press.Test.Pester'
    'Press.Test.Pester.WindowsPowershell'
)
Task Press.Default @(
    'Press.Build'
    'Press.Test'
)
#endregion MetaTasks

#region Defaults
task Clean      Press.Clean
task Build      Press.Build
Task Test       Press.Test
task Package    Press.Package
task Version    Press.Version
Task .          Press.Default
#endregion Defaults