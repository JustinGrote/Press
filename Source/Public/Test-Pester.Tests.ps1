. $(Resolve-Path "$PSScriptRoot/../../Tests/Shared.ps1")

Describe 'Test-Pester' {
    It 'Runs SimpleModule Test' {
        #TestDrive Doesn't work due to nested pester so we set up our own temp folder
        $tempPath = Join-Path ([io.path]::GetTempPath()) (New-Guid)
        New-Item $tempPath -ItemType Directory
        try {
            $testResults = Test-Pester -Quiet -Path (Resolve-Path $Mocks/SimpleModule) -OutputPath $tempPath
            $testResults.Result | Should -Be 'Passed'
            $testResults.PSVersion | Should -BeGreaterThan '6.0'
        } catch {
            $PSItem |
                Format-List |
                Write-Host -Fore Yellow
            throw
        } finally {
            Remove-Item $tempPath -Recurse -Force
        }
    }

    It 'Runs SimpleModule Test as Job' {
        #TestDrive Doesn't work due to nested pester so we set up our own temp folder
        $tempPath = Join-Path ([io.path]::GetTempPath()) (New-Guid)
        New-Item $tempPath -ItemType Directory
        try {
            $testResults = Test-Pester -Quiet -InJob -Path (Resolve-Path $Mocks/SimpleModule) -OutputPath $tempPath
            $testResults.Result | Should -Be 'Passed'
            $testResults.PSVersion | Should -BeGreaterThan '6.0'
        } catch { throw } finally {
            Remove-Item $tempPath -Recurse -Force
        }
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