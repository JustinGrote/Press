#Skip this test if we are in a "nested" Pester Session
Describe 'SimpleModule' {
    BeforeAll {
        Import-Module $PSScriptRoot/SimpleModule.psd1 -Force
    }
    It 'SimpleTest' {
        Test-SimpleModule | Should -Be $true
    }
    AfterAll {
        Remove-Module SimpleModule
    }
}