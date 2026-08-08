# Runs a POSIX sh command line inside the project's wslc devShell
# container, from the repository root on Windows. See SKILL.md.
#
# Usage: pwsh devshell-exec.ps1 <posix command...>
# Env overrides: DEVSHELL_CONTAINER, DEVSHELL_MOUNT, DEVSHELL_USER
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$CommandParts
)
$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$repoRoot = $repoRoot.Replace('/', '\')
$repoName = Split-Path -Leaf $repoRoot

$container = if ($env:DEVSHELL_CONTAINER) { $env:DEVSHELL_CONTAINER } else { "devshell-$repoName" }
$mount = if ($env:DEVSHELL_MOUNT) { $env:DEVSHELL_MOUNT } else { "/workspaces/$repoName" }
$user = if ($env:DEVSHELL_USER) { $env:DEVSHELL_USER } else { 'vscode' }

# Map cwd (if under the repo) to the container path so relative work
# lands in the same directory.
$cwd = (Get-Location).Path
$sub = ''
if ($cwd -like "$repoRoot*") {
    $sub = $cwd.Substring($repoRoot.Length).Replace('\', '/')
}
$workdir = "$mount$sub"

$posix = $CommandParts -join ' '
$escaped = $posix.Replace("'", "'\''")
# cd must live inside the direnv exec shell: direnv exec itself chdirs
# to the directory given as its first argument.
$inner = ". ~/.nix-profile/etc/profile.d/nix.sh && direnv exec '$mount' bash -c 'cd `"$workdir`" && $escaped'"

wslc exec -u $user -e USER=$user $container bash -c $inner
if ($LASTEXITCODE -ne 0) {
    $execCode = $LASTEXITCODE
    # Retry only when the failure was the container being absent/stopped,
    # never when the command itself failed (it may not be idempotent).
    $inspectJson = wslc inspect $container 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container '$container' not found. Run provision.ps1 first (see nix-windows-wslc SKILL.md)."
    }
    if ((($inspectJson | ConvertFrom-Json)[0].State.Status) -ne 'running') {
        wslc start $container | Out-Null
        wslc exec -u $user -e USER=$user $container bash -c $inner
        exit $LASTEXITCODE
    }
    exit $execCode
}
exit $LASTEXITCODE
