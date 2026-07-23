# GHCR prebuilt devcontainer image: feasibility and pitfalls (research snapshot)

Date: 2026-07-23. Immutable research snapshot (ADR-0006 tier 2) backing
ADR-0015 (proposed). Investigates publishing the repository's generic Nix
devcontainer (ADR-0010..0014) as a prebuilt image on GitHub Container
Registry (GHCR) for cross-repository reuse. Sources are primary: GitHub
Docs, the containers.dev spec, devcontainers/ci and devcontainers/features
upstream repositories, and Docker documentation, fetched 2026-07-23.


## Executive Summary

Publishing a devcontainer image to GHCR is well-supported by the official toolchain and is free for public images. **However, our current design has a fundamental conflict with prebuilding:** `devcontainer build` does not execute `postCreateCommand`, so a naive prebuild produces only the bare Ubuntu base image — no Nix installed at all. Realizing any benefit requires restructuring the installation to use the official Nix Feature or a Dockerfile `RUN`-based install. Even after restructuring, the named-volume `/nix` design introduces subtle but serious staleness pitfalls upon image updates, and single-user Nix ownership baked at UID 1000 is fragile on Linux hosts. The `/nix` named volume already amortizes the one-time installation cost for repeat users on the same machine, so the net benefit of a prebuilt image is narrower than it initially appears: it primarily helps first-time users on new machines and ephemeral CI environments.

---

## 1. GHCR Basics

### 1.1 Can Container Images Be Published to GHCR?

Yes. GHCR is GitHub's first-class OCI registry at `ghcr.io`. It supports:
- Docker Image Manifest V2, Schema 2
- Open Container Initiative (OCI) Specifications
- Multi-arch image manifests (OCI image index)
- Foreign layers (e.g., Windows images)

Images are namespaced under a personal account or organization:
```
ghcr.io/NAMESPACE/IMAGE_NAME:TAG
```

> Source: [docs.github.com — Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### 1.2 Storage and Bandwidth Costs for Public Images

The GitHub Packages billing page states two relevant facts:

> **"GitHub Packages usage is free for public packages."**

And a special note specific to the Container registry:

> **"Billing for container image storage: Container image storage and bandwidth for the Container registry is currently free. If you use Container registry, you'll be informed at least one month in advance of any change to this policy."**

> Source: [docs.github.com — GitHub Packages billing](https://docs.github.com/en/billing/concepts/product-billing/github-packages)

**Interpretation:** Public GHCR images currently incur zero cost for both storage and egress bandwidth to the publisher, regardless of pull volume. This is explicitly more generous than the general GitHub Packages free tier table (which applies to private package storage). The "currently free" language for Container registry bandwidth is a separate, stronger commitment than the plan-quota table — GitHub commits to one month's advance notice before changing it. This is distinct from Docker Hub, which bills egress for all accounts.

### 1.3 Rate Limits on Anonymous and Authenticated Pulls

GitHub has **no documented pull rate limit for GHCR public images**. The permissions documentation explicitly states:

> **"In the Container registry, public packages allow anonymous access and can be pulled without authentication or signing in via the CLI."**

> Source: [docs.github.com — About permissions for GitHub Packages](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages)

For comparison, Docker Hub imposes 10 pulls/hour for unauthenticated users and 100/6h for free authenticated users (as of April 2025). GHCR has no equivalent published limit. Community tracking of this (github/docs issue #24504) confirms transient pull errors are infrastructure incidents, not rate-cap enforcement.

**Caveat — Excessive Bandwidth clause:** The Acceptable Use Policy states:

> **"If we determine your bandwidth usage to be significantly excessive in relation to other users of similar features, we reserve the right to suspend your Account, throttle your file hosting, or otherwise limit your activity."**

> Source: [docs.github.com — GitHub Acceptable Use Policies §9](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)

For a devcontainer image serving a small-to-medium team or even a moderately popular open-source project, this is not a practical concern. Hosting a devcontainer image that gets pulled by hundreds of developers is exactly the intended use case of GHCR public packages.

### 1.4 Package Retention and Deletion Policies

**There is no automatic expiration or garbage collection of GHCR packages.** Packages persist until explicitly deleted by an admin via:
- The web UI (Package Settings → Delete package / Delete version)
- The GitHub REST API
- GitHub Actions with `delete:packages` scope

Untagged image digests accumulate over time. For public images (currently free storage) this is benign, but good hygiene practice is to prune old untagged digests in the push workflow (e.g., using `actions/delete-package-versions` or similar). There is no equivalent of Docker Hub's 6-month inactivity auto-deletion for GHCR.

### 1.5 GHCR Visibility — Critical Default Behavior

**The default visibility of a newly pushed GHCR package is PRIVATE.**

> **"When you first publish a package, the default visibility is private."**

> Source: [docs.github.com — Working with the Container registry (Pushing container images)](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

To allow anonymous pulls (required for devcontainer use without credentials), you must explicitly navigate to Package Settings and set visibility to **Public**. This is a one-time manual action per package — it cannot be done via `docker push` or `GITHUB_TOKEN` in a workflow. Forgetting this step is the #1 operational pitfall for new GHCR setups.

**Permission inheritance:** If you push from a GitHub Actions workflow using `GITHUB_TOKEN`, and you add the label `org.opencontainers.image.source=https://github.com/OWNER/REPO` to the image, the package is automatically linked to that repository and inherits its access permissions. For a public repository, the package would inherit read access for everyone — but visibility (public vs. private) is still set separately and defaults to private.

---

## 2. Devcontainer Prebuild Mechanism

### 2.1 The `devcontainer build` CLI Command

The official CLI for prebuilding:

```bash
devcontainer build \
  --workspace-folder . \
  --push true \
  --image-name ghcr.io/NAMESPACE/IMAGE_NAME:TAG
```

> Source: [containers.dev — Reference: Prebuilding](https://containers.dev/implementors/reference/#prebuilding)

The `devcontainers/ci` GitHub Action wraps this CLI (since v0.3, which updated to use `@devcontainers/cli` under the hood). The canonical prebuild workflow:

```yaml
name: Prebuild devcontainer
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * 0'  # weekly rebuild for base image security patches

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/NAMESPACE/IMAGE_NAME
          cacheFrom: ghcr.io/NAMESPACE/IMAGE_NAME
          push: always
```

> Source: [github.com/devcontainers/ci — docs/github-action.md](https://github.com/devcontainers/ci/blob/main/docs/github-action.md)

The action uses Docker BuildKit for efficient layer caching. Layer cache is stored with the image in GHCR and reused on subsequent builds via `cacheFrom`.

### 2.2 What `devcontainer build` Bakes Into the Image — and What It Definitively Does NOT

This is the most important distinction for our design.

#### What IS baked into the image:

| Component | Mechanism |
|---|---|
| Base image filesystem | Pulled and baked as image layer |
| `features` listed in `devcontainer.json` | Feature `install.sh` scripts run **as root** during the Docker build step. The CLI generates an ephemeral Dockerfile with `RUN` instructions for each Feature, in dependency order. |
| `/etc/nix/nix.conf`, `/usr/local/share/nix-entrypoint.sh`, etc. | Written by Feature install scripts |
| `devcontainer.metadata` image label | Automatically embedded by CLI/Action (see §2.3) |
| Any `RUN` instructions in a referenced Dockerfile | Normal Dockerfile build |

#### What is NOT baked — under any circumstances:

| Component | Why |
|---|---|
| **`postCreateCommand`** | Runs at container startup, after the container is running. Never executed during image build. |
| `onCreateCommand` | Same — runs at startup (specifically on first creation). Not during image build. |
| `updateContentCommand` | Same — runs at startup. |
| `postStartCommand` | Same. |
| `postAttachCommand` | Same. |
| **Named volume contents** | Volumes are runtime constructs. During `devcontainer build`, no volumes are mounted. The image filesystem at `/nix` reflects only what was written by `RUN` instructions or Feature scripts. |

**Authoritative citation for the postCreate exclusion** (from Codespaces prebuilds docs, which are explicit about lifecycle command ordering):

> **"When a prebuild configuration workflow runs, GitHub creates a temporary codespace, performing setup operations up to and including any `onCreateCommand` and `updateContentCommand` commands in the `devcontainer.json` file. No `postCreateCommand` commands are run during the creation of a prebuild."**

> Source: [docs.github.com — About GitHub Codespaces prebuilds](https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds)

Note: This quote describes Codespaces prebuilds (which DO run onCreate/updateContent in a live container before snapshotting). For `devcontainer build` CLI, the behavior is even stricter — **no lifecycle commands run at all**; only the Docker image is built.

### 2.3 The `devcontainer.metadata` Label — Embedding and Merge Logic

When the CLI or CI Action builds an image, it automatically embeds a `devcontainer.metadata` label on the image containing a JSON array of configuration snippets from `devcontainer.json` and each Feature's `devcontainer-feature.json`. This makes the image self-describing.

> **"This metadata label is automatically added when you pre-build using the Dev Container CLI... and includes settings from `devcontainer.json` and any referenced Dev Container Features."**

> Source: [containers.dev — Reference: Metadata in image labels](https://containers.dev/implementors/reference/#labels)

The spec documents which properties are 🏷️ (label-eligible). All the major ones are:
`remoteUser`, `containerUser`, `mounts`, `customizations`, `capAdd`, `securityOpt`, `init`, `privileged`, `onCreateCommand`, `updateContentCommand`, `postCreateCommand`, `postStartCommand`, `postAttachCommand`, `remoteEnv`, `containerEnv`, `forwardPorts`, `updateRemoteUserUID`, `hostRequirements`, etc.

When a consuming repo's `devcontainer.json` references the prebuilt image (via `"image": "ghcr.io/..."`), the CLI reads the `devcontainer.metadata` label and **merges** it with the consuming `devcontainer.json`. The merge rules per the spec:

| Property | Merge Rule |
|---|---|
| `remoteUser` | **Last value wins** — consuming repo's `devcontainer.json` is always "last", so it overrides |
| `mounts` | **Collected list; for same `source`, last wins** — both sets of mounts are applied; duplicates collapsed |
| `postCreateCommand` | **Collected list** — ALL postCreateCommands from image label AND consuming devcontainer.json run, in order |
| `onCreateCommand` | Collected list — same |
| `capAdd`, `securityOpt` | Union without duplicates |
| `customizations` | Left to tools (VS Code merges settings keys) |
| `init`, `privileged` | `true` if any source is `true` |

> Source: [containers.dev — Image Metadata: Merge Logic](https://containers.dev/implementors/spec/#merge-logic)

**Critical operational implications of the merge:**

1. **`mounts` are sticky in the image label.** If our prebuilt image's `devcontainer.metadata` embeds the `/nix` volume mount, a consuming repo's `devcontainer.json` that simply says `"image": "ghcr.io/..."` with no explicit `mounts` will still get the `/nix` volume mount applied — because it comes from the label. You cannot opt out of a mount baked into the image label without workarounds. (You could override with `volume-nocopy` or an incompatible source name, but there's no "remove inherited mount" syntax.)

2. **`postCreateCommand` accumulates.** If both the image label and the consuming repo define a `postCreateCommand`, both run. This means the consuming repo can still add project-specific setup on top of the prebuilt image's postCreate.

3. **`remoteUser` can be overridden by consuming repo**, which is useful but means the consuming repo must be explicit if it needs a different user than what the image label specifies.

---

## 3. Pitfalls Specific to Our Nix-in-Volume Design

### 3.1 The Fundamental Conflict: Our Nix Install Is In postCreateCommand

**This is the root blocker.** Our `postCreateCommand.sh`:
- Runs the upstream Nix installer (single-user mode, as user `vscode`)
- Pins `NIXPKGS_REV` and installs `direnv`, `nix-direnv`, `nil`, `nixfmt` into the user profile
- Optionally warms up the project's flake devShell

Since `devcontainer build` does not run `postCreateCommand`, a prebuild of our current `devcontainer.json` produces an image that is **just `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` with no modifications**. This image is no different from what we already have. It would consume GHCR storage and CI time in exchange for zero benefit.

**Conclusion:** Prebuilding requires restructuring the Nix installation out of `postCreateCommand` and into either:
- A devcontainer Feature (runs `install.sh` at `devcontainer build` time)
- A `Dockerfile` `RUN` step
- A custom Feature published to GHCR

The rest of Section 3 assumes this restructuring has happened.

### 3.2 Named Volume, Docker Copy-on-First-Use (COFU), and the Staleness Trap

Docker's behavior for named volumes is precisely documented:

> **"If you mount an _empty volume_ into a directory in the container in which files or directories exist, these files or directories are propagated (copied) into the volume by default."**

> **"If you mount a _non-empty volume_ into a directory in the container in which files or directories exist, the pre-existing files are obscured by the mount."**

> Source: [docs.docker.com — Volumes: Mounting a volume over existing data](https://docs.docker.com/engine/storage/volumes/)

The COFU behavior can be suppressed with `volume-nocopy` (a `--mount` flag option or an option in the mounts array), but our current setup and the official Nix Feature do not set this.

**Applying this to our design (assuming Nix IS baked into the image at `/nix`):**

| Scenario | What Happens | Safe? |
|---|---|---|
| **First container creation, volume `nix-store-<devcontainerId>` does not yet exist** | Docker creates an empty named volume. The COFU behavior triggers: image's `/nix` content is copied into the volume. Container has working Nix. | ✅ Works |
| **"Rebuild Container" in VS Code, volume still exists and is populated** | Existing volume (with previously accumulated Nix store) is mounted. Image's `/nix` is shadowed. User sees old Nix store contents. postCreateCommand still runs and can add to/update the store. | ✅ Mostly fine for same image |
| **Image is updated (new Nix version, new tool versions baked), same old volume still exists** | Old volume is mounted. New image's `/nix` is completely shadowed. Developer **never sees the new Nix content from the image** without explicitly deleting the volume. | ❌ Silent staleness |
| **Developer deletes volume (`docker volume rm nix-store-<id>`) then rebuilds** | Empty volume → COFU copies new image's `/nix` → Updated store. | ✅ Works, but requires deliberate manual action |
| **New machine / new clone (different `devcontainerId`)** | New volume name → COFU from image → Fast first start, no postCreate install wait. | ✅ This is the primary benefit of a prebuilt image |

**The critical staleness pitfall, fully stated:** Once the volume is seeded (after first container creation), any subsequent image update that modifies `/nix` is silently ignored. Developers who rebuilt their container without deleting the volume get the old Nix store. There is no tooling today that detects this mismatch or prompts the user to refresh. The `devcontainerId` in the volume name is stable per workspace path, so it doesn't change on rebuild.

**The `volume-nocopy` escape hatch (and why it destroys the benefit):** If you set `volume-nocopy` on the `/nix` mount, the COFU seeding never happens — the empty volume is always mounted empty, and `postCreateCommand` must install Nix from scratch every time (unless it detects an existing install in the volume). This defeats the purpose of prebuilding.

### 3.3 Dangling Symlinks — The Home Directory / Nix Profile Interplay

This is the **most insidious pitfall** and requires careful analysis.

**How Nix user profiles work:**
- Single-user Nix installs tools into the Nix store under `/nix/store/...`
- The user's "profile" is a directory tree at `/nix/var/nix/profiles/per-user/vscode/profile-N-link/`
- `~/.nix-profile` is a symlink → `/nix/var/nix/profiles/per-user/vscode/profile-N-link`
- `~/.bashrc` (or `~/.profile`) sources `$HOME/.nix-profile/etc/profile.d/nix.sh`
- `~/.local/state/nix/` (modern Nix) contains additional profile state with symlinks into `/nix/var/...`

**What is in the image filesystem vs. the volume:**

| Location | In image? | In `/nix` volume? | Notes |
|---|---|---|---|
| `/nix/store/*` | Yes (baked by Feature) | Copied to volume by COFU | Contains all Nix packages |
| `/nix/var/nix/profiles/per-user/vscode/` | Yes (baked) | Copied to volume by COFU | Profile symlink chain |
| `~/.nix-profile` | **Yes (baked, in home dir)** | **No (home is NOT in volume)** | Symlink in container's home |
| `~/.bashrc` Nix sourcing line | **Yes (baked)** | **No** | Written by installer |
| `~/.local/state/nix/` | **Yes (baked)** | **No** | Modern Nix profile state |

**Scenario A — First run, empty volume (COFU triggers):**
- COFU copies image's `/nix/store/*` and `/nix/var/nix/profiles/...` into volume
- `~/.nix-profile` → `/nix/var/nix/profiles/per-user/vscode/profile-N-link` → volume content
- Symlink chain is valid ✅

**Scenario B — Existing volume, same image version:**
- Volume has accumulated packages via `nix-env -i` or flake installs during previous sessions
- `~/.nix-profile` still points into `/nix/var/nix/profiles/...` which is in the volume
- Symlink chain is valid ✅ (profile generation number may have advanced; `~/.nix-profile` points to newest)

**Scenario C — Image updated (new Nix version, new profile generation baked in), OLD volume:**
- Old volume is mounted, shadowing the image's `/nix`
- `~/.nix-profile` (from image, in home dir) now points to `/nix/var/nix/profiles/per-user/vscode/profile-M-link` (the new generation baked in the image)
- But the old volume at `/nix/var/nix/profiles/per-user/vscode/` only has generations up to `profile-N-link` (old)
- If `M > N`: **`~/.nix-profile` is a dangling symlink** → `nix` command not found, tools not in PATH ❌
- If the image bakes a fresh profile starting at generation 1 again (e.g., new install): same issue

**Scenario D — postCreateCommand re-runs Nix install detection:**
- If our postCreateCommand script checks `[ -d /nix/store ]` and skips re-install if present: the OLD volume is accepted, the script doesn't fix the dangling symlink from `~/.nix-profile`
- If the script unconditionally re-links `~/.nix-profile`: requires Nix to be functional first to run `nix-env`, which is a circular dependency

**This is a genuine breakage scenario**, not just theoretical. In practice, if you push an updated prebuilt image where the baked Nix store has a newer generation/profile path, any developer with an existing volume will land in a broken container on their next rebuild. They will need to either delete the volume OR the postCreateCommand must be defensively written to always re-run `nix-env --set-flag priority 0 ~/.nix-profile/...` or similar profile fixup.

**Mitigation options:**
1. **Never mutate profile paths between image versions** — ensure the baked Nix install always produces the same symlink path (e.g., always generation 1, always fresh). This is fragile.
2. **postCreateCommand always re-runs `nix-env` setup** — detect stale profile and relink. Still requires Nix to be partially functional.
3. **Use the volume for the store, not for profiles** — store profile state in `~/.nix-profile` pointing to a store path that DOES exist in the current volume. The official Nix Feature's multi-user mode addresses this differently (daemon manages profiles).
4. **Don't use a volume** — bake everything into the image, no runtime volume. Eliminates staleness entirely but loses persistence and increases image size and pull time.

### 3.4 Single-User Nix Ownership Baked at UID 1000

The official Nix Feature documentation explicitly warns:

> **"Only works with the user specified in the `remoteUser` property or an auto-detected user. If this user's UID/GID is updated, that user will no longer be able to work with Nix. This is primarily a consideration when running on Linux where the UID/GID is sync'd to the local user."**


The devcontainer spec's `updateRemoteUserUID` property (default `true`) causes the CLI to remap the container user's UID/GID to match the **host developer's** UID/GID at container startup on Linux:

> **"On Linux, if `containerUser` or `remoteUser` is specified, the user's UID/GID will be updated to match the local user's UID/GID to avoid permission problems with bind mounts. Defaults to `true`."**

> Source: [containers.dev — json_reference: updateRemoteUserUID](https://containers.dev/implementors/json_reference/)

The `devcontainers/ci` action also performs this remapping (its `skipContainerUserIdUpdate` input defaults to `false`).

**Applied to a prebuilt image with single-user Nix baked at UID 1000:**

- The image bakes `/nix` owned by UID 1000 (`vscode`)
- On a Linux host where the developer's UID is 1001 (or any value ≠ 1000), the CLI remaps the container `vscode` user to UID 1001
- Now `/nix` (in the volume, populated from image) is still owned by UID 1000
- Single-user Nix checks ownership: `nix-env` will fail with permission errors because `/nix/store` is owned by UID 1000 but the running user is UID 1001 ❌

On macOS/Windows Docker Desktop this is not an issue (UID mapping is abstracted by the VM). On Linux Docker hosts (including GitHub Codespaces running local devcontainers), it is a real, silent, hard-to-debug failure.

**The official Nix Feature defaults to multi-user mode precisely because of this problem.** Multi-user mode runs a `nix-daemon` as root, and all users invoke it over a socket — UID remapping does not affect store ownership. However, multi-user mode requires:
- Container running as root internally, OR
- `sudo` available without password for the remote user (the Feature provides `nix-entrypoint.sh` to start the daemon)
- Nix 2.11 or later

Our current setup deliberately chose **single-user/daemonless** to avoid the daemon complexity. Switching to the Feature's default multi-user mode would resolve the UID issue but adds daemon startup complexity (and requires the entrypoint script to be registered correctly, which the official Feature handles via the `"entrypoint"` field in `devcontainer-feature.json`).

> Source: devcontainers/features `src/nix/devcontainer-feature.json`, verified via API:
> `"entrypoint": "/usr/local/share/nix-entrypoint.sh"` and `"mounts": [{"source": "nix-store-${devcontainerId}", "target": "/nix", "type": "volume"}]`

---

## 4. Alternatives Comparison

### 4a. Prebuilt Image, Everything Baked, No Volume Mount

**Design:** Write a `Dockerfile` (or use the Nix Feature with `multiUser: false`) that installs Nix into `/nix` at build time. Remove the `mounts` entry for `/nix` from `devcontainer.json`. The full Nix store is baked into image layers.

**Pros:**
- Clean, fully deterministic, reproducible across all machines and all users
- No COFU/staleness issues; every developer gets exactly the image's Nix store
- No volume management overhead
- UID ownership issues disappear (no runtime writes to `/nix` from user)
- Image digest pinning gives exact reproducibility

**Cons:**
- **Image size:** A Nix store with `direnv`, `nix-direnv`, `nil`, `nixfmt` and their transitive closure is typically 500 MB–2 GB uncompressed. Compressed layers may be 300–700 MB. This is a significant pull cost on first use and on every image update.
- **No persistence:** Every container rebuild re-downloads the exact same store — there is no cross-session accumulation. If a developer runs `nix shell nixpkgs#ripgrep` interactively, that package is gone on rebuild.
- **Stale packages vs. frequent rebuilds tension:** To stay current, the image must be rebuilt frequently. But every rebuild is a full re-pull for developers.
- **Flake warmup can't be baked** (project-specific; would need to be in postCreateCommand anyway)
- `devcontainer build` with a large Nix store baked in can be very slow in CI

**Verdict:** Best fit when the Nix environment is small and stable, and developer workflows don't involve frequent `nix-env` additions. Not appropriate for a "generic/reusable across repositories" image where each project may add packages.

---

### 4b. Prebuilt Image + Keep Named Volume (Hybrid / COFU strategy)

**Design:** Restructure Nix install into a Feature or Dockerfile `RUN` step (so it's baked into the image at `/nix`). Keep the `mounts` entry for the named volume at `/nix`. Rely on Docker's COFU behavior to seed the volume on first use.

**Pros:**
- First-time users on any machine get a fast start: pull image, COFU seeds volume, no postCreate Nix install wait
- Subsequent uses retain accumulated store in volume (per-workspace persistence)
- Pull size is smaller than 4a if tools are kept minimal in image

**Cons:**
- **Staleness trap (§3.2):** Volume persists across image updates; old Nix store silently shadows new image content. Developers with existing volumes do not benefit from image updates without manual `docker volume rm`.
- **Dangling symlinks (§3.3):** If image updates change the Nix profile generation chain, `~/.nix-profile` may dangle. Requires defensive postCreateCommand logic.
- **UID issue (§3.4):** Single-user mode with UID 1000 is fragile on Linux hosts.
- **Multi-user mode alternative:** Use the official Feature's multi-user mode. This installs Nix as root in the image, starts the daemon via entrypoint. COFU still applies. UID issue resolved. But daemon startup adds complexity and requires passwordless sudo or root container start.
- **No "refresh" signal:** No built-in way to tell VS Code to delete the volume when the image changes. Users must know to do it.

**Verdict:** This is the natural next step from the status quo and is essentially what the official Nix Feature implements. It works well for new machines (the main win) but provides false security around image updates. Requires operational documentation to avoid developer confusion.

---

### 4c. Status Quo — Copy `.devcontainer/` Into Each Repository (No Prebuilt Image)

**Design:** Current approach. Each repository copies the `.devcontainer/` folder (with `devcontainer.json` and `postCreateCommand.sh`). Base image is `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` (prebuilt by Microsoft). Nix is installed by postCreateCommand. Volume persists per-workspace.

**Pros:**
- No image publishing infrastructure to maintain
- No GHCR visibility/permissions management
- No staleness trap — there is no cached Nix store in the image to go stale
- Nix install version is always fresh (pinned by installer URL or version in script)
- Works correctly on all UID values (installer runs as the current user)
- Simple to understand

**Cons:**
- First-time setup on a new machine is slow (Nix install + tool downloads: typically 3–8 minutes depending on network)
- Volume already amortizes repeat cost: once the volume exists, rebuild is fast
- Duplication: every repository copies the same `.devcontainer/` directory; updates must be propagated manually
- No single source of truth; risk of `.devcontainer/` configs drifting between repos

**What a prebuilt image actually saves over this approach:**
The volume already mitigates the slow repeat cost. The **only scenario** where a prebuilt image provides a real speedup is:
1. A developer's first time on a new machine (no volume → must run postCreate Nix install)
2. CI/CD pipelines where containers are ephemeral (no volume persistence → postCreate runs every time)

For developers who have already opened the devcontainer once on their machine, the volume is already seeded and rebuilds are fast. A prebuilt image gives them essentially zero additional benefit (they would still run postCreateCommand for flake warmup, and volume already has the Nix store).

**Quantifying the saving:** The Nix installer download + single-user setup is roughly 2–4 minutes on a typical network. The tool profile installs (direnv, nix-direnv, nil, nixfmt from a pinned nixpkgs rev) add another 2–5 minutes. Total first-run cost: **4–9 minutes**. This is saved once per machine per workspace clone. For a team of 10 developers this is a modest but real saving. For CI (no volume persistence), it could save 5–9 minutes per CI run — more significant.

**Verdict:** Status quo is the lowest-maintenance option. Appropriate if the team is small, CI doesn't use the devcontainer, and each developer only clones each repo once.

---

### 4d. Publish a Devcontainer Feature to GHCR

**Design:** Instead of (or in addition to) a prebuilt image, publish our Nix setup as a devcontainer Feature OCI artifact to GHCR. Repositories reference it in their `devcontainer.json` `features` block.

Features are OCI artifacts too — they are published to and pulled from OCI registries (GHCR is the canonical host for community features). The Feature's `install.sh` runs at `devcontainer build` time (as root), so it is baked into the image when developers build locally or when the CI action prebuilds.

#### The Official Nix Feature (Already Exists)

**Reference:** `ghcr.io/devcontainers/features/nix:1` (latest: `1.3.1`)

> Source: [containers.dev/features](https://containers.dev/features) — listed under Dev Container Spec Maintainers

This Feature:
- Runs the upstream Nix installer at image build time (`install.sh` runs as root, using the official `https://releases.nixos.org/nix/nix-${VERSION}/install` script)
- Supports both **multi-user** (default) and **single-user** modes via `multiUser` option
- Supports `packages` (comma-separated nixpkgs packages to install) and `flakeUri` options
- Adds `/nix` named volume to `devcontainer.metadata` via `devcontainer-feature.json`
- Adds PATH entries for `/nix/var/nix/profiles/default/bin` via `containerEnv`
- Registers `/usr/local/share/nix-entrypoint.sh` as the container entrypoint (for multi-user daemon startup)

Verified from `devcontainer-feature.json` (devcontainers/features@`765e8ebd8f8012fb740cd7b41483a745bcedd212`):

```json
{
  "id": "nix",
  "version": "1.3.1",
  "mounts": [
    {
      "source": "nix-store-${devcontainerId}",
      "target": "/nix",
      "type": "volume"
    }
  ],
  "containerEnv": {
    "PATH": "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:${PATH}"
  },
  "entrypoint": "/usr/local/share/nix-entrypoint.sh",
  "installsAfter": ["ghcr.io/devcontainers/features/common-utils"]
}
```

> Source: [github.com/devcontainers/features — src/nix/devcontainer-feature.json](https://github.com/devcontainers/features/blob/main/src/nix/devcontainer-feature.json)

**Critical observation:** The official Nix Feature uses **exactly the same volume strategy** as our current postCreateCommand setup (`nix-store-${devcontainerId}` volume at `/nix`). It hits all the same COFU/staleness/dangling-symlink pitfalls described in §3. However, because the Feature's `install.sh` runs at build time, Nix IS baked into the image — so the COFU seeding works on first use.

**A minimal `devcontainer.json` using the official Feature:**

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "features": {
    "ghcr.io/devcontainers/features/nix:1": {
      "multiUser": false,
      "packages": "direnv,nix-direnv,nil,nixfmt-rfc-style",
      "extraNixConfig": "experimental-features = nix-command flakes"
    }
  },
  "remoteUser": "vscode",
  "postCreateCommand": ".devcontainer/postCreateCommand.sh"
}
```

The `postCreateCommand` would then only need to: (1) pin the nixpkgs rev if needed, and (2) warm up the project flake — the Nix install and tool downloads are moved to Feature install time (baked into image).

**Limitation noted in the official Feature docs:**

> **"Currently `flakeUri` works best with a remote URI (e.g., `github:nixos/nixpkgs/nixpkgs-unstable#hello`) as local files need to be in the image."**
>
> **"Proposed support for lifecycle hooks in Features ([#60](https://github.com/devcontainers/spec/issues/60)) would allow for expressions files or Flakes to exist in the source tree to be automatically installed on initial container startup, but today you will have to manually add the appropriate install command to `postCreateCommand` to your `devcontainer.json` instead."**

> Source: [github.com/devcontainers/features — src/nix README](https://github.com/devcontainers/features/tree/main/src/nix)

This means our project flake warmup must remain in `postCreateCommand` regardless. The Feature handles Nix installation and base tools; the project-specific flake warmup remains in `postCreateCommand` (run at container creation, not baked).

**Publishing our own custom Feature** (instead of using the official one) makes sense only if we need meaningfully different behavior — e.g., our specific nixpkgs pinning strategy, single-user mode with specific profile fixup logic, or additional tooling. The publication mechanism is identical to images: OCI artifact pushed to `ghcr.io/NAMESPACE/FEATURE_NAME`. The `devcontainers/cli` command `devcontainer features publish` or the `devcontainers/action` handles this. Features are versioned with semver and pulled by consuming `devcontainer.json` at build time.

**Feature vs. prebuilt image — key tradeoff:**

| Dimension | Custom Feature on GHCR | Prebuilt full image on GHCR |
|---|---|---|
| Build time per developer | Feature runs at local `devcontainer build` (~same as postCreate cost, but at build not start) | Image pulled, no local Feature build |
| First-run speed | Slow (Feature install runs locally) | Fast (pull pre-built layers) |
| Composability | ✅ Any base image + this Feature | ❌ Locked to prebuilt base |
| Staleness risk | Low (Feature always re-runs on image rebuild) | High (volume shadowing issue) |
| Maintenance surface | Feature versioning + OCI publish | Image versioning + OCI publish + base image rebuild cadence |
| Flake warmup | Still needs `postCreateCommand` | Still needs `postCreateCommand` |

**Verdict for §4d:** The official `ghcr.io/devcontainers/features/nix:1` Feature already implements our design pattern correctly and is maintained by the devcontainers spec team. Adopting it (possibly with `multiUser: false` and specific `packages`) gets us the build-time Nix install without maintaining our own image or Feature. Staleness pitfalls from §3 still apply because the Feature embeds the same volume mount. Publishing a *custom* Feature is only warranted if our requirements diverge from the official one's options.

---

### 4e. GitHub Codespaces Prebuilds (Brief Comparison)

Codespaces prebuilds are a **repository-scoped, GitHub-managed** mechanism distinct from publishing a GHCR image. Key differences:

- A prebuild is a snapshot of a live container (including volumes and cloned source), not a portable OCI image. It cannot be referenced by other repositories.
- Configured per-repo, per-branch, per-`devcontainer.json` combination, in the repository's Codespaces settings — not in a workflow YAML.
- GitHub runs `onCreateCommand` and `updateContentCommand` during prebuild creation; **`postCreateCommand` is explicitly excluded** (same as `devcontainer build`).
- Billing: Prebuild storage and Actions minutes are billed to the repository owner's Codespaces quota. Not free.
- Only works within GitHub Codespaces — does not help local VS Code + Docker development.
- Updating the prebuild on every push triggers an Actions workflow run (configurable to scheduled or manual).

> Source: [docs.github.com — About GitHub Codespaces prebuilds](https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds)

**For our purposes:** Codespaces prebuilds and GHCR image prebuilds are complementary, not competing. A GHCR prebuilt image improves local devcontainer startup everywhere; a Codespaces prebuild improves Codespaces startup for one specific repo. If Codespaces usage is a goal, both can be combined — the Codespaces prebuild would use the GHCR prebuilt image as its base (already-pulled layers), then snapshot the post-onCreate state.

---

## 5. Maintenance Pitfalls

### 5.1 Base Image Security Patch Cadence

`mcr.microsoft.com/devcontainers/base:ubuntu-24.04` receives regular OS package updates from Microsoft's devcontainers team. When you publish a prebuilt image that `FROM`s this base, your prebuilt image freezes the base at the time of build. Security patches in the base are **not retroactively applied** to your already-pushed image.

**Implication:** Without a scheduled rebuild, your prebuilt image accumulates CVEs over time. You become responsible for the rebuild cadence that Microsoft previously handled for you. The standard mitigation is a scheduled GitHub Actions workflow (e.g., weekly):

```yaml
schedule:
  - cron: '0 3 * * 1'  # Every Monday 03:00 UTC
```

This triggers a rebuild-and-push even if `devcontainer.json` has not changed, pulling a fresh base image layer and picking up upstream OS patches.

### 5.2 Tag Strategy — `latest` vs. Pinned Digests

**`latest` tag only:** Simple to reference (`"image": "ghcr.io/org/devcontainer:latest"`) but non-deterministic. Two developers building at different times may pull different images if `latest` was updated in between. Debugging environment differences becomes harder.

**Immutable versioned tags** (e.g., `YYYY-MM-DD`, `v1.2.3`, or `sha-<gitrev>`): Deterministic, auditable, easy to roll back. Can be combined with `latest` (push both `latest` and the versioned tag in the same workflow step):

```yaml
imageTag: latest,2026-07-23
```

The `devcontainers/ci` action's `imageTag` input accepts comma-separated tags.

**Pinned digests** (`ghcr.io/org/devcontainer@sha256:abc123…`): Maximum reproducibility. The devcontainer spec supports digest references in the `image` field. However, updating to a new digest requires a PR to every consuming repository — high maintenance, high security value.

**Recommended strategy:** Push both `latest` and a date/semver tag on every build. Consuming repositories reference the versioned tag. Renovate (see §5.3) automates bumping the tag reference on PR.

### 5.3 Dependabot and Renovate Support for `devcontainer.json` References

**Dependabot (as of January 2024):**
- Supports updating devcontainer **Features** (`ghcr.io/devcontainers/features/nix:1` → `1.3.1`) via the `devcontainers` ecosystem in `dependabot.yml`
- Does **NOT** support updating the `image:` field (base image reference) in `devcontainer.json`
- No support for security advisories on devcontainer images

> Source: [GitHub Changelog — Dependabot version updates support devcontainers (2024-01-24)](https://github.blog/changelog/2024-01-24-dependabot-version-updates-support-devcontainers/)

**Renovate:**
- Natively supports updating the `image:` field in `devcontainer.json` (both `.devcontainer/devcontainer.json` and `.devcontainer.json`)
- Also updates Feature references
- Supports digest pinning, version range strategies, grouping, scheduling, and multi-platform

> Source: [docs.renovatebot.com — devcontainer manager](https://docs.renovatebot.com/modules/manager/devcontainer/)

**Recommendation:** Use Renovate for full automation coverage (image + Features). Dependabot covers Features only. If the team already uses Dependabot exclusively and only references Features (not a custom prebuilt image), Dependabot is sufficient for Feature updates. For a custom prebuilt GHCR image in the `image:` field, Renovate is required for automated tag bumping.

### 5.4 Multi-Architecture Builds (arm64 / amd64)

Apple Silicon developers (M1/M2/M3 Macs) run arm64 containers natively via Docker Desktop. GitHub-hosted CI runners are amd64 (`ubuntu-latest`). Without a multi-arch manifest, developers on one architecture would either get the wrong image or fail to pull.

The `devcontainers/ci` action supports multi-platform builds via the `platform` input:

```yaml
- uses: devcontainers/ci@v0.3
  with:
    imageName: ghcr.io/org/devcontainer
    platform: linux/amd64,linux/arm64
    push: always
```

When `useNativeRunner` is `false` (default), a single runner uses QEMU emulation to cross-compile both architectures. This is slower but simpler. When `useNativeRunner` is `true`, `platform` must be a single value — you run a matrix with one job per architecture and merge manifests afterward.

> Source: [github.com/devcontainers/ci — docs/github-action.md (platform / useNativeRunner inputs)](https://github.com/devcontainers/ci/blob/main/docs/github-action.md)

**Nix-specific consideration:** Nix stores are architecture-specific. A multi-arch image built with QEMU will have architecture-correct Nix store paths baked into each manifest variant. This works correctly but QEMU-emulated arm64 builds are significantly slower (3–5× typical). Native runners (using GitHub's arm64 runners, now generally available) are preferred for Nix-heavy images.

**Volume persistence and multi-arch:** The named volume `nix-store-${devcontainerId}` is architecture-agnostic at the Docker level, but its contents are architecture-specific Nix store paths. If a developer switches between architectures (rare but possible), the old volume is incompatible and must be deleted.

### 5.5 GHCR Visibility and Package-to-Repository Linking

Two operational gotchas to document in runbooks:

**1. Default private visibility:** Every newly pushed GHCR package is private. Anonymous pulls (required for devcontainer use without credentials) fail silently or produce authentication errors. Making the package public requires a manual step in the GitHub web UI: Package → Package Settings → Change visibility → Public. This cannot be automated via `docker push` or standard GitHub Actions permissions.

**2. Package-repository linking:** Pushing via `GITHUB_TOKEN` from a workflow automatically links the package to the workflow's repository — but only if the `org.opencontainers.image.source` label is set on the image. Without this label, the package may be unlinked (orphaned under the account, not visible in the repository's Packages tab), and the `GITHUB_TOKEN` from other repositories cannot read it without explicit `packages: read` permission granted in package settings.

Recommended Dockerfile label:

```dockerfile
LABEL org.opencontainers.image.source=https://github.com/OWNER/REPO
LABEL org.opencontainers.image.description="Nix devcontainer for fuj1g0n/skills"
LABEL org.opencontainers.image.licenses=MIT
```

> Source: [docs.github.com — Working with the Container registry: Labelling container images](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

---

## 6. Licensing / Terms of Service

### 6.1 Acceptable Use

Hosting a prebuilt devcontainer image on GHCR for use by a team or open-source community is the intended, documented use case for GitHub Packages / Container Registry. The official devcontainer prebuild guide specifically names GHCR as the recommended registry and links to it as the example. No ToS concern exists for this use.

The GitHub Acceptable Use Policy's most relevant constraint is the **excessive bandwidth** clause (§9, cited in §1.3). For a devcontainer image used by a development team, even a large one, bandwidth is nowhere near the scale that would trigger this. The policy targets cryptocurrency mining, mass data scraping, and denial-of-service vectors — not developer tooling images.

There is no prohibition on hosting "CDN-like" public assets on GHCR in the sense that would apply to a container image. GitHub Pages has more explicit restrictions on CDN-like use; GHCR does not.

### 6.2 Content Licensing

If the prebuilt image contains Nix store paths from nixpkgs (baked via the Feature's `packages` option or flakeUri), those packages carry their own licenses (GPL, MIT, Apache, etc.). Publishing an image containing those packages as layers is no different from any other redistributed container image — you are bound by the upstream licenses of included software, which for most nixpkgs packages permit redistribution. This is the same situation as Microsoft's `mcr.microsoft.com/devcontainers/base` images.

No GitHub-specific licensing concern applies to image content.

---

## Critical Conclusion

### What We Can State With Certainty

1. **GHCR is a sound registry choice.** Public images are free (storage + bandwidth, with advance-notice policy), no rate limits on anonymous pulls, OCI-compliant, multi-arch capable. No ToS blocker.

2. **Our current `devcontainer.json` cannot be prebuilt as-is.** `devcontainer build` does not run `postCreateCommand`. A prebuild of the current config produces a pure-base Ubuntu image with zero Nix content — entirely useless as a prebuilt image. This is the single most important fact for the ADR.

3. **The path to a real prebuild requires restructuring.** Nix installation must move from `postCreateCommand` into a Feature (`install.sh`, runs at build time). The official `ghcr.io/devcontainers/features/nix:1` already does this correctly and is maintained by the spec team. Adopting it with `packages: "direnv,nix-direnv,nil,nixfmt-rfc-style"` eliminates the need to maintain our own install logic.

4. **Even after restructuring, the `/nix` named volume creates a staleness trap.** The official Nix Feature uses the exact same volume pattern as our current setup. The first-use COFU seeding works. But image updates are silently ignored for developers with existing volumes — `/nix` stays at the old version. The dangling symlink failure mode (§3.3) is a real breakage risk when image updates change the Nix profile generation chain. Operational runbooks must document: "delete the `nix-store-<devcontainerId>` volume after an image update."

5. **Single-user Nix + UID remapping on Linux hosts is a latent breakage.** The official Feature defaults to multi-user precisely to avoid this. If we keep single-user mode in a prebuilt image, we must set `updateRemoteUserUID: false` (accepting bind-mount permission trade-offs) or document that the image only works reliably on macOS/Windows Docker Desktop.

6. **The volume already amortizes the cost we are trying to eliminate.** A developer who has opened the devcontainer once on their machine already has a populated `/nix` volume. Their rebuild is fast. The prebuilt image helps only: (a) first clone on a new machine, and (b) ephemeral CI environments. For a team that does not use the devcontainer in CI, the practical benefit is narrow.

### ADR Recommendation

**Proposed path (if proceeding):**

| Decision | Recommendation | Rationale |
|---|---|---|
| Nix install mechanism | Adopt `ghcr.io/devcontainers/features/nix:1` with `multiUser: true` | Build-time install, maintained upstream, resolves UID issue |
| Volume strategy | Keep volume (COFU seeding), document staleness | Needed for performance; alternative (no volume) makes image multi-GB |
| Prebuilt image | Publish `ghcr.io/fuj1g0n/skills-devcontainer` | Base image + Feature baked; tools pre-cached |
| postCreateCommand | Retain for flake warmup only | Cannot be baked; Feature handles tool install |
| Tags | `latest` + `YYYY-MM-DD` | Automated via `devcontainers/ci` `imageTag` input |
| Update automation | Renovate for `image:` field + Feature versions | Dependabot covers Features only, not the base image reference |
| Multi-arch | `linux/amd64,linux/arm64` via `devcontainers/ci` `platform` | Apple Silicon + CI coverage; use native arm64 runners for speed |
| Rebuild cadence | Weekly scheduled GitHub Actions workflow | Base image security patches |
| Visibility | Manually set to Public after first push | Cannot be automated; add to runbook |

**If the team is small (<5 people) and does not run devcontainers in CI:** the status quo (copy `.devcontainer/`, rely on volume) has lower total maintenance cost and avoids all the staleness/UID/symlink pitfalls. The prebuilt image adds ongoing CI, rebuild cadence, and volume-lifecycle-management complexity in exchange for saving one 5–9 minute first-run cost per developer per machine.

**If CI uses the devcontainer (ephemeral environments, no volume persistence):** a prebuilt image is strongly recommended and the benefit is clear — every CI run saves 5–9 minutes. In this case, restructuring to use the official Nix Feature is a prerequisite, and the ADR should be `accepted`, not merely `proposed`.

---

*Key sources: [containers.dev/guide/prebuild](https://containers.dev/guide/prebuild) · [containers.dev/implementors/spec/#image-metadata](https://containers.dev/implementors/spec/#image-metadata) · [containers.dev/implementors/reference/#labels](https://containers.dev/implementors/reference/#labels) · [github.com/devcontainers/ci docs/github-action.md](https://github.com/devcontainers/ci/blob/main/docs/github-action.md) · [github.com/devcontainers/features src/nix](https://github.com/devcontainers/features/tree/main/src/nix) · [docs.github.com Packages billing](https://docs.github.com/en/billing/concepts/product-billing/github-packages) · [docs.github.com Codespaces prebuilds](https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds) · [docs.docker.com Volumes](https://docs.docker.com/engine/storage/volumes/) · [docs.renovatebot.com devcontainer manager](https://docs.renovatebot.com/modules/manager/devcontainer/)*
