$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "deploy-user.ps1") -Action Verify
if ($LASTEXITCODE -ne 0) {
    throw "The deployed user environment verification failed."
}

Write-Output "Deployment regression passed: config discovery and profile/no-profile launcher exposure are correct."