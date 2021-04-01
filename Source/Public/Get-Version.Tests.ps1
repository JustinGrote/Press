. '../../Tests/Shared.ps1'
Describe 'Get-Version' {
    BeforeAll {
        #TODO: Move this to testcases
        #Create Simple Mock Project Repository
        $pesterProject = New-Item -ItemType Directory "$TestDrive/$(New-Guid)"
        Push-Location $pesterProject
        & git init -q $pesterProject *>&1 | Out-Null
        & git config user.email 'pester@pester.pester'
        & git config user.name 'Pester'
        & git commit --allow-empty -am 'PesterCommit1' | Out-Null
        & git commit --allow-empty -am 'PesterCommit2' | Out-Null
        & git commit --allow-empty -am 'PesterCommit3' | Out-Null
        Pop-Location
    }

    It 'Fails gracefully if Git is not present' {
        InModuleScope Press {
            Mock Get-Command -ParameterFilter { $Name -eq 'git' } { $null }
        }
        { Get-Version -ProjectPath $TestDrive } | Should -Throw 'git was not found*'
    }

    It 'Fails gracefully if repository is not a git repository' {
        $pesterFakeProject = New-Item -ItemType Directory $TestDrive/PesterNotAProject
        { Get-Version -ProjectPath $pesterFakeProject } | Should -Throw 'No Git repository*'
    }

    It 'Fails gracefully if no commits found on the current branch' {
        if ($ENV:GITHUB_ACTIONS) {
            Set-ItResult -Inconclusive -Because 'FIXME: Doesnt work in github actions due to actions detection'
            return
        }
        $pesterEmptyProject = New-Item -ItemType Directory $TestDrive/PesterEmptyProject
        git init -q $pesterEmptyProject
        { Get-Version -ProjectPath $pesterEmptyProject } | Should -Throw '*GitVersion.GitVersionException: No commits found on the current branch*'
    }

    It 'Runs successfully' {
        if ($ENV:GITHUB_ACTIONS) {
            Set-ItResult -Inconclusive -Because 'FIXME: Doesnt work in github actions due to actions detection'
            return
        }
        $result = Get-Version -ProjectPath $pesterProject
        $result.NuGetVersionV2 | Should -Be '0.1.0-beta0002'
        $result.NuGetPreReleaseTagV2 | Should -Be 'beta0002'
        $result.SemVer | Should -Be '0.1.0-beta.2'
    }
    
    It 'Shows Diag Successfully' {
        if ($ENV:GITHUB_ACTIONS) {
            Set-ItResult -Inconclusive -Because 'FIXME: Doesnt work in github actions due to actions detection'
            return
        }
        [String]$debugResult = Get-Version -ProjectPath $pesterProject -Debug *>&1
        $debugResult | Should -Match 'Dumping commit graph'
    }
}