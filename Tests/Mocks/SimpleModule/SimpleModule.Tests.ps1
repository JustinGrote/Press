BeforeAll {
    Import-Module $PSScriptRoot/SimpleModule.psd1 -Force
}

Describe 'SimpleModule' {
    It 'SimpleTest' {
        Test-SimpleModule | Should -Be $true
    }
}

AfterAll {
    Remove-Module SimpleModule
}