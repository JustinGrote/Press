Import-Module -Name $PSScriptRoot\Source\Press.psd1 -Force
. Press.Tasks

#TODO: Replace this with using the existing task and a settings variable


Task Press.CopyModuleFiles @{
    Inputs  = { 
        Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir
        $SCRIPT:IncludeFiles = (
            "$($PressSetting.General.SrcRootDir)\GitVersion.default.yml",
            "$($PressSetting.General.SrcRootDir)\Press.tasks.ps1"
            | Resolve-Path
        )
        $IncludeFiles
    }
    Outputs = { 
        $buildItems = Get-ChildItem -File -Recurse $PressSetting.Build.ModuleOutDir
        if ($buildItems) { $buildItems } else { 'EmptyBuildOutputFolder' } 
    }
    Jobs    = {
        Remove-BuildItem $PressSetting.Build.ModuleOutDir

        $copyResult = Copy-PressModuleFiles @commonParams `
            -Destination $PressSetting.Build.ModuleOutDir `
            -PSModuleManifest $PressSetting.BuildEnvironment.PSModuleManifest `
            -Include $SCRIPT:IncludeFiles

        $PressSetting.OutputModuleManifest = $copyResult.OutputModuleManifest
    }
}
