---
name: nix-user-tools
description: Manages explicit user-wide tools in Linux or WSL through Nix profiles or officially recommended self-upgrading binaries in ~/.local/bin. Use only for requested global installs, updates, removals, rollback, or user-profile diagnosis.
---

# Nix User Tools

This is the explicit-only owner of user-wide tools in Linux or WSL. User
scope uses Nix or a self-upgrading binary; mise is a project toolchain.

## Workflow

1. Check that the user explicitly asked for a user-wide change. Otherwise
   hand off to `missing-tools` for a one-shot need or to the project
   toolchain owner.
2. If the target is native Windows, hand off to `windows-user-tools`. If
   the request names another user-wide manager such as mise, Block: no
   skill owns that channel. Report the supported route and end without
   changes.
3. Inspect the existing profile, Nix installation, and `~/.local/bin`
   before changing them.
4. For a new install, check the tool's official installation docs. When
   they recommend a single binary in `~/.local/bin` and the tool has a
   self-upgrade command, follow the self-upgrading binary path below
   instead of Nix. A tool already in the Nix profile stays there; name the
   binary option in the report.
5. Otherwise, if Nix is not installed, Block: installing Nix is out of
   scope. Report it and end without changes.
6. Resolve an exact package attribute from the established nixpkgs source.
7. Install, update, or remove with `nix profile`; `nix-env` mixes profile
   formats.
8. Report the generation and rollback command.

```sh
nix profile list
nix profile install nixpkgs#<package>
nix profile upgrade <name>
nix profile remove <name>
nix profile rollback
```

## Self-upgrading binaries

The tool owns its own updates, so Nix would pin a version the tool then
fights to replace.

- Install with the officially documented installer or release asset into
  `~/.local/bin`, and verify the published checksum or signature when the
  project provides one.
- Update with the tool's self-upgrade command.
- Remove by deleting the binary and any files the official uninstall docs
  list.
- If `~/.local/bin` is not on `PATH`, report it and leave shell startup
  files unchanged.

Use `nix-github-rate-limit` for GitHub-backed fetches. For diagnosis, GC, and
profile recovery details, read
[references/troubleshooting.md](references/troubleshooting.md).

Project tools belong to the owner `project-toolchain-selection` selects;
one-shot needs belong to `missing-tools`.

## Invariants

- No global change inferred from a project need or missing command, because
  user-wide state outlives the request and affects every project.
- No installation or upgrade of Nix itself, because the package manager is
  machine setup that the user provisions deliberately.
- No edits to project manifests, devShells, package outputs, task recipes,
  language locks, shell startup files, or native Win32 `PATH`, because
  those belong to project owners, the user's shell setup, or Windows.

## Done when

- For a Nix install, `nix profile list` shows the requested entry, the
  executable reports the expected version from the profile location, and
  the report names the generation and the rollback command.
- For a self-upgrading binary, `command -v <tool>` resolves to
  `~/.local/bin`, the tool reports its version, and the report names its
  self-upgrade and removal commands.

Canonical references: [Nix profiles](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile.html)
and [Determinate Nix](https://docs.determinate.systems/).
