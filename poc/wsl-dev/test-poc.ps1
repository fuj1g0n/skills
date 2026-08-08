param(
    [string]$Distribution = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$sourceFixture = Join-Path $root "fixture"
$fixture = Join-Path $env:TEMP "wsl dev runtime $([guid]::NewGuid().ToString('N'))"
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

& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    bash -c 'test "$POC_DEV_SHELL" = wsl-direnv && test "${PWD#/mnt/}" != "$PWD"'
if ($LASTEXITCODE -ne 0) {
    throw "The project environment check failed."
}

$nixVersion = & $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    nix --version
if ($LASTEXITCODE -ne 0 -or $nixVersion -notmatch '^nix .* 2\.') {
    throw "The direct exec syntax did not resolve Nix in the WSL devShell."
}

$nixPath = & $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    bash -lc 'command -v nix'
if ($LASTEXITCODE -ne 0 -or $nixPath -notmatch '^/nix/') {
    throw "Bash did not resolve Nix from the WSL installation."
}

& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec npm test
if ($LASTEXITCODE -ne 0) {
    throw "The npm/uv process-tree test failed."
}

& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    bash -lc 'exit 23'
if ($LASTEXITCODE -ne 23) {
    throw "The launcher did not propagate exit code 23."
}
$global:LASTEXITCODE = 0

$shellStart = [Diagnostics.ProcessStartInfo]::new()
$shellStart.FileName = (Get-Process -Id $PID).Path
$shellStart.UseShellExecute = $false
$shellStart.RedirectStandardInput = $true
$shellStart.RedirectStandardOutput = $true
$shellStart.RedirectStandardError = $true
foreach ($argument in @(
    "-NoProfile", "-File", $launcher, "-Distribution", $Distribution,
    "-ProjectDirectory", $fixture, "shell"
)) {
    $shellStart.ArgumentList.Add($argument)
}
$shell = [Diagnostics.Process]::Start($shellStart)
$shell.StandardInput.WriteLine("exit")
$shell.StandardInput.Close()
$shellOutput = $shell.StandardOutput.ReadToEnd()
$shellError = $shell.StandardError.ReadToEnd()
$shell.WaitForExit()
if ($shell.ExitCode -ne 0) {
    throw "The interactive shell did not start and exit cleanly: $shellError$shellOutput"
}

if ($env:PATH -match "/nix/store") {
    throw "The launcher leaked a Nix store path into the Windows PATH."
}

Write-Output "PoC passed: Nix, the descendant fixture, and a shell ran in WSL from a spaced Windows path."
