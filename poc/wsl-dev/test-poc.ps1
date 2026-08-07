param(
    [string]$Distribution = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$sourceFixture = Join-Path $root "fixture"
$fixture = Join-Path $env:TEMP "wsl-dev-runtime-$([guid]::NewGuid().ToString('N'))"
$launcher = Join-Path $root "wsl-dev.ps1"

New-Item -ItemType Directory -Force -Path $fixture | Out-Null
Get-ChildItem -LiteralPath $sourceFixture -Force |
    Where-Object Name -ne ".direnv" |
    Copy-Item -Destination $fixture -Recurse -Force

$wslFixture = (& wsl.exe --distribution $Distribution --exec wslpath -a $fixture).Trim()

if ($LASTEXITCODE -ne 0) {
    throw "Could not translate the fixture path."
}

& wsl.exe --distribution $Distribution --cd $wslFixture --exec `
    bash -lc "direnv allow ."
if ($LASTEXITCODE -ne 0) {
    throw "direnv allow failed."
}

& $launcher exec -Distribution $Distribution -ProjectDirectory $fixture `
    bash -c 'test "$POC_DEV_SHELL" = wsl-direnv && test "${PWD#/mnt/}" != "$PWD"'
if ($LASTEXITCODE -ne 0) {
    throw "The project environment check failed."
}

& $launcher exec -Distribution $Distribution -ProjectDirectory $fixture npm test
if ($LASTEXITCODE -ne 0) {
    throw "The npm/uv process-tree test failed."
}

if ($env:PATH -match "/nix/store") {
    throw "The launcher leaked a Nix store path into the Windows PATH."
}

Write-Output "PoC passed: the Windows-hosted project ran entirely in the WSL direnv devShell."
