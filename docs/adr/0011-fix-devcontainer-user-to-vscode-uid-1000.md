---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Fix the container user to vscode (UID 1000)

## Context and Problem Statement

[ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) decided to run
Nix inside the devcontainer in single-user mode (store owned by the
container user, no daemon). This requires deciding *who* the container
user is.

Investigation confirmed that the devcontainer user is not assumed to be
root; it is configuration-dependent.

* The base image `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
  creates a non-root user `vscode` (UID/GID 1000, passwordless sudo) via
  the common-utils feature and sets `remoteUser=vscode` in the image
  metadata.
* Lifecycle scripts (postCreateCommand etc.) run as `remoteUser`. If
  unset, `containerUser` is used; failing that, the image's default user
  (which may be root).
* `updateRemoteUserUID` (enabled by default on Linux) rewrites the
  remoteUser's UID/GID to match the host user at container creation and
  chowns only the home directory. The username does not change, and paths
  outside home such as `/nix` are untouched.

Furthermore, the Nix "install destination" is not a single place; it
splits into three layers with different owners and persistence.

| Layer | Location | Owner | Persistence |
|---|---|---|---|
| store / default profile (nix CLI itself) | `/nix` | store owner | persisted via named volume |
| system configuration | `/etc/nix`, `/etc/profile.d`, etc. | root | lost on container re-creation |
| user profile (direnv/nix-direnv/nil added via `nix profile add`; `~/.nix-profile` → `~/.local/state/nix/profiles`) | `$HOME` | container user | lost on container re-creation |

Single-user Nix breaks when the store owner's UID and the executing UID
diverge. Tracking an arbitrary remoteUser / UID would require checking
and running `chown -R /nix` on every start to cope with volume reuse
after a UID rewrite — but the store is large and chown cost scales with
store size. On the other hand, there is virtually no real-world case for
changing the container user away from the default `vscode` (UID 1000).

## Decision Drivers

* postCreateCommand speed: keep store-size-proportional work (like
  chowning the whole store) off the steady-state path.
* Simplicity: minimize the combinations of states the script must check
  and repair.
* Preserve ADR-0010's single-user configuration (no daemon, no build
  users).
* When the assumption breaks, fail detectably and explicitly rather than
  silently.

## Considered Options

* Fix the container user to `vscode` (UID 1000) and state it as an
  explicit constraint
* Run the installer itself as the vscode user so the store is
  vscode-owned from the start (eliminating chown)
* Resolve the user at runtime with `id -un` and check/fix ownership every
  time to track arbitrary users
* Fix `containerUser`/`remoteUser` to root and run single-user as root
* Return to multi-user (root-owned store + daemon) to support arbitrary
  users

## Decision Outcome

Chosen option: "Fix the container user to `vscode` (UID 1000) and state
it as an explicit constraint", because promoting the base image's default
(vscode/1000) to a constraint settles the store ownership with a single
chown at first install, eliminating all subsequent checks and repairs.
Tracking arbitrary users costs a store-size-proportional `chown -R /nix`
check on every start, which is not worth paying for flexibility that has
virtually no real-world use. Fixing to root goes against the base image's
design (non-root + sudo), and multi-user reintroduces the complexity
ADR-0010 rejected.

Implementation outline:

* Non-root installation is not an option: the Determinate Nix Installer
  enforces root via `ensure_root()`; started as non-root, it re-executes
  itself as root via `sudo --set-home`. There is no equivalent of the
  upstream legacy installer's "single-user install owned by the invoking
  user (`--no-daemon`)", and `--init none` is also a root-only layout.
  Therefore root install + a one-time chown at first install is the only
  path.

* Leave `remoteUser` as `vscode`, unchanged. Assume the host user's UID
  is 1000 (updateRemoteUserUID stays enabled at its default; on a
  UID-1000 host the rewrite is a no-op).
* At the top of postCreateCommand, verify `id -un` = `vscode` and
  `id -u` = 1000, and on violation fail immediately with the cause and
  remedy (reconsider this ADR).
* Run `chown -R vscode: /nix` only once, at first install.
* Ownership of the three install layers: run the installer as root
  (sudo) and chown the store to vscode. `/etc/nix` stays root-owned and
  is restored from the in-volume backup (ADR-0010). The user profile is
  built by vscode itself via `nix profile add`; since `$HOME` is lost on
  container re-creation, postCreateCommand rebuilds it idempotently every
  time (the store remains in the volume, so this completes without
  re-downloading).

### Consequences

* Good, because the steady-state path (volume reuse) has no
  store-size-proportional work, making container re-creation fast.
* Good, because the script can assume "the user is always vscode/1000",
  reducing the states to check and repair, and thus stays simple.
* Bad, because in environments where the host user's UID is not 1000
  (e.g. the second or later user on a multi-user Linux host),
  updateRemoteUserUID rewrites vscode's UID and the guard fails
  immediately. Using such an environment requires revisiting this ADR
  (the arbitrary-user-tracking option).
* Bad, because configurations that change remoteUser, or switching to a
  base image with a different username, are not possible (stating the
  constraint explicitly prevents silent breakage).
* Bad, because the user profile disappears along with `$HOME`, leaving
  dangling GC roots in `/nix/var/nix/gcroots/auto`, and the old profile's
  store paths become GC candidates (they are re-registered by the
  postCreateCommand rebuild, so the only real cost is rebuilding).

### Confirmation

The guard at the top of postCreateCommand automatically verifies the
constraint (vscode/1000) every time. Additionally confirm that the
devShell works via both paths — (1) a fresh volume, (2) container
re-creation reusing the volume — and (3) that opening as a host user with
a UID other than 1000 makes the guard fail with a clear error.

## More Information

See the [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md)
for the detailed investigation.
Of the implementation outline, "non-root installation is not an option"
was written under the assumption of the Determinate Nix Installer; after
switching to the upstream official installer (single-user mode, run as
the vscode user) in
[ADR-0012](0012-use-upstream-installer-single-user-mode.md), the root
install + chown and the `/etc/nix` restore are no longer needed. This
ADR's decision (fixing to vscode/UID 1000 with the guard) remains in
effect.

* [Dev Container Specification](https://containers.dev/implementors/spec/) — execution user of lifecycle scripts and the `remoteUser`/`containerUser` merge rules.
* [devcontainers/images src/base-ubuntu](https://github.com/devcontainers/images/tree/main/src/base-ubuntu) — creation of the `vscode` user by common-utils (username/userUid/userGid = vscode/1000/1000).
* [Add a non-root user to a container (VS Code docs)](https://github.com/microsoft/vscode-docs/blob/main/remote/advancedcontainers/add-nonroot-user.md) — behavior of `updateRemoteUserUID` (UID/GID rewrite and home chown).
* [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) — the underlying single-user configuration decision.
