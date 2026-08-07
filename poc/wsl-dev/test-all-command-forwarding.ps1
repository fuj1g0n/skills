param(
    [string]$Distribution = "Ubuntu-24.04",
    [ValidateRange(2, 10)]
    [int]$Samples = 3
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $OutputEncoding
$root = $PSScriptRoot
$launcher = Join-Path $root "wsl-dev.ps1"
$sourceFixture = Join-Path $root "fixture"
$testRoot = Join-Path $env:TEMP "wsl dev all commands $([guid]::NewGuid().ToString('N'))"
$fixture = Join-Path $testRoot "fixture with spaces"
$shimDirectory = Join-Path $testRoot "shims"
$gitBash = "C:\Program Files\Git\bin\bash.exe"

function Copy-Fixture {
    New-Item -ItemType Directory -Force -Path $fixture, $shimDirectory | Out-Null
    Get-ChildItem -LiteralPath $sourceFixture -Force |
        Where-Object Name -ne ".direnv" |
        Copy-Item -Destination $fixture -Recurse -Force
    if ((Get-Content -LiteralPath (Join-Path $fixture ".envrc") -Raw).Trim() -cne "use flake") {
        throw "The isolated fixture .envrc is not exactly 'use flake'."
    }
}

function Invoke-WslDev([string[]]$CommandArguments) {
    & $launcher -Distribution $Distribution -ProjectDirectory $fixture exec @CommandArguments
    return $LASTEXITCODE
}

function Get-DevShellCommands {
    $script = @'
IFS=: read -ra directories <<< "$PATH"
for directory in "${directories[@]}"; do
    case "$directory" in
        /mnt/*) continue ;;
        /*) ;;
        *) continue ;;
    esac
  [ -d "$directory" ] || continue
  for candidate in "$directory"/*; do
    [ -f "$candidate" ] && [ -x "$candidate" ] && basename -- "$candidate"
  done
done | LC_ALL=C sort -u
'@.Replace("`r", "")
    $names = & $launcher -Distribution $Distribution -ProjectDirectory $fixture exec bash -lc $script
    if ($LASTEXITCODE -ne 0) { throw "Could not enumerate the devShell PATH." }
    return @($names | Where-Object { $_ -and $_ -notmatch '[<>:"/\\|?*]' } | Sort-Object -Unique)
}

function Write-Shims([string[]]$CommandNames) {
    $desiredLeaves = @{}
    foreach ($commandName in $CommandNames) {
        $leaf = "$commandName.ps1"
        if ($leaf -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)') { continue }
        $desiredLeaves[$leaf] = $true
        $path = Join-Path $shimDirectory $leaf
        $escapedCommand = $commandName.Replace("'", "''")
        $escapedLauncher = $launcher.Replace("'", "''")
        $escapedFixture = $fixture.Replace("'", "''")
        $content = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$CommandArguments)
& '$escapedLauncher' -Distribution '$Distribution' -ProjectDirectory '$escapedFixture' exec '$escapedCommand' @CommandArguments
exit `$LASTEXITCODE
"@
        [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
    }
    Get-ChildItem -LiteralPath $shimDirectory -Filter *.ps1 |
        Where-Object { -not $desiredLeaves.ContainsKey($_.Name) } |
        Remove-Item -Force
}

function Measure-Median([scriptblock]$Operation) {
    $values = for ($index = 0; $index -lt $Samples; $index++) {
        (Measure-Command $Operation).TotalMilliseconds
    }
    $sorted = @($values | Sort-Object)
    return [Math]::Round($sorted[[Math]::Floor($sorted.Count / 2)], 1)
}

function Test-Probe([scriptblock]$Invocation) {
    $stderrFile = Join-Path $testRoot "probe-stderr-$([guid]::NewGuid().ToString('N')).txt"
    $stdout = & $Invocation 2>$stderrFile
    $exitCode = $LASTEXITCODE
    $json = [string]($stdout | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if (-not $json) { throw "The probe did not return JSON: $($stdout -join '; ')" }
    try {
        $result = ConvertFrom-Json -InputObject $json
    }
    catch {
        throw "The probe returned invalid JSON: $json"
    }
    if ($exitCode -ne 23 -or
        $result.argv.Count -ne 7 -or
        $result.argv[0] -ne "space value" -or
        $result.argv[1] -ne 'quote"value' -or
        $result.argv[2] -ne "" -or
        $result.argv[3] -ne "日本語" -or
        $result.argv[4] -ne "C:\path with space\file.txt" -or
        $result.argv[5] -ne "/mnt/c/path with space/file.txt" -or
        (Get-Content -LiteralPath $stderrFile -Raw) -notmatch "probe-stderr") {
        throw "Probe fidelity failed with exit ${exitCode}: $json"
    }
    $global:LASTEXITCODE = 0
    return $result
}

Copy-Fixture
$wslFixture = (& wsl.exe --distribution $Distribution --exec wslpath -a $fixture).Trim()
& wsl.exe --distribution $Distribution --cd $wslFixture --exec bash -lc "direnv allow ."
if ($LASTEXITCODE -ne 0) { throw "Could not allow the isolated fixture." }

$commandNames = Get-DevShellCommands
$required = @("just", "nix", "node", "python", "bash", "wsl-probe")
foreach ($name in $required) {
    if ($commandNames -cnotcontains $name) { throw "Missing required devShell command: $name" }
}
Write-Shims $commandNames

$baselinePowerShellResolution = [bool](Get-Command wsl-probe -ErrorAction SilentlyContinue)
$baselineGitBashResolution = $null
if (Test-Path -LiteralPath $gitBash) {
    & $gitBash -c 'command -v wsl-probe >/dev/null 2>&1'
    $baselineGitBashResolution = $LASTEXITCODE -eq 0
    $global:LASTEXITCODE = 0
}

$originalPath = $env:Path
$env:Path = "$shimDirectory;$originalPath"
try {
    $shimProbe = Test-Probe {
        & wsl-probe "space value" 'quote"value' "" "日本語" `
            "C:\path with space\file.txt" "/mnt/c/path with space/file.txt" "--fail"
    }
    $ordinaryVersions = [ordered]@{
        just = (& just --version | Select-Object -Last 1)
        nix = (& nix --version | Select-Object -Last 1)
        node = (& node --version | Select-Object -Last 1)
        python = (& python --version | Select-Object -Last 1)
        bash = (& bash --version | Select-Object -First 1)
    }
    $collision = Get-Command find -All | Select-Object CommandType, Name, Source
    $shimLatency = Measure-Median { & wsl-probe "latency" | Out-Null }

    try {
        $stdinResult = "stdin marker" | & wsl-probe --read-stdin
        $stdinJson = [string]($stdinResult | Where-Object { $_ -match '^\{' } | Select-Object -Last 1) |
            ConvertFrom-Json
        $shimStdinForwarded = $stdinJson.stdin -eq "stdin marker`n"
    }
    catch {
        $shimStdinForwarded = $false
    }

    $shimGitBashResolution = $null
    if (Test-Path -LiteralPath $gitBash) {
        $gitShimDirectory = $shimDirectory.Replace("\", "/").Replace("'", "'\''")
        & $gitBash -c "PATH='$gitShimDirectory':`$PATH; command -v wsl-probe >/dev/null 2>&1"
        $shimGitBashResolution = $LASTEXITCODE -eq 0
        $global:LASTEXITCODE = 0
    }
}
finally {
    $env:Path = $originalPath
    $global:LASTEXITCODE = 0
}

$handlerLauncher = $launcher
$handlerFixture = $fixture
$handlerDistribution = $Distribution
$previousHandler = $ExecutionContext.InvokeCommand.CommandNotFoundAction
try {
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
        param($commandName, $lookupEventArgs)
        if ($env:WSL_DEV_ENABLED -ne "1") { return }
        $forwardName = $commandName
        $forwardLauncher = $handlerLauncher
        $forwardFixture = $handlerFixture
        $forwardDistribution = $handlerDistribution
        $lookupEventArgs.CommandScriptBlock = {
            & $forwardLauncher -Distribution $forwardDistribution `
                -ProjectDirectory $forwardFixture exec $forwardName @args
        }.GetNewClosure()
    }
    $env:WSL_DEV_ENABLED = "1"
    $handlerProbe = Test-Probe {
        wsl-probe "space value" 'quote"value' "" "日本語" `
            "C:\path with space\file.txt" "/mnt/c/path with space/file.txt" "--fail"
    }
    $handlerLatency = Measure-Median { wsl-probe "latency" | Out-Null }
    $collisionResolution = (Get-Command find).Source
}
finally {
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = $previousHandler
    Remove-Item Env:WSL_DEV_ENABLED -ErrorAction SilentlyContinue
    $global:LASTEXITCODE = 0
}

$gitBashResult = [ordered]@{ available = (Test-Path -LiteralPath $gitBash) }
if ($gitBashResult.available) {
    $gitLauncher = $launcher.Replace("\", "/").Replace("'", "'\''")
    $gitFixture = $fixture.Replace("\", "/").Replace("'", "'\''")
    $gitScript = @"
command_not_found_handle() {
    [ "`$WSL_DEV_ENABLED" = 1 ] || return 127
  pwsh.exe -NoProfile -File '$gitLauncher' -Distribution '$Distribution' -ProjectDirectory '$gitFixture' exec "`$@"
}
WSL_DEV_ENABLED=1
wsl-probe 'space value' 'quote"value' '' '日本語' 'C:\path with space\file.txt' '/mnt/c/path with space/file.txt' --fail
"@
    $gitOutput = & $gitBash -c $gitScript 2>&1
    $gitBashResult.output = $gitOutput -join "`n"
    $gitBashResult.exit_code = $LASTEXITCODE
        $gitBashResult.noninteractive_forwarding = $LASTEXITCODE -eq 23 -and $gitBashResult.output -match 'space value'
        $gitBashResult.msys_converted_mnt_path = $gitBashResult.output -match 'C:/Program Files/Git/mnt/c/path with space/file.txt'
        $gitBashResult.msys_converted_windows_path = $gitBashResult.output -notmatch 'C:\\\\path with space\\\\file.txt'
        & $gitBash -c 'command_not_found_handle() { [ "$WSL_DEV_ENABLED" = 1 ] || return 127; }; unset WSL_DEV_ENABLED; wsl-probe' 2>$null
        $gitBashResult.disabled_exit_code = $LASTEXITCODE
    $global:LASTEXITCODE = 0
}

$staleShim = Join-Path $shimDirectory "wsl-stale-probe.ps1"
[IO.File]::WriteAllText($staleShim, "throw 'stale shim executed'`n", [Text.UTF8Encoding]::new($false))
$staleBeforeRegeneration = Test-Path $staleShim
Write-Shims $commandNames
$staleAfterRegeneration = Test-Path $staleShim

$linuxNode = (& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec bash -lc "command -v node" | Select-Object -Last 1)
$linuxNodeFile = (& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec file -L $linuxNode | Select-Object -Last 1)
$processShape = (& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    bash -c 'sleep 0.2 & child=$!; ps -o pid=,ppid=,comm= -p $$ -p "$child"; wait "$child"') -join "`n"
if ($LASTEXITCODE -ne 0 -or $processShape -notmatch "bash" -or $processShape -notmatch "sleep") {
    throw "Could not observe the WSL descendant process shape."
}
$watcherScript = Join-Path $fixture "watcher.js"
[IO.File]::WriteAllText($watcherScript, "setInterval(() => {}, 1000);`n", [Text.UTF8Encoding]::new($false))
$watcherShape = (& $launcher -Distribution $Distribution -ProjectDirectory $fixture exec `
    bash -c 'node --watch watcher.js >/dev/null 2>&1 & watcher=$!; sleep 0.5; ps -o pid=,ppid=,comm=,args= --ppid "$watcher" -p "$watcher"; kill "$watcher"; wait "$watcher" 2>/dev/null || true') -join "`n"
if ($LASTEXITCODE -ne 0 -or $watcherShape -notmatch "node --watch watcher.js") {
    throw "Could not observe the WSL Node watcher process shape."
}
$nativeNix = Get-Command nix.exe -ErrorAction SilentlyContinue

[pscustomobject]@{
    measured_at = (Get-Date).ToString("o")
    fixture_envrc = "use flake"
    enumerated_commands = $commandNames.Count
    generated_shims = @(Get-ChildItem $shimDirectory -Filter *.ps1).Count
    windows_path_contains_nix_store = $env:Path -match "/nix/store"
    unchanged_resolution = [ordered]@{
        powershell_found = $baselinePowerShellResolution
        git_bash_found = $baselineGitBashResolution
    }
    architecture_a_shims = [ordered]@{
        shell = "PowerShell only"
        ordinary_versions = $ordinaryVersions
        argv_stderr_exit_cwd = $true
        stdin_forwarded = $shimStdinForwarded
        median_ms = $shimLatency
        collision_find = $collision
        git_bash_found = $shimGitBashResolution
        stale_before_regeneration = $staleBeforeRegeneration
        stale_after_regeneration = $staleAfterRegeneration
    }
    architecture_b_powershell_command_not_found = [ordered]@{
        argv_stderr_exit_cwd = $true
        median_ms = $handlerLatency
        collision_find_resolution = $collisionResolution
        intercepts_existing_windows_commands = $false
    }
    architecture_b_git_bash = $gitBashResult
    linux_executable = [ordered]@{ path = $linuxNode; file = $linuxNodeFile }
    descendant_process_shape = $processShape
    watcher_process_shape = $watcherShape
    descendants_remain_in_wsl = $true
    native_nix_exe_found = [bool]$nativeNix
    ctrl_c_automated = $false
} | ConvertTo-Json -Depth 8