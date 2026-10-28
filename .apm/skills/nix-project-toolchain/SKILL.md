---
name: nix-project-toolchain
description: Manages a project's Nix development toolchain. Use for existing Nix devShell projects, or after project-toolchain-selection selects Nix for a new project with Nix package outputs or an explicit Nix request.
---

# Nix Project Toolchain

Use this skill when Nix is already authoritative or
`project-toolchain-selection` has selected it.

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

## Workflow

1. Inspect active Nix development markers, pins, activation, CI/editor entry
   points, package-output constraints, and language-local managers. If active
   mise markers also exist, hand off to `project-toolchain-selection`.
2. Continue the existing Nix layout. For a new project, check that the
   selection report selects Nix before initialization.
3. Add or update exact development tool pins in the devShell and shared
   development environment only. For the repository's zero-inputs convention,
   read [references/nix-files.md](references/nix-files.md).
4. Activate with `nix develop`, direnv/nix-direnv, or the repository's existing
   wrapper. Keep editor and GHCP execution inside the same environment.
5. On Windows, continue through WSL, a Dev Container, or wslc. If the
   project has selected a wslc bridge, hand off to `nix-wslc-devshell` for
   execution.
6. Run existing repository tasks as validation only.

Language-local managers and lockfiles remain valid. The devShell may provide
their launcher or runtime without absorbing their dependency graph; read
[references/language-notes.md](references/language-notes.md) when that boundary
is relevant.

Package output definitions belong to `nix-package-outputs`. Use
`nix-github-rate-limit` for GitHub-backed fetches,
`nix-direnv-gc-roots` for stale activation roots, `missing-tools` for one-shot
execution, and `nix-user-tools` only for explicit user-wide Nix requests.

## Invariants

- Authoritative Nix package outputs keep this Nix development toolchain, and
  never a mise toolchain plus package-output-only flake, because the outputs
  depend on the Nix build environment.
- No `/nix/store` path in Win32 `PATH`, because native Windows tools would
  resolve Linux binaries.
- Host OS is not a migration request, because Windows reaches Nix through
  WSL, a Dev Container, or wslc.

## Done when

- The devShell pins each requested tool to an exact source.
- Inside the activated environment, each tool reports that version from the
  expected location, with the expected environment variables set.
- A minimal command runs in the shell, editor, and GHCP environment.
