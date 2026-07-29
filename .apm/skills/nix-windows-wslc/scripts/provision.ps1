# Provisions a wslc devShell container for the current repository.
# See SKILL.md (nix-windows-wslc). Idempotent: safe to re-run; reuses
# the /nix volume so re-provisioning after `wslc rm` is fast.
#
# Usage: pwsh provision.ps1 [-Image <ref>]
# Env overrides: DEVSHELL_CONTAINER, DEVSHELL_MOUNT, DEVSHELL_USER
[CmdletBinding()]
param(
    [string]$Image = 'mcr.microsoft.com/devcontainers/base:ubuntu-24.04'
)
$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { Write-Error 'Run from inside a git repository.' }
$repoRoot = $repoRoot.Replace('/', '\')
$repoName = Split-Path -Leaf $repoRoot

$container = if ($env:DEVSHELL_CONTAINER) { $env:DEVSHELL_CONTAINER } else { "devshell-$repoName" }
$mount = if ($env:DEVSHELL_MOUNT) { $env:DEVSHELL_MOUNT } else { "/workspaces/$repoName" }
$user = if ($env:DEVSHELL_USER) { $env:DEVSHELL_USER } else { 'vscode' }
$volume = "nix-store-$repoName"

function Invoke-Container([string]$Script) {
    wslc exec -u $user -e USER=$user $container bash -c $Script
    if ($LASTEXITCODE -ne 0) { Write-Error "container step failed: $Script" }
}

# 1. Container up (create if missing, start if stopped).
$inspectJson = wslc inspect $container 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating container '$container' (volume '$volume')..."
    wslc run -d --name $container -v "${repoRoot}:${mount}" -v "${volume}:/nix" $Image sleep infinity
    if ($LASTEXITCODE -ne 0) {
        Write-Error "wslc run failed. If pull reported 'network is unreachable', run 'wslc system session terminate' and retry."
    }
} elseif ((($inspectJson | ConvertFrom-Json)[0].State.Status) -ne 'running') {
    wslc start $container | Out-Null
}

# 2. Nix + devShell toolchain. Prefer the repository's devcontainer
# setup script (ADR-0012/0013); strip CR defensively.
if (Test-Path (Join-Path $repoRoot '.devcontainer\postCreateCommand.sh')) {
    Invoke-Container "tr -d '\r' < '$mount/.devcontainer/postCreateCommand.sh' > /tmp/devshell-setup.sh && cd '$mount' && bash /tmp/devshell-setup.sh"
} else {
    Invoke-Container 'command -v nix >/dev/null 2>&1 || { curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --no-modify-profile; }'
    Invoke-Container '. ~/.nix-profile/etc/profile.d/nix.sh && for p in direnv nix-direnv; do nix profile list | grep -q "\.$p\$" || nix profile add "nixpkgs#$p"; done'
}

# 3. Relocate the direnv layout dir off the virtiofs mount (chmod is
# rejected there and .direnv/ must not pollute the NTFS tree). The
# override MUST keep sourcing nix-direnv or caching silently degrades.
$direnvrc = @'
source $HOME/.nix-profile/share/nix-direnv/direnvrc
direnv_layout_dir() {
  echo "$HOME/.cache/direnv/layouts/$(echo -n "$PWD" | sha1sum | cut -c1-40)"
}
'@ -replace "`r", ''
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($direnvrc))
Invoke-Container "mkdir -p ~/.config/direnv && echo $b64 | base64 -d > ~/.config/direnv/direnvrc"

# 4. Allow the devShell and warm the nix-direnv cache.
Invoke-Container ". ~/.nix-profile/etc/profile.d/nix.sh && cd '$mount' && direnv allow && direnv exec . true"

Write-Host "Provisioned '$container'. Use scripts/devshell-exec.ps1 for devShell commands."
