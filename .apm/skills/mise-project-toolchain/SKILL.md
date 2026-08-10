---
name: mise-project-toolchain
description: Manages a project's mise+Aqua development toolchain. Use for existing mise projects, or after project-toolchain-selection confirms mise for a new project that may include Windows.
---

# mise Project Toolchain

Use this skill only when mise is already authoritative or
`project-toolchain-selection` has recorded the user's confirmation. Aqua is a
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
   exist, stop and invoke `project-toolchain-selection`.
2. Preserve the current setup. For a new project, confirm that the selection
   record permits mise before creating files.
3. Choose an exact version and backend. Read
   [references/backends-and-supply-chain.md](references/backends-and-supply-chain.md)
   for Aqua and corporate npm policy.
4. Edit project-scoped mise configuration and lock data. Never use floating
   versions such as `latest`.
5. Activate through mise for the current shell, IDE, and agent environment.
   Keep native Windows paths native; never add `/nix/store` to Win32 `PATH`.
6. Install from the configured trusted source and verify the resolved version,
   executable location, checksum/signature policy, and a minimal command.
7. Run existing repository validation or task recipes without redefining
   them.

Language-local managers and committed locks remain authoritative for their
dependency graphs. This skill may require their normal workflow as a handoff,
but must not replace it with mise configuration.

Nix package outputs are incompatible with mise as the project development
toolchain. If any may exist, stop and return to `project-toolchain-selection`.
