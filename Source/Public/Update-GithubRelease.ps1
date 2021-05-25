#requires -version 7
#because it uses System.Management.Automation.SemanticVersion
function Update-GithubRelease {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][String]$Owner,
        [Parameter(Mandatory)][String]$Repository,
        [Parameter(Mandatory)][SemVer]$Version,
        [Parameter(Mandatory)][String]$AccessToken,
        [Parameter(Mandatory)][String]$Body,
        [String[]]$ArtifactPath,
        #Skip cleanup of old drafts within the same major version
        [Switch]$NoCleanup
    )

    $Tag = "v$Version"
    $gitHubParams = @{
        OwnerName      = $Owner
        RepositoryName = $Repository
        AccessToken    = $accessToken
        Verbose        = $Verbose
    }

    #Get all releases of the same major version
    [Collections.ArrayList]$existingReleases = @(
        Get-GitHubRelease @gitHubParams
        | Where-Object {
            #Skip nulls
            if ($null -eq $PSItem) { continue }
            #TODO: Allow custom version prefix
            [Semver]$releaseVersion = $PSItem.tag_name -replace 'v',''
            ($releaseVersion.Major -eq $Version.Major)
        }
    )

    #Cleanup older drafts within the same major release if they exist
    if (-not $NoCleanup) {
        if ($PSCmdlet.ShouldProcess('Existing Github Releases', 'Remove all existing draft releases with same major version')) {
            $removedReleases = $existingReleases
            | Where-Object Draft
            | Where-Object tag_name -NE $Tag
            | ForEach-Object {
                Write-Verbose "Detected Older Draft Release for $($PSItem.tag_name) older minor version than $Version, removing"
                $PSItem | Remove-GitHubRelease @gitHubParams -ErrorAction Stop -Force
                Write-Output $PSItem
            }
        }
    }

    $removedReleases.foreach{
        $existingReleases.Remove($removedReleases)
    }

    [Collections.ArrayList]$taggedRelease = @(
        $existingReleases | Where-Object tag_name -EQ $Tag
    )

    #There should be only one release per tag
    if ($taggedRelease.count -gt 1) {
        Write-Warning "Multiple Releases found for $Tag. Will attempt to arrive at a single candidate release"

        #Attempt to resolve the "best" release and remove the rest
        $removedReleases = $taggedRelease
        | Sort-Object published_at,draft,created_at -Descending
        | Select-Object -Skip 1
        | ForEach-Object {
            Write-Verbose "Detected duplicate Release for $($PSItem.tag_name) with ID $($PSItem.ReleaseID), removing"
            $PSItem | Remove-GitHubRelease @gitHubParams -ErrorAction Stop -Force
            Write-Output $PSItem
        }

        $removedReleases.foreach{
            $taggedRelease.Remove($removedReleases)
        }

        #Should be zero or one at this point
        if ($taggedRelease.count -gt 1) {
            throw "Unable to resolve to a single release for tag $Tag. This is probably a bug. Items: $taggedRelease"
        }
    }

    $ghReleaseParams = $gitHubParams.Clone()
    $ghReleaseParams.Body = $Body
    $ghReleaseParams.Name = "$Repository $Tag"

    #If a release exists, update the existing one, otherwise create a new draft release
    #TODO: Add option to re-create so that the date of the release creation updates
    $releaseResult = if ($taggedRelease -and $taggedRelease.count -eq 1) {
        #Update Release Notes
        $taggedRelease | Set-GitHubRelease @ghReleaseParams -Tag $Tag -PassThru
    } else {
        New-GitHubRelease @ghReleaseParams -Draft -Tag $Tag
    }

    Write-Output $releaseResult

    #Update artifacts if required by pulling the existing artifacts and replacing them
    Write-Verbose "Github Artifacts: $artifactPath"
    if ($artifactPath) {
        Write-Verbose "Uploading Github Artifacts: $artifactPath"
        $releaseResult
        | Get-GitHubReleaseAsset @gitHubParams
        | Remove-GitHubReleaseAsset @gitHubParams -Force

        $artifactPath
        | New-GitHubReleaseAsset @gitHubParams -Release $releaseResult.releaseID
        | Out-Null
    }
}