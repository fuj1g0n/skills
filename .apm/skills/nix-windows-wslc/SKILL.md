---
name: nix-windows-wslc
description: Runs Nix devShell commands from Windows by delegating to a wslc container while the repository stays on NTFS. Use on Windows when a project needs nix, devShell, direnv, or just tooling, when nix/just/direnv commands fail as not recognized, or when commands must run on Linux against a Windows-managed working tree.
---

# Nix devShells on Windows via wslc

Status: provisional (ADR-0019, proposed). Nix does not run on Windows.
Delegate every devShell command to a per-project wslc container (WSL
Containers, public preview): project bind-mounted from `C:\` (virtiofs),
`/nix` on a persistent named volume, GHCP CLI and the user shell stay on
Windows. Warm overhead is ~0.8 s per command (wslc exec + devShell
activation via warm nix-direnv cache).

## Prerequisites

- `wslc` available (`wslc version`; ships with WSL >= 2.9.4).
- The repository pins LF for scripts consumed inside the container:
  `.gitattributes` with `*.sh text eol=lf`, `*.nix text eol=lf`,
  `.envrc text eol=lf`. CRLF in these files breaks bash and direnv
  inside the container. Fix this FIRST if missing.
- The project follows the `nix-for-dev` layout (`flake.nix` +
  `shell.nix` + `.envrc`).

## Provision (once per project)

```powershell
& <skill-dir>/scripts/provision.ps1
```

Creates container `devshell-<repo>` with the repo mounted at
`/workspaces/<repo>` and volume `nix-store-<repo>` at `/nix`, installs
single-user Nix (reuses `.devcontainer/postCreateCommand.sh` when
present, per ADR-0012/0013), installs direnv/nix-direnv, relocates the
direnv layout dir off the mount, and runs `direnv allow`. Volume reuse
makes re-provisioning after `wslc rm` an offline fast path (~1 min).

## Execute (every devShell command)

All devShell work — just, nix, formatters, linters, builds, tests —
goes through the wrapper. Never invoke these tools in the Windows
shell; they do not exist there.

```powershell
& <skill-dir>/scripts/devshell-exec.ps1 just lint
& <skill-dir>/scripts/devshell-exec.ps1 nixfmt flake.nix
```

Call with `&` from the current PowerShell; a child `pwsh -File` spawn
adds ~1 s per command.

Rules:

- The argument is a POSIX sh command line, not PowerShell. Quote for
  bash, use `/` paths relative to the repo, chain with `&&`.
- The wrapper maps the current Windows directory to the container path
  and runs inside `direnv exec .` (devShell env, warm nix-direnv).
- Overrides via env vars: `DEVSHELL_CONTAINER`, `DEVSHELL_MOUNT`,
  `DEVSHELL_USER` (defaults: `devshell-<repo>`, `/workspaces/<repo>`,
  `vscode`).
- git/gh and Windows-native operations stay in the Windows shell
  (credentials live there).

## Known pitfalls

- `network is unreachable` on `wslc pull`: stale session; run
  `wslc system session terminate` and retry.
- File watchers inside the container do not see Windows-side edits
  (no inotify across virtiofs); edit through the container or restart
  the watcher.
- Do not create `.direnv/` on the mount: virtiofs rejects `chmod` and
  the artifacts pollute the NTFS tree. Provisioning installs a
  `direnv_layout_dir()` override; if devShell activation slows from
  under a second to several seconds, check that
  `~/.config/direnv/direnvrc` in the container still sources
  nix-direnv's direnvrc.

Background, benchmarks, and rationale: ADR-0019 and
`docs/research/2026-07-29-windows-wslc-devshell-delegation.md` in the
skills repository.
