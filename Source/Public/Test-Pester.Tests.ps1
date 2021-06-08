. $(Resolve-Path "$PSScriptRoot/../../Tests/Shared.ps1")

Describe 'Test-Pester' {
    It 'Runs SimpleModule Test' {
        #FIXME: TestDrive doesn't resolve right within the test as a path, probably because of nested Pester
        Set-ItResult -Skipped -Because 'BROKEN: $testdrive does not resolve correctly'
        New-Item -ItemType Directory -Path $testDrive/SMTest -ErrorAction SilentlyContinue
        $testResults = Test-Pester -Quiet -Path (Resolve-Path $Mocks/SimpleModule) -OutputPath $testDrive/SMTest
        $testResults.Result | Should -Be 'Passed'
        $testResults.PSVersion | Should -BeGreaterThan '6.0'
    }

    It 'Runs SimpleModule Test as Job' {
        New-Item -ItemType Directory -Path $testDrive/SMTest -ErrorAction SilentlyContinue
        $testResults = Test-Pester -Quiet -InJob -Path (Resolve-Path $Mocks/SimpleModule) -OutputPath $testDrive/SMTest
        $testResults.Result | Should -Be 'Passed'
        $testResults.PSVersion | Should -BeGreaterThan '6.0'
    }

    It 'Runs SimpleModule Test as Job (PS5.1)' {
        if (-not (Get-Command 'Powershell.exe' -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Test System does not have access to Windows Powershell'
        }
        New-Item -ItemType Directory -Path $testDrive/SM51Test -ErrorAction SilentlyContinue
        $testResults = Test-Pester -Quiet -InJob -UseWindowsPowershell -Path (Resolve-Path $Mocks/SimpleModule) -OutputPath $TestDrive/SM51Test
        $testResults.Result | Should -Be 'Passed'
        $testResults.PSVersion | Should -BeLessThan '6.0'
    }
}