#requires -module Press

$commonParams = @{
    Verbose = ($VerbosePreference -eq 'continue')
}

Enter-Build {
    #TODO: Make this faster by not relying on PSGetv2
    @('PSDepend').foreach{
        try {
            Write-Verbose "Importing $PSItem"
            Import-Module $PSItem -Global
        } catch [IO.FileNotFoundException] {
            if ($PSItem.FullyQualifiedErrorId -ne 'Modules_ModuleNotFound,Microsoft.PowerShell.Commands.ImportModuleCommand') {
                throw $PSItem
            }
            Write-Verbose "Installing $PSItem"
            Install-Module -Scope CurrentUser -Force PSDepend
        }
    }
    Write-Verbose "Invoking $PSItem"
    $PSDependConfigRoot = Resolve-Path "$PSScriptRoot\.config"
    Invoke-PSDepend -Path $PSDependConfigRoot -Force

    $SCRIPT:PressSetting = Get-PressSetting -ConfigPath $BuildRoot
    New-Item -ItemType Directory -Path $PressSetting.Build.OutDir -Force | Out-Null
}

Task Press.Version @{
    Inputs  = {
        #Calculate a new version on every commit. Ignore for Github Actions due to PRs
        if (-not $ENV:GITHUB_ACTIONS) {
            Join-Path "$BuildRoot\.git\refs\heads\" $PressSetting.BuildEnvironment.BranchName
        }
        #META: Gitversion Config
        #FIXME: This should probably be in settings
        [String]$SCRIPT:GitVersionConfig = ''
        if ($PressSetting.General.ModuleName -eq 'Press') {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.General.SrcRootDir 'GitVersion.default.yml'
        } else {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.General.SrcRootDir 'Gitversion.yml'
        }

        #Gitversion config is optional but we want to detect changes if it exists
        Get-Item $GitVersionConfig -ErrorAction SilentlyContinue
    }
    Outputs = {
        "$($PressSetting.Build.OutDir)\.gitversion"
    }
    Jobs    = {
        $SCRIPT:GitVersionInfo = Get-PressVersion -ProjectPath $buildRoot -GitVersionConfigPath $SCRIPT:GitVersionConfig @commonParams
        $SCRIPT:GitVersionInfo | ConvertTo-Json > $Outputs
    }
}

Task Press.Clean {
    Invoke-PressClean -buildOutputPath $PressSetting.Build.OutDir -buildProjectName $PressSetting.General.ModuleName @commonParams
}

Task Press.Test.Pester @{
    Inputs  = { [String[]](Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir) }
    Outputs = { Join-Path $PressSetting.Build.OutDir 'TEST-Results.xml' }
    Jobs    = {
        $pesterResult = Test-PressPester -Path $PressSetting.General.ProjectRoot -OutputPath $PressSetting.Build.OutDir
        Assert $pesterResult 'No Pester Result produced'
    }
}

#TODO: Inputs/Outputs
Task Press.ReleaseNotes {
    #TODO: Replace OutDir with ReleaseNotes or Changelog Specific PSSetting
    Build-PressReleaseNotes @commonParams -Path $PressSetting.General.ProjectRoot -Destination (Join-Path $PressSetting.Build.OutDir 'RELEASENOTES.MD')
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
    $ReleaseNotesCompare = [text.encoding]::UTF8.GetBytes($ReleaseNotes) | Where-Object { $_ -ne 10 }
    $ReleaseNotesNewCompare = [text.encoding]::UTF8.GetBytes($newReleaseNotes) | Where-Object { $_ -ne 10 }
    if (-not $ReleaseNotes -or (Compare-Object $ReleaseNotesCompare $ReleaseNotesNewCompare)) {
        #BUG: Do not use update-modulemanifest because https://github.com/PowerShell/PowerShellGetv2/issues/294
        BuildHelpers\Update-Metadata -Path $ModuleOutManifest -Property ReleaseNotes -Value $newReleaseNotes.Trim()
    }
}

#FIXME: Implement non-press version
# Task Press.CopyModuleFiles @{
#     Inputs  = Get-ChildItem -File -Recurse "$BuildRoot\Source"
#     Outputs = Get-ChildItem -File -Recurse "$BuildRoot\BuildOutput\Press"
#     #(Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)

#     Jobs    = {
#         $copyResult = Copy-PressModuleFiles -Destination "$BuildRoot\BuildOutput\Press" @commonParams
#         $PressSetting.OutputModuleManifest = $copyResult.OutputModuleManifest
#     }
# }

Task Press.SetModuleVersion {
    $SCRIPT:GitVersionInfo = Get-Content -Raw "$($PressSetting.Build.OutDir)\.gitversion" | ConvertFrom-Json
    Set-PressVersion @commonParams -Version $GitVersionInfo.MajorMinorPatch -PreRelease $GitVersionInfo.NuGetPreReleaseTagV2 -Path (Get-Item "$($PressSetting.Build.ModuleOutDir)\*.psd1")
    if ($ENV:GITHUB_ACTIONS) {
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