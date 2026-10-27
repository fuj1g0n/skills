---
name: mise-project-toolchain
description: Manages a project's mise+Aqua development toolchain. Use for existing mise projects, or after project-toolchain-selection confirms mise for a new project that may include Windows.
---

# mise Project Toolchain

Use this skill when mise is already authoritative or
`project-toolchain-selection` has recorded the user's approval. Aqua is a
mise backend, not a standalone toolchain.

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
   record approves mise before creating files.
3. Choose an exact version and backend. Read
   [references/backends-and-supply-chain.md](references/backends-and-supply-chain.md)
   for Aqua and corporate npm policy.
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
