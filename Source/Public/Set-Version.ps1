<#
.SYNOPSIS
Sets the version on a powershell Module
#>
function Set-Version {
    [CmdletBinding()]
    param (
        #Path to the module manifest to update
        [String]$Path = $PressSetting.OutputModuleManifest,
        #Version to set for the module
        [Version]$Version = $PressSetting.Version,
        #Prerelease tag to add to the module, if any
        [String]$PreRelease = $PressSetting.Prerelease
    )
    #Default is to update version so no propertyname specified
    BuildHelpers\Update-Metadata -Path $Path -PropertyName 'ModuleVersion' -Value $Version

    BuildHelpers\Update-Metadata -Path $Path -PropertyName 'PreRelease' -Value $PreRelease
}