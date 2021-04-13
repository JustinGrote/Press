function Build-ReleaseNotes {
    <#
    .SYNOPSIS
    Build release notes from commit logs using Keep a Changelog format
    #>
    [CmdletBinding()]
    param(
        #Path to the project folder where the git repository is located
        [Parameter(Mandatory)][String]$Path,
        #Version for the release notes. If not specified will be unreleased
        [String]$Version,
        #Output Path for the Changelog. If not specified it will be output directly as a string
        [String]$Destination,
        #By default, only builds the release notes since the last tag. Specify full to process the full operation.
        [Switch]$Full
    )

    if ($full) { throw [NotImplementedException]'#TODO: Full Release Notes Generation' }

    [String]$markdownResult = Get-MessagesSinceLastTag -Path $Path
    | Add-CommitType
    | ConvertTo-ReleaseNotesMarkdown -Version $Version
    
    if ($Destination) {
        Write-Verbose "Release Notes saved to $Destination"
        Out-File -FilePath $Destination -InputObject $markdownResult
    } else {
        return $markdownResult
    }
}

function Get-MessagesSinceLastTag ([String]$Path) {
    try {
        Push-Location -StackName GetMessagesSinceLastTag -Path $Path
        #If this is a release tag, the release notes should be everything since the last release tag
        [String]$currentCommitTag = try {
            & git describe --exact-match --tags 2>$null
        } catch {}
        [String]$lastVersionTag = & git tag --list 'v*' --sort="version:refname" --merged
        | Where-Object { $PSItem -ne $currentCommitTag }
        | Select-Object -Last 1
        if (-not $lastVersionTag) {
            Write-Verbose 'No version tags (vX.X.X) found in this repository, using all commits to generate release notes'
            $lastVersionTag = '--all'
        }
        [String]$lastVersionCommit = & git rev-list -n 1 $lastVersionTag
        #The surrounding spaces are to preserve indentation in Markdown
        #TOOD: Better Parsing of this
        [String]$gitLogResult = (& git log --pretty=format:"|||%h||%B" "$lastVersionCommit..") -join "`n"
    } catch {
        throw
    } finally {
        Pop-Location -StackName GetMessagesSinceLastTag
    }

    $gitLogResult.Split('|||').where{ $PSItem }.foreach{
        $logItem = $PSItem.Split('||')
        [PSCustomObject]@{
            CommitId   = $logItem[0]
            Message    = $logItem[1].trim()
            CommitType = $null
        }
    }
}

function Add-CommitType {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$logMessage
    )

    begin {
        #TODO: Move this to PSSettings
        $commitTypes = @(
            @{
                Name  = 'Breaking Changes'
                Regex = '💥|:boom:|BREAKING CHANGE:|\+semver:\s?(breaking|major)'
            }
            @{
                Name  = 'New Features'
                Regex = '✨|:(feat|tada):|^feat:|\+semver:\s?(feature|minor)'
            }
            @{
                Name  = 'Minor Updates and Bug Fixes'
                Regex = '[📌🐛🩹🚑♻️🗑️🔥⚡🔒➕➖🔗⚙️]|:(bug|refactor|perf|security|add|remove|deps|config):|^(fix|refactor|perf|security|style|deps):|\+semver:\s?(fix|patch)'
            }
            @{
                Name  = 'Documentation Updates'
                Regex = '📝'
            }
        )
    }

    process {
        foreach ($logItem in $logMessage) {
            foreach ($commitTypeItem in $commitTypes) {
                if ($LogItem -match $commitTypeItem.Regex) {
                    $LogItem.CommitType = $commitTypeItem.Name
                    break
                }
                #Last Resort
                $LogItem.CommitType = 'Other'
            }
            Write-Output $logItem
        }
    }
}

function ConvertTo-ReleaseNotesMarkdown {
    [CmdletBinding()]
    param (
        #Log Item with commit Type
        [Parameter(ValueFromPipeline)]$InputObject,
        #Version to use
        [String]$Version
    )
    begin {
        $markdown = [Text.StringBuilder]::new()
        
        #Top header
        $baseHeader = if ($Version) {
            $currentDate = Get-Date -Format 'yyyy-MM-dd'
            "## [$Version] - $currentDate"
        } else {
            '## [Unreleased]'
        }

        [void]$markdown.AppendLine($baseHeader)
    }

    end {
        $sortOrder = 'Breaking Changes','New Features','Minor Updates and Bug Fixes','Documentation Updates'
        $messageGroups = $input 
        | Group-Object CommitType
        | Sort-Object {
            #Sort by our custom sort order. Anything that doesn't match moves to the end
            $index = $sortOrder.IndexOf($PSItem.Name)
            if ($index -eq -1) { $index = [int]::MaxValue }
            $index
        }

        foreach ($messageGroupItem in $messageGroups) {
            #Header First
            [void]$markdown.AppendLine("### $($messageGroupItem.Name)")

            #Then the issue lines
            #TODO: Create links for PRs
            $messageGroupItem.Group.Message.foreach{
                #Multiline List format, removing extra newlines
                [String]$ListBody = ($PSItem -split "`n").where{ $PSItem } -join "  `n    "
                [String]$ChangeItem = '- ' + $ListBody
                [void]$markdown.AppendLine($ChangeItem)
            }
            #Spacer
            [Void]$markdown.AppendLine()
        }
        return ([String]$markdown).trim()
    }
}