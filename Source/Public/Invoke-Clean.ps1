function Invoke-Clean {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]$BuildOutputPath,
        [Parameter(Mandatory)]$buildProjectName,
        [Switch]$Prerequisites
    )

    #Taken from Invoke-Build because it does not preserve the command in the scope this function normally runs
    #Copyright (c) Roman
    function Remove-BuildItem() {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', Scope = 'Function', Target = '*')]
        param(
            [Parameter(Mandatory)][string[]]$Path
        )
        if ($Path -match '^[.*/\\]*$') { *Die 'Not allowed paths.' 5 }
        $v = $PSBoundParameters['Verbose']
        try {
            foreach ($_ in $Path) {
                if (Get-Item $_ -Force -ErrorAction 0) {
                    if ($v) { Write-Verbose "remove: removing $_" -Verbose }
                    Remove-Item $_ -Force -Recurse -ErrorAction stop
                } elseif ($v) { Write-Verbose "remove: skipping $_" -Verbose }
            }
        } catch {
            throw $_
        }
    }

    #Reset the BuildOutput Directory
    if (Test-Path $buildOutputPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildOutputPath"
        Remove-BuildItem $buildOutputPath -Verbose:$false
    }

    if ($Prerequisites) {
        $PrerequisitePath = (Join-Path ([Environment]::GetFolderpath('LocalApplicationData')) 'Press')
        Write-Verbose "Removing and resetting Press Prerequisites: $PrerequisitePath"
        Remove-BuildItem $PrerequisitePath -Verbose:$false
    }

    New-Item -Type Directory $BuildOutputPath > $null

    #META: Force reload Press if building press
    if ($buildProjectName -eq 'Press') {
        Write-Verbose 'Detected Press Meta-Build'
        Import-Module -Force -Global -Verbose -Name (Join-Path $MyInvocation.MyCommand.Module.ModuleBase 'Press.psd1')
    } else {
        #Unmount any modules named the same as our module
        Remove-Module $buildProjectName -Verbose:$false -ErrorAction SilentlyContinue
    }
}