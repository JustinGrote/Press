function Set-ReleaseNotes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        #Path to the module manifest
        [Parameter(Mandatory, Position = 0)][String]$Path,
        #Content to replace the release notes with
        [Parameter(Mandatory, ValueFromPipeline)][String]$Content
    )
    process {
        $ErrorActionPreference = 'Stop'
        [string]$ReleaseNotes = (Import-PowerShellDataFile $Path).PrivateData.PSData.ReleaseNotes

        $ReleaseNotesCompare = [text.encoding]::UTF8.GetBytes($ReleaseNotes) | Where-Object { $_ -notin 10, 13 }
        $ReleaseNotesNewCompare = [text.encoding]::UTF8.GetBytes($Content) | Where-Object { $_ -notin 10, 13 }

        if (-not $ReleaseNotes -or (Compare-Object $ReleaseNotesCompare $ReleaseNotesNewCompare)) {
            #BUG: Do not use update-modulemanifest
            #Reference: https://github.com/PowerShell/PowerShellGetv2/issues/294
            Write-Verbose "Detected Release Notes update, updating ReleaseNotes property of $Path"
            try {
                Update-Metadata -Path $Path -Property ReleaseNotes -Value $Content.Trim()
            } catch [ItemNotFoundException] {
                if ($PSItem -notmatch "Can't find") { throw }
                #TODO: Automatically add it if not present
                'Your module .psd1 template must have a PrivateData.PSData.ReleaseNotes property ' +
                'uncommented for Set-ReleaseNotes to work' | Write-Error
                return
            }
        } else {
            Write-Verbose "Release Notes in $Path do not require updating"
        }
    }
}