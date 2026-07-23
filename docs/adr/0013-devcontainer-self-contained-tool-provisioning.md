---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Provision editor-required tools from a devcontainer-pinned nixpkgs

## Context and Problem Statement

`devcontainer.json` declares VS Code customizations that require tools on
the user-wide PATH: the Nix IDE extension launches nil outside the direnv
environment, nil spawns nixfmt as its formatter subprocess, and the direnv
extension needs direnv + nix-direnv before any devShell can load
(bootstrap problem). The initial implementation installed these via
`nix profile add .#<name>` against a `packages` output of the project
flake.

This devcontainer is not intended to be specific to this repository; it
should be reusable across projects. Viewed standalone, the devcontainer is
broken by design: in any repository whose flake does not export these
packages (including the zero-inputs layout of ADR-0014, which has no
`packages` output for them), `nix profile add .#nil` fails and the VS Code
integration silently loses its formatter. Where should the tools that the
devcontainer itself requires come from?

## Decision Drivers

* Self-containedness: requirements declared in `devcontainer.json`
  (extensions, `nix.serverSettings`) must be satisfiable by the
  devcontainer alone, without cooperation from the project flake.
* Reusability: the same `.devcontainer/` should work when copied into
  repositories with different (or no) flake layouts.
* Reproducibility: tool versions must be pinned, consistent with the
  pinned Nix installer (ADR-0012).

## Considered Options

* Install from the project flake's `packages` output (`nix profile add .#<name>`)
* Install from a nixpkgs revision pinned inside `postCreateCommand.sh`
* Install via apt from the base image's package repositories

## Decision Outcome

Chosen option: "Install from a nixpkgs revision pinned inside
`postCreateCommand.sh`", because tools required by the devcontainer's own
configuration are the devcontainer's responsibility: `postCreateCommand.sh`
pins a nixpkgs revision (`NIXPKGS_REV`) and installs direnv, nix-direnv,
nil, and nixfmt from `github:NixOS/nixpkgs/<rev>`, decoupling the
devcontainer from the project flake entirely. The project flake keeps
supplying the project toolchain via its devShell only. Installing via apt
would abandon Nix-based pinning and version consistency with the store.

The boundary rule: anything referenced by `devcontainer.json` belongs to
the devcontainer (pinned in `postCreateCommand.sh`); anything belonging to
the project's workflow belongs to the flake devShell.

### Consequences

* Good, because the devcontainer works unchanged in repositories whose
  flakes export nothing, or that have no flake at all (`nix develop`
  warm-up and `direnv allow` are guarded by file-existence checks).
* Good, because VS Code formatting (nil → nixfmt) works regardless of the
  project flake's contents.
* Bad, because two independent nixpkgs pins now exist — `NIXPKGS_REV` in
  `postCreateCommand.sh` and the project's own pin (npins) — so the
  user-wide nixfmt and the devShell nixfmt can drift apart in version
  until the pins are updated together.
* Bad, because tools appear in the user profile that are not declared in
  the repository's Nix code, which weakens the "centralize tool
  definitions in flake.nix" driver of ADR-0010 for this narrow category.

### Confirmation

Run `.devcontainer/postCreateCommand.sh` in a container against a
repository without a flake `packages` output and confirm `direnv`, `nil`,
and `nixfmt` resolve from `~/.nix-profile/bin`. Verified with wslc on
fresh-volume and volume-reuse paths (the bootstrap manifest records all
five profile packages, so volume reuse rebuilds the profile offline with
zero `nix profile add` invocations).

## More Information

The flake's former `packages` output (direnv, nix-direnv, nil, nixfmt)
was removed together with the migration to the zero-inputs layout
([ADR-0014](0014-zero-inputs-flake-with-npins.md)). nixfmt remains in the
devShell as well: the two copies serve different consumers (devShell for
shell/host usage such as `just fmt`; user profile for the VS Code
formatter path) and resolve to the same store path while the pins agree.
