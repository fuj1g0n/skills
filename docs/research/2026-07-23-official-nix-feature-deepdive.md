# Official Nix devcontainer Feature deep-dive (research snapshot)

Date: 2026-07-23. Immutable research snapshot (ADR-0006 tier 2), companion
to [2026-07-23-ghcr-prebuilt-devcontainer.md](2026-07-23-ghcr-prebuilt-devcontainer.md)
and [2026-07-23-devcontainer-nix-installer.md](2026-07-23-devcontainer-nix-installer.md).
Reads the actual source of `ghcr.io/devcontainers/features/nix` (v1.3.1,
`devcontainers/features` ref `765e8ebd`, `src/nix/`), its issue tracker,
and re-reads the two articles that ADR-0010 was based on, to decide the
best design for a generic devcontainer for flake.nix repositories.

## Summary

The official Nix Feature installs Nix at **image-build time** via the
upstream nixos.org installer script (no hash verification), then declares
a named volume `nix-store-${devcontainerId}` at `/nix` that shadows the
build-time install at runtime — a structural staleness problem confirmed
by open issue #1505 with no mitigation in the Feature. Multi-user mode
requires passwordless sudo (silent daemon-start failure without it) and
its `packages` option has an open PATH bug (#1573, fix PR #1691 unmerged
as of 2026-07-23). The Feature does not provide direnv/nix-direnv; the
community direnv Feature is unmaintained (last commit 2023-08-17).
Neither of the two reference articles used the official Feature; both
independently converged on the custom single-user postCreateCommand
pattern this repository uses. Recommendation: keep the custom approach
(option c), evolve into a custom Feature (option d) for cross-repository
distribution.

## 1. install.sh mechanics

Source: `devcontainers/features:src/nix/install.sh` (sha `0030c2b`).

### 1.1 Installer and version resolution

```bash
# install.sh:34–36
find_version_from_git_tags VERSION https://github.com/NixOS/nix "tags/"
curl -sSLf -o "${tmpdir}/install-nix" https://releases.nixos.org/nix/nix-${VERSION}/install
```

* Resolves `latest` (or partial versions like `2.11`) against
  `git ls-remote --tags` of NixOS/nix; falls back one version if the
  release download 404s.
* Downloads the upstream release install script with **no GPG/hash
  verification** — a supply-chain gap that the ncaq article addresses by
  SHA256-pinning (the pattern this repository adopted in ADR-0012).

### 1.2 Multi-user vs single-user

**Multi-user** (`multiUser=true`, default): `sh install-nix --daemon` as
root. Creates nixbld group/users, `/etc/nix/nix.conf`, root-owned store.
The installer does not start the daemon (no systemd in containers);
daemon start is deferred to the entrypoint (§3).

**Single-user** (`multiUser=false`):

```bash
# install.sh:59–68
mkdir -p /nix
chown ${USERNAME} /nix ${tmpdir}
su ${USERNAME} -c "sh \"${tmpdir}/install-nix\" --no-daemon --no-modify-profile"
```

`${USERNAME}` is resolved at build time by `detect_user()` (`utils.sh`):
`_REMOTE_USER` env var, then probing for `vscode`/`node`/`codespace`,
then the UID-1000 user from `/etc/passwd`, else root (rejected for
single-user). `/nix` is chowned to that user **at image build time**, so
the owning UID is baked into the image. The script itself warns at build
time: "Nix will only work for user ${USERNAME} on Linux if the host
machine user's UID is $(id -u ${USERNAME}). You will need to chown /nix
otherwise." `NOTES.md` repeats this ("If this user's UID/GID is updated,
that user will no longer be able to work with Nix"). Our custom approach
avoids this because the chown runs at container-create time against the
already-remapped UID.

PATH snippets sourcing `~/.nix-profile/etc/profile.d/nix.sh` are appended
to `.bashrc`, `.zshenv`, and `.profile`.

### 1.3 PATH wiring discrepancy

`devcontainer-feature.json` sets:

```json
"containerEnv": {
  "PATH": "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:${PATH}"
}
```

This is the **multi-user default profile** path. In single-user mode the
binaries live under `~/.nix-profile/bin`, which `containerEnv.PATH` does
not cover — Nix is on PATH only in shells that source the rc snippets,
not in exec contexts (VS Code task runners, language-server startup)
unless `userEnvProbe` is `loginInteractiveShell`.

### 1.4 `packages` and `flakeUri`

Handled by `post-install-steps.sh` (sha `68f93a3`): `nix-env -iA` /
`nix-env --install` for `packages`, `nix profile install` for `flakeUri`,
run inside `su ${USERNAME} -c` sourcing the daemon profile script.

* **Bug #1573** (open, 2026-02-16, labeled bug): in multi-user mode
  `nix-env` inside the `su` subshell defaults to the per-user profile
  `~/.nix-profile`, but `containerEnv.PATH` only adds the default
  profile — packages installed via the `packages` option are unreachable
  at runtime. Fix PR #1691 (2026-07-22) proposes installing into
  `/nix/var/nix/profiles/default`; **unmerged as of 2026-07-23** (bug
  open 5 months).
* **Issue #1518** (open): `flakeUri` cannot reference the repository's
  own `flake.nix` — the workspace is not mounted at build time; only
  remote URIs work.

### 1.5 nix.conf

```bash
# install.sh:74–93
create_or_update_file /etc/nix/nix.conf 'sandbox = false'          # always
# 'experimental-features = nix-command flakes'                     # only if flakeUri set
# each comma-separated element of extraNixConfig appended
```

Flakes are **not enabled by default** (issue #1519, open 2025-11-23,
requesting flakes-by-default; no maintainer action). Consumers must pass
`extraNixConfig = "experimental-features = nix-command flakes"`.
`sandbox = false` is always written (correct in containers).

## 2. nix-entrypoint.sh

Source: `src/nix/nix-entrypoint.sh` (sha `0ec7188`). For single-user
installs, install.sh replaces it with a stub `exec "$@"` (no logic). For
multi-user:

* Checks `pidof nix-daemon`; if absent and running as root, starts the
  daemon in a background subshell (log to `/tmp/nix-daemon.log`).
* Non-root: falls back to `sudo -n sh -c '... nix-daemon ...' &`. `-n`
  is non-interactive: **if passwordless sudo is absent, the daemon
  silently never starts** — `$?` of a backgrounded fork is 0, so
  `start_ok=true` and no error surfaces; every later `nix` command fails
  with a socket error. `NOTES.md` documents the passwordless-sudo
  requirement.
* `exec "$@"` immediately after — **no wait/poll for daemon readiness**;
  a terminal opened within the first few hundred ms can see connection
  errors. This is the daemon race the sigma_devsecops article hit
  (its "Failure 4", §5).
* Feature entrypoints compose with (are not replaced by) the consuming
  `devcontainer.json`'s `overrideCommand`, which controls CMD only. With
  `mcr.microsoft.com/devcontainers/base` (CMD `sleep infinity`) the
  chaining works in both VS Code and the devcontainer CLI.

## 3. Volume handling and known issues

`devcontainer-feature.json` declares
`{"source": "nix-store-${devcontainerId}", "target": "/nix", "type": "volume"}`.
`${devcontainerId}` is scoped to the devcontainer config, not the image
digest, so the volume persists across image rebuilds.

install.sh runs during `docker build` with no volume mounted: Nix lands
in the image layer's `/nix`. At runtime, Docker copy-on-first-use seeds a
fresh empty volume from the image layer (works), but an **existing volume
shadows the image layer entirely**: after an image rebuild (new Nix
version, changed `packages`, new base), the volume still holds the old
store, profile symlinks dangle, and the new store paths are hidden.
**Neither the entrypoint nor any script checks store integrity or
re-seeds the volume — there is zero staleness handling.** The only
workaround is manual `docker volume rm`.

Known issue index (devcontainers/features, state as of 2026-07-23):

| # | Title | State | Date |
|---|---|---|---|
| #275 | Nix feature doesn't work on GitHub Codespaces universal image | Open (bug, external) | 2022-11-11 |
| #1093 | Nix post-installation script failing | Open (gathering-community-feedback) | 2024-08-15 |
| #1505 | Nix store volume not updating during rebuilds | Open | 2025-10-20 |
| #1518 | flakeUri cannot reference local flake.nix | Open | 2025-11-23 |
| #1519 | Enable flakes by default | Open | 2025-11-23 |
| #1573 | Packages installing but not in PATH (multi-user profile mismatch) | Open (bug) | 2026-02-16 |
| #1691 | PR: fix packages PATH mismatch in multi-user mode | Open PR | 2026-07-22 |

## 4. Multi-user specifics and direnv provisioning

* **Passwordless sudo**: required for daemon auto-start when the
  container is not running as root (`NOTES.md`). The official base
  images configure `NOPASSWD` for vscode; custom bases without it fail
  silently (§2).
* **Sandbox**: `sandbox = false` always written; correct, no action
  needed.
* **Per-user profiles in multi-user mode**: `nix profile install` /
  `nix-env -i` work for vscode without extra setup (daemon handles store
  writes); `~/.nix-profile/bin` reaches PATH only via shell rc sourcing.
* **direnv/nix-direnv/nil/nixfmt**: the Feature installs **only Nix**.
  The sole community Feature,
  `ghcr.io/devcontainers-community/features/direnv` (v1.0.0), installs
  direnv via direnv.net's install.sh and hooks `/etc/bash.bashrc`; last
  commit 2023-08-17, no nix-direnv integration — effectively
  unmaintained. A working direnv+nix-direnv stack therefore still needs
  custom postCreateCommand scripting, negating the Feature's savings for
  our use case.

## 5. Reference articles and prior art

**sigma_devsecops (Qiita, 2026-05)** — does **not** mention the official
Nix Feature; independently chose the custom postCreateCommand pattern.
Documented "失敗4: nixをmulti userモードでインストールする": "postCreateCommand
実行時にmulti userモードの場合にはNix Deamonの起動を待つ必要がある。そのためsingle user
modeでインストールする方針に変更" — precisely the daemon race in §2. Volume:
unnamed `nix-store` volume + `[ ! -w /nix ] && sudo chown -R vscode: /nix`.
direnv via apt in Dockerfile, nix-direnv via `nix profile install`.

**ncaq (2026-01-16)** — also does **not** evaluate the official Feature.
Single-user because "DevContainerではsystemdが動いていないので、デーモンモードで
インストールすると正常に動作しません". SHA256-pins the installer script
(the supply-chain gap the official Feature leaves open). Volume:
`nix-store-${devcontainerId}` + chown-on-first-mount. direnv/nix-direnv/nil
global via `nix profile add` ("VS CodeのNix拡張機能がうまくdirenvの環境を
認識できないのでグローバルに入れる"); mentions the community direnv Feature
but did not use it.

**Other prior art**: xtruder/nix-devcontainer — not found/abandoned.
Determinate Systems — no official devcontainer guidance; their installer
is root/multi-user only (see the 2026-07-23 installer snapshot).
devenv (cachix) — different workflow (devenv instead of flake devShells),
no devcontainer Feature. devcontainers/spec#60 (Feature lifecycle hooks)
was **closed as completed 2023-04-07**: Features can now contribute
lifecycle commands such as `onCreateCommand`, but the official Nix
Feature has not been updated to use this for workspace-flake installs
(its NOTES.md still cites #60 as a limitation).

## 6. Synthesis

| Criterion | (a) Official Feature, multiUser=true | (b) Official Feature, multiUser=false | (c) Custom postCreateCommand (current) | (d) Custom Feature wrapping (c) |
|---|---|---|---|---|
| Nix install timing | Build-time (image layer) | Build-time (image layer) | Create-time (into mounted volume) | Create-time via Feature-contributed lifecycle hook |
| Volume behavior | Broken on rebuild (#1505), no mitigation | Same fatal flaw | Correct: installs into the already-mounted volume; rebuild re-runs against the volume | Correct if install is deferred to create-time hook |
| UID robustness | Good (daemon owns store) | Fragile: /nix chowned to build-time UID | Robust: chown runs at create time against actual runtime UID | Robust (same) |
| Passwordless sudo | Required; silent failure without | No | No (single non-recursive chown only) | No |
| Flakes by default | No (#1519) | No | Yes (user-controlled ~/.config/nix/nix.conf) | Yes |
| `packages` option | Broken (#1573, PR #1691 unmerged) | Same code path | N/A (explicit installs) | N/A |
| direnv/nil/nixfmt | Separate provisioning needed; community feature abandoned | Same | Explicit in postCreateCommand, full control | Explicit in hook, full control |
| Prebuilt-image compatibility | Poor (volume staleness defeats prebuild) | Same | Good as a *pattern* (no Nix in image; install at create time) | Good |
| Maintenance | Upstream-owned but 5+ open bugs, slow response | Same | Script owned by us | One-time wrap; versioned on GHCR |
| Supply chain | No installer hash verification | Same | SHA256-pinned installer | SHA256-pinned installer |

**Recommendation: keep (c) now; evolve to (d) for distribution.**
Option (a) stacks three blockers: volume staleness (#1505) is structural
to build-time-install + persistent volume; the packages bug (#1573) is
unmerged after 5 months; daemon start silently requires passwordless
sudo. Option (b) keeps the staleness flaw and adds baked-UID fragility.
Option (c) is architecturally correct — install after the volume mounts,
chown at runtime UID, SHA256-pinned installer, explicit tool provisioning
— and both reference articles independently converged on it. Option (d)
wraps (c) as a Feature published to GHCR: `install.sh` copies the setup
script into the image and registers it as an `onCreateCommand` lifecycle
hook (possible since spec#60 closed), giving consuming repositories a
one-line `features` reference with versioned releases, while keeping the
create-time install semantics that make the volume design correct.

Implication for [ADR-0015](../adr/0015-distribute-devcontainer-as-custom-feature-on-ghcr.md)
(proposed): the earlier snapshot's tentative recommendation "adopt the
official Feature with multiUser=true inside a prebuilt image" is
contradicted by the Feature's source and issue tracker; the prebuilt
*image* route inherits the staleness architecture, whereas a custom
*Feature* on GHCR (option d) achieves the distribution goal without it.
