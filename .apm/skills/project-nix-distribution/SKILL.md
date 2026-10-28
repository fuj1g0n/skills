---
name: project-nix-distribution
description: Manages projects built and distributed through Nix, including package, app, check, derivation, OCI, and release outputs and the devShell tools, direnv activation, and PATH visibility their development needs. Use when a project has or will add Nix package outputs.
---

# Project Nix Distribution

Nix is the project toolchain only when the project builds or distributes
through Nix. This skill owns those outputs and the devShell that develops
them. Other projects use `project-dev-tools`.

## Entry gate

- Read the marker rules in `project-toolchain-selection` when output
  ownership is uncertain. Without authoritative Nix package outputs, a
  devShell tool change goes to `project-toolchain-selection`, which offers
  migration. Running or activating an existing devShell continues here.
- If the project uses mise for development or its authority is unknown,
  hand off to `project-toolchain-selection`.

## Scope contract

Own:

- flake `packages`, `apps`, and `checks`; derivations and `callPackage`
  expressions; Nix-built OCI images and release artifacts; and build,
  evaluation, and output-specific release validation;
- devShell tool selection with exact source pins, environment variables,
  activation, `PATH`, and shell, editor, and agent visibility.

Do not own:

- task or recipe definitions and workflow orchestration;
- language dependency graphs and locks;
- Nix-to-mise migration.

Installing and pinning `just` is in scope; editing `justfile` recipes is
normal repository work. Existing recipes may be invoked for validation.

## Workflow

1. Inspect active Nix markers, pins, outputs and their consumers,
   activation, CI and editor entry points, and language-local managers. If
   active mise markers also exist, hand off to `project-toolchain-selection`.
2. Continue the existing Nix layout. For a new project, check that the
   selection report selects Nix. For layout conventions, read
   [references/nix-files.md](references/nix-files.md); for output marker
   classification, read
   [references/output-boundaries.md](references/output-boundaries.md).
3. For an output, define the smallest output-specific expression and
   preserve exact source pins, checksums, runtime closure, metadata, and
   supported systems. Module integration checks that need flake inputs go
   in a sub-flake; read [references/sub-flakes.md](references/sub-flakes.md).
4. For a development tool, add or update the exact pin in the devShell and
   shared development environment only.
5. Activate with `nix develop`, direnv with nix-direnv, or the repository's
   wrapper, and keep editor and agent execution inside the same
   environment.
6. On Windows, continue through WSL, a Dev Container, or wslc; when the
   project has selected a wslc bridge, hand off to
   `windows-wslc-project-shell` for execution.
7. Run existing repository tasks as validation only.

Language-local managers and lockfiles remain valid; the devShell may
provide their runtime without absorbing their dependency graph. Read
[references/language-notes.md](references/language-notes.md) when that
boundary is relevant.

Use `github-fetch-rate-limit` for GitHub-backed fetches,
`project-env-cache-cleanup` for stale activation roots, `missing-tools` for
one-shot execution, and `linux-user-tools` only for explicit user-wide
requests.

## Invariants

- No mise toolchain or package-output-only flake beside these outputs,
  because the outputs depend on the Nix build environment and two
  development authorities drift.
- No `/nix/store` path in Win32 `PATH`, because native Windows tools would
  resolve Linux binaries.
- Host OS is not a migration request, because Windows reaches Nix through
  WSL, a Dev Container, or wslc.

## Done when

- For an output, `nix flake show` lists it, `nix build .#<attribute>`
  succeeds, and `nix flake check` passes where the repository supports it;
  task definitions are unchanged.
- For a development tool, the devShell pins it to an exact source, and in
  the activated environment it reports that version from the expected
  location, with the expected environment variables set.
- A minimal command runs in the shell, editor, and agent environment.
