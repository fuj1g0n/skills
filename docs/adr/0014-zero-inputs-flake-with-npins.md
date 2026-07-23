---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Zero-inputs flake with npins-pinned nixpkgs

## Context and Problem Statement

The repository's `flake.nix` declared `inputs.nixpkgs.url =
"github:NixOS/nixpkgs/nixpkgs-unstable"` pinned by `flake.lock`. The
user-level nix-for-dev skill establishes a convention against flake
inputs: each input adds fetcher-cache verification on cold evaluation (a
single nixpkgs input costs ~7s cold), and prescribes a zero-inputs
`flake.nix` with nixpkgs pinned by npins instead. The skill explicitly
permits a single-input flake "for small projects where cold-start time
does not matter".

This repository could claim the small-project exception. However, the
devcontainer setup built here (ADR-0010..0013) is intended as a template
to be reused broadly, so the flake layout that accompanies it will be
copied too. Should the flake keep the single nixpkgs input or migrate to
the zero-inputs layout?

## Decision Drivers

* Cold `nix develop` latency, paid on every fresh container creation
  (the devcontainer runs `nix develop --command true` in
  postCreateCommand and direnv evaluates the devShell in new clones).
* Convention consistency: the nix-for-dev skill's default layout should
  be exercised by the repository that develops and distributes skills.
* Template quality: whatever layout ships here will be replicated by
  reuse of the devcontainer.

## Considered Options

* Keep the single-input flake (nixpkgs only), claiming the skill's
  small-project exception
* Migrate to the zero-inputs layout: `flake.nix` with no `inputs`,
  nixpkgs pinned by npins, devShell in `shell.nix`

## Decision Outcome

Chosen option: "Migrate to the zero-inputs layout", because the repository
serves as a template whose layout propagates through reuse, so it should
model the convention's default rather than its escape hatch, and the cold
evaluation cost is paid repeatedly in devcontainer re-creation.

Implementation:

* `flake.nix` — slim zero-inputs wrapper exposing `devShells` only (the
  former `packages` output was removed; ADR-0013 decoupled the
  devcontainer from it).
* `nix/nixpkgs.nix` — imports the npins-pinned nixpkgs.
* `shell.nix` — the devShell, taking `pkgs ? import ./nix/nixpkgs.nix { }`
  so plain `nix-shell` works too.
* `npins/` — generated pin (same nixpkgs revision the former `flake.lock`
  held); update with `npins update nixpkgs`. `flake.lock` is deleted (a
  flake without inputs generates none).

### Consequences

* Good, because cold `nix develop` no longer pays flake-input
  fetcher-cache verification (~7s for a nixpkgs input per the skill).
* Good, because the layout matches the nix-for-dev convention, so the
  template propagates the default pattern.
* Bad, because the layout is more complex: four Nix files across three
  directories instead of one `flake.nix`, and contributors must know
  npins (not `nix flake update`) to bump nixpkgs.
* Bad, because npins pin updates and the devcontainer's independent
  `NIXPKGS_REV` (ADR-0013) must be bumped in separate places.

### Confirmation

`nix develop --command sh -c 'command -v just nixfmt markdownlint-cli2'`
resolves all devShell tools; warm `nix develop --command true` completes
in ~2s on the host. The devcontainer fresh-volume and volume-reuse paths
pass under wslc with the new layout.

## More Information

nix-for-dev skill: "Core principle: zero flake inputs" / "Do not add
nixpkgs, flake-parts, git-hooks, etc. as flake inputs"; exception: "For
small projects where cold-start time does not matter, a single-input
flake (nixpkgs only) with an inline mkShell is acceptable". Downstream
consumers can override the pin with `NPINS_OVERRIDE_nixpkgs=/path`.
