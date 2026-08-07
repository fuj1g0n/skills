param(
    [string]$Distribution = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"
$expectedDirenvHash = "d96fc8b7cf020c2d4c1dbbc2ccec5fd1cab05b51c491f02c8527a7fa6c50a1cd"
$root = $PSScriptRoot
$adapterProject = Join-Path $root "wsl-bash-adapter\WslBashAdapter.csproj"
$fixture = Join-Path $root "evaluator-fixture"
$testRoot = Join-Path $env:TEMP "wsl-bash-adapter-$([guid]::NewGuid().ToString('N'))"
$publishDirectory = Join-Path $testRoot "adapter"
$configDirectory = Join-Path $testRoot "config"
$direnv = Join-Path $testRoot "direnv.exe"
$errorLog = Join-Path $testRoot "adapter-error.log"

New-Item -ItemType Directory -Force -Path $publishDirectory, $configDirectory | Out-Null

dotnet publish $adapterProject --nologo --output $publishDirectory | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Could not publish the WSL Bash adapter."
}

Invoke-WebRequest `
    "https://github.com/direnv/direnv/releases/download/v2.37.1/direnv.windows-amd64" `
    -OutFile $direnv
$actualDirenvHash = (Get-FileHash -Algorithm SHA256 $direnv).Hash.ToLowerInvariant()
if ($actualDirenvHash -ne $expectedDirenvHash) {
    throw "The downloaded direnv binary did not match the published SHA-256."
}

$direnvrc = (Get-Content (Join-Path $fixture "direnvrc") -Raw).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText((Join-Path $configDirectory "direnvrc"), $direnvrc)
$adapter = (Join-Path $publishDirectory "WslBashAdapter.exe").Replace("\", "/")
@"
[global]
bash_path = "$adapter"
"@ | Set-Content -Encoding utf8 (Join-Path $configDirectory "config.toml")

$env:DIRENV_CONFIG = $configDirectory
$env:XDG_CONFIG_HOME = Join-Path $testRoot "xdg-config"
$env:XDG_CACHE_HOME = Join-Path $testRoot "xdg-cache"
$env:XDG_DATA_HOME = Join-Path $testRoot "xdg-data"
$env:WSL_DEV_DISTRO = $Distribution
$env:AdapterCaseProbe = "PreserveMe"
$windowsPath = $env:Path

Push-Location $fixture
try {
    & $direnv allow .
    if ($LASTEXITCODE -ne 0) {
        throw "Native direnv could not allow the isolated fixture."
    }

    $json = & $direnv export json 2>$errorLog
    if ($LASTEXITCODE -ne 0) {
        Get-Content $errorLog | Out-Host
        throw "Native direnv could not evaluate the fixture through WSL."
    }

    $diff = $json | ConvertFrom-Json
    if ($diff.WSL_DEV_ENABLED -ne "1" -or
        $diff.WSL_DEV_EMPTY -ne "" -or
        $env:WSL_DEV_DISTRO -ne $Distribution) {
        throw "The expected WSL_DEV metadata or empty value was not emitted."
    }

    $unexpected = @($diff.PSObject.Properties.Name | Where-Object {
        $_ -notlike "DIRENV_*" -and $_ -notlike "WSL_DEV_*"
    })
    if ($unexpected.Count -ne 0) {
        throw "The adapter emitted non-allowlisted changes: $($unexpected -join ', ')"
    }

    if ($json -match "/nix/store" -or
        $diff.PSObject.Properties.Name -ccontains "PATH" -or
        $diff.PSObject.Properties.Name -ccontains "Path" -or
        $diff.PSObject.Properties.Name -ccontains "AdapterCaseProbe" -or
        $env:Path -cne $windowsPath) {
        throw "The adapter changed Windows PATH/casing or emitted a Nix store path."
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $configDirectory "direnvrc"),
        "$direnvrc`nexport PATH=`"/nix/store/forbidden/bin:`$PATH`"`n")
    $null = & $direnv export json 2>$errorLog
    if ($LASTEXITCODE -eq 0) {
        throw "The adapter accepted an evaluator PATH containing /nix/store."
    }
    if ((Get-Content $errorLog -Raw) -notmatch "Refusing a WSL evaluator result") {
        Get-Content $errorLog | Out-Host
        throw "The adapter failed without the expected PATH safety diagnostic."
    }
}
finally {
    Pop-Location
}

$global:LASTEXITCODE = 0
Write-Output "Adapter PoC passed: native direnv emitted only WSL_DEV metadata and rejected Linux PATH."