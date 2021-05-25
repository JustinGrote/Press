#region SourceInit
$publicFunctions = @()
foreach ($ScriptPathItem in 'Private','Public') {
    $ScriptSearchFilter = [io.path]::Combine($PSScriptRoot, $ScriptPathItem, '*.ps1')
    $ScriptExcludeFilter = {$PSItem -notlike '*.tests.ps1' -and $PSItem -notlike '*.build.ps1'}
    Get-ChildItem $ScriptSearchFilter |
        Where-Object -FilterScript $ScriptExcludeFilter |
        Foreach-Object {
            if ($ScriptPathItem -eq 'Public') {$PublicFunctions += $PSItem.BaseName}
            . $PSItem
        }
}
Export-ModuleMember -Function $publicFunctions
#endregion SourceInit

$taskAliasName = '.Tasks'
Set-Alias -Name $taskAliasName -Value (Join-Path $PSScriptRoot 'Press.tasks.ps1')
Export-ModuleMember -Alias $taskAliasName