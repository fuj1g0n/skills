[CmdletBinding()]
param(
    [ValidateSet("Install", "Rollback", "Verify")]
    [string]$Action = "Install",
    [string]$Distribution = "Ubuntu-24.04",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$installRoot = Join-Path $env:LOCALAPPDATA "wsl-dev"
$adapterDirectory = Join-Path $installRoot "adapter"
$adapterPath = Join-Path $adapterDirectory "WslBashAdapter.exe"
$adapterFingerprintPath = Join-Path $adapterDirectory "source.sha256"
$binDirectory = Join-Path $installRoot "bin"
$launcherPath = Join-Path $binDirectory "wsl-dev.ps1"
$configDirectory = Join-Path $installRoot "direnv"
$configPath = Join-Path $configDirectory "config.toml"
$configDirenvrcPath = Join-Path $configDirectory "direnvrc"
$stateDirectory = Join-Path $installRoot "state"
$statePath = Join-Path $stateDirectory "deployment.json"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDirectory = Join-Path $installRoot "backups\$timestamp"
$profileStart = "# >>> wsl-dev experimental direnv >>>"
$profileEnd = "# <<< wsl-dev experimental direnv <<<"
$proxyStart = "# >>> wsl-dev experimental metadata proxy >>>"
$proxyEnd = "# <<< wsl-dev experimental metadata proxy <<<"
$environmentNames = @("DIRENV_CONFIG", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "WSL_DEV_DISTRO")

function Write-Plan([string]$Message) {
    Write-Output $(if ($DryRun) { "DRY-RUN: $Message" } else { $Message })
}

function Get-Text([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path)
    }
    return ""
}

function Merge-MarkerBlock(
    [string]$Content,
    [string]$Start,
    [string]$End,
    [string]$Body
) {
    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $block = ($Start, $Body.TrimEnd(), $End) -join $newline
    $startIndex = $Content.IndexOf($Start, [StringComparison]::Ordinal)
    $endIndex = $Content.IndexOf($End, [StringComparison]::Ordinal)
    if (($startIndex -ge 0) -xor ($endIndex -ge 0) -or $endIndex -lt $startIndex) {
        throw "Refusing to edit an incomplete managed block: $Start"
    }
    if ($startIndex -ge 0) {
        $endIndex += $End.Length
        return $Content.Substring(0, $startIndex) + $block + $Content.Substring($endIndex)
    }
    if ($Content.Length -eq 0) {
        return "$block$newline"
    }
    return $Content.TrimEnd("`r", "`n") + $newline + $newline + $block + $newline
}

function Merge-BashPath([string]$Content, [string]$Path) {
    $normalizedPath = $Path.Replace("\", "/")
    $value = "bash_path = `"$normalizedPath`""
    $globalMatch = [regex]::Match(
        $Content,
        '(?ms)^\[global\]\s*$.*?(?=^\[|\z)')
    if (-not $globalMatch.Success) {
        return $Content.TrimEnd("`r", "`n") + "`r`n`r`n[global]`r`n$value`r`n"
    }
    $section = $globalMatch.Value
    if ($section -match '(?m)^\s*bash_path\s*=') {
        $updated = [regex]::Replace($section, '(?m)^\s*bash_path\s*=.*$', $value, 1)
    }
    else {
        $updated = [regex]::Replace($section, '(?m)^\[global\]\s*$', "[global]`r`n$value", 1)
    }
    return $Content.Substring(0, $globalMatch.Index) + $updated +
        $Content.Substring($globalMatch.Index + $globalMatch.Length)
}

function Backup-WindowsFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    if ($DryRun) {
        Write-Plan "Back up $Path under $backupDirectory"
        return $null
    }
    New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
    $backup = Join-Path $backupDirectory ([IO.Path]::GetFileName($Path))
    $suffix = 0
    while (Test-Path -LiteralPath $backup) {
        $suffix++
        $backup = Join-Path $backupDirectory "$([IO.Path]::GetFileName($Path)).$suffix"
    }
    Copy-Item -LiteralPath $Path -Destination $backup
    return $backup
}

function Set-WindowsText([string]$Path, [string]$Content) {
    if ((Get-Text $Path) -ceq $Content) {
        Write-Plan "No change: $Path"
        return
    }
    $null = Backup-WindowsFile $Path
    Write-Plan "Update $Path"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
        [System.IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    }
}

function Copy-WindowsFileIfChanged([string]$Source, [string]$Destination) {
    if ((Test-Path -LiteralPath $Destination) -and
        (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash) {
        Write-Plan "No change: $Destination"
        return
    }
    $null = Backup-WindowsFile $Destination
    Write-Plan "Update $Destination"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function Get-AdapterFingerprint {
    $projectDirectory = Join-Path $root "wsl-bash-adapter"
    $inputs = Get-ChildItem -LiteralPath $projectDirectory -File -Recurse |
        Where-Object FullName -NotMatch '[\\/](bin|obj)[\\/]' |
        Sort-Object FullName
    $lines = @(
        "sdk=$((& dotnet.exe --version).Trim())"
        "configuration=Release"
        "runtime=win-x64"
        "self-contained=true"
        "publish-single-file=true"
        "debug-type=None"
    )
    $lines += $inputs | ForEach-Object {
        $relativePath = [IO.Path]::GetRelativePath($projectDirectory, $_.FullName).Replace("\", "/")
        "$relativePath=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($lines -join "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Invoke-Wsl([string]$Script, [string[]]$Arguments = @()) {
    $output = & wsl.exe --distribution $Distribution --exec bash -lc $Script wsl-dev @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed for distribution $Distribution."
    }
    return $output
}

function Get-WslConfigDirectory {
    return (Invoke-Wsl 'printf %s "${DIRENV_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/direnv}"').Trim()
}

function Set-WslText([string]$Path, [string]$Content) {
    $existing = (Invoke-Wsl 'if [ -f "$1" ]; then cat -- "$1"; fi' @($Path)) -join "`n"
    if ($existing.Length -gt 0) { $existing += "`n" }
    if ($existing -ceq $Content.Replace("`r`n", "`n")) {
        Write-Plan "No change: ${Distribution}:$Path"
        return
    }
    $backup = "$Path.wsl-dev-backup-$timestamp"
    Write-Plan "Back up ${Distribution}:$Path to $backup"
    Write-Plan "Update ${Distribution}:$Path"
    if ($DryRun) { return }
    Invoke-Wsl 'mkdir -p -- "$(dirname "$1")"; if [ -f "$1" ]; then cp -p -- "$1" "$2"; fi' @($Path, $backup) | Out-Null
    $tempPath = Join-Path $env:TEMP "wsl-dev-direnvrc-$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText($tempPath, $Content.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
        $wslTempPath = (& wsl.exe --distribution $Distribution --exec wslpath -a $tempPath).Trim()
        if ($LASTEXITCODE -ne 0) { throw "Could not translate the temporary direnvrc path." }
        Invoke-Wsl 'install -m 0644 -- "$1" "$2"' @($wslTempPath, $Path) | Out-Null
    }
    finally {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-OriginalState([string]$ProfilePath, [string]$WslDirenvrcPath) {
    $environment = [ordered]@{}
    foreach ($name in $environmentNames) {
        $environment[$name] = [Environment]::GetEnvironmentVariable($name, "User")
    }
    return [ordered]@{
        installed_at = (Get-Date).ToString("o")
        distribution = $Distribution
        profile = [ordered]@{ path = $ProfilePath; existed = (Test-Path -LiteralPath $ProfilePath); backup = $null }
        config = [ordered]@{ path = $configPath; existed = (Test-Path -LiteralPath $configPath); backup = $null }
        config_direnvrc = [ordered]@{ path = $configDirenvrcPath; existed = (Test-Path -LiteralPath $configDirenvrcPath); backup = $null }
        wsl_direnvrc = [ordered]@{ path = $WslDirenvrcPath; existed = $false; backup = $null }
        environment = $environment
    }
}

function Restore-WindowsFile($State) {
    if ($State.existed) {
        Copy-Item -LiteralPath $State.backup -Destination $State.path -Force
    }
    else {
        Remove-Item -LiteralPath $State.path -Force -ErrorAction SilentlyContinue
    }
}

function Send-EnvironmentChange {
    if (-not ("WslDev.NativeMethods" -as [type])) {
        Add-Type -TypeDefinition @'
namespace WslDev {
    using System;
    using System.Runtime.InteropServices;

    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint message, UIntPtr wParam, string lParam,
            uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    $result = [UIntPtr]::Zero
    $null = [WslDev.NativeMethods]::SendMessageTimeout(
        [IntPtr]0xffff, 0x001a, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref]$result)
}

function Get-CurrentSessionActivation {
    return ($environmentNames | ForEach-Object {
        "`$env:$_ = [Environment]::GetEnvironmentVariable('$_', 'User')"
    }) -join "; "
}

function Invoke-DirenvConfigProbe(
    [string]$ProbeName,
    [string]$DirenvPath,
    [switch]$LoadProfile,
    [switch]$OmitDirenvConfig
) {
    if (-not (Test-Path -LiteralPath $installRoot)) {
        throw "The deployment root does not exist: $installRoot"
    }
    $process = [Diagnostics.ProcessStartInfo]::new()
    $process.FileName = (Get-Process -Id $PID).Path
    $process.WorkingDirectory = $installRoot
    $process.UseShellExecute = $false
    $process.RedirectStandardOutput = $true
    $process.RedirectStandardError = $true
    if (-not $LoadProfile) {
        $process.ArgumentList.Add("-NoProfile")
    }
    $process.ArgumentList.Add("-NonInteractive")
    $process.ArgumentList.Add("-Command")
    $process.ArgumentList.Add(@'
$ErrorActionPreference = "Stop"
$resolved = (Get-Command direnv.exe -ErrorAction Stop).Source
$expectedExecutable = $env:WSL_DEV_CONFIG_PROBE_DIRENV
if ([IO.Path]::GetFullPath($resolved) -cne [IO.Path]::GetFullPath($expectedExecutable)) {
    throw "Unexpected direnv executable: $resolved"
}
$output = (& $resolved status 2>&1 | Out-String)
if ($output -match "couldn't find a configuration directory") {
    throw $output.Trim()
}
$match = [regex]::Match($output, '(?m)^DIRENV_CONFIG\s+(.+?)\r?$')
if (-not $match.Success) {
    throw "direnv status did not report DIRENV_CONFIG: $output"
}
$actual = [IO.Path]::GetFullPath($match.Groups[1].Value.Trim())
$expected = [IO.Path]::GetFullPath($env:WSL_DEV_CONFIG_PROBE_EXPECTED)
if ($actual -cne $expected) {
    throw "direnv resolved config '$actual', expected '$expected'."
}
Write-Output "direnv=$resolved"
Write-Output "config=$actual"
'@)
    foreach ($environmentName in $environmentNames) {
        $null = $process.Environment.Remove($environmentName)
    }
    if (-not $LoadProfile) {
        foreach ($environmentName in $environmentNames) {
            $value = [Environment]::GetEnvironmentVariable($environmentName, "User")
            if ($null -ne $value) {
                $process.Environment[$environmentName] = $value
            }
        }
    }
    if ($OmitDirenvConfig) {
        $null = $process.Environment.Remove("DIRENV_CONFIG")
    }
    $process.Environment["WSL_DEV_CONFIG_PROBE_DIRENV"] = $DirenvPath
    $process.Environment["WSL_DEV_CONFIG_PROBE_EXPECTED"] = $configDirectory
    $child = [Diagnostics.Process]::Start($process)
    $stdout = $child.StandardOutput.ReadToEnd()
    $stderr = $child.StandardError.ReadToEnd()
    $child.WaitForExit()
    if ($child.ExitCode -ne 0) {
        throw "$ProbeName failed with exit code $($child.ExitCode): $stderr$stdout"
    }
    Write-Output "$ProbeName passed: $($stdout.Trim() -replace "`r?`n", "; ")"
}

if ($Action -eq "Rollback") {
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw "No deployment state exists at $statePath."
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $Distribution = $state.distribution
    Write-Plan "Restore PowerShell profile and native direnv configuration"
    Write-Plan "Restore $($state.distribution):$($state.wsl_direnvrc.path)"
    Write-Plan "Restore user environment variables and remove installed binaries"
    if ($DryRun) { return }
    Restore-WindowsFile $state.profile
    Restore-WindowsFile $state.config
    Restore-WindowsFile $state.config_direnvrc
    if ($state.wsl_direnvrc.existed) {
        Invoke-Wsl 'cp -p -- "$1" "$2"' @($state.wsl_direnvrc.backup, $state.wsl_direnvrc.path) | Out-Null
    }
    else {
        Invoke-Wsl 'rm -f -- "$1"' @($state.wsl_direnvrc.path) | Out-Null
    }
    foreach ($property in $state.environment.PSObject.Properties) {
        [Environment]::SetEnvironmentVariable($property.Name, $property.Value, "User")
        [Environment]::SetEnvironmentVariable($property.Name, $property.Value, "Process")
    }
    Send-EnvironmentChange
    Remove-Item -LiteralPath $adapterDirectory, $binDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Rollback complete. Backups and deployment state remain under $installRoot."
    Write-Output "Activate restored values in this PowerShell: $(Get-CurrentSessionActivation)"
    return
}

$direnv = Get-Command direnv.exe -ErrorAction Stop
if ((& $direnv.Source version) -ne "2.37.1") {
    throw "This experimental deployment requires native direnv 2.37.1."
}
if ($Action -eq "Verify") {
    Invoke-DirenvConfigProbe "Persisted user environment no-profile probe" $direnv.Source
    Invoke-DirenvConfigProbe "Sanitized DIRENV_CONFIG XDG fallback probe" $direnv.Source -OmitDirenvConfig
    Invoke-DirenvConfigProbe "Profile-loaded probe" $direnv.Source -LoadProfile
    Write-Output "Deployment environment verification passed."
    return
}
$null = Get-Command dotnet.exe -ErrorAction Stop
$null = Get-Command wsl.exe -ErrorAction Stop
$wslConfigDirectory = Get-WslConfigDirectory
$wslDirenvrcPath = "$wslConfigDirectory/direnvrc"
$profilePath = $PROFILE.CurrentUserCurrentHost

$state = if (Test-Path -LiteralPath $statePath) {
    Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}
else {
    Get-OriginalState $profilePath $wslDirenvrcPath
}

if (-not (Test-Path -LiteralPath $statePath) -and -not $DryRun) {
    New-Item -ItemType Directory -Force -Path $stateDirectory, $backupDirectory | Out-Null
    if ($state.profile.existed) { $state.profile.backup = Backup-WindowsFile $state.profile.path }
    if ($state.config.existed) { $state.config.backup = Backup-WindowsFile $state.config.path }
    if ($state.config_direnvrc.existed) { $state.config_direnvrc.backup = Backup-WindowsFile $state.config_direnvrc.path }
    $wslExists = (Invoke-Wsl 'if [ -f "$1" ]; then printf yes; else printf no; fi' @($wslDirenvrcPath)).Trim() -eq "yes"
    $state.wsl_direnvrc.existed = $wslExists
    if ($wslExists) {
        $state.wsl_direnvrc.backup = "$wslDirenvrcPath.wsl-dev-original-$timestamp"
        Invoke-Wsl 'cp -p -- "$1" "$2"' @($wslDirenvrcPath, $state.wsl_direnvrc.backup) | Out-Null
    }
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding utf8
}

Write-Plan "Publish adapter to $adapterPath"
Write-Plan "Install launcher to $launcherPath"
if (-not $DryRun) {
    $adapterFingerprint = Get-AdapterFingerprint
    if ((Test-Path -LiteralPath $adapterPath) -and
        (Get-Text $adapterFingerprintPath).Trim() -ceq $adapterFingerprint) {
        Write-Plan "No change: $adapterPath (source fingerprint matches)"
    }
    else {
        $publishDirectory = Join-Path $env:TEMP "wsl-dev-publish-$([guid]::NewGuid().ToString('N'))"
        try {
            dotnet publish (Join-Path $root "wsl-bash-adapter\WslBashAdapter.csproj") `
                --nologo --configuration Release --runtime win-x64 --self-contained true `
                -p:PublishSingleFile=true -p:DebugType=None --output $publishDirectory | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Could not publish WslBashAdapter." }
            Copy-WindowsFileIfChanged (Join-Path $publishDirectory "WslBashAdapter.exe") $adapterPath
            Set-WindowsText $adapterFingerprintPath $adapterFingerprint
        }
        finally {
            Remove-Item -LiteralPath $publishDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Copy-WindowsFileIfChanged (Join-Path $root "wsl-dev.ps1") $launcherPath
}

$configContent = Merge-BashPath (Get-Text $configPath) $adapterPath
Set-WindowsText $configPath $configContent

$configDirenvrcBody = @'
# The adapter runs this file in WSL, where HOME identifies the target Linux user.
source "$HOME/.config/direnv/direnvrc"
'@
$configDirenvrcContent = Merge-MarkerBlock (Get-Text $configDirenvrcPath) $proxyStart $proxyEnd $configDirenvrcBody
$configDirenvrcContent = $configDirenvrcContent.Replace("`r`n", "`n")
Set-WindowsText $configDirenvrcPath $configDirenvrcContent

$profileBody = @"
`$env:DIRENV_CONFIG = Join-Path `$env:LOCALAPPDATA "wsl-dev\direnv"
`$env:XDG_CONFIG_HOME = Join-Path `$env:LOCALAPPDATA "wsl-dev"
`$env:XDG_CACHE_HOME = Join-Path `$env:LOCALAPPDATA "wsl-dev\xdg\cache"
`$env:XDG_DATA_HOME = Join-Path `$env:LOCALAPPDATA "wsl-dev\xdg\data"
`$env:WSL_DEV_DISTRO = "$Distribution"
Invoke-Expression ((& direnv.exe hook pwsh) -join [Environment]::NewLine)
"@
$profileContent = Merge-MarkerBlock (Get-Text $profilePath) $profileStart $profileEnd $profileBody
Set-WindowsText $profilePath $profileContent

$wslProxyBody = @'
if [[ ${DIRENV_WSL_DEV_METADATA_ONLY:-} == 1 ]]; then
  use_flake() {
    export WSL_DEV_ENABLED=1
    export WSL_DEV_DISTRO="${WSL_DEV_DISTRO:?}"
    export WSL_DEV_PROJECT="$PWD"
    export WSL_DEV_EMPTY=""
    export WSL_DEV_UNICODE=$'wsl-\u2713'
  }
fi
'@
$wslContent = (Invoke-Wsl 'if [ -f "$1" ]; then cat -- "$1"; fi' @($wslDirenvrcPath)) -join "`n"
if ($wslContent.Length -gt 0) { $wslContent += "`n" }
$wslContent = Merge-MarkerBlock $wslContent $proxyStart $proxyEnd $wslProxyBody
Set-WslText $wslDirenvrcPath $wslContent

$userEnvironment = [ordered]@{
    DIRENV_CONFIG = $configDirectory
    XDG_CONFIG_HOME = $installRoot
    XDG_CACHE_HOME = Join-Path $installRoot "xdg\cache"
    XDG_DATA_HOME = Join-Path $installRoot "xdg\data"
    WSL_DEV_DISTRO = $Distribution
}
foreach ($entry in $userEnvironment.GetEnumerator()) {
    Write-Plan "Set user environment $($entry.Key)=$($entry.Value)"
    if (-not $DryRun) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "User")
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
    }
}
if (-not $DryRun) {
    Send-EnvironmentChange
    Invoke-DirenvConfigProbe "Persisted user environment no-profile probe" $direnv.Source
    Invoke-DirenvConfigProbe "Sanitized DIRENV_CONFIG XDG fallback probe" $direnv.Source -OmitDirenvConfig
    Invoke-DirenvConfigProbe "Profile-loaded probe" $direnv.Source -LoadProfile
}

Write-Output "Experimental wsl-dev deployment complete."
Write-Output "Adapter: $adapterPath"
Write-Output "Launcher: $launcherPath"
Write-Output "Native direnv config: $configDirectory"
Write-Output "WSL direnvrc: ${Distribution}:$wslDirenvrcPath"
Write-Output "Activate this already-open PowerShell: $(Get-CurrentSessionActivation)"
Write-Output "Rollback: & '$PSCommandPath' -Action Rollback"