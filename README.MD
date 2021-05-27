![Press Logo](./Images/Press.png)

Press is a continuous integration build system for [PowerShell modules](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules). It enables you to build, test, and deploy high quality modules using a highly configurable build engine that works out of the box but is completely customizable to your needs.

## Configuring Press
Press using the [PowerConfig configuration engine](https://github.com/justingrote/PowerConfig) to manage settings.

`Get-PressSetting` will show you the default configuration values of the project. You can override these settings currently in two ways:

1. Define an environment variable prefixed by `PRESS_`. For nested settings, separate each level with : or __ (as supported by your OS)
<br />Example: `$ENV:PRESS_General__ModuleVersion = '3.2.1'`
<br />Example: `$ENV:PRESS_General__ModuleVersion = '3.2.1'`
1. Define a `.config/Press.yml` in your repository and override settings there.
<br />Example:
    ```yaml
    General:
        ModuleVersion: 3.2.1
    ```
1. [Advanced] Override the Get-PressSetting task with your custom PowerConfig


## Press Commandments

Thou shalt:
1. Structure with Public and Private folders to denote exported and non-exported functions
1. Name public functions the same as their .ps1 file name. Note that you can have other "helper" functions in the same file that the public function references, as long as they are not named the same as the .ps1 file
1. Not nest functions within other functions. It makes debugging and pester testing difficult, instead define private functions either in the Private folder, or helper functions in the same file as their associated Public function, with different names than the file.

See the project section for the roadmap

More to follow...

# Workflows
Press supports the following workflows:

## Local Git Development
You can use Press to automate the build, test and deploy settings for any Powershell module in a git repository. Press will
use your commit messages to generate release notes, build zip and nupkg versions of your module. To publish a release,
tag a commit with the version you want to release e.g. v2.0.3 and run the Deploy task.

## GitHub Integrated
Press has tight integration with Github, including Github Actions, Releases, and Environments.

Here is what a typical workflow would look like:
1. Start a new repository and enable Press. Your environment is now automatically at v0.0.1
2. Create a feature branch 'myfeature' and add a commit. This commit is now at v0.0.2-myfeature0001
3. Create a pull request to your main branch of your feature, it will automatically be checked and tested.
4. Merge the feature request to your main branch and ensure the PR message has the feature emoji ✨ or feat:. Your main branch is now automatically at v0.0.2-beta0001 and a release has automatically been drafted for you in GitHub, and if enabled, will be made available on the Powershell Gallery
5. Follow steps 2-4 again. Your main branch is now automatically at v0.0.2-beta0002 and the draft release has been updated with the latest release notes. If enabled, your beta version will automatically be made available on the Powershell Gallery
6. Go the the release draft and click "Publish". Your project is now at v0.0.2 and your latest commit will be tagged as such, and a production version matching your release will be made available on the Powershell Gallery.

## Origin
Press is a rewrite of PowerCD with some modern decisions:
1. PS7+ Only for Building (built modules can still have lower compatability)
1. Drop Azure Pipelines/Appveyor support and go all-in on Github Actions. Local packages.
1. Support a Github development workflow via Github Pull Requests/Features and vscode
1. Embrace devmoji but still support conventional commits
1. Expand to github releases, changelog support, artifacts, etc.