---
name: mise-user-tools
description: Manages explicit user-wide native tool defaults with mise. Use only when the user asks for a global install, default, update, removal, or diagnosis outside a project.
---

# mise User Tools

This is an explicit-only user scope. Never infer global mutation from a
missing command, recurring project need, or desire to share a local setup.

## Workflow

1. Confirm the request is user-wide and native to the host environment.
2. Inspect existing global mise configuration and preserve its backend and
   trust conventions.
3. Select an exact version. For Aqua or npm sources, apply the supply-chain
   policy in `mise-project-toolchain` without editing a project.
4. Update the user mise configuration, install, and verify the resolved
   version and executable location.
5. Report the user-level files changed and how to roll back the entry.

Do not edit repository manifests, language dependency locks, task recipes, or
Nix profiles. A user-wide Nix request belongs to `nix-user-tools`; a project
request belongs to the selected project toolchain owner.
