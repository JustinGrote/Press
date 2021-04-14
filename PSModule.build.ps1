Import-Module -Name $PSScriptRoot\Source\Press.psd1 -Force
. Press.Tasks

#TODO: Replace this with using the existing task and a settings variable

Task CopyGitVersionAndTasks -After Press.CopyModuleFiles {
    $IncludeFiles = @(
        "$($PressSetting.General.SrcRootDir)\GitVersion.default.yml"
        "$($PressSetting.General.SrcRootDir)\Press.tasks.ps1"
    ) | Resolve-Path

    Copy-Item $includeFiles -Destination $($PressSetting.Build.ModuleOutDir)
}

Task CopyRequiredModules -After Press.CopyModuleFiles {
    $PressConfigDir = New-Item -ItemType Directory "$($PressSetting.Build.ModuleOutDir)/Config" -Force
    Copy-Item "$($PressSetting.General.SrcRootDir)/Config/RequiredModules.psd1" $PressConfigDir
}