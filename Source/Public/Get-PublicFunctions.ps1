<#
.SYNOPSIS
Fetch the names of public functions in the specified folder using AST
.DESCRIPTION
This is a better method than grabbing the names of the .ps1 file and "hoping" they line up.
This also only gets parent functions, child functions need not apply
#>
#TODO: Better Function handling: Require function to be the same name as the file. Accessory private functions are OK.
function Get-PublicFunctions {
    [CmdletBinding()]
    param(
        #The path to the public module directory containing the modules. Defaults to the "Public" folder where the source module manifest resides.
        [Parameter(Mandatory)][String[]]$PublicModulePath
    )

    $publicFunctionFiles = Get-ChildItem $PublicModulePath -Filter '*.ps1'
    | Where-Object Name -NotMatch '\.\w+?\.ps1$' #Exclude Tests.ps1, etc.
    #TODO: Make this a PSSetting

    foreach ($fileItem in $publicFunctionFiles) {
        $scriptContent = Get-Content -Raw $fileItem
        $functionNames = [ScriptBlock]::Create($scriptContent).AST.EndBlock.Statements | Where-Object {
            $PSItem -is [Management.Automation.Language.FunctionDefinitionAst]
        } | ForEach-Object Name
        $functionName = $FileItem.BaseName
        if ($functionName -notin $functionNames) {
            Write-Warning "$fileItem`: There is no function named $functionName in $fileItem, please ensure your public function is named the same as the file. Discovered functions: $functionNames"
            continue
        }
        Write-Verbose "Discovered public function $functionName in $fileItem"
        Write-Output $functionName
    }
}