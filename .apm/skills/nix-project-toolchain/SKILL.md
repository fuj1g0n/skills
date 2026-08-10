---
name: nix-project-toolchain
description: Manages a project's Nix development toolchain. Use for existing Nix devShell projects, or after project-toolchain-selection confirms Nix for a new guaranteed Linux-only project.
---

# Nix Project Toolchain

Use this skill only when Nix is already authoritative or
`project-toolchain-selection` has recorded the user's confirmation.

## Scope contract

Own:

- developer CLI and runtime selection with exact source pins;
- project environment variables, activation, `PATH`, and shell/IDE/GHCP
  visibility;
- install, lock, update, remove, diagnosis, source selection, and
  supply-chain validation.

Do not own:

- task or recipe definitions and workflow orchestration;
- language dependency graphs and locks;
- Nix package outputs, build products, OCI images, or release definitions;
- application compilation logic beyond proving provisioned tools work.

Installing and pinning `just` is in scope. Editing `justfile` recipes is normal
repository task work. Existing recipes may be invoked for validation.

## Hard constraint

Authoritative Nix package outputs require this Nix development toolchain, but
their definitions belong to `nix-package-outputs`. Never propose a mise
toolchain plus package-output-only flake.

## Workflow

1. Inspect active Nix development markers, pins, activation, CI/editor entry
   points, package-output constraints, and language-local managers. If active
   mise markers also exist, stop and invoke `project-toolchain-selection`.
2. Continue the existing Nix layout. For a new project, require confirmed Nix
   selection before initialization.
3. Add or update exact development tool pins in the devShell and shared
   development environment only. For the repository's zero-inputs convention,
   read [references/nix-files.md](references/nix-files.md).
4. Activate with `nix develop`, direnv/nix-direnv, or the repository's existing
   wrapper. Keep editor and GHCP execution inside the same environment.
5. On Windows, continue through WSL, a Dev Container, or wslc. Never export
   `/nix/store` into Win32 `PATH`, and never infer migration from host OS. If
   the project has selected a wslc bridge, hand its execution to
   `nix-wslc-devshell`.
6. Validate exact versions, executable locations, environment variables, and
   a minimal command. Run existing repository tasks as validation only.

Language-local managers and lockfiles remain valid. The devShell may provide
their launcher or runtime without absorbing their dependency graph; read
[references/language-notes.md](references/language-notes.md) when that boundary
is relevant.

Use `nix-github-rate-limit` for GitHub-backed fetches,
`nix-direnv-gc-roots` for stale activation roots, `missing-tools` for one-shot
execution, and `nix-user-tools` only for explicit user-wide Nix requests.
