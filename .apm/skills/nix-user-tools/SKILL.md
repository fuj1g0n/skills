---
name: nix-user-tools
description: Manages explicit user-wide Nix tools and profiles in Linux or WSL. Use only for requested global installs, updates, removals, rollback, or Nix user-profile diagnosis.
---

# Nix User Tools

This is an explicit-only user scope for an existing Nix installation. Never
infer global mutation from a project need or missing command.

## Workflow

1. Confirm the request is user-wide and belongs in the Linux or WSL Nix user
   profile, not a native Windows environment.
2. Inspect the existing profile and Nix installation before changing it.
3. Resolve an exact package attribute from the established nixpkgs source.
4. Install, update, or remove with `nix profile`; do not use `nix-env`.
5. Verify the profile entry, executable location, and version. Report the
   generation and rollback command.

```sh
nix profile list
nix profile install nixpkgs#<package>
nix profile upgrade <name>
nix profile remove <name>
nix profile rollback
```

Use `nix-github-rate-limit` for GitHub-backed fetches. For diagnosis, GC, and
profile recovery details, read
[references/troubleshooting.md](references/troubleshooting.md).

Do not edit project manifests, devShells, package outputs, task recipes,
language locks, or native Win32 `PATH`. Project tools belong to
`nix-project-toolchain`; one-shot needs belong to `missing-tools`; native
user-wide mise requests belong to `mise-user-tools`.

Canonical references: [Nix profiles](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile.html)
and [Determinate Nix](https://docs.determinate.systems/).
