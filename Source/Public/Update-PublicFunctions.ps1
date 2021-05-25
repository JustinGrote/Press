<#
.SYNOPSIS
This function sets a module manifest for the various function exports that are present in a module such as private/public functions, classes, etc.
#>

function Update-PublicFunctions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        #Path to the module manifest to update
        [Parameter(Mandatory)][String]$Path,
        #Paths to the module public function files
        [String]$PublicFunctionPath,
        #Optionally Specify the list of functions to override auto-detection
        [String[]]$Functions
    )

    if (-not $Functions) {
        $Functions = Get-PublicFunctions $PublicFunctionPath
    }

    if (-not $Functions) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
        return
    }

    $currentFunctions = Get-Metadata -Path $Path -PropertyName FunctionsToExport
    if (Compare-Object $currentFunctions $functions) {
        Write-Verbose "Current Function List in manifest doesn't match. Current: $currentFunctions New: $Functions. Updating."
        #HACK: Don't use Update-ModuleManifest because of https://github.com/PowerShell/PowerShellGetv2/issues/294
        if ($PSCmdlet.ShouldProcess($Path, "Add Functions $($Functions -join ', ')")) {
            BuildHelpers\Update-Metadata -Path $Path -PropertyName FunctionsToExport -Value $Functions
        }
    }
}