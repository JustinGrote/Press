. '../../Tests/Shared.ps1'

Describe 'Update-GithubRelease' {
    BeforeAll {
        Write-Verbose 'Loading PowershellForGithub Module'
        $UpdateGithubReleaseCommonParams = @{
            Owner         = 'Pester'
            Repository    = 'Pester'
            Version       = '2.1.5'
            AccessToken   = 'PesterToken'
            Body          = 'PesterBody'
            ArtifactPath  = [String](New-Item -ItemType File -Path TestDrive:/PesterArtifact)
            WarningAction = 'SilentlyContinue'
        }
    }

    It 'Should run <Action> for <MockFile> and remove <RemoveCount> releases' -Tag 'Test' {
        $SCRIPT:MockFileName = $MockFile
        [Int]$SCRIPT:RemoveReleaseInvokeCount = 0
        Mock -ModuleName Press Get-GitHubReleaseAsset
        Mock -ModuleName Press New-GitHubReleaseAsset
        Mock -ModuleName Press Remove-GithubRelease
        Mock -ModuleName Press Get-GithubRelease {
            JsonMock Get-GithubRelease/$MockFileName.json
        }
        Mock -ModuleName Press -CommandName $Action -Verifiable -MockWith {
            $SCRIPT:SetReleaseIdResult = $release
        }

        Update-GithubRelease @UpdateGithubReleaseCommonParams

        if ($Action -eq 'Set-GithubRelease') {
            $SCRIPT:SetReleaseIdResult | Should -Be $SetReleaseId
        }

        Should -InvokeVerifiable
        Should -Invoke 'Remove-GithubRelease' -ModuleName Press -Exactly -Times $RemoveCount

    } -TestCases @(
        @{
            MockFile    = 'Null'
            Action      = 'New-GithubRelease'
            RemoveCount = 0
        }
        @{
            MockFile     = 'ExistingDraft'
            Action       = 'Set-GitHubRelease'
            RemoveCount  = 0
            SetReleaseId = 41097540
        }
        @{
            MockFile     = 'ExistingPublished'
            Action       = 'Set-GitHubRelease'
            RemoveCount  = 0
            SetReleaseId = 51097999
        }
        @{
            MockFile    = 'EarlierMajorVersionDraft'
            Action      = 'New-GitHubRelease'
            RemoveCount = 0
        }
        @{
            MockFile    = 'EarlierMinorVersionDraft'
            Action      = 'New-GitHubRelease'
            RemoveCount = 1
        }
        @{
            MockFile     = 'SameVersionPublishedAndDraft'
            Action       = 'Set-GitHubRelease'
            RemoveCount  = 1
            SetReleaseId = 51097999
        }
        @{
            MockFile     = 'MultiplePastDrafts'
            Action       = 'Set-GitHubRelease'
            RemoveCount  = 3 #Should not remove other major versions
            SetReleaseId = 51097999 #Should select later dated one
        }
    )
}