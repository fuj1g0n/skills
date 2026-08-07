param(
    [string]$Distribution = "Ubuntu-24.04",
    [string]$DirenvPath,
    [string]$GitBashPath = "C:\Program Files\Git\bin\bash.exe",
    [ValidateRange(3, 30)]
    [int]$Samples = 7
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $OutputEncoding
$root = $PSScriptRoot
$fixtureSource = Join-Path $root "evaluator-fixture"
$runtimeFixtureSource = Join-Path $root "fixture"
$testRoot = Join-Path $env:TEMP "wsl dev measure $([guid]::NewGuid().ToString('N'))"
$adapterPublish = Join-Path $testRoot "wsl-adapter"
$gitAdapterPublish = Join-Path $testRoot "git-adapter"
$managedEnvironmentNames = @(
    Get-ChildItem Env: | Where-Object {
        $_.Name -like "DIRENV_*" -or $_.Name -like "WSL_DEV_*" -or $_.Name -like "XDG_*"
    } | Select-Object -ExpandProperty Name
)
$originalManagedEnvironment = @{}
foreach ($environmentName in $managedEnvironmentNames) {
    $originalManagedEnvironment[$environmentName] = [Environment]::GetEnvironmentVariable($environmentName, "Process")
}

function Find-NativeDirenv {
    if ($DirenvPath) {
        return (Resolve-Path -LiteralPath $DirenvPath).Path
    }

    $command = Get-Command direnv.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $packages = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $installed = Get-ChildItem $packages -Filter direnv.exe -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $installed) {
        throw "Native direnv.exe was not found on PATH or under the WinGet package directory."
    }
    return $installed
}

function Copy-Fixture([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        Where-Object Name -ne ".direnv" |
        Copy-Item -Destination $Destination -Recurse -Force
}

function Reset-DirenvEnvironment {
    Get-ChildItem Env: | Where-Object {
        $_.Name -like "DIRENV_*" -or $_.Name -like "WSL_DEV_*" -or $_.Name -like "XDG_*"
    } | Remove-Item
    foreach ($environmentName in $originalManagedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable(
            $environmentName,
            $originalManagedEnvironment[$environmentName],
            "Process")
    }
}

function Get-Statistics([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    $median = if ($sorted.Count % 2) {
        $sorted[$middle]
    }
    else {
        ($sorted[$middle - 1] + $sorted[$middle]) / 2
    }
    return [ordered]@{
        samples = $sorted.Count
        values_ms = @($Values | ForEach-Object { [Math]::Round($_, 1) })
        median_ms = [Math]::Round($median, 1)
        min_ms = [Math]::Round($sorted[0], 1)
        max_ms = [Math]::Round($sorted[-1], 1)
    }
}

function Measure-CommandSamples([scriptblock]$Operation) {
    $values = for ($sample = 0; $sample -lt $Samples; $sample++) {
        (Measure-Command $Operation).TotalMilliseconds
    }
    return Get-Statistics $values
}

function Invoke-Direnv([string[]]$Arguments, [string]$ErrorFile) {
    $output = & $script:NativeDirenv @Arguments 2>$ErrorFile
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output -join "`n"
        Error = if (Test-Path $ErrorFile) { Get-Content $ErrorFile -Raw } else { "" }
    }
}

function Assert-ExportFidelity([string]$Json, [string]$OriginalPath) {
    $diff = $Json | ConvertFrom-Json
    if ($diff.WSL_DEV_ENABLED -ne "1" -or
        $diff.WSL_DEV_EMPTY -ne "" -or
        $diff.WSL_DEV_SPACE -ne "alpha beta" -or
        $diff.WSL_DEV_MULTILINE -ne "line one`nline two" -or
        $diff.WSL_DEV_UNICODE -ne "日本語-✓" -or
        $diff.WSL_DEV_SPECIAL -ne 'dollar=$;quote=";backslash=\') {
        throw "Environment fidelity assertion failed."
    }

    $unexpected = @($diff.PSObject.Properties.Name | Where-Object {
        $_ -notlike "DIRENV_*" -and $_ -notlike "WSL_DEV_*"
    })
    if ($unexpected.Count -ne 0) {
        throw "Non-allowlisted changes were emitted: $($unexpected -join ', ')"
    }
    if ($Json -match "/nix/store" -or
        $diff.PSObject.Properties.Name -ccontains "PATH" -or
        $diff.PSObject.Properties.Name -ccontains "Path" -or
        $diff.PSObject.Properties.Name -ccontains "ArchitectureCaseProbe" -or
        $env:Path -cne $OriginalPath) {
        throw "Windows PATH/casing changed or a Nix store path leaked."
    }
}

function Write-Proxy([string]$ConfigDirectory, [switch]$Fail) {
    $body = if ($Fail) {
@'
use_flake() {
  echo "proxy failure marker" >&2
    exit 23
}
'@
    }
    else {
@'
use_flake() {
  watch_file "$PWD/flake.nix"
  export WSL_DEV_ENABLED=1
  export WSL_DEV_DISTRO="${WSL_DEV_DISTRO:?}"
  export WSL_DEV_PROJECT="$PWD"
  export WSL_DEV_EMPTY=""
  export WSL_DEV_SPACE="alpha beta"
  export WSL_DEV_MULTILINE=$'line one\nline two'
    export WSL_DEV_UNICODE='日本語-✓'
  export WSL_DEV_SPECIAL='dollar=$;quote=";backslash=\'
  export WSL_DEV_WATCH_BYTES="$(wc -c < "$PWD/flake.nix" | tr -d ' ')"
}
'@
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $ConfigDirectory "direnvrc"),
        $body.Replace("`r`n", "`n"))
}

function Measure-NativeArchitecture(
    [string]$Name,
    [string]$Adapter,
    [string]$Fixture,
    [string]$ConfigDirectory,
    [switch]$TestHook
) {
    Reset-DirenvEnvironment
    $env:DIRENV_CONFIG = $ConfigDirectory
    $env:XDG_CONFIG_HOME = Join-Path $ConfigDirectory "xdg-config"
    $env:XDG_CACHE_HOME = Join-Path $ConfigDirectory "xdg-cache"
    $env:XDG_DATA_HOME = Join-Path $ConfigDirectory "xdg-data"
    $env:WSL_DEV_DISTRO = $Distribution
    $env:GIT_BASH_PATH = $GitBashPath
    $env:ArchitectureCaseProbe = "PreserveMe"
    $originalPath = $env:Path
    $adapterPath = $Adapter.Replace("\", "/")
    @"
[global]
bash_path = "$adapterPath"
"@ | Set-Content -Encoding utf8 (Join-Path $ConfigDirectory "config.toml")
    Write-Proxy $ConfigDirectory
    $errorFile = Join-Path $ConfigDirectory "stderr.log"

    Push-Location $Fixture
    try {
        $allow = Invoke-Direnv @("allow", ".") $errorFile
        if ($allow.ExitCode -ne 0) {
            throw "$Name allow failed: $($allow.Error)"
        }

        $initial = Invoke-Direnv @("export", "json") $errorFile
        if ($initial.ExitCode -ne 0) {
            throw "$Name initial export failed: $($initial.Error)"
        }
        Assert-ExportFidelity $initial.Output $originalPath
        $initialDiff = $initial.Output | ConvertFrom-Json

        $cold = Measure-CommandSamples {
            Remove-Item Env:DIRENV_DIFF, Env:DIRENV_FILE, Env:DIRENV_WATCHES -ErrorAction SilentlyContinue
            $result = Invoke-Direnv @("export", "json") $errorFile
            if ($result.ExitCode -ne 0) { throw $result.Error }
        }

        $pwshExport = Invoke-Direnv @("export", "pwsh") $errorFile
        if ($pwshExport.ExitCode -ne 0 -or -not $pwshExport.Output) {
            throw "$Name PowerShell export failed: $($pwshExport.Error)"
        }
        Invoke-Expression $pwshExport.Output
        if ($env:WSL_DEV_SPACE -ne "alpha beta" -or
            $env:WSL_DEV_MULTILINE -ne "line one`nline two" -or
            $env:WSL_DEV_UNICODE -ne "日本語-✓" -or
            $env:WSL_DEV_EMPTY -ne "") {
            throw "$Name PowerShell export did not apply faithfully."
        }

        $warm = Measure-CommandSamples {
            $result = Invoke-Direnv @("export", "json") $errorFile
            if ($result.ExitCode -ne 0) { throw $result.Error }
        }

        $hookContract = $false
        if ($TestHook) {
            $hookText = & $script:NativeDirenv hook pwsh
            $hookContract = ($hookText -join "`n") -match "LocationChangedAction" -and
                ($hookText -join "`n") -match "export pwsh"
            if (-not $hookContract) {
                throw "Native PowerShell hook did not expose the expected location-change contract."
            }
        }

        $beforeWatch = $env:WSL_DEV_WATCH_BYTES
        $watchedFile = Join-Path $Fixture "flake.nix"
        Add-Content -LiteralPath $watchedFile -Value "`n"
        (Get-Item -LiteralPath $watchedFile).LastWriteTimeUtc =
            (Get-Date).ToUniversalTime().AddSeconds(2)
        $watchExport = Invoke-Direnv @("export", "pwsh") $errorFile
        if ($watchExport.ExitCode -ne 0) {
            throw "$Name watch-triggered export failed: $($watchExport.Error)"
        }
        $watchDetected = [bool]$watchExport.Output
        if ($watchDetected) {
            Invoke-Expression $watchExport.Output
            $watchDetected = $env:WSL_DEV_WATCH_BYTES -ne $beforeWatch
        }

        $reload = Invoke-Direnv @("reload") $errorFile
        if ($reload.ExitCode -ne 0) {
            throw "$Name reload failed: $($reload.Error)"
        }
        $reloadExport = Invoke-Direnv @("export", "pwsh") $errorFile
        if ($reloadExport.ExitCode -ne 0 -or -not $reloadExport.Output) {
            throw "$Name reload did not trigger an export."
        }
        Invoke-Expression $reloadExport.Output

        [System.IO.File]::AppendAllText(
            (Join-Path $Fixture ".envrc"),
            "`n# changed after allow`n")
        Remove-Item Env:DIRENV_DIFF, Env:DIRENV_FILE, Env:DIRENV_WATCHES -ErrorAction SilentlyContinue
        $blocked = Invoke-Direnv @("export", "json") $errorFile
        if ($blocked.ExitCode -eq 0 -or $blocked.Error -notmatch "blocked") {
            throw "$Name did not block the changed .envrc."
        }
        $allowAgain = Invoke-Direnv @("allow", ".") $errorFile
        if ($allowAgain.ExitCode -ne 0) {
            throw "$Name could not re-allow the changed .envrc."
        }

        Write-Proxy $ConfigDirectory -Fail
        Remove-Item Env:DIRENV_DIFF, Env:DIRENV_FILE, Env:DIRENV_WATCHES -ErrorAction SilentlyContinue
        $failure = Invoke-Direnv @("export", "json") $errorFile
        if ($failure.ExitCode -eq 0 -or $failure.Error -notmatch "proxy failure marker") {
            throw "$Name did not propagate evaluator exit/stderr (exit $($failure.ExitCode)): $($failure.Error)"
        }

        return [ordered]@{
            architecture = $Name
            cold_evaluation = $cold
            warm_hook = $warm
            hook_contract = $hookContract
            allow_reload = $true
            proxy_watch_forwarded = $watchDetected
            envrc_change_blocked = $true
            environment_fidelity = $true
            failure_exit_stderr = $true
            evaluator_project_path = $initialDiff.WSL_DEV_PROJECT
        }
    }
    finally {
        Pop-Location
        Reset-DirenvEnvironment
    }
}

function Measure-DirectWsl([string]$Fixture) {
    Reset-DirenvEnvironment
    $launcher = Join-Path $root "wsl-dev.ps1"
    $firstValues = for ($sample = 0; $sample -lt $Samples; $sample++) {
        $freshFixture = "$Fixture-$sample"
        Copy-Fixture $runtimeFixtureSource $freshFixture
        $wslFreshFixture = (& wsl.exe --distribution $Distribution --exec wslpath -a $freshFixture).Trim()
        & wsl.exe --distribution $Distribution --cd $wslFreshFixture --exec bash -lc "direnv allow ." | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "WSL direnv allow failed." }
        (Measure-Command {
            & pwsh -NoProfile -File $launcher exec -Distribution $Distribution `
                -ProjectDirectory $freshFixture bash -c 'test "$POC_DEV_SHELL" = wsl-direnv'
            if ($LASTEXITCODE -ne 0) { throw "First wsl-dev exec failed." }
        }).TotalMilliseconds
    }
    $first = Get-Statistics $firstValues

    $wslFixture = (& wsl.exe --distribution $Distribution --exec wslpath -a $Fixture).Trim()
    & wsl.exe --distribution $Distribution --cd $wslFixture --exec bash -lc "direnv allow ." | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "WSL direnv allow failed." }
    & pwsh -NoProfile -File $launcher exec -Distribution $Distribution `
        -ProjectDirectory $Fixture bash -c 'test "$POC_DEV_SHELL" = wsl-direnv'
    if ($LASTEXITCODE -ne 0) { throw "Could not prime the warm runtime fixture." }
    $warm = Measure-CommandSamples {
        & pwsh -NoProfile -File $launcher exec -Distribution $Distribution `
            -ProjectDirectory $Fixture bash -c 'test "$POC_DEV_SHELL" = wsl-direnv'
        if ($LASTEXITCODE -ne 0) { throw "Warm wsl-dev exec failed." }
    }

    $stderrFile = Join-Path $testRoot "runtime-stderr.log"
    & pwsh -NoProfile -File $launcher exec -Distribution $Distribution `
        -ProjectDirectory $Fixture bash -c 'echo runtime-stderr-marker >&2; exit 23' 2>$stderrFile
    $failureExit = $LASTEXITCODE
    if ($failureExit -ne 23 -or (Get-Content $stderrFile -Raw) -notmatch "runtime-stderr-marker") {
        throw "wsl-dev did not propagate runtime exit/stderr."
    }
    if ($env:Path -match "/nix/store") {
        throw "wsl-dev leaked a Nix store path into Windows PATH."
    }

    return [ordered]@{
        architecture = "D: direct wsl-dev exec"
        first_fresh_fixture = $first
        warm_exec = $warm
        failure_exit_stderr = $true
        descendant_runtime = $true
        runtime_project_path = $wslFixture
    }
}

$script:NativeDirenv = Find-NativeDirenv
if (-not (Test-Path $GitBashPath)) {
    throw "Git Bash was not found at $GitBashPath."
}

New-Item -ItemType Directory -Force -Path $testRoot, $adapterPublish, $gitAdapterPublish | Out-Null
dotnet publish (Join-Path $root "wsl-bash-adapter\WslBashAdapter.csproj") --nologo --output $adapterPublish | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Could not publish the WSL adapter." }
dotnet publish (Join-Path $root "git-bash-filter-adapter\GitBashFilterAdapter.csproj") --nologo --output $gitAdapterPublish | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Could not publish the Git Bash adapter." }

$aFixture = Join-Path $testRoot "fixture-a"
$bFixture = Join-Path $testRoot "fixture-b"
$dFixture = Join-Path $testRoot "fixture-d"
$aConfig = Join-Path $testRoot "config-a"
$bConfig = Join-Path $testRoot "config-b"
Copy-Fixture $fixtureSource $aFixture
Copy-Fixture $fixtureSource $bFixture
Copy-Fixture $runtimeFixtureSource $dFixture
New-Item -ItemType Directory -Force -Path $aConfig, $bConfig | Out-Null

$results = @()
$results += Measure-NativeArchitecture `
    "A: native direnv + Git Bash filter" `
    (Join-Path $gitAdapterPublish "GitBashFilterAdapter.exe") `
    $aFixture $aConfig -TestHook
$results += Measure-NativeArchitecture `
    "B: native direnv + WSL Bash adapter" `
    (Join-Path $adapterPublish "WslBashAdapter.exe") `
    $bFixture $bConfig -TestHook
$results += Measure-DirectWsl $dFixture

$negativeConfig = Join-Path $testRoot "config-negative"
New-Item -ItemType Directory -Force -Path $negativeConfig | Out-Null
@"
[global]
bash_path = "wsl.exe"
"@ | Set-Content -Encoding utf8 (Join-Path $negativeConfig "config.toml")
Write-Proxy $negativeConfig
Reset-DirenvEnvironment
$env:DIRENV_CONFIG = $negativeConfig
$env:XDG_CONFIG_HOME = Join-Path $negativeConfig "xdg-config"
$env:XDG_CACHE_HOME = Join-Path $negativeConfig "xdg-cache"
$env:XDG_DATA_HOME = Join-Path $negativeConfig "xdg-data"
Push-Location $bFixture
try {
    $null = Invoke-Direnv @("allow", ".") (Join-Path $negativeConfig "allow-error.log")
    $negative = Invoke-Direnv @("export", "json") (Join-Path $negativeConfig "export-error.log")
    if ($negative.ExitCode -eq 0) {
        throw "Direct bash_path=wsl.exe unexpectedly succeeded."
    }
}
finally {
    Pop-Location
    Reset-DirenvEnvironment
}

[pscustomobject]@{
    measured_at = (Get-Date).ToString("o")
    native_direnv = (& $script:NativeDirenv version)
    native_direnv_path = $script:NativeDirenv
    distribution = $Distribution
    git_bash = (& $GitBashPath --version | Select-Object -First 1)
    samples = $Samples
    direct_wsl_bash_path_negative_control = $true
    results = $results
} | ConvertTo-Json -Depth 8