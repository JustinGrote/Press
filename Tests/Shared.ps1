#requires -Modules BuildHelpers
#requires -Modules @{ModuleName='Pester';ModuleVersion='5.1.1'}
BeforeAll {
    $SCRIPT:Mocks = Resolve-Path $PSScriptRoot/Mocks
    Import-Module $PSScriptRoot/../Source/Press.psm1 -Force -Global
}
AfterAll {
    Import-Module $PSScriptRoot/../Source/Press.psd1 -Force -Global
}