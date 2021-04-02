function Build-ReleaseNotes {
    [CmdletBinding()]
    param(
        #Path to the project folder where the git repository is located
        [Parameter(Mandatory)][String]$Path,
        #Output Path for the Changelog. If not specified it will be output directly as a string
        [String]$Destination,
        #By default, only builds the release notes since the last tag. Specify full to process the full operation.
        [Switch]$Full
    )

    if ($full) { throw [System.NotImplementedException]'TODO' }

    [String]$markdownResult = Get-MessagesSinceLastTag -Path $Path
    | Add-CommitType
    | ConvertTo-ReleaseNotesMarkdown
    
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
        [String]$lastVersionTag = & git tag --list 'v*' --sort="version:refname" --merged | Select-Object -Last 1
        if (-not $lastVersionTag) {
            Write-Verbose 'No version tags (vX.X.X) found in this repository. Starting'
            $lastVersionTag = '--all'
        }
        [String]$lastVersionCommit = & git rev-list --reverse --abbrev-commit $lastVersionTag | Select-Object -First 1
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
        [Parameter(ValueFromPipeline)]$InputObject
    )
    begin {
        Import-Module MarkdownPS -ErrorAction Stop
        $markdown = [Text.StringBuilder]::new()
    }

    end {
        $messageGroups = ($input | Group-Object CommitType)
        foreach ($messageGroupItem in $messageGroups) {
            #Header First
            $markdown.AppendLine("### $($messageGroupItem.Name)") | Out-Null
            $markdown.AppendLine() | Out-Null

            #Then the issue lines
            #TODO: Create links for PRs
            $messageGroupItem.Group.Message.foreach{
                #Multiline List format, removing extra newlines
                [String]$ListBody = ($PSItem -split "`n").where{ $PSItem } -join "  `n    "
                [String]$ChangeItem = '- ' + $ListBody
                $markdown.AppendLine($ChangeItem) | Out-Null
            }
            #Spacer
            $markdown.AppendLine() | Out-Null
        }
        return [String]$markdown
    }
}