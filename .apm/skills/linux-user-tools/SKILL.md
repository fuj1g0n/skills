---
name: linux-user-tools
description: Manages explicit user-wide tools in Linux or WSL through Nix profiles or officially recommended self-upgrading binaries in ~/.local/bin. Use only for requested global installs, updates, removals, rollback, or user-profile diagnosis.
---

# Linux User Tools

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
3. Inspect `nix profile list`, `command -v <tool>`, and `~/.local/bin` to
   find the current install channel. An install request for a tool already
   present through the same channel changes nothing; report the available
   upgrade.
4. For a new install, read the tool's official Linux installation docs.
   When they offer a per-user install without root, such as a single
   binary in `~/.local/bin`, and the tool updates itself through a command
   or a built-in updater, follow the self-upgrading binary path below even
   if nixpkgs also packages it. A tool already installed through another
   channel stays there; name the other option in the report.
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
  the documented per-user directory. Verify the downloaded artifact against
  its published checksum or signature when the project provides one, and
  state in the report when it provides none.
- Use the installer's option to skip shell-profile edits, such as
  `UV_NO_MODIFY_PATH=1`. If it has none, install the official release asset
  directly instead.
- Update with the tool's self-upgrade command.
- Remove by deleting the binary and any files the official uninstall docs
  list.
- If the install directory is not on `PATH`, report it and leave shell
  startup files unchanged.

Use `github-fetch-rate-limit` for GitHub-backed fetches. For diagnosis, GC,
and profile recovery details, read
[references/troubleshooting.md](references/troubleshooting.md).

Project tools belong to the owner `project-toolchain-selection` selects;
one-shot needs belong to `missing-tools`.

## Invariants

- No global change inferred from a project need or missing command, because
  user-wide state outlives the request and affects every project.
- No tool managed through two channels, because each channel overwrites or
  misreads the other's version.
- No installation or upgrade of Nix itself, because the package manager is
  machine setup that the user provisions deliberately.
- No edits to project manifests, devShells, package outputs, task recipes,
  language locks, shell startup files, or native Win32 `PATH`, because
  those belong to project owners, the user's shell setup, or Windows.

## Done when

- For a Nix install, `nix profile list` shows the requested entry, the
  executable reports the expected version from the profile location, and
  the report names the generation and the rollback command.
- For a self-upgrading binary, `command -v <tool>` resolves to the
  documented per-user directory, the tool reports its version, and the report names its
  self-upgrade and removal commands.

Canonical references: [Nix profiles](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile.html)
and [Determinate Nix](https://docs.determinate.systems/).
