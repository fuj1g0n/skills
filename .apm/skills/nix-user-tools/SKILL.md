---
name: nix-user-tools
description: Manages explicit user-wide Nix tools and profiles in Linux or WSL. Use only for requested global installs, updates, removals, rollback, or Nix user-profile diagnosis.
---

# Nix User Tools

This is an explicit-only user scope for an existing Nix installation.

## Workflow

1. Check that the user explicitly asked for a user-wide change in the Linux
   or WSL Nix user profile. Otherwise hand off to `missing-tools` for a
   one-shot need or to the project toolchain owner.
2. Inspect the existing profile and Nix installation before changing it.
3. Resolve an exact package attribute from the established nixpkgs source.
4. Install, update, or remove with `nix profile`; `nix-env` mixes profile
   formats.
5. Report the generation and rollback command.

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

Project tools belong to `nix-project-toolchain`; one-shot needs belong to
`missing-tools`; native user-wide mise requests belong to `mise-user-tools`.

## Invariants

- No global change inferred from a project need or missing command, because
  user-wide state outlives the request and affects every project.
- No edits to project manifests, devShells, package outputs, task recipes,
  language locks, or native Win32 `PATH`, because those belong to project
  owners or to Windows.

## Done when

- `nix profile list` shows the requested entry, and the executable reports
  the expected version from the profile location.
- The report names the generation and the rollback command.

Canonical references: [Nix profiles](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile.html)
and [Determinate Nix](https://docs.determinate.systems/).
