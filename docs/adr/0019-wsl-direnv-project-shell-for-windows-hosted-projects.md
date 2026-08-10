---
type: Architecture Decision Record
status: rejected
date: 2026-08-07
decision-makers: "@fuj1g0n (with GitHub Copilot)"
---

# Use a WSL direnv project shell for Windows-hosted projects

## Context and Problem Statement

The proof of concept tested whether native Windows direnv could act as a
metadata control plane while a launcher moved interactive shells, commands,
and their descendants into a WSL Nix devShell. It kept Linux executable paths
out of Win32 `PATH` and left project files on the Windows filesystem.

The adapter and launcher demonstrated the process boundary, but the project
still needs one deterministic development toolchain authority that works with
Windows-hosted shells, editors, agents, and native artifacts.

## Decision Drivers

* Keep one authoritative project development toolchain.
* Make tools directly usable by the participating host platforms.
* Avoid importing Linux executable paths into Win32.
* Preserve complete shell, process, TTY, signal, and editor behavior.
* Avoid a second lifecycle and compatibility surface for directory activation.
* Make production support commitments only for maintained project policy.

## Considered Options

* Adopt the native-direnv adapter and `wsl-dev` launcher.
* Use mise with Aqua or other native artifact backends for Windows-capable
  projects.
* Keep Nix for guaranteed Linux-only projects and established Nix projects,
  using an explicit WSL or container boundary when Windows hosts participate.

## Decision Outcome

Rejected option: "Adopt the native-direnv adapter and `wsl-dev` launcher".
The proof of concept validated metadata filtering, explicit WSL execution, and
the prohibition on exporting `/nix/store` into Win32 `PATH`, but it is not
adopted.

Windows-capable project development tool management will use mise with Aqua or
other native artifacts under the deterministic toolchain policy documented by
[Select one authoritative project development toolchain](0021-select-one-project-development-toolchain.md).
That accepted decision supersedes this experiment and is the durable source of
project toolchain policy and skill taxonomy.

Authoritative Nix package outputs are a hard Nix constraint. A project cannot
migrate to mise+Aqua until a separate, explicitly authorized plan removes or
replaces every such output. Project toolchain skills may provision a task
runner, but task definitions and workflow orchestration remain normal
repository work outside those skills.

Nix remains appropriate when development and execution are guaranteed
Linux-only and for projects that already use Nix. Existing Nix projects opened
from Windows continue through WSL, a Dev Container, or another selected Linux
boundary. They do not import Linux tool paths into Win32.

The adapter is rejected because crossing the process and shell boundary adds
configuration and lifecycle complexity while still failing to expose every
devShell command transparently. Aliases, functions, builtins, completion, and
command collisions cannot all behave like the active Linux shell. TTY, signal,
job-control, watcher, debugger, language-server, and editor integration also
remain boundary-specific. Maintaining that bridge alongside a native Windows
toolchain would create overlapping toolchain authority.

No production deployment or support commitment remains for this proof of
concept.

### Consequences

* Good, because Windows-capable projects have one native toolchain authority.
* Good, because Nix remains authoritative within explicit Linux boundaries.
* Good, because no Linux executable path is presented as a Win32 tool path.
* Good, because the experimental adapter, launcher, fixtures, deployment
  scripts, and forwarding layers require no ongoing maintenance.
* Bad, because the proof-of-concept launcher is no longer a supported shortcut
  for entering a Nix devShell from a native Windows prompt.
* Neutral, because an existing user-scoped prototype deployment is external
  machine state and must be rolled back explicitly rather than by this
  repository change.

### Confirmation

The repository contains no `poc/wsl-dev` implementation or provisional
`nix-windows-wslc` skill. Historical research remains available as evidence,
and the active skill names and ownership boundaries come from the deterministic
toolchain taxonomy.

## More Information

* [Windows-hosted WSL direnv project shell research](../research/2026-08-07-windows-wsl-direnv-project-shell.md)
* [Windows-native tool management alternatives to Nix](../research/2026-08-08-windows-native-tool-management-alternatives.md)
* [Earlier wslc delegation research](../research/2026-07-29-windows-wslc-devshell-delegation.md)
