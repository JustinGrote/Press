. $(Resolve-Path "$PSScriptRoot/../../Tests/Shared.ps1")

Describe 'Set-ReleaseNotes' {
    BeforeEach {
        $testPath = "TestDrive:/$(New-Guid).psd1"
        $content = 'PesterTest'
    }
    It 'Sets ReleaseNotes' {
        New-ModuleManifest -Path $testPath -ReleaseNotes $content
        Set-ReleaseNotes -Path $testPath -Content $content
        $setResult = (Import-PowerShellDataFile $testPath).PrivateData.PSData.ReleaseNotes
        $setResult | Should -Be $content
    }
    It 'Sets Multi-Line ReleaseNotes With Unicode Characters' {
        $content = Get-Content -Raw $Mocks/ReleaseNotes.txt
        New-ModuleManifest -Path $testPath -ReleaseNotes 'Pester'
        Set-ReleaseNotes -Path $testPath -Content $content
        $setResult = (Import-PowerShellDataFile $testPath).PrivateData.PSData.ReleaseNotes
        $setResult | Should -Be $content
    }
    It 'Errors if ReleaseNotes Node is Missing in Manifest' {
        New-ModuleManifest -Path $testPath
        { Set-ReleaseNotes -Path $testPath -Content $content } |
            Should -Throw 'Your module .psd1 template must have a PrivateData*'
    }

    It 'Does not update the file if the content already exists' {
        New-ModuleManifest -Path $testPath -ReleaseNotes $content
        $lastWrite = (Get-Item $testPath).LastWriteTime
        Set-ReleaseNotes -Path $testPath -Content $content
        $lastWrite | Should -Be (Get-Item $testPath).LastWriteTime -Because 'the File LastWriteTime should not change'
    }
}