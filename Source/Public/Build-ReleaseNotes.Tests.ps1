. '../../Tests/Shared.ps1'

Describe 'Build-ReleaseNotes' {
    BeforeAll {
        #TODO: Move this to testcases
        #Create Simple Mock Project Repository
        $pesterProject = New-Item -ItemType Directory "$TestDrive/$(New-Guid)"
        Push-Location $pesterProject
        & git init -q $pesterProject *>&1 | Out-Null
        & git config user.email 'pester@pester.pester'
        & git config user.name 'Pester'
        & git commit --allow-empty -am 'PesterCommit1' | Out-Null
        [String]$multilineFeature = '✨ New Feature','Line1 of new feature','Line2 of new feature' -join "`n"
        & git commit --allow-empty -am $multilineFeature | Out-Null
            & git commit --allow-empty -am 'PesterCommit3' | Out-Null
            Pop-Location
    }
    It 'Processes New Features' {
        [String]$markdownResult = Build-ReleaseNotes -Path $PesterProject
        $markdownResult | Should -Match '### New Features'
    }
}

Describe 'Add-PullRequestContributorThanks' {
    It 'Adds thanks to PR' {
        $result = & (Get-Module Press) {
            @{
                Author  = 'Pester'
                Committer = 'SomeCommitter'
                Message = '✨ PR Commit (#99)'
            } | Add-PullRequestContributorThanks
        }
        $result.message | Should -Be '✨ PR Commit (#99) - Thanks @Pester!'
    }
    It 'Adds thanks to multiline PR' {
        $result = & (Get-Module Press) {
            @{
                Author    = 'Pester'
                Committer = 'SomeCommitter'
                Message   = 'PR Commit (#99)','Adds some stuff','Removes some stuff' -join "`n"
            } | Add-PullRequestContributorThanks
        }
        $result.message | Should -BeLike 'PR Commit (#99) - Thanks @Pester!*'
    }
    It 'Doesnt add thanks if author and committer are the same' {
        $result = & (Get-Module Press) {
            @{
                Author    = 'Pester'
                Committer = 'Pester'
                Message   = 'PR Commit (#99)'
            } | Add-PullRequestContributorThanks
        }
        $result.message | Should -Be 'PR Commit (#99)'
    }
    It 'Does not add thanks to non-PR' {
        $result = & (Get-Module Press) {
            @{
                Author  = 'Pester'
                Message = 'Non-PR Commit'
            } | Add-PullRequestContributorThanks
        }
        $result.Message | Should -Be 'Non-PR Commit'
    }

    It 'Does not add thanks to PR by Github' {
        $result = & (Get-Module Press) {
            @{
                Author    = 'PesterAuthor'
                Committer = 'noreply'
                Message   = 'PR Commit (#99)'
            } | Add-PullRequestContributorThanks
        }
        $result.message | Should -BeLike 'PR Commit (#99)'
    }
}

Describe 'Add-CommitIdIfNotPullRequest' {
    It 'Adds commit if not PR' {
        $result = & (Get-Module Press) {
            @{
                Message  = 'PR Commit'
                CommitId = 'PesterSHA'
            } | Add-CommitIdIfNotPullRequest
        }
        $result.message | Should -Be 'PR Commit (PesterSHA)'
    }
    It 'Doesnt alter PR commit' {
        $result = & (Get-Module Press) {
            @{
                Message  = 'PR Commit (#99)'
                CommitId = 'PesterSHA'
            } | Add-CommitIdIfNotPullRequest
        }
        $result.message | Should -Be 'PR Commit (#99)'
    }
}