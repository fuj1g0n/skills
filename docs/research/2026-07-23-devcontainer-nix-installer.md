# Devcontainer Nix installer: single-user feasibility survey (snapshot)

Date: 2026-07-23. Immutable research snapshot backing ADR-0010/0011/0012.
Sources are primary: installer source code, official manuals, upstream issue
trackers, and the Dev Container specification. Originally researched while
prototyping in fuj1g0n-demo-01/slides; the environment now lives in this
repository.

## 1. Dev Container user model (backing ADR-0011)

From the [Dev Container Specification](https://containers.dev/implementors/spec/),
[devcontainers/images src/base-ubuntu](https://github.com/devcontainers/images/tree/main/src/base-ubuntu)
and [VS Code non-root user docs](https://github.com/microsoft/vscode-docs/blob/main/remote/advancedcontainers/add-nonroot-user.md):

* The devcontainer user is not assumed to be root; it is
  configuration-dependent.
  `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` creates the
  non-root user `vscode` (UID/GID 1000, passwordless sudo) via the
  common-utils feature and sets `remoteUser=vscode` in the image
  metadata.
* Lifecycle scripts (postCreateCommand etc.) run as `remoteUser`. If
  unset, `containerUser`; failing that, the image's default user.
* `updateRemoteUserUID` (enabled by default on Linux) rewrites the
  remoteUser's UID/GID to match the host user at container creation and
  chowns only the home directory. Paths outside home such as `/nix` are
  untouched.
  → With host UID ≠ 1000, the owning UID of the store inside the volume
  diverges from the executing UID.

## 2. The three layers of a Nix installation (backing ADR-0011)

The "Nix install destination" splits into three layers with different
owners and persistence.

| Layer | Location | Persistence (with /nix volume) |
|---|---|---|
| store / db / gcroots | `/nix` | persisted via named volume |
| system configuration | `/etc/nix` etc. | lost on container re-creation |
| user profile (`~/.nix-profile` → `~/.local/state/nix/profiles`) | `$HOME` | lost on container re-creation |

In single-user mode (ADR-0012) the `/etc/nix` layer disappears, and the
nix CLI itself lives in the user-profile layer, so on volume reuse the
profile must be rebuilt from the store with `nix-env -i` (the store paths
remain in the volume; the symlinks in `/nix/var/nix/gcroots/auto`
pointing to the old profile become dangling, but the rebuild re-registers
them, so there is no real harm).

## 3. The Determinate Nix Installer enforces root (backing ADR-0012)

* `ensure_root()` in `src/cli/mod.rs` re-executes the installer as root
  via `sudo --set-home` when started as non-root. Not avoidable.
* The only supported layout is the multi-user model of "root-owned store
  + daemon + build users". `--init none` merely skips init integration;
  it is still a root-only layout, not a user-owned mode.
* `--nix-build-user-count 0` exists (build users are unnecessary when
  daemonless). `build-users-group` is written to nix.conf only when it
  differs from the default name.
* Non-root / user-owned single-user installation has been requested in
  [nix-installer#214](https://github.com/DeterminateSystems/nix-installer/issues/214)
  and
  [nix-installer#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075),
  open for years and unimplemented. "chown `/nix` after a root install"
  is a community workaround and is inconsistent with root-ownership-based
  features such as `determinate-nixd upgrade` — i.e. off-label use.

## 4. The upstream official installer's single-user mode (backing ADR-0012)

* `sh install --no-daemon` runs as the invoking user and builds the store
  owned by that user (officially supported). It does not create
  `/etc/nix`.
* The wrapper script (`releases.nixos.org/nix/nix-<ver>/install`) embeds
  the per-architecture tarball sha256s, so hash-pinning the script itself
  chains verification through to the tarball.
  Script sha256 for 2.31.2:
  `078e2ffeddf6a9c1f22adf41458ccc46a58bb26911a9e01579645314f9982994`.
* The actual logic inside the tarball is
  `scripts/install-nix-from-tarball.sh` (verified against NixOS/nix
  2.31.2). If `/nix` exists and is writable it is used as-is; store paths
  are copied and a profile is created with `nix-env -i`. It accepts
  `--yes --no-channel-add --no-modify-profile`.
* Upstream discourages single-user because (a) builds run with the
  invoking user's privileges, (b) there is no build-user separation,
  (c) the store cannot be shared between users
  ([Nix manual: Installation](https://nix.dev/manual/nix/2.29/installation/)).
  None of these applies to a devcontainer that is single-user with the
  container itself as the isolation boundary; rather, a devcontainer
  without systemd matches the intended use case of "environments that
  cannot run the daemon".
* Flakes are experimental upstream, so
  `experimental-features = nix-command flakes` is required in
  `~/.config/nix/nix.conf`. Sandboxing requires root or user namespaces,
  so set `sandbox = false` (the container provides isolation).
* `nix profile` can read nix-env-style profiles (`manifest.nix`) and
  migrates them to the new format on first write (ProfileManifest in
  `src/nix/profile.cc`). Combining the installer's `nix-env -i` with
  postCreateCommand's `nix profile add` therefore works.

## 5. Conclusion

Starting from ADR-0010 (Approach 1: generic image + postCreateCommand +
/nix volume), ADR-0011 fixed the user to vscode/UID 1000 (removing
store-size-proportional chown from the steady-state path), and ADR-0012
adopted the upstream single-user installer (eliminating root escalation,
`chown -R`, and `/etc/nix` restore entirely, and ending the off-label
usage).
