[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("shell", "exec")]
    [string]$Mode,
    [string]$Distribution = $env:WSL_DEV_DISTRO,
    [string]$ProjectDirectory = (Get-Location).Path,
    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"

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

if ($Arguments.Count -eq 0) {
    throw "The exec mode requires a command after the options."
}

& wsl.exe --distribution $Distribution --cd $wslProjectPath --exec `
    bash -lc 'exec direnv exec . "$@"' wsl-dev @Arguments
exit $LASTEXITCODE
