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
* Determinate Nix `2.34.7` and direnv `2.37.1` in WSL.
* `%USERPROFILE%/.wslconfig` sets `virtiofs=true`; `/mnt/c` is virtiofs.
* No native Windows direnv was installed permanently. The official direnv
  `2.37.1` Windows binary was downloaded to a temporary directory and verified
  against its published SHA-256 digest for the native integration experiment.

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
