---
name: project-dev-tools
description: Manages a project's development tools through mise, including adding, pinning, updating, or removing CLIs and runtimes, and activation or PATH visibility in shells, editors, and agents. Use in existing mise projects or after project-toolchain-selection selects mise.
---

# Project Dev Tools

Use this skill when mise is already authoritative or
`project-toolchain-selection` has selected it. Aqua appears only as mise's
`aqua:` backend, never as the standalone aqua CLI or `aqua.yaml`.

## Scope contract

Own:

- developer CLI and runtime selection with exact versions;
- project environment variables, activation, `PATH`, and shell/IDE/GHCP
  visibility;
- install, lock, update, remove, diagnosis, backend selection, and
  supply-chain validation.

Do not own:

- task or recipe definitions and workflow orchestration;
- language dependency graphs and locks;
- Nix package outputs, application builds, or release definitions.

Installing and pinning `just` is in scope. Editing `justfile` recipes or
creating mise `[tasks]` is not; hand that work back as normal repository task
work. Existing tasks may be invoked for validation.

## Workflow

1. Inspect active `mise.toml` or `.mise.toml`, `mise.lock`, CI, editor setup,
   and language-local managers. If authoritative Nix development markers also
   exist, hand off to `project-toolchain-selection`.
2. Preserve the current setup. For a new project, check that the selection
   report selects mise before creating files.
3. Choose an exact version and backend. Read
   [references/backends-and-supply-chain.md](references/backends-and-supply-chain.md)
   for backend order and corporate npm policy.
4. Edit project-scoped mise configuration and lock data.
5. Activate through mise for the current shell, IDE, and agent environment.
   Keep native Windows paths native.
6. Install from the configured trusted source.
7. Run existing repository validation or task recipes without redefining
   them.

Language-local managers and committed locks remain authoritative for their
dependency graphs. This skill may require their normal workflow as a handoff,
but must not replace it with mise configuration.

If Nix package outputs may exist, hand off to `project-toolchain-selection`.

## Invariants

- No floating versions such as `latest`, because an unpinned tool is a
  different tool on the next run.
- No `asdf:`, `vfox:`, or `ubi:` backend, because they run unverified plugin
  code, do not run on native Windows, or are deprecated.
- No `/nix/store` path in Win32 `PATH`, because native Windows tools would
  resolve Linux binaries.
- No mise toolchain beside Nix package outputs, because those outputs need
  Nix as the development authority.

## Done when

- The project mise configuration and lock data pin the exact version and
  backend.
- The installed tool reports that version from the expected executable
  location, and checksum/signature policy passed.
- A minimal command runs in the shell, IDE, and agent environment.
