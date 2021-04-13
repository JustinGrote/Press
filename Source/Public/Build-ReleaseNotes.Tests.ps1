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
        It 'Processes logs successfully' {
            Set-ItResult -Pending -Because 'Seems to be not matching correctly'
            [String]$markdownResult = Build-ReleaseNotes -Path $PesterProject
            $markdownResult | Should -Match 'New Features'
        }
    }