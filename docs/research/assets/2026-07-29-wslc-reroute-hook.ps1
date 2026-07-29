# PoC preToolUse hook: reroute shell commands into the wslc container.
# Reads the camelCase preToolUse payload on stdin; if the tool is a shell
# tool and the command is not on the Windows-side exception list, returns
# modifiedArgs rewriting it to `wslc exec ... bash -c '<command>'` with
# the project path mapped to the container mount.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Only intercept shell tools.
if ($payload.toolName -notin @('powershell', 'bash')) {
    Write-Output '{}'
    exit 0
}

$command = $payload.toolArgs.command
if (-not $command) {
    Write-Output '{}'
    exit 0
}

# Exception list: these stay on Windows (credentials, GHCP-internal ops).
if ($command -match '^\s*(git|gh)\b') {
    Write-Output '{}'
    exit 0
}

$container = 'poc-skills'
$winRoot = 'C:\Users\kfujita\workspace\github.com\fuj1g0n\skills'
$ctrRoot = '/workspaces/skills'

# Map Windows project paths appearing in the command to container paths.
$mapped = $command.Replace($winRoot, $ctrRoot).Replace($winRoot.Replace('\', '/'), $ctrRoot).Replace('\', '/')

# Wrap for container execution with the devShell environment.
$inner = ". ~/.nix-profile/etc/profile.d/nix.sh && cd $ctrRoot && direnv exec . bash -c " + "'" + $mapped.Replace("'", "'\''") + "'"
$rewritten = "wslc exec -u vscode -e USER=vscode $container bash -c `"$inner`""

@{ modifiedArgs = @{ command = $rewritten } } | ConvertTo-Json -Compress -Depth 5
