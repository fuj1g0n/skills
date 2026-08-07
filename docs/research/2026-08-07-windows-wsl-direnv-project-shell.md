---
type: Research
---

# Windows-hosted WSL direnv project shell

Date: 2026-08-07
Author: @fuj1g0n (with GitHub Copilot)
Status: working note

## Question

Can a project stored on the Windows filesystem provide the same Nix and direnv
experience as an ordinary WSL project? The complete interactive shell,
including builds, tests, package-manager subprocesses, and project-local
executables, must run in WSL. Access to selected commands is insufficient.

## Environment

* Windows build `10.0.26200.8893`.
* WSL `2.9.4.0`, Ubuntu 24.04, kernel
  `6.18.35.2-microsoft-standard-WSL2`.
* PowerShell `7.6.4`, .NET SDK `10.0.302`, and Git for Windows Bash
  `5.3.15(1)-release` (`x86_64-pc-cygwin`).
* Determinate Nix `2.34.7` and direnv `2.37.1` in WSL.
* `%USERPROFILE%/.wslconfig` sets `virtiofs=true`; `/mnt/c` is virtiofs.
* winget-installed native Windows direnv `2.37.1` at
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\direnv.direnv_Microsoft.Winget.Source_8wekyb3d8bbwe\direnv.exe`.

The winget package directory was present in both the current process and User
`PATH`, so this VS Code terminal did not need a refresh. A terminal that was
already running before winget updated User `PATH` may need to be reopened; the
binary can be invoked by its package path until then. `direnv status` worked
when explicit XDG directories were set and reported the WindowsApps
`bash.exe` (the WSL launcher) as the default `bash_path`. Without XDG variables
it failed with `couldn't find a configuration directory for direnv`.

Native `direnv hook` succeeded for `pwsh`, Bash, zsh, fish, tcsh, and Elvish on
this binary. `powershell`, `cmd`, and `nu` returned `unknown target shell`.

## 2026-08-07 installed-direnv measurements

### Method

`poc/wsl-dev/measure-architectures.ps1` used only copies under a uniquely named
Windows temporary directory containing spaces. The project `.envrc` remained
the ordinary one-line `use flake` contract. A temporary global `use_flake`
proxy watched `flake.nix` and emitted metadata containing an empty value,
spaces, a newline, shell metacharacters, and `日本語-✓`.

For A and B, each cold sample removed `DIRENV_DIFF`, `DIRENV_FILE`, and
`DIRENV_WATCHES` before `direnv export json`, forcing evaluator execution. Each
warm sample followed an applied `direnv export pwsh` and measured the no-change
hook path. These are process-warm measurements, not machine-reboot cold starts.
For D, a first sample used a fresh copied fixture whose Nix environment had not
yet been evaluated; warm samples reused one primed nix-direnv cache. Seven
wall-clock samples were taken with `Measure-Command`. No claims about CPU or
memory precision are made.

The PowerShell harness sets native-command encoding to BOM-less UTF-8. Before
that setting, PowerShell 7.6.4 mis-decoded otherwise valid UTF-8 JSON containing
the Unicode probe. Raw redirected bytes were valid UTF-8
(`E6-97-A5-E6-9C-AC-E8-AA-9E-2D-E2-9C-93`). Both compiled adapters now also
declare UTF-8 for child stdout/stderr and their JSON stdout.

### Latency results

| Option | Measurement | Individual samples (ms) | Median | Range |
|---|---|---|---:|---:|
| A. Git Bash filter | cold evaluator | 12936.0, 10147.8, 4447.2, 3143.5, 3703.4, 2598.5, 3428.7 | 3703.4 | 2598.5-12936.0 |
| A. Git Bash filter | warm no-change hook | 185.5, 198.2, 101.8, 211.5, 146.6, 177.5, 156.0 | 177.5 | 101.8-211.5 |
| B. WSL Bash adapter | cold evaluator | 5144.7, 9175.4, 3115.6, 6540.0, 3228.3, 2710.0, 2472.8 | 3228.3 | 2472.8-9175.4 |
| B. WSL Bash adapter | warm no-change hook | 508.8, 187.4, 369.7, 194.6, 218.3, 702.1, 514.3 | 369.7 | 187.4-702.1 |
| D. direct `wsl-dev exec` | first fresh fixture | 11640.2, 8378.1, 15105.2, 9553.5, 44468.5, 31431.6, 14489.3 | 14489.3 | 8378.1-44468.5 |
| D. direct `wsl-dev exec` | warm cached exec | 16103.4, 5063.0, 4725.7, 4677.2, 4591.5, 7567.6, 4427.9 | 4725.7 | 4427.9-16103.4 |

The large ranges are real observations on a non-isolated development machine.
They support only order-of-magnitude and workflow comparisons. A/B warm
results measure native hook checks; D warm results enter the real Nix devShell
and execute a command, so the rows do not represent equivalent work.

### Behavior results

| Behavior | A. Git Bash filter | B. WSL Bash adapter | C. Alternative interpreter | D. direct `wsl-dev` |
|---|---|---|---|---|
| Ordinary `use flake` project contract | Pass through global proxy | Pass through global proxy | Not executable on this machine | Pass through WSL nix-direnv |
| Native allow and changed-`.envrc` block/re-allow | Pass | Pass | Not tested | WSL allow passes |
| Native reload | Pass | Pass | Not tested | Not applicable |
| Proxy `watch_file flake.nix` reaches native hook | **Fail** | **Fail** | Not tested | WSL nix-direnv owns real watches |
| Windows path containing spaces | Pass; MSYS path form | Pass; `/mnt/c/...` form | Not tested | Pass; `/mnt/c/...` form |
| Empty, mixed-case, multiline, special, Unicode values | Pass after explicit UTF-8 handling | Pass after explicit UTF-8 handling | Not tested | Runtime environment, not exported to Win32 |
| Exit code and stderr | Pass; proxy exit 23 and marker propagated | Pass; proxy exit 23 and marker propagated | Not tested | Pass; runtime exit 23 and marker propagated |
| Repeated invocation | Pass | Pass | Not tested | Pass |
| `/nix/store` or Linux `PATH` enters Win32 | No | No; negative test fails closed | Not tested | No |
| Only intended metadata crosses evaluator boundary | `WSL_DEV_*` plus native `DIRENV_*` state | `WSL_DEV_*` plus native `DIRENV_*` state | Not tested | No environment import |
| Guarantees complete dev descendants in WSL | No; control plane only | No; control plane only | No executable evidence | Yes, when commands enter through `shell/exec` |

The proxy watch failure is caused by the filtering boundary: evaluator-side
`DIRENV_WATCHES` is intentionally not allowlisted. Native direnv still watches
the project `.envrc`, blocks it after a content change, and supports reload.
This is acceptable only while Windows metadata is static; real flake watches
and cache invalidation remain WSL nix-direnv's responsibility.

The A and B failure fixture printed `proxy failure marker` and native direnv
reported `exit status 23`. Setting `bash_path = "wsl.exe"` directly failed as
the negative control with `direnv: error exit status 0xffffffff`, confirming
that the WSL launcher is not itself a Bash evaluator adapter.

No suitable C candidate was installed: `nu`, `xonsh`, BusyBox, Cygwin command
entry points, dash, and fish were absent from Windows `PATH`. The only default
Windows `bash.exe` was the WSL launcher, covered by the failed negative control.
Git Bash is executable but is Option A, not an embedded interpreter. Installing
a heavyweight shell runtime solely for this matrix was intentionally avoided.
Even if installed, a candidate would need compatibility with direnv's Bash
functions, arrays, traps, process substitution, and recursive direnv calls.

### Process and resource shape

A cold evaluation starts native direnv, the compiled filter, and Git Bash. B
starts native direnv, the compiled adapter, `wsl.exe`, and WSL Bash. D performs
a WSL path conversion and then starts `wsl.exe`, the WSL `/init` relay, and the
runtime Bash. A runtime snapshot reported Bash in `/mnt/c/...` with
`POC_DEV_SHELL=wsl-direnv` and `/init` as its relay parent. The focused runtime
test provides the stronger descendant check: npm -> Node -> uv -> Python ->
Bash all observed the same marker and WSL cwd. A/B only decide metadata; neither
can constrain later Win32 commands. Complete descendant containment therefore
depends on entering through D's `wsl-dev shell/exec` runtime boundary.

### Reproduction

```powershell
$direnv = (Get-Command direnv.exe).Source
direnv version
direnv status
./poc/wsl-dev/measure-architectures.ps1 -DirenvPath $direnv -Samples 7
./poc/wsl-dev/test-wsl-bash-adapter.ps1
./poc/wsl-dev/test-poc.ps1
```

The scripts use isolated temporary fixtures and do not read or modify the
repository root `.envrc`.

### Pros and cons under the fixed constraints

| Option | Pros | Cons | Result |
|---|---|---|---|
| A. Git Bash/MSYS filter | Fastest measured warm no-change median; directly accepts `-c`; can reconstruct Win32 state and allowlist metadata | Cold median 3.70 s with wide variance; MSYS changes paths and environment representation before filtering; adds a Bash unlike runtime WSL; does not contain descendants; proxy watches do not cross | Executable, but not recommended |
| B. WSL Bash adapter | Meets native-direnv interface; preserves ordinary `use flake`; evaluates with runtime Bash family; emits only metadata; rejects Nix paths; translates spaced paths correctly | Cold median 3.23 s and warm median 0.37 s; version-sensitive generated-script translation; extra WSL process; separate allow state; proxy watches do not cross; adapter alone does not contain descendants | Recommended Windows control plane |
| C. Embedded/alternative Bash | Could avoid WSL startup if a fully compatible implementation existed | No installed suitable candidate; direct WSL launcher fails; Bash compatibility and security surface is large; no execution evidence | Blocked/rejected |
| D. direct `wsl-dev shell/exec` | Simplest runtime; real nix-direnv watches/cache; no environment import; measured complete WSL descendant tree; preserves Linux artifacts and semantics | Violates native-direnv-as-interface if used alone; first median 14.49 s and warm command median 4.73 s in this fixture; NTFS/virtiofs overhead remains | Required runtime, fallback control plane |

The evidence supports B plus D: native Windows direnv remains a metadata-only
interface through B, while every development command enters D. The project
keeps ordinary `use flake`, Win32 receives neither `/nix/store` nor Linux
executable paths, and the complete development process tree stays in WSL.

## Findings

### Exporting a Nix environment to Windows is not viable

Nix officially supports Linux and macOS, not Windows. A WSL devShell contains
Linux executables under `/nix/store`. Path conversion does not change their
executable format, loader, signals, permissions, or process semantics.

Native Windows direnv can return an environment-variable diff, but it cannot
turn that diff into a Linux process environment. `WSLENV` can translate
selected path values across the boundary; it cannot make Linux executables
runnable by Win32. Aliases and shell functions are not exported by direnv.

The following model is therefore invalid:

1. Windows direnv invokes Nix in WSL.
2. It imports the devShell environment into PowerShell.
3. PowerShell directly executes tools from the imported Linux `PATH`.

### Native Windows direnv is not a transparent front end

The official Windows binary supports `direnv hook pwsh`, but this machine
exposed three additional integration constraints:

* Native direnv could not infer an XDG cache directory until
  `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` were set explicitly.
* The `bash` found on the default Windows `PATH` was the WSL launcher. It could
  not execute the Windows `direnv.exe` path used internally to evaluate an
  `.envrc`.
* Setting `DIRENV_BASH` to Git for Windows Bash allowed evaluation to start,
  but the shared `use flake path:.` failed because native Windows has no Nix.
  Evaluation also produced a large Git Bash-to-PowerShell environment diff,
  including replacement of the Windows `PATH`.

Native direnv can therefore be used only for Windows-safe metadata, such as a
WSL distribution name or launcher state. It must not import the devShell or
alter `PATH` with Linux values. A metadata-only Git Bash fixture exported
`WSL_DEV_ENABLED` and `WSL_DEV_DISTRO`, but Git Bash also removed PowerShell's
`Path`, replaced it with its own `PATH`, and changed case-variant system
variables. Filtering after an MSYS evaluation is possible, but it starts from
an environment representation that is already different from Win32.

Source inspection of direnv 2.37.1 narrowed the evaluator contract. `RC.Load`
invokes the configured `bash_path` as exactly `-c <generated-script>`, sets the
project as the child working directory, and expects a complete environment JSON
object on stdout. The generated script embeds the native direnv executable and
`.envrc` paths. The stdlib then invokes direnv recursively for `stdlib`, `watch`,
logging, and the final `dump json`. Consequently, `bash_path=wsl.exe` alone
cannot work: `wsl.exe` does not interpret `-c`, Windows paths are not WSL paths,
and the returned environment is Linux-shaped.

### A WSL Bash evaluator adapter is feasible

The repository PoC adds a small compiled adapter between native direnv and
`wsl.exe`. It performs four bounded operations:

1. Accept only direnv's `-c <script>` evaluator contract.
2. Replace the generated native `direnv.exe stdlib` call with WSL direnv,
  translate the drive-rooted working directory and generated project path, and
  stream the script to login-initialized WSL Bash with LF line endings.
3. Parse the complete WSL environment JSON, reject `/nix/store` in evaluator
  `PATH` or allowed metadata, and discard every WSL-side key except
  `WSL_DEV_*`.
4. Reconstruct stdout from the original Win32 environment block plus the
  allowed metadata. This preserves key casing, `Path`, empty values, and the
  hidden drive-current-directory entry that native direnv represents as an
  empty environment key. Native direnv then adds its own Windows `DIRENV_*`
  state.

An isolated fixture kept `.envrc` exactly ordinary:

```bash
use flake
```

Its WSL-visible global `use_flake` proxy returned launcher metadata without
calling Nix. Native direnv 2.37.1 was downloaded from the official release and
matched the published Windows amd64 SHA-256
`d96fc8b7cf020c2d4c1dbbc2ccec5fd1cab05b51c491f02c8527a7fa6c50a1cd`.
The native export diff contained only `WSL_DEV_*` metadata and native
`DIRENV_*` state. It did not contain `Path`, `PATH`, an unrelated mixed-case
probe, or `/nix/store`; an intentionally empty `WSL_DEV_EMPTY` survived. A
negative proxy added `/nix/store/forbidden/bin` to evaluator `PATH`, and the
adapter failed closed.

This experiment also found two serialization details that a Git Bash-only
test did not expose. C#-generated CRLF input appends carriage returns to Bash
`export` values, so the adapter must normalize the streamed script to LF. Also,
.NET's ordinary environment enumeration omits Windows' hidden `=C:` state while
Go's environment parser retains it as an empty key; the adapter must read the
Win32 environment block directly to avoid a spurious deletion on every hook.

### A global `use_flake` override keeps projects portable

The project does not need to detect Windows, WSL, or ordinary Linux. Direnv
loads its standard library and global configuration before loading the project
`.envrc`, and `use flake` dispatches to the currently defined `use_flake`
function. This permits each host to supply the appropriate implementation:

* Ordinary Linux and WSL load nix-direnv globally and evaluate the real Nix
  devShell.
* Native Windows configures a compiled WSL evaluator adapter. The adapter uses
  an isolated WSL-visible global proxy `use_flake` implementation that exports
  only `WSL_DEV_*` launcher metadata, then reconstructs the original Win32
  environment and rejects Linux Nix paths.

With a temporary Windows global library, this project file worked unchanged:

```bash
use flake
```

The proxy sets `WSL_DEV_ENABLED=1` and launcher metadata only. It does not need
to watch flake inputs because their contents cannot change the static Windows
metadata; normal WSL nix-direnv owns flake watches and cache invalidation for
the runtime. When `wsl-dev` enters Linux, Linux direnv evaluates the same
`.envrc` again and nix-direnv supplies the real `use_flake`. No WSL-specific
condition is needed in the repository.

### The complete project shell is the correct boundary

Microsoft supports launching WSL from PowerShell with the current Windows
directory translated to `/mnt/<drive>`. On this machine, a warm WSL invocation
took approximately 166-204 ms. Nix was absent from a non-login `wsl.exe nix`
invocation but available through the configured login shell.

The proposed boundary is:

```text
Windows Terminal / PowerShell / VS Code
        |
        | enter project shell
        v
      wsl.exe
        |
        | translated project directory
        v
WSL interactive shell + direnv + nix-direnv + Nix devShell
        |
        +-- npm / uv / compiler / test runner / task runner
        |      |
        |      +-- every child process remains in WSL
        |
        +-- project files on /mnt/c through virtiofs
```

The primary interface is `wsl-dev shell`: enter interactive WSL Bash at the
translated Windows project directory and let the normal WSL direnv hook load
the allowed `.envrc`. A secondary `wsl-dev exec` operation runs editor tasks
and automation through `direnv exec` without returning descendants to Windows.

### Mixed process trees fail on common project artifacts

Two local experiments demonstrate why wrapping only `npm` or `uv` is not
enough:

* WSL Nix Node.js successfully installed and ran TypeScript in a project under
  Windows `%TEMP%`. npm created `node_modules/.bin/tsc` as a Linux symbolic
  link. It worked in WSL but Windows could not read it.
* WSL Nix uv successfully created a Python 3.13.14 `.venv` under Windows
  `%TEMP%`. `.venv/bin/python` linked to a Linux Nix store path. It worked in
  WSL but Windows could not read it.

In the proposed model these are Linux project artifacts. npm scripts, uv,
builds, tests, language services, debuggers, and nested subprocesses that
consume them must execute through WSL.

### virtiofs helps but does not equal ext4

A metadata-heavy microbenchmark created 3,000 one-byte files and ran one
`stat` process per file:

| Location | Filesystem | Elapsed |
|---|---|---:|
| WSL `/tmp` | ext4 | 3.81 s |
| Windows `%TEMP%` through `/mnt/c` | virtiofs | 15.24 s |

This synthetic result is not a general filesystem benchmark. It establishes
that virtiofs is active but that real acceptance tests must measure dependency
installation, builds, tests, and watchers on representative projects. Nix
store and global Linux caches should remain on WSL ext4.

### PoC result

The repository-local [`poc/wsl-dev`](../../poc/wsl-dev/README.md) implements:

* `shell`: translated Windows cwd, interactive WSL Bash, normal direnv hook.
* `exec`: non-interactive commands through `direnv exec`.

The automated fixture ran this process tree from an NTFS checkout:

```text
PowerShell launcher
  -> WSL direnv + Nix devShell
     -> npm
        -> Node test runner
           -> uv
              -> Python
                 -> Bash grandchild
```

Every process observed `POC_DEV_SHELL=wsl-direnv` and a `/mnt/c/...` working
directory. Interactive mode resolved Node.js 24.18.1 and uv 0.12.1 from
`/nix/store`. A repeated PowerShell-to-test run reused the nix-direnv cache and
completed in approximately 3.0 seconds.

The PoC validates the process boundary, not production readiness. Real-project
watch mode, Ctrl+C and terminal resize forwarding, VS Code tasks, language
servers, debuggers, and comparative ext4/virtiofs performance remain open.

The evaluator adapter validates the native control-plane contract, not a
production installation. It currently accepts drive-rooted paths only, rewrites
the direnv 2.37.1 generated script shape, starts a login Bash for tool discovery,
and has not been tested with UNC paths, cancellation, native hook lifecycle,
multiple distributions, or future direnv releases. Native and WSL direnv each
retain an independent allow decision. Allowing a project in native direnv also
authorizes its `.envrc` to execute in WSL during metadata evaluation; filtering
the returned environment does not remove that code-execution boundary.

### Experimental user-scoped deployment

The prototype was installed for one Windows user under `LOCALAPPDATA`, without
adding a directory to `PATH`. Native direnv 2.37.1 used the installed adapter as
its configured `bash_path`; explicit user-scoped XDG directories resolved the
Windows config-dir limitation. The normal PowerShell location hook loaded in a
new PowerShell 7 process.

The Windows-side global `direnvrc` is evaluated by WSL Bash and sources the
actual Ubuntu user's global `direnvrc`. That file retains its existing
nix-direnv source and adds a conditional metadata proxy. The adapter sets
`DIRENV_WSL_DEV_METADATA_ONLY=1` only in its evaluator process, so direct WSL
runtime evaluation does not replace nix-direnv's real `use_flake`.

An allowed Windows temporary fixture whose path contained spaces kept `.envrc`
exactly `use flake`. Hook and explicit exports preserved empty and Unicode
metadata, returned only `WSL_DEV_*` plus native `DIRENV_*`, repeated cleanly,
and retained native `.envrc` reload ownership without forwarding proxy flake
watches. Neither the export nor the parent Windows `PATH` contained
`/nix/store`. The installed launcher then ran the existing npm, Node, uv,
Python, and Bash descendant fixture entirely in WSL while resolving runtime
Node.js from the Nix store.

The deployment script is idempotent, supports dry-run and rollback, merges
managed blocks, and records initial state plus timestamped backups. This closes
the local installation gap only; it does not resolve the production-readiness
limitations above.

## Options

### WSL interactive project shell

Recommended. It reuses the existing WSL store and nix-direnv cache, preserves
the complete Linux process tree, and requires no container.

### WSL Bash evaluator adapter

Recommended control plane under the fixed native-direnv requirement. It uses
WSL's Bash semantics, avoids MSYS mutation, and can fail closed while returning
only `WSL_DEV_*`. It remains launcher configuration rather than devShell
activation; the complete runtime still begins at `wsl-dev shell/exec`.

### Git Bash filtering bridge

Technically feasible, but not recommended. It directly satisfies `-c`, yet
MSYS changes `Path`/`PATH`, casing, and path values before filtering and adds a
second Bash distribution that does not own the runtime. Correctness requires
reconstructing the Win32 environment anyway, eliminating its apparent
simplicity advantage over the WSL adapter.

### Embedded interpreter

Rejected. An embedded shell could avoid WSL startup for metadata, but direnv's
stdlib uses Bash-specific functions, arrays, traps, process substitution, and
recursive direnv commands. A partial interpreter would create a broad and
security-sensitive compatibility surface for a deliberately small bridge.

### Bypass native direnv

Best simplification if the visible-control-plane requirement is relaxed:
invoke `wsl-dev shell/exec` directly and let only WSL direnv evaluate `.envrc`.
It is not selected here because native direnv is a fixed interface requirement,
not because the runtime needs it.

### Native Windows direnv environment import

Rejected as the runtime. It exports unusable Linux executable paths and cannot
represent the process boundary. The selected native hook is metadata-only.
Host-specific behavior belongs in global direnv configuration, not in the
project `.envrc`.

### wslc container delegation

Useful when the user or agent shell must remain on Windows or container
isolation is required. The earlier investigation measured warm per-command
execution at 0.23-0.39 s, but it requires a second Nix installation, container
lifecycle, and preview wslc infrastructure. See the
[2026-07-29 snapshot](2026-07-29-windows-wslc-devshell-delegation.md).

### VS Code Remote - WSL or Dev Containers

Both provide coherent Linux editor services. They remain optional integration
and isolation modes rather than prerequisites for Windows Terminal usage.

## Sources

* [Nix supported platforms](https://nix.dev/manual/nix/latest/installation/supported-platforms)
* [direnv manual](https://direnv.net/man/direnv.1.html)
* [direnv standard library](https://direnv.net/man/direnv-stdlib.1.html)
* [direnv 2.37.1 evaluator implementation](https://github.com/direnv/direnv/blob/v2.37.1/internal/cmd/rc.go)
* [direnv 2.37.1 stdlib](https://github.com/direnv/direnv/blob/v2.37.1/stdlib.sh)
* [direnv 2.37.1 release](https://github.com/direnv/direnv/releases/tag/v2.37.1)
* [direnv Windows PATH issue](https://github.com/direnv/direnv/issues/253)
* [direnv Windows XDG directory issue](https://github.com/direnv/direnv/issues/442)
* [Microsoft WSL filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
* [Microsoft WSL interoperability](https://learn.microsoft.com/en-us/windows/wsl/interop)
* [Microsoft WSL configuration](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
* [WSL 2.9.4 release](https://github.com/microsoft/WSL/releases/tag/2.9.4)
