#requires -Modules BuildHelpers
#requires -Modules @{ModuleName='Pester';ModuleVersion='5.1.1'}
BeforeAll {
    $SCRIPT:Mocks = Resolve-Path $PSScriptRoot/Mocks
    Write-Verbose 'Loading Module to Test'
    #TODO: Remove Press Hardcoding
    Get-Module Press | Remove-Module -Verbose
    Import-Module $PSScriptRoot/../Source/Press.psm1 -Force 4>$null
    function JsonMock ($Path) {
        Get-Content -Raw (Join-Path $SCRIPT:Mocks $Path) | ConvertFrom-Json
    }
}