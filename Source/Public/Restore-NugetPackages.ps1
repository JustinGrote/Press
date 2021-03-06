<#
.SYNOPSIS
Retrieves the dotnet dependencies for a powershell module
.NOTES
This process basically builds a C# Powershell Standard Library and identifies the resulting assemblies. There is probably a more lightweight way to do this.
.EXAMPLE
Get-PSModuleNugetDependencies @{'System.Text.Json'='4.6.0'}
#>
function Restore-NugetPackages {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName = 'String')]
    param (
        #A list of nuget packages to include. You can specify a nuget-style version with a / separator e.g. yamldotnet/3.2.*
        [Parameter(ParameterSetName = 'String',Mandatory,Position = 0)][String[]]$PackageName,
        #Which packages and their associated versions to include, in hashtable form. Supports Nuget Versioning: https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards
        [Parameter(ParameterSetName = 'Hashtable',Mandatory,Position = 0)][HashTable]$Packages,
        #Which .NET Framework target to use. Defaults to .NET Standard 2.0 and is what you should use for PS5+ compatible modules
        [String]$Target = 'netstandard2.0',
        #Where to output the resultant assembly files. Default is a new folder 'lib' in the current directory.
        [Parameter(Position = 1)][String]$Destination,
        #Which PS Standard library to use. Defaults to 7.0.0-preview.1.
        [String]$PowershellTarget = '7.0.0-preview.1',
        [String]$BuildPath = (Join-Path ([io.path]::GetTempPath()) "PSModuleDeps-$((New-Guid).Guid)"),
        #Name of the build project. You normally don't need to change this.
        [String]$BuildProjectName = 'PSModuleDeps',
        #Whether to output the resultant copied file paths
        [Switch]$PassThru,
        #Whether to do an online restore check of the dependencies. Disable this to speed up the process at the risk of compatibility.
        [Switch]$NoRestore
    )

    if ($PSCmdlet.ParameterSetName -eq 'String') {
        $Packages = @{}
        $PackageName.Foreach{
            $PackageVersion = $PSItem -split '/'
            if ($PackageVersion.count -eq 2) {
                $Packages[$PackageVersion[0]] = $PackageVersion[1]
            } else {
                $Packages[$PSItem] = '*'
            }
        }
    }

    #Add Powershell Standard Library
    $Packages['PowerShellStandard.Library'] = $PowershellTarget

    if (-not ([version](dotnet --version) -ge 2.2)) { throw 'dotnet 2.2 or later is required. Make sure you have the .net core SDK 2.x+ installed' }

    #Add starter Project for netstandard 2.0
    $BuildProjectFile = Join-Path $BuildPath "$BuildProjectName.csproj"
    New-Item -ItemType Directory $BuildPath -Force > $null
    @"
<Project Sdk="Microsoft.NET.Sdk">

<PropertyGroup>
    <TargetFramework>$Target</TargetFramework>
    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
</PropertyGroup>
<ItemGroup>
<PackageReference Include="PowerShellStandard.Library" Version="$PowerShellTarget">
  <PrivateAssets>All</PrivateAssets>
</PackageReference>
</ItemGroup>

</Project>
"@ | Out-File -FilePath $BuildProjectFile

    foreach ($ModuleItem in $Packages.keys) {

        $dotnetArgs = 'add',$BuildProjectFile,'package',$ModuleItem

        if ($Packages[$ModuleItem] -ne $true) {
            if ($NoRestore) {
                $dotNetArgs += '--no-restore'
            }
            $dotnetArgs += '--version'
            $dotnetArgs += $Packages[$ModuleItem]
        }
        Write-Verbose "Executing: dotnet $dotnetArgs"
        & dotnet $dotnetArgs | Write-Verbose
    }

    & dotnet publish -o $BuildPath $BuildProjectFile | Write-Verbose

    function ConvertFromModuleDeps ($Path) {
        $runtimeDeps = Get-Content -Raw $Path | ConvertFrom-Json
        $depResult = [ordered]@{}
        $TargetFullName = $runtimeDeps.targets[0].psobject.properties.name
        $runtimeDeps.targets.$TargetFullName.psobject.Properties.name |
            Where-Object { $PSItem -notlike "$BuildProjectName*" } |
            Sort-Object |
            ForEach-Object {
                $depInfo = $PSItem -split '/'
                $depResult[$depInfo[0]] = $depInfo[1]
            }
        return $depResult
    }
    #Use return to end script here and don't actually copy the files
    $ModuleDeps = ConvertFromModuleDeps -Path $BuildPath/obj/project.assets.json

    if (-not $Destination) {
        #Output the Module Dependencies and end here
        Remove-Item $BuildPath -Force -Recurse
        return $ModuleDeps
    }

    if ($PSCmdlet.ShouldProcess($Destination,'Copy Resultant DLL Assemblies')) {
        New-Item -ItemType Directory $Destination -Force > $null
        $CopyItemParams = @{
            Path        = "$BuildPath/*.dll"
            Exclude     = "$BuildProjectName.dll"
            Destination = $Destination
            Force       = $true
        }

        if ($PassThru) { $CopyItemParams.PassThru = $true }
        Copy-Item @CopyItemParams
        Remove-Item $BuildPath -Force -Recurse
    }
}