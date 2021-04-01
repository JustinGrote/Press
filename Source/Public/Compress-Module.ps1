function Compress-Module {
    [CmdletBinding()]
    param(
        #Path to the directory to archive
        [Parameter(Mandatory)]$Path,
        #Output for Zip File Name
        [Parameter(Mandatory)]$Destination
    )

    $CompressArchiveParams = @{
        Path = $Path
        DestinationPath = $Destination
    }

    Compress-Archive @CompressArchiveParams
    Write-Verbose ('Zip File Output:' + $CompressArchiveParams.DestinationPath)
}