---
status: proposed
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Distribute the devcontainer as a custom Feature on GHCR

## Context and Problem Statement

The devcontainer built in ADR-0010..0014 is designed as a generic,
reusable template for repositories that carry a flake.nix, but today
reuse means copying `.devcontainer/` into each repository: copies drift
apart, and every repository pays the postCreateCommand cost (Nix install
+ tool downloads, roughly 4–9 minutes) on first container creation per
machine. How should this environment be distributed so that other
repositories can adopt it with minimal friction?

The initially proposed answer was a prebuilt container image on GHCR.
Two investigations ([GHCR prebuild feasibility](../research/2026-07-23-ghcr-prebuilt-devcontainer.md),
[official Nix Feature deep-dive](../research/2026-07-23-official-nix-feature-deepdive.md))
established that GHCR itself is viable (public packages are free for
both storage and bandwidth, anonymously pullable, no documented rate
limits, and devcontainer Features are OCI artifacts publishable to GHCR
just like images) — but that any build-time Nix install (prebuilt image
or the official Nix Feature) conflicts structurally with the /nix named
volume, and the official Feature carries additional unresolved defects.

## Decision Drivers

* Instant reuse: a consuming repository should adopt the environment via
  a short, versioned reference — no copied scripts.
* Single source of truth: one published artifact, versioned releases,
  no `.devcontainer/` drift.
* Preserve the architecture validated in ADR-0010..0013: create-time
  single-user Nix install into the mounted /nix volume, runtime-UID
  chown, SHA256-pinned installer, self-contained editor tooling.
* Bounded maintenance: no permanent image-rebuild pipeline for CVE
  patching if avoidable.

## Considered Options

* Publish a custom devcontainer Feature on GHCR wrapping the current
  create-time install
* Publish a prebuilt container image on GHCR (Nix baked at build time)
* Adopt the official Nix Feature (`ghcr.io/devcontainers/features/nix`)
* Status quo: copy `.devcontainer/` into each repository
* GitHub Codespaces prebuilds

## Decision Outcome

Proposed option: "Publish a custom devcontainer Feature on GHCR wrapping
the current create-time install", because it is the only distribution
mechanism that keeps the create-time install semantics that make the
/nix volume design correct, while still giving consuming repositories a
one-line versioned reference. Feature lifecycle-command contribution
(devcontainers/spec#60, closed as completed 2023-04-07) makes this
possible: the Feature's `install.sh` runs at build time but only copies
the setup script into the image and registers it as an `onCreateCommand`
lifecycle hook — the actual Nix install still runs at container-create
time, after the volume is mounted, as the actual runtime user.

Outline:

* Feature published as `ghcr.io/fuj1g0n/skills/<feature-id>` via the
  devcontainers/action from this repository's CI (GITHUB_TOKEN with
  `packages: write`); semver-versioned. PoC verified that publishing
  from a public repository's workflow links the package to the
  repository and it is anonymously pullable immediately — the manual
  Public-visibility flip that first pushes normally require was not
  needed.
* `devcontainer-feature.json` declares the `nix-store-${devcontainerId}`
  volume mount, the VS Code customizations (extensions,
  `nix.serverSettings`), and the `onCreateCommand` hook; pins
  (NIX_VERSION, installer sha256, NIXPKGS_REV) become Feature options
  with defaults, versioned with the Feature.
* The hook script is the current `postCreateCommand.sh` logic unchanged:
  UID-1000 guard (ADR-0011), pinned upstream single-user installer
  (ADR-0012), bootstrap manifest for volume reuse, direnv/nix-direnv/
  nil/nixfmt from the pinned nixpkgs (ADR-0013), flake devShell warmup.
* A consuming repository's `devcontainer.json` reduces to a base image
  reference plus one `features` entry.

Rejection of the alternatives, from the research:

* Prebuilt image (and any build-time install): `devcontainer build`
  never runs postCreateCommand, so prebuilding requires moving the
  install to build time — and then an existing volume shadows every
  image update (Docker copy-on-first-use seeds only an empty volume),
  with dangling `~/.nix-profile` symlinks as a hard failure mode, plus a
  permanent rebuild pipeline for base-image CVEs.
* Official Nix Feature: same build-time/volume staleness architecture
  (devcontainers/features#1505, open, no mitigation); `packages` option
  broken in multi-user mode for 5+ months (#1573, fix PR #1691 unmerged
  as of 2026-07-23); daemon start silently fails without passwordless
  sudo and has no readiness wait; installer fetched without hash
  verification; flakes not enabled by default (#1519); provides no
  direnv/nix-direnv (the community direnv Feature is unmaintained since
  2023-08), so the custom scripting remains necessary anyway. Notably,
  both articles that ADR-0010 was based on independently bypassed the
  official Feature and converged on the create-time single-user pattern.
* Status quo: no distribution mechanism; copies drift.
* Codespaces prebuilds: repository-scoped and Codespaces-only; cannot be
  referenced by other repositories; billed.

### Consequences

* Good, because consuming repositories adopt the environment with one
  versioned `features` line instead of copying two files, and updates
  ship as Feature releases.
* Good, because the create-time install architecture (volume-correct,
  runtime-UID-robust, hash-pinned) is preserved exactly; no new failure
  modes are introduced by distribution.
* Good, because there is no CVE-rebuild treadmill: the Feature contains
  scripts, not OS layers; the base image remains
  `mcr.microsoft.com/devcontainers/base` maintained by Microsoft.
* Good, because Dependabot natively supports Feature version updates in
  consuming repositories (unlike `image:` references, which need
  Renovate).
* Bad, because the first-run install cost (4–9 minutes per machine) is
  NOT eliminated — this option deliberately trades away the prebuilt
  image's first-run speedup to keep volume correctness. Ephemeral CI
  environments keep paying the full cost per run.
* Bad, because we own a published artifact: publish workflow and semver
  discipline.
* Bad, because Feature-contributed lifecycle hooks and metadata merge
  behavior add a layer of devcontainer-spec machinery between the
  consuming repository and the script, making debugging less direct than
  a script sitting in the repository.

### Confirmation

Before acceptance, prototype and verify in a consuming repository with a
flake.nix: (1) `devcontainer.json` referencing only the base image and
the Feature yields a working environment — devShell tools on PATH,
nil/nixfmt working in VS Code, direnv activation; (2) volume reuse
across container rebuilds still skips reinstall via the bootstrap
manifest; (3) a Feature version bump against an existing volume behaves
correctly (manifest fallback reinstalls; no dangling profile);
(4) anonymous consumption works — verified by the publish PoC
(workflow run 30011517328): tags 0 / 0.0 / 0.0.1 / latest published to
`ghcr.io/fuj1g0n/skills/nix-devshell`, manifest carries the
`dev.containers.metadata` annotation (mounts, onCreateCommand,
customizations), and the layer is anonymously pullable without any
manual visibility change.

## More Information

Research snapshots:
[GHCR prebuild feasibility and pitfalls](../research/2026-07-23-ghcr-prebuilt-devcontainer.md)
(GHCR billing/visibility, `devcontainer build` semantics,
`devcontainer.metadata` merge logic, Docker copy-on-first-use, tag and
multi-arch guidance, ToS review) and
[official Nix Feature deep-dive](../research/2026-07-23-official-nix-feature-deepdive.md)
(Feature source analysis, issue index, reference-article positions,
option synthesis).

An earlier draft of this ADR proposed the prebuilt-image option; it was
rewritten before acceptance when the Feature deep-dive showed that
build-time installs are structurally incompatible with the /nix volume.
If ephemeral CI usage later makes the first-run cost unacceptable, a
prebuilt image can be reconsidered as a separate decision on top of the
Feature — with the volume dropped or explicitly lifecycle-managed.

Related decisions: [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md)
(create-time install + volume architecture, preserved),
[ADR-0011](0011-fix-devcontainer-user-to-vscode-uid-1000.md) /
[ADR-0012](0012-use-upstream-installer-single-user-mode.md) /
[ADR-0013](0013-devcontainer-self-contained-tool-provisioning.md)
(guard, installer, and pinning logic that moves into the Feature
unchanged).
