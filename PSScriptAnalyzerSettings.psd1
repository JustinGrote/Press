# PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSUseDeclaredVarsMoreThanAssignments' #Problem with Update-GithubRelease Line 6 and cannot override it with attribute
        'PSAvoidUsingInvokeExpression' #Have a use case in build.ps1 and cannot override it with attribute
    )
}