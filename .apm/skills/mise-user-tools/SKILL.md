---
name: mise-user-tools
description: Manages explicit user-wide native tool defaults with mise. Use only when the user asks for a global install, default, update, removal, or diagnosis outside a project.
---

# mise User Tools

This is an explicit-only user scope.

## Workflow

1. Check that the user explicitly asked for a user-wide change native to
   the host. Otherwise hand off to `missing-tools` for a one-shot need or to
   the project toolchain owner.
2. Inspect existing global mise configuration and preserve its backend and
   trust conventions.
3. Select an exact version. For Aqua or npm sources, apply the supply-chain
   policy in `mise-project-toolchain` without editing a project.
4. Update the user mise configuration and install.
5. Report the user-level files changed and how to roll back the entry.

A user-wide Nix request belongs to `nix-user-tools`; a project request
belongs to the selected project toolchain owner.

## Invariants

- No global change inferred from a missing command, recurring project need,
  or wish to share a local setup, because user-wide state outlives the
  request and affects every project.
- No edits to repository manifests, language dependency locks, task recipes,
  or Nix profiles, because those belong to their own owners.

## Done when

- The user mise configuration pins the exact version, and the tool reports
  it from the expected executable location.
- The report names the changed files and the rollback.
