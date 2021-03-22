#requires -module Press

if ($PSVersionTable.PSVersion -lt '7.0.0') {
    Write-Warning "Press is only supported on Powershell 7 and above. You are currently on unsupported Powershell version: $($PSVersionTable.PSVersion) and while it may still work, there are no guarantees whatsoever. Note that while the build process is only supported on Powershell 7, your BUILT modules can operate on earlier powershell versions if you so choose."
}

$commonParams = @{
    Verbose = ($VerbosePreference -eq 'continue')
}

Task Press.Init {
    $GLOBAL:PressSetting = Get-PressSetting
}

Task Press.Version {
    $SCRIPT:GitVersionInfo = Get-PressVersion @commonParams
}

Task Press.Clean Press.Init,{
    Invoke-PressClean @commonParams
}

Task Press.SetModuleVersion Press.Version,{
    Set-PressVersion -Version $GitVersionInfo.MajorMinorPatch -PreRelease $GitVersionInfo.NuGetPreReleaseTagV2
}

task Press.CopyModuleFiles {
    Copy-PressModuleFiles @commonParams
}

task Press.ExportPublicFunctions {
    Update-PressPublicFunctions @commonParams
}


Task Clean Press.Clean
Task Version Press.Version
Task Build Press.CopyModuleFiles,Press.SetModuleVersion,Press.ExportPublicFunctions

Task . Clean,Version,Build