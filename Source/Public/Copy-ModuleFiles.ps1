<#
.SYNOPSIS
This function prepares a powershell module from a source powershell module directory
.DESCRIPTION
This function can also optionally "compile" the module, which is place all relevant powershell code in a single .psm1 file. This improves module load performance.
If you choose to compile, place any script lines you use to dot-source the other files in your .psm1 file into a #region SourceInit region block, and this function will replace it with the "compiled" scriptblock
#>
function Copy-ModuleFiles {
    [CmdletBinding()]
    param (
        #Path to the Powershell Module Manifest representing the file you wish to compile
        [Parameter(Mandatory)]$PSModuleManifest,
        #Path to the build destination. This should be non-existent or deleted by Clean prior
        [Parameter(Mandatory)]$Destination,
        #By Default this command expects a nonexistent destination, specify this to allow for a "Dirty" copy
        [Switch]$Force,
        #By default, the build will consolidate all relevant module files into a single .psm1 file. This enables the module to load faster. Specify this if you want to instead copy the files as-is
        [Switch]$NoCompile,
        #If you chose compile, specify this for the region block in your .psm1 file to replace with the compiled code. If not specified, it will just append to the end of the file. Defaults to 'SourceInit' for #region SourceInit
        [String]$SourceRegionName = 'SourceInit',
        #Files that are considered for inclusion to the 'compiled' module. This by default includes .ps1 files only. Uses Filesystem Filter syntax
        [String[]]$PSFileInclude = '*.ps1',
        #Files that are considered for exclusion to the 'compiled' module. This excludes any files that have two periods before ps1 (e.g. .build.ps1, .tests.ps1). Uses Filesystem Filter syntax
        [String[]]$PSFileExclude = '*.*.ps1',
        #If a prerelease tag exists, the build will touch a prerelease warning file into the root of the module folder. Specify this parameter to disable this behavior.
        [Switch]$NoPreReleaseFile = (-not $PressSetting.PreRelease),
        #Additional files to include in the folder. These will be dropped directly into the resulting module folder. Paths should be relative to the module root.
        [String[]]$Include
    )

    $SourceModuleDir = Split-Path $PSModuleManifest

    #Verify a clean build folder
    try {
        $DestinationDirectory = New-Item -ItemType Directory -Path $Destination -ErrorAction Stop
    } catch [IO.IOException] {
        if ($PSItem.exception.message -match 'already exists\.$') {
            if (-not $Force) {
                throw "Folder $Destination already exists. Make sure that you cleaned your Build Output directory. To override this behavior, specify -Force"
            } else {
                #Downgrade error to warning
                Write-Warning $PSItem
            }
        } else {
            throw $PSItem
        }
    }

    #TODO: Use this one command and sort out the items later
    #$FilesToCopy = Get-ChildItem -Path $PSModuleManifestDirectory -Filter '*.ps*1' -Exclude '*.tests.ps1' -Recurse

    $SourceManifest = Import-PowerShellDataFile -Path $PSModuleManifest

    #TODO: Allow .psm1 to be blank and generate it on-the-fly
    if (-not $SourceManifest.RootModule) { throw "The source manifest at $PSModuleManifest does not have a RootModule specified. This is required to build the module." }
    $SourceRootModulePath = Join-Path $SourceModuleDir $sourceManifest.RootModule
    $SourceRootModule = Get-Content -Raw $SourceRootModulePath

    #Cannot use Copy-Item Directly because the filtering isn't advanced enough (can't exclude)
    $SourceFiles = Get-ChildItem -Path $SourceModuleDir -Include $PSFileInclude -Exclude $PSFileExclude -File -Recurse
    if (-not $NoCompile) {
        #TODO: Apply ordering if important (e.g. classes)

        #Collate the files, pulling out using lines because these have to go first
        [String[]]$UsingLines = @()
        [String]$CombinedSourceFiles = ((Get-Content -Raw $SourceFiles) -split '\r?\n' | Where-Object {
                if ($_ -match '^using .+$') {
                    $UsingLines += $_
                    return $false
                }
                return $true
            }) -join [Environment]::NewLine

        #If a SourceInit region was set, inject the files there, otherwise just append to the end.
        $sourceRegionRegex = "(?s)#region $SourceRegionName.+#endregion $SourceRegionName"
        if ($SourceRootModule -match $sourceRegionRegex) {
            #Need to escape the $ in the replacement string
            $RegexEscapedCombinedSourceFiles = [String]$CombinedSourceFiles.replace('$','$$')
            $SourceRootModule = $SourceRootModule -replace $sourceRegionRegex,$RegexEscapedCombinedSourceFiles
        } else {
            #Just add them to the end of the file
            $SourceRootModule += [Environment]::NewLine + $CombinedSourceFiles
        }

        #Use a stringbuilder to piece the portions of the config back together, with using statements up-front
        [Text.StringBuilder]$OutputRootModule = ''
        if ($UsingLines) {
            $UsingLines.trim() | Sort-Object -Unique | ForEach-Object {
                [void]$OutputRootModule.AppendLine($PSItem)
            }
        }
        [void]$OutputRootModule.AppendLine($SourceRootModule)
        [String]$SourceRootModule = $OutputRootModule

        #Strip non-help-related comments and whitespace
        #[String]$SourceRootModule = Remove-CommentsAndWhiteSpace $SourceRootModule
    } else {
        #TODO: Track all files in the source directory to ensure none get missed on the second step

        try {
            #In order to get relative paths we have to be in the directory we want to be relative to
            Push-Location (Split-Path $PSModuleManifest)

            $SourceFiles | ForEach-Object {
                #Powershell 6+ Preferred way.
                #TODO: Enable when dropping support for building on 5.x
                #$RelativePath = [io.path]::GetRelativePath($SourceModuleDir,$PSItem.fullname)

                #Powershell 3.x compatible "Ugly" Regex method
                #$RelativePath = $PSItem.FullName -replace [Regex]::Escape($SourceModuleDir),''

                $RelativePath = Resolve-Path $PSItem.FullName -Relative

                #Copy-Item doesn't automatically create directory structures when copying files vs. directories
                $DestinationPath = Join-Path $DestinationDirectory $RelativePath
                $DestinationDir = Split-Path $DestinationPath
                if (-not (Test-Path $DestinationDir)) { New-Item -ItemType Directory $DestinationDir > $null }
                $copiedItems = Copy-Item -Path $PSItem -Destination $DestinationPath -PassThru
                #Update file timestamps for Invoke-Build Incremental Build detection
                $copiedItems.foreach{
                    $PSItem.LastWriteTime = [DateTime]::Now
                }
            }
        } catch {
            throw
        } finally {
            #Return after processing relative paths
            Pop-Location
        }
    }

    #Output the (potentially) modified Root Module
    $SourceRootModule | Out-File -FilePath (Join-Path $DestinationDirectory $SourceManifest.RootModule)

    #If there is a "lib" folder, copy that as-is
    if (Test-Path "$SourceModuleDir\lib") {
        Write-Verbose 'lib folder detected, copying entire contents'
        $copiedItems = Copy-Item -Recurse -Force -Path "$SourceModuleDir\lib" -Destination $DestinationDirectory -PassThru
        $copiedItems.foreach{
            $PSItem.LastWriteTime = [DateTime]::Now
        }
    }

    #Copy the Module Manifest
    $OutputModuleManifest = Copy-Item -PassThru -Path $PSModuleManifest -Destination $DestinationDirectory
    $OutputModuleManifest.foreach{
        $PSItem.LastWriteTime = [DateTime]::Now
    }
    $OutputModuleManifest = [String]$OutputModuleManifest

    #Additional files to include
    if ($Include) {
        $copiedItems = $Include | Copy-Item -Destination $DestinationDirectory -PassThru
        $copiedItems.foreach{
            $PSItem.LastWriteTime = [DateTime]::Now
        }
    }

    #Add a prerelease
    if (-not $NoPreReleaseFile) {
        'This is a prerelease build and not meant for deployment!' |
            Out-File -FilePath (Join-Path $DestinationDirectory "PRERELEASE-$($PressSetting.VersionLabel)")
    }

    return [PSCustomObject]@{
        OutputModuleManifest = $OutputModuleManifest
    }
}