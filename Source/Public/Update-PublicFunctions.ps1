<#
.SYNOPSIS
This function sets a module manifest for the various function exports that are present in a module such as private/public functions, classes, etc.
#>

function Update-PublicFunctions {
    param(
        #Path to the module manifest to update
        [String]$Path = $PressSetting.OutputModuleManifest,
        #Specify to override the auto-detected function list
        [String[]]$Functions = $PressSetting.Functions,
        #Paths to the module public function files
        [String]$PublicFunctionPath = (Join-Path $PressSetting.BuildEnvironment.ModulePath 'Public')
    )

    if (-not $Functions) {
        write-verbose "Autodetecting Public Functions in $Path"
        $Functions = Get-PublicFunctions $PublicFunctionPath
    }

    if (-not $Functions) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
        return
    }

    BuildHelpers\Update-Metadata -Path $Path -PropertyName FunctionsToExport -Value $Functions
}