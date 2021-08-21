using namespace Microsoft.PowerShell.Commands
function New-NugetPackage {
    <#
.SYNOPSIS
Creates a Nuget Package from a Powershell Module
.OUTPUTS
System.String. The path to the generated nuget package file
#>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        #Path to the module manifest to build
        [Parameter(Mandatory)][String]$Path,
        #Where to output the new module package. Specify a folder
        [Parameter(Mandatory)][String]$Destination,
        #Whether the license must be accepted to use this package
        [Switch]$RequireLicenseAcceptance
    )
    $ErrorActionPreference = 'Stop'

    $ModuleName = (Get-Item $Path).basename
    $ModuleMetaData = Import-PowerShellDataFile $Path
    $ModuleDir = Split-Path $Path

    #Fast Method but skips some metadata. Doesn't matter for non-powershell gallery publishes
    #Call private method in PSGetv2
    #Also replicates and simplifies some logic from https://github1s.com/PowerShell/PowerShellGetv2/src/PowerShellGet/private/functions/Publish-PSArtifactUtility.ps1
    if ($PSCmdlet.ShouldProcess($Destination, "Build Nuget Package for $ModuleName")) {
        $psGetv2 = Import-Module PowershellGet -PassThru -MaximumVersion 2.99.99 -MinimumVersion 2.2.5
        $version = @($ModuleMetaData.ModuleVersion, $ModuleMetaData.PrivateData.PSData.Prerelease) | Where-Object { $_ } | Join-String -Separator '-'
        $newNuSpecFileParams = @{
            OutputPath  = $ModuleDir
            Id          = $ModuleName
            Version     = $version
            Description = $ModuleMetaData.Description
            Authors     = $ModuleMetaData.Author
        }

        $PSData = $ModuleMetaData.PrivateData.PSData
        $metadata = @{
            Owners                   = $PSData.CompanyName
            Files                    = $ModuleMetaData.FileList
            LicenseUrl               = $PSData.LicenseUrl
            ProjectUrl               = $PSData.ProjectUrl
            IconUrl                  = $PSData.IconUrl
            ReleaseNotes             = $PSData.ReleaseNotes
            Tags                     = $PSData.Tags
            RequireLicenseAcceptance = $PSData.RequireLicenseAcceptance
        }

        $metadata.Tags += $ModuleMetaData.FunctionsToExport.foreach{
            if ($_ -ne '*') { "PSCommand_$PSItem" }
        }
        $metadata.Tags += $ModuleMetaData.CmdletsToExport.foreach{
            if ($_ -ne '*') { "PSCmdlet_$PSItem" }
        }
        $metadata.Tags += $ModuleMetaData.DscResourcesToExport.foreach{
            if ($_ -ne '*') { "DscResource_$PSItem" }
        }

        $metadata.Dependencies = $ModuleMetaData.RequiredModules.foreach{
            $spec = [ModuleSpecification]::new($PSItem)
            [PSCustomObject]@{
                id      = $spec.Name
                version = ConvertTo-NugetVersion $Spec
            }
        }

        $metadata.
        GetEnumerator().
        where{
            $null -ne $PSItem.Value
        }.
        foreach{
            $newNuSpecFileParams[$PSItem.Name] = $PSItem.Value
        }

        $NuSpecPath = & ($psGetv2) New-NuSpecFile @newNuSpecFileParams

        $newNugetPackageParams = @{
            UseDotnetCli     = $true
            NuSpecPath       = $NuSpecPath
            NuGetPackageRoot = Split-Path $Path
            OutputPath       = $Destination
        }
        try {
            $nuGetPackagePath = & ($PSGetv2) New-NugetPackage @newNugetPackageParams
            Write-Verbose "Created NuGet Package at $nuGetPackagePath"
            return $nuGetPackagePath
        } catch { throw } finally {
            Remove-Item $NuSpecPath
        }
    }
}

#Adapted from Publish-PSArtifactUtility
function ConvertTo-NugetVersion {

    param(
        [ModuleSpecification]$spec
    )

    switch ($true) {
        $spec.RequiredVersion {
            '[{0}]' -f $spec.RequiredVersion
            break
        }
        ($spec.MinimumVersion -and $spec.MaximumVersion) {
            '[{0},{1}]' -f $spec.RequiredVersion, $spec.MaximumVersion
            break
        }
        $spec.MaximumVersion {
            '(,{0}]' -f $spec.MaximumVersion
            break
        }
        $spec.MinimumVersion {
            $spec.MinimumVersion
        }
    }
}
