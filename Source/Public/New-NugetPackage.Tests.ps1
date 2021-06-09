. $(Resolve-Path "$PSScriptRoot/../../Tests/Shared.ps1")

Describe 'New-NugetPackage' {
    BeforeEach {
        $target = New-Item -ItemType Directory ('TestDrive:' + (New-Guid))
        $moduleName = 'PesterTestModule'
        $moduleDir = New-Item -ItemType Directory "$target/$moduleName"
        'function PesterTest {$true}' > "$moduleDir/$moduleName.psm1"
        $moduleManifestPath = "$moduleDir/$moduleName.psd1"
        $newModuleManifestParams = @{
            Path          = $moduleManifestPath
            Author        = 'PesterAuthor'
            Description   = 'PesterDescription'
            ModuleVersion = '0.0.1'
        }

    }
    It 'Creates a Nuget Package from a simple module' {
        New-ModuleManifest @newModuleManifestParams
        $package = New-NugetPackage -Path $moduleManifestPath -Destination $target
        $packageFile = Get-Item $package
        $packageFile | Should -BeLike '*.nupkg'
    }
    It 'Creates a Nuget Package from a module with simple dependency' {
        $newModuleManifestParams = @{
            Path            = $moduleManifestPath
            Author          = 'PesterAuthor'
            Description     = 'PesterDescription'
            ModuleVersion   = '0.0.1'
            RequiredModules = @('PowerConfig')
        }
        New-ModuleManifest @newModuleManifestParams
        $package = New-NugetPackage -Path $moduleManifestPath -Destination $target
        $packageFile = Get-Item $package
        $packageFile | Should -BeLike '*.nupkg'
    }
    It 'Creates a Nuget Package from a module with multiple complex dependencies' {
        $newModuleManifestParams = @{
            Path            = $moduleManifestPath
            Author          = 'PesterAuthor'
            Description     = 'PesterDescription'
            ModuleVersion   = '0.0.1'
            RequiredModules = @(
                'PowerConfig'
                @{
                    ModuleName    = 'PowerShellGet'
                    ModuleVersion = '2.2.4'
                }
            )
        }
        New-ModuleManifest @newModuleManifestParams
        $package = New-NugetPackage -Path $moduleManifestPath -Destination $target
        $packageFile = Get-Item $package
        $packageFile | Should -BeLike '*.nupkg'
    }
}