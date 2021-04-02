# Press

Press is a rewrite of PowerCD with some modern decisions:
1. PS7+ Only for Building (built modules can still have lower compatability)
1. Drop Azure Pipelines/Appveyor support and go all-in on Github Actions. Local packages.
1. Support a Github development workflow via Github Pull Requests/Features and vscode
1. Embrace devmoji but still support conventional commits
1. Expand to github releases, changelog support, artifacts, etc.


## Press Commandments

Thou shalt:
1. Structure with Public and Private folders to denote exported and non-exported functions
1. Name public functions the same as their .ps1 file name. Note that you can have other "helper" functions in the same file that the public function references, as long as they are not named the same as the .ps1 file
1. Not nest functions within other functions. It makes debugging and pester testing difficult, instead define private functions either in the Private folder, or helper functions in the same file as their associated Public function, with different names than the file.

See the project section for the roadmap

More to follow...