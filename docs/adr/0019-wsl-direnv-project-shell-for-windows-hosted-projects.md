---
type: Architecture Decision Record
status: proposed
date: 2026-08-07
decision-makers: "@fuj1g0n (with GitHub Copilot)"
---

# Use a WSL direnv project shell for Windows-hosted projects

## Context and Problem Statement

Development projects are stored on the Windows filesystem and opened by
Windows applications, while this repository's development skills assume Nix
devShells on Linux. The desired experience is not access to selected commands:
from a Windows project directory, the user must enter an ordinary interactive
WSL direnv/Nix shell in which dependency installation, builds, tests, watchers,
project scripts, and every child process run normally.

How should Windows-hosted projects obtain this complete Nix-centric development
environment without requiring a Dev Container?

## Decision Drivers

* Preserve the `nix-for-dev` model: one project devShell defines the complete
  environment, including environment variables, shell hooks, and toolchains.
* Provide an interactive project shell, not wrappers for selected tools.
* Keep package-manager scripts, builds, tests, and all descendants in one Linux
  process environment.
* Keep the project tree on NTFS so Windows applications see changes directly.
* Reuse the existing WSL Nix store, direnv, and nix-direnv cache.
* Avoid making Dev Containers or preview container technology mandatory.
* Make the Windows/Linux process and filesystem boundary explicit.
* Keep each project's `.envrc` portable across ordinary Linux, WSL, and
  Windows entry points without repository-level OS detection.

## Considered Options

* Enter a WSL direnv project shell through a Windows-native launcher
* Use native direnv with a WSL Bash evaluator adapter and filtered metadata
* Use native direnv with a Git Bash filtering bridge
* Embed a Bash-compatible interpreter in a native evaluator
* Bypass native direnv and launch WSL directly
* Delegate each command to a wslc container
* Require VS Code Remote - WSL
* Require the existing Nix Dev Container
* Maintain a separate native Windows toolchain

## Decision Outcome

Proposed option: "Enter a WSL direnv project shell through a Windows-native
launcher", because Nix devShell paths, npm local executables, Python virtual
environments, and build outputs contain Linux executables and symbolic links.
The interactive shell and every process it starts must therefore remain in
WSL, while the project files remain available at their `/mnt/c` path.

The proposed interface has two operations:

* `wsl-dev shell` translates the current Windows directory and enters an
  interactive WSL Bash session. The existing WSL direnv hook activates the
  project's allowed `.envrc` and cached Nix devShell.
* `wsl-dev exec -- <command> ...` runs one non-interactive task through
  `direnv exec` for Windows editor tasks and automation. All descendants remain
  in WSL.

The project `.envrc` remains OS-independent:

```bash
use flake
```

Host-global direnv configuration supplies the implementation. Ordinary Linux
and WSL load nix-direnv normally, so `use flake` evaluates and caches the Nix
devShell. Native Windows loads a global proxy `use_flake` that marks the
project as WSL-backed and configures the Windows-native launcher. A compiled
evaluator adapter satisfies native direnv's `bash_path` contract by accepting
`-c <script>`, translating only the generated evaluator's working-directory
and project paths, and streaming the script to WSL Bash. The WSL-visible global
proxy does not evaluate Nix. The same `.envrc` is evaluated again after
`wsl-dev` crosses the process boundary, at which point the normal WSL global
configuration loads nix-direnv and performs the real activation.

Native Windows direnv is therefore a control plane, not the runtime. It must
not export `/nix/store`, `node_modules/.bin`, or `.venv/bin` as a Windows
executable `PATH`; path conversion cannot make Linux executables runnable by
Win32. The adapter reconstructs the result from the original Win32 environment
block and merges only `WSL_DEV_*` values from WSL. This preserves `Path`,
variable casing, empty values, and Windows' hidden drive-current-directory
state while native direnv itself owns its `DIRENV_*` state. It rejects any WSL
result whose `PATH` or allowed metadata contains `/nix/store`.

This WSL evaluator adapter is selected over a Git Bash filtering bridge. Git
Bash can satisfy `-c`, but MSYS mutates `PATH` and environment-variable casing
before the result can be filtered and introduces a second Bash distribution.
An embedded interpreter would avoid that dependency, but direnv's stdlib is
Bash-specific and invokes the direnv executable recursively; reproducing those
semantics is a compatibility project rather than a bridge. Bypassing native
direnv is simpler and remains a sound fallback, but it does not meet the fixed
requirement that native direnv remain the visible Windows control plane.

The earlier draft of this ADR selected a per-project wslc container because it
assumed both GitHub Copilot CLI and the interactive user shell had to remain on
Windows and Linux artifacts had to stay out of the NTFS tree. Those are not
requirements of the clarified interactive-development goal. wslc remains an
option when additional container isolation or Windows-shell-only operation is
required, but its second Nix installation, lifecycle management, preview API,
and per-command wrapper are unnecessary for the default workflow.

### Consequences

* Good, because projects receive the same interactive direnv/Nix model used by
  ordinary WSL-hosted projects.
* Good, because npm, uv, compilers, tests, and nested subprocesses inherit one
  Linux devShell naturally.
* Good, because one existing WSL Nix store and nix-direnv cache serve all
  projects.
* Good, because projects use the conventional `use flake` entry on ordinary
  Linux and WSL without WSL-specific branches.
* Good, because native Windows receives only launcher metadata and retains its
  original executable search path and environment representation.
* Good, because Dev Containers remain available for isolation without becoming
  mandatory for routine development.
* Bad, because dependency trees and build outputs on NTFS retain virtiofs
  metadata overhead.
* Bad, because Linux symbolic links in `node_modules`, `.venv`, and build output
  may be unreadable by Windows tools.
* Bad, because Windows-native language servers, test adapters, and debuggers
  cannot consume Linux-only artifacts; those integrations must execute through
  WSL or attach to it.
* Bad, because cross-filesystem file-watch event behavior must be verified for
  each workflow; polling or WSL-side editing may be required.
* Bad, because the launcher must preserve TTY, signals, terminal resize,
  standard streams, exit codes, argv, and working-directory semantics.
* Bad, because Windows needs a version-sensitive evaluator adapter and separate
  native and WSL direnv authorization.
* Bad, because the adapter PoC currently supports drive-rooted Windows paths,
  not UNC paths, and depends on the direnv 2.37.1 evaluator-script shape.
* Bad, because entering a directory may execute its allowed `.envrc` in WSL;
  the native allow decision is a real code-execution trust boundary even though
  only metadata returns to Windows.

### Confirmation

The repository-local `poc/wsl-dev` validates the core execution model:

* Interactive mode entered the Windows project through `/mnt/c`, and the normal
  WSL direnv hook activated the Nix devShell.
* Non-interactive mode ran npm, the Node test runner, uv, Python, and a Bash
  grandchild; every level inherited the same devShell marker and Linux working
  directory.
* Node.js and uv resolved from `/nix/store`, while the parent Windows `PATH`
  remained unchanged.
* A repeated automated run reused the nix-direnv cache and completed in
  approximately 3.0 seconds on the measured machine.
* A separate native experiment kept the project `.envrc` at `use flake` and
  supplied a proxy `use_flake` through an isolated WSL-visible global direnv
  configuration.
* Native direnv 2.37.1 successfully invoked the compiled adapter with its real
  `-c <script>` evaluator contract. The resulting native diff contained only
  `WSL_DEV_*` metadata and native `DIRENV_*` state; `Path`, casing, an unrelated
  mixed-case variable, an empty metadata value, and hidden Windows drive state
  were preserved.
* A negative fixture injected `/nix/store/forbidden/bin` into the WSL evaluator
  `PATH`; the adapter failed closed and native direnv emitted no Linux path.

Keep this ADR proposed until these remaining checks pass:

* Verify dependency installation, build, test, and watch mode in representative
  real Node.js and Python projects.
* Verify path arguments, standard streams, non-zero exits, Ctrl+C, and terminal
  resize behavior.
* Compare cold and warm workflow latency on NTFS/virtiofs and WSL ext4.
* Verify Windows VS Code tasks and establish the supported model for language
  servers, test adapters, and debuggers.
* Package and harden the WSL evaluator adapter and global `use_flake` proxy,
  including UNC paths, cancellation, timeout, diagnostics, and upgrades across
  supported direnv versions.
* Verify the native PowerShell hook and launcher metadata in a persistent user
  configuration without changing project `.envrc` files.

## Pros and Cons of the Options

### Enter a WSL direnv project shell

* Good, because it uses Microsoft's supported Windows-to-WSL process model.
* Good, because it reuses existing WSL Nix and nix-direnv state.
* Good, because nested processes inherit the devShell without wrappers.
* Bad, because Linux project artifacts are present in the NTFS tree.

### Native direnv with a WSL Bash evaluator adapter

* Good, because it keeps native direnv as the visible control plane while using
  the same Bash implementation family as the WSL runtime.
* Good, because a fail-closed native adapter can preserve Win32 environment
  semantics and merge only explicit metadata.
* Bad, because it translates a version-specific generated evaluator script and
  runs a WSL process on native direnv evaluation.

### Native direnv with a Git Bash filtering bridge

* Good, because Git Bash directly accepts direnv's `-c` contract.
* Bad, because MSYS rewrites `Path`/`PATH`, casing, and path values before the
  bridge can decide what to retain.
* Bad, because it adds a second Bash environment that differs from WSL runtime.

### Embedded Bash-compatible interpreter

* Good, because it could avoid an external Bash installation and WSL startup.
* Bad, because direnv's stdlib relies on Bash behavior, subprocesses, traps,
  and recursive direnv commands that partial shell interpreters need not match.
* Bad, because compatibility and security maintenance exceed the bridge's
  metadata-only purpose.

### Bypass native direnv

* Good, because `wsl-dev shell/exec` already provides the correct runtime with
  the fewest control-plane components.
* Bad, because it fails the requirement that native direnv provide visible
  directory state and launcher metadata on Windows.

### Delegate each command to a wslc container

* Good, because Linux artifacts and the container Nix store can be isolated.
* Good, because it supports a user or agent shell that must remain on Windows.
* Bad, because wslc is preview technology with additional provisioning and
  lifecycle infrastructure.
* Bad, because a command wrapper is a weaker interactive experience than a
  long-lived project shell.

### Require VS Code Remote - WSL

* Good, because editor services and development processes remain on Linux.
* Bad, because it makes one editor attachment model mandatory and does not
  provide a general Windows Terminal entry point.

### Require the existing Nix Dev Container

* Good, because it provides reproducibility and isolation established by
  ADR-0010 through ADR-0015.
* Bad, because container creation and attachment are unnecessary when the
  existing WSL environment is sufficient.

### Maintain a separate native Windows toolchain

* Good, because tools and artifacts are native Windows processes and paths.
* Bad, because package definitions, versions, and caches diverge from Nix.

## More Information

New research and PoC:
[2026-08-07 Windows-hosted WSL direnv project shell](../research/2026-08-07-windows-wsl-direnv-project-shell.md).

The superseded draft's constraints, wslc benchmarks, and provisional
container implementation remain recorded in the immutable
[2026-07-29 wslc research snapshot](../research/2026-07-29-windows-wslc-devshell-delegation.md)
and `.apm/skills/nix-windows-wslc/`.

Related decisions: [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md),
[ADR-0014](0014-zero-inputs-flake-with-npins.md), and
[ADR-0015](0015-distribute-devcontainer-as-custom-feature-on-ghcr.md).
