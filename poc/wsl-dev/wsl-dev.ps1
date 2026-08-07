param(
    [string]$Mode,
    [string]$Distribution = $env:WSL_DEV_DISTRO,
    [string]$ProjectDirectory = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

if ($Mode -notin @("shell", "exec")) {
    throw "Mode must be either shell or exec."
}

if ([string]::IsNullOrWhiteSpace($Distribution)) {
    throw "Specify -Distribution or set WSL_DEV_DISTRO."
}

$projectPath = (Resolve-Path -LiteralPath $ProjectDirectory).Path
$wslProjectPath = (& wsl.exe --distribution $Distribution --exec wslpath -a $projectPath).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslProjectPath)) {
    throw "Could not translate the project path for WSL: $projectPath"
}

if ($Mode -eq "shell") {
    & wsl.exe --distribution $Distribution --cd $wslProjectPath --exec bash -li
    exit $LASTEXITCODE
}

if ($args.Count -eq 0) {
    throw "The exec mode requires a command after the options."
}

& wsl.exe --distribution $Distribution --cd $wslProjectPath --exec `
    bash -lc 'exec direnv exec . "$@"' wsl-dev @args
exit $LASTEXITCODE
