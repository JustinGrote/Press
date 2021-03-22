BeforeAll {
    Import-Module $PSScriptRoot/../Press.psd1 -force
}
Describe 'Get-Version' {
    It 'Runs successfully' {
        $result = Get-PressVersion
        $result.NuGetVersionV2 | Should -not -BeNullOrEmpty
        $result.SemVer | Should -not -BeNullOrEmpty
    }
    It 'Shows Diag Successfully' {
        [String]$debugResult = Get-PressVersion -Debug *>&1
        $debugResult | Should -Match 'Dumping commit graph'
    }
    It 'Fails gracefully if Git is not present' {
        Set-ItResult -Pending
    }
    It 'Fails gracefully if repository is not a git repository' {
        Set-ItResult -Pending
    }

    It 'Fails gracefully if no commits found on the current branch' {
        Set-ItResult -Pending
    }
}