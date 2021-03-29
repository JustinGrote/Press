Import-Module -Name $PSScriptRoot\Source\Press.psd1 -Force
. Press.Tasks

#TODO: Replace this with using the existing task and a settings variable
Task Press.CopyModuleFiles @{
    Inputs  = { Get-ChildItem -File -Recurse "$BuildRoot\Source" }
    Outputs = { 
        $buildItems = Get-ChildItem -File -Recurse "$BuildRoot\BuildOutput\Press"
        if ($buildItems) { $buildItems } else { 'EmptyBuildOutputFolder' } 
    }
    #(Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    Jobs    = {
        Remove-BuildItem "$BuildRoot\BuildOutput\Press"
        $copyResult = Copy-PressModuleFiles -Destination "$BuildRoot\BuildOutput\Press" -PSModuleManifest $PressSetting.BuildEnvironment.PSModuleManifest -Include (Resolve-Path "$buildRoot\Source\GitVersion.default.yml"),(Resolve-Path "$buildRoot\Source\Press.tasks.ps1") @commonParams
        $PressSetting.OutputModuleManifest = $copyResult.OutputModuleManifest
    }
}
