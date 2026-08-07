# WSL direnv project shell PoC

This proof of concept tests a Windows-hosted project whose interactive shell and
complete development process tree run in a WSL Nix devShell.

## Proposed experience

From PowerShell in any Windows project containing an allowed `.envrc`:

```powershell
$env:WSL_DEV_DISTRO = "Ubuntu-24.04"
path\to\wsl-dev.ps1 shell
```

The resulting Bash session starts in the same project through `/mnt/c`, and the
normal WSL direnv hook activates the project devShell. Commands such as
`npm test`, `uv run pytest`, compilers, watchers, and their child processes run
inside WSL.

Windows editor tasks can use the non-interactive form:

```powershell
path\to\wsl-dev.ps1 exec -Distribution Ubuntu-24.04 npm test
```

## Automated check

```powershell
./poc/wsl-dev/test-poc.ps1
```

The fixture's Node test runner starts uv, which starts Python, which starts a
Bash grandchild. Every level checks the same devShell marker and Linux working
directory. The test copies the fixture to an isolated Windows temporary
directory so bare `use flake` is evaluated outside the repository's Git index.
It also confirms that the Windows `PATH` is not modified with Nix store paths.

## Native direnv evaluator adapter

The optional native control-plane experiment is separate from the runtime
launcher. Native direnv invokes the compiled
`wsl-bash-adapter/WslBashAdapter.csproj` through its normal `bash_path` and
`-c <script>` contract. The adapter evaluates the unchanged project contract
through WSL Bash:

```bash
use flake
```

An isolated WSL-visible global `use_flake` proxy emits only `WSL_DEV_*`
launcher metadata. The adapter reconstructs the original Win32 environment,
merges that allowlist, and rejects `/nix/store` in evaluator `PATH` or metadata.
It never makes Linux tools available to Win32; `shell` and `exec` remain the
only runtime entry points.

## Experimental user deployment

The deployment is experimental and currently pins the control plane to native
direnv 2.37.1. Preview the user-scoped changes, then install the adapter,
launcher, native configuration, PowerShell hook, and conditional WSL metadata
proxy:

```powershell
./poc/wsl-dev/deploy-user.ps1 -Distribution Ubuntu-24.04 -DryRun
./poc/wsl-dev/deploy-user.ps1 -Distribution Ubuntu-24.04
```

The adapter and launcher are installed below `$env:LOCALAPPDATA\wsl-dev`; no
global `PATH` change is made. The script records the original files and user
environment values in `$env:LOCALAPPDATA\wsl-dev\state\deployment.json` and
creates timestamped backups before changing existing files. It merges managed
blocks rather than replacing the PowerShell profile or WSL global `direnvrc`.
Repeated installation is idempotent: an adapter source fingerprint includes the
project inputs, .NET SDK version, and publish options, so an unchanged adapter
is not rebuilt or backed up again.

In a Windows-hosted project, keep `.envrc` portable and allow it independently
in native direnv:

```powershell
Get-Content -Raw .envrc # exactly: use flake
direnv allow .
direnv export pwsh | Invoke-Expression
& "$env:LOCALAPPDATA\wsl-dev\bin\wsl-dev.ps1" exec npm test
```

The PowerShell profile also installs the normal native `direnv hook pwsh`, so
changing location performs the metadata-only export automatically in a new
PowerShell session. The adapter sets an internal flag only for metadata
evaluation. The conditional proxy is therefore inactive when `wsl-dev` enters
the runtime, where the existing WSL nix-direnv `use_flake` remains authoritative.

Preview or perform exact rollback with:

```powershell
./poc/wsl-dev/deploy-user.ps1 -Action Rollback -DryRun
./poc/wsl-dev/deploy-user.ps1 -Action Rollback
```

Rollback restores the original PowerShell profile, native config files, WSL
`direnvrc`, and user environment values, then removes the installed adapter and
launcher. Timestamped backups and deployment state remain under
`$env:LOCALAPPDATA\wsl-dev` for audit and manual recovery.

Run the contract and negative-path test with:

```powershell
./poc/wsl-dev/test-wsl-bash-adapter.ps1
```

Run the installed native direnv architecture comparison with:

```powershell
$direnv = (Get-Command direnv.exe).Source
./poc/wsl-dev/measure-architectures.ps1 -DirenvPath $direnv -Samples 7
```

The benchmark copies fixtures to a temporary path containing spaces and tests
the Git Bash filter, WSL Bash adapter, and direct `wsl-dev exec` paths. It
records individual cold/warm wall-time samples and verifies allow/re-allow,
reload, `.envrc` blocking, path conversion, empty and Unicode values, variable
casing, stderr and exit codes, metadata filtering, and repeated invocation.
The adapters intentionally discard evaluator-side `DIRENV_WATCHES`, so a
proxy `watch_file flake.nix` does not trigger native reevaluation. Native
direnv still watches `.envrc`; WSL nix-direnv owns real flake watches at
runtime.

The test downloads native direnv 2.37.1 to an isolated temporary directory,
verifies its published SHA-256, publishes the adapter, and uses temporary XDG
and direnv configuration. It does not read or modify the repository root
`.envrc`.

This is not a production launcher. Editor language servers, test adapters,
debuggers, file watchers, TTY behavior, signal forwarding, and performance on
real projects need separate acceptance tests before ADR-0019 can be accepted.
The evaluator adapter additionally needs packaging, UNC-path support,
cancellation, native hook lifecycle tests, and compatibility checks for future
direnv versions.
