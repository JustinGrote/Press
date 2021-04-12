<#
.SYNOPSIS
Sets the version on a powershell Module
#>
function Set-Version {
    [CmdletBinding()]
    param (
        #Path to the module manifest to update
        [String][Parameter(Mandatory)]$Path,
        #Version to set for the module
        [Version][Parameter(Mandatory)]$Version,
        #Prerelease tag to add to the module, if any
        [AllowEmptyString()][String]$PreRelease
    )
    #Default is to update version so no propertyname specified
    $Manifest = Import-PowerShellDataFile $Path
    $currentVersion = $Manifest.ModuleVersion
    # $currentVersion = Get-Metadata -Path $Path -PropertyName 'ModuleVersion'
    if ($currentVersion -ne $Version) {
        Write-Verbose "Current Manifest Version $currentVersion doesn't match $Version. Updating..."
        BuildHelpers\Update-Metadata -Path $Path -PropertyName ModuleVersion -Value $Version
    }

    $currentPreRelease = $Manifest.privatedata.psdata.prerelease
    if ($PreRelease) {
        if ($currentPreRelease -ne $PreRelease) {
            Write-Verbose "Current Manifest Prerelease Tag $currentPreRelease doesn't match $PreRelease. Updating..."
            #HACK: Do not use update-modulemanifest because https://github.com/PowerShell/PowerShellGetv2/issues/294
            #TODO: AutoCreate prerelease metadata
            try {
                Update-Metadata -Path $Path -PropertyName PreRelease -Value $PreRelease
            } catch {
                if ($PSItem -like "Can't find*") {
                    throw 'Could not find the Prerelease field in your source manifest file. You must add this under PrivateData/PSData first'
                }
            }
            
        }
    } elseif ($CurrentPreRelease -ne '') {
        Update-Metadata -Path $Path -PropertyName PreRelease -Value ''
    }
}