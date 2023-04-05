#requires -version 7
using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
Bootstraps Invoke-Build and starts it with supplied parameters.
.NOTES
If you already have Invoke-Build installed, just use Invoke-Build instead of this script. This is for CI/CD environments like Appveyor, Jenkins, or Azure DevOps pipelines.
.EXAMPLE
.\build.ps1
Starts Invoke-Build with the default parameters
#>

$ErrorActionPreference = 'Stop'
$moduleFastCommand = try {
    Get-Command Install-ModuleFast -ErrorAction Stop
} catch [CommandNotFoundException] {
    Write-Verbose 'ModuleFast not found, bootstrapping from GitHub...'
    [ScriptBlock]::Create((Invoke-WebRequest bit.ly/modulefast))
}

[string[]]$modulesToInstall = 'InvokeBuild'
$modulesToInstall += 'ModuleFast'

& $moduleFastCommand -NoProfileUpdate -ModulesToInstall $modulesToInstall


#Passthrough Invoke-Build
try {
    Push-Location $PSScriptRoot
    & Invoke-Build @args
} catch {
    throw
} finally {
    Pop-Location
}