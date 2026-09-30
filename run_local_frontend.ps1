[CmdletBinding()]
param(
    [int]$Port = 8000,
    [switch]$SkipInstall,
    [switch]$RunSmokeTests,
    [switch]$NoBrowser,
    [switch]$Reload
)
& "$PSScriptRoot\deploy_locally.ps1" -Port $Port -SkipInstall:$SkipInstall -RunSmokeTests:$RunSmokeTests -NoBrowser:$NoBrowser -Reload:$Reload
exit $LASTEXITCODE
