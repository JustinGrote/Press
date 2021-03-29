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
    New-Item -ItemType Directory -Path $PressSetting.BuildEnvironment.BuildOutput -Force | Out-Null
}

Task Press.Version @{
    Inputs  = {
        #Calculate a new version on every commit. Ignore for Github Actions due to PRs
        if (-not $ENV:GITHUB_ACTIONS) {
            Join-Path "$BuildRoot\.git\refs\heads\" $PressSetting.BuildEnvironment.BranchName
        }
        #META: Gitversion Config
        [String]$SCRIPT:GitVersionConfig = ''
        if ($PressSetting.BuildEnvironment.ProjectName -eq 'Press') {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.BuildEnvironment.ProjectPath 'Source\GitVersion.default.yml'
        } else {
            $SCRIPT:GitVersionConfig = Join-Path $PressSetting.BuildEnvironment.ProjectPath 'Gitversion.yml'
        }

        #Gitversion config is optional but we want to detect changes if it exists
        Get-Item $GitVersionConfig -ErrorAction SilentlyContinue
    }
    Outputs = {
        "$BuildRoot\BuildOutput\.gitversion"
    }
    Jobs    = {
        $SCRIPT:GitVersionInfo = Get-PressVersion -ProjectPath $buildRoot -GitVersionConfigPath $SCRIPT:GitVersionConfig @commonParams
        $SCRIPT:GitVersionInfo | ConvertTo-Json > $Outputs
    }
}

Task Press.Clean {
    Invoke-PressClean -buildOutputPath "$BuildRoot\BuildOutput" -buildProjectName $PressSetting.BuildEnvironment.ProjectName @commonParams
}

Task Press.Test.Pester @{
    Inputs  = (Get-ChildItem -File -Recurse "$BuildRoot\Source")
    Outputs = "$BuildRoot\BuildOutput\TEST-Results.xml"
    Jobs    = {
        $pesterResult = Test-PressPester -Path $PressSetting.BuildEnvironment.ProjectPath -OutputPath $PressSetting.BuildEnvironment.BuildOutput
        Assert $pesterResult 'No Pester Result produced'
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
    $SCRIPT:GitVersionInfo = Get-Content -Raw "$BuildRoot\BuildOutput\.gitversion" | ConvertFrom-Json
    Set-PressVersion @commonParams -Version $GitVersionInfo.MajorMinorPatch -PreRelease $GitVersionInfo.NuGetPreReleaseTagV2 -Path (Get-Item $BuildRoot\BuildOutput\Press\*.psd1)
    if ($ENV:GITHUB_ACTIONS) {
        "::set-output name=nugetVersion::$($SCRIPT:GitVersionInfo.NugetVersionV2)"
        #TODO: Move elsewhere?
        "::set-output name=moduleName::$(Split-Path $PressSetting.BuildEnvironment.ProjectName -Leaf)"
    }
}

Task Press.UpdatePublicFunctions {
    Update-PressPublicFunctions @commonParams -Path (Get-Item $BuildRoot\BuildOutput\Press\*.psd1) -PublicFunctionPath $(Join-Path $PressSetting.BuildEnvironment.ModulePath 'Public')
}

Task Press.Package.Zip @{
    Inputs  = {
        Get-ChildItem -File -Recurse "$BuildRoot\BuildOutput\Press"
        #Get-Item (Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    }
    Outputs = {
        $SCRIPT:GitVersionInfo = Get-Content -Raw "$BuildRoot\BuildOutput\.gitversion" | ConvertFrom-Json
        [String]$ZipFileName = $PressSetting.BuildEnvironment.ProjectName + '.' + $SCRIPT:GitVersionInfo.NugetVersionV2 + '.zip'
        [String](Join-Path $PressSetting.BuildEnvironment.BuildOutput $ZipFileName)
    }
    Jobs    = {
        Remove-Item "$(Split-Path $Outputs)\*.zip"
        Compress-PressModule -Path $Inputs -Destination $Outputs
    }
}

Task Press.Package.Nuget @{
    Inputs  = {
        Get-ChildItem -File -Recurse "$BuildRoot\BuildOutput\Press"
        Get-ChildItem -File -Recurse "$BuildRoot\BuildOutput\.gitversion"
        #Get-Item (Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    }
    Outputs = {
        # [String]$ZipFileName = $PressSetting.BuildEnvironment.ProjectName + '.' + $SCRIPT:GitVersionInfo.NugetVersionV2 + '.zip'
        # [String](Join-Path $PressSetting.BuildEnvironment.BuildOutput $ZipFileName)
        $nugetPackageName = $PressSetting.BuildEnvironment.ProjectName + '.' + (Get-Content -Raw $BuildRoot\BuildOutput\.gitversion | ConvertFrom-Json).NugetVersionV2 + '.nupkg'
        
        "$BuildRoot\BuildOutput\$nugetPackageName"
    }
    Jobs    = {
        Remove-Item "$(Split-Path $Outputs)\*.nupkg"
        New-PressNugetPackage @commonParams -Path "$BuildRoot\BuildOutput\Press" -Destination "$BuildRoot\BuildOutput"
    }
}

#region MetaTasks
Task Press.Build @(
    'Press.Version'
    'Press.CopyModuleFiles'
    'Press.SetModuleVersion'
    'Press.UpdatePublicFunctions'
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