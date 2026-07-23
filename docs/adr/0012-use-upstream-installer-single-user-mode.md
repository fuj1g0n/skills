---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Install Nix in the devcontainer with the upstream official installer in single-user mode

## Context and Problem Statement

[ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) chose the
Determinate Nix Installer for the devcontainer too, for consistency with
the host (Determinate Nix). However, while implementing the single-user
configuration, structural problems with the Determinate approach became
apparent.

* The Determinate Nix Installer enforces root via `ensure_root()` (when
  started as non-root it re-executes itself via `sudo --set-home`) and
  supports only the multi-user model of "root-owned store + daemon +
  build users". `--init none` is also a root-only layout operated
  directly by root, not a user-owned mode.
* A single-user install owned by a non-root user has been an open feature
  request for years
  ([#214](https://github.com/DeterminateSystems/nix-installer/issues/214),
  [#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075))
  and remains unimplemented; the current "chown /nix after install"
  approach is a community workaround — i.e. off-label use from the
  vendor's perspective. It is also inconsistent with root-ownership-based
  features such as `determinate-nixd upgrade`.
* The upstream official installer, on the other hand, officially supports
  single-user mode (`--no-daemon`). Upstream discourages single-user for
  three reasons: (a) builds run with the invoking user's privileges,
  (b) no isolation via build-user separation, (c) the store cannot be
  shared between users. None of these applies to a single-user
  devcontainer where the container itself is the isolation boundary. On
  the contrary, a devcontainer without systemd matches single-user
  mode's intended use case of "environments that cannot run the
  multi-user daemon".

Decide which installer to use inside the devcontainer.

## Decision Drivers

* Stay within the installer's officially supported usage (do not depend
  on off-label workarounds).
* Simplicity: eliminate root escalation, chowning the whole store, and
  backup/restore of `/etc/nix`.
* Reproducibility: version pinning and hash verification of the installer
  and Nix itself.
* Consistency with the host's Nix-based workflow (ADR-0010 driver).

## Considered Options

* Switch to the upstream official installer's single-user mode
  (`--no-daemon`)
* Keep the current Determinate + post-install chown approach (accepting
  that it is off-label)
* Use Determinate's multi-user model as-is and start nix-daemon manually

## Decision Outcome

Chosen option: "Switch to the upstream official installer's single-user
mode (`--no-daemon`)", because the devcontainer's requirements (single
user, no systemd, container as the isolation boundary) are exactly the
officially supported scope of upstream single-user mode, and since the
installer builds the store owned by vscode while running as the vscode
user, neither root escalation nor chowning the whole store nor restoring
`/etc/nix` is needed. Keeping Determinate means continued off-label use,
and the manual-daemon option reintroduces the complexity ADR-0010
eliminated. What is lost is only Determinate's added features
(lazy-trees, FlakeHub cache, etc. — unused in this repository) and nix
CLI version parity with the host; artifact reproducibility is unchanged
thanks to flake.lock.

Implementation outline:

* Beforehand, `sudo chown vscode: /nix` the empty `/nix` (freshly volume
  mounted, root-owned) — non-recursive, O(1). This is the only point
  where root privileges are needed.
* Pin the version of the install script
  (`releases.nixos.org/nix/nix-<version>/install`) and verify its sha256.
  The script embeds the sha256 of the Nix tarball, so verification chains
  from the script through to the tarball.
* Flakes are disabled by default, so idempotently write
  `experimental-features = nix-command flakes` to
  `~/.config/nix/nix.conf`.
* In single-user mode the nix CLI itself lives in the user profile (under
  `$HOME`, lost on container re-creation). When the /nix volume is
  reused, rebuild the user profile with `nix-env -i` from the nix package
  remaining in the store (no network needed).
* Keep ADR-0011's constraint (fixed vscode/UID 1000) and guard as-is. The
  premise that the store is owned by vscode (UID 1000) is unchanged.

### Consequences

* Good, because usage stays within the installer's officially supported
  scope, reducing the risk of future installer changes breaking a
  workaround.
* Good, because root install, `chown -R`, and `/etc/nix` backup/restore
  disappear from postCreateCommand, and the only state left outside the
  /nix volume is `$HOME`.
* Good, because sha256 verification chains from the script to the
  tarball, giving stronger supply-chain pinning than the Determinate
  approach (whose installer binary hash is not embedded in the script).
* Bad, because the nix CLI version and behavior (lazy-trees etc.) diverge
  between the host (Determinate Nix 3.x) and the container (upstream
  2.31.x). Artifacts are identical thanks to flake.lock, but subtle CLI
  differences can confuse debugging.
* Bad, because upstream officially positions single-user mode as
  "discouraged", and if upstream ever removes it this will need
  reconsideration (no removal is planned at present).
* Bad, because Determinate's added features (FlakeHub cache,
  `determinate-nixd upgrade`, lazy-trees) are unavailable.

### Confirmation

Confirm that postCreateCommand succeeds via both paths — (1) a fresh
volume, (2) container re-creation reusing the volume — and that `nix
develop` / direnv loading works as the vscode user without root
privileges. Confirm with `ps` that no nix-daemon exists and with
`stat /nix/store` that it is owned by vscode.

## More Information

See the [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md)
for the detailed investigation.
Supersedes the installer-selection part of
[ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) (adoption of the
Determinate Nix Installer). ADR-0010's core decision (Approach 1:
devcontainer + flake devShell + persisted /nix volume) and
[ADR-0011](0011-fix-devcontainer-user-to-vscode-uid-1000.md)'s constraint
(fixed vscode/UID 1000) remain in effect.

* [Nix Reference Manual: Installation](https://nix.dev/manual/nix/2.29/installation/) — positioning of single-user / multi-user and the reasons single-user is discouraged.
* [DeterminateSystems/nix-installer#214](https://github.com/DeterminateSystems/nix-installer/issues/214) / [#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075) — feature requests for non-root single-user installation (unimplemented).
* [nix-installer src/cli/mod.rs `ensure_root()`](https://github.com/DeterminateSystems/nix-installer/blob/main/src/cli/mod.rs) — implementation of root enforcement (sudo self re-execution).
