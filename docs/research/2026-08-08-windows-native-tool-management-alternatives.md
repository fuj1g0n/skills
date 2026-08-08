---
type: Research
---

# Windows-native tool management alternatives to Nix

Date: 2026-08-08
Author: @fuj1g0n (with GitHub Copilot)
Status: working note

## Question

What can serve as the primary tool manager for this repository when humans,
VS Code GitHub Copilot, and GitHub Copilot CLI work from Windows?

The goal is not transparent execution of Linux Nix binaries from a Windows
shell. The goal is a practical Windows-native or Windows-friendly workflow
that preserves as much as useful of Nix's declarative, pinned, reproducible,
and project-local development-environment role.

## Scope and decision criteria

The primary manager should provide:

* a repository-owned declaration and lock or checksum data;
* native Windows executables visible to ordinary child processes;
* per-project version selection without requiring an activated WSL shell;
* unattended setup suitable for humans and coding agents;
* coexistence of projects that request different versions;
* a credible bootstrap and rollback path;
* enough ecosystem coverage for the actual repository inventory; and
* a clear boundary where Linux-only Nix remains necessary.

This note distinguishes three different guarantees:

1. **Version pinning** selects a named top-level release.
2. **Artifact integrity** verifies the bytes downloaded for that release.
3. **Closure reproducibility** fixes all transitive build and runtime inputs.

Nix provides all three when nixpkgs and inputs are pinned. Most native Windows
managers provide the first, some backends provide the second, and ecosystem
lockfiles provide part of the third. None of the evaluated general-purpose
Windows-native options reproduces Nix's immutable heterogeneous closure.

## Repository baseline

The current `shell.nix` contains exactly three packages:

| Tool | Version from the pinned Nix shell | Current role |
|---|---:|---|
| `just` | 1.57.0 | Task runner |
| `nixfmt` | 1.4.0 | Format Nix files |
| `markdownlint-cli2` | 0.22.1 | Lint Markdown |

`flake.nix` exposes only `x86_64-linux` and `aarch64-linux`. nixpkgs is pinned
by npins at revision `421eebfd0ec7bccd4abe826ce62d7e6e83129493` with
hash `sha256-/FCliTPgiuV1owejZFNx3Ch9irdvkOfOFl+HHZ+DrtM=`. The repository
therefore has a precise Linux environment but no native Windows output.

The observed Windows host had WinGet 1.29.280, Node 24.13.0, npm 11.6.2,
Corepack 0.34.5, and WSL 2.9.4.0. mise, Pixi, uv, and Scoop were not installed
globally. The experiments used isolated directories below `%TEMP%`; they did
not change the repository or user-level package configuration.

## Candidate summary

| Candidate | Native Windows | Repository declaration | Lock/integrity model | Inventory fit | Position |
|---|---|---|---|---|---|
| mise | Yes | `mise.toml` | Exact versions; optional `mise.lock`; checksums depend on backend | Strong for `just` and Node; npm supported directly or through npm lockfiles; no native `nixfmt` artifact | Best primary orchestrator |
| Pixi | Yes | `pixi.toml` | Conda lockfile with platform artifacts and hashes | Strong for Python/Conda stacks; forcing this small mixed inventory through Conda adds a packaging constraint; `nixfmt` remains a gap | Best when Conda/Python is central |
| aqua | Yes | `aqua.yaml` | Registry metadata and checksums for release assets | Excellent for checksum-verified standalone CLIs such as `just`; not a complete Node/npm environment manager | Useful backend or focused alternative |
| Scoop | Yes | JSON manifests | Manifest URL and hash; optional repository-owned bucket | Good native CLI installation; weaker project activation and multi-project version semantics | Bootstrap or machine layer |
| WinGet | Yes | Manifests/configuration | Installer hashes in community manifests | Installed by default and useful for bootstrap; package versions and upgrades are machine-oriented | Bootstrap layer only |
| Volta | Yes | `package.json` | Pins Node/package-manager versions; npm lockfile handles dependencies | Excellent Node-only fit; does not manage `just` or `nixfmt` | Too narrow as primary |
| uv | Yes | `pyproject.toml` and `uv.lock` | Strong Python dependency and interpreter locking | Excellent Python fit; unrelated to this inventory | Not applicable today |
| Devbox, Flox, Nix | No native Nix execution | Nix-based declarations | Nix closure | Highest Linux parity, but require WSL or a container | Keep as Linux fallback, not Windows primary |

## Candidate analysis

### mise

mise is the best general fit because one project file can select runtime and
standalone CLI versions, inject environment variables, expose tasks, and
switch versions by working directory. It has a native Windows binary and
supports PowerShell activation, shims, and explicit `mise exec` execution.

Its reproducibility is backend-specific rather than uniform:

* core backends can verify upstream checksums when the distribution publishes
  them;
* Aqua-backed tools inherit Aqua registry release-asset and checksum metadata;
* `mise.lock` records resolved platform artifacts for supported backends;
* npm packages still need npm's lockfile and install semantics for their full
  dependency graph; and
* a version in `mise.toml` alone is not equivalent to a Nix closure.

That model is acceptable if the repository deliberately assigns ownership:
mise owns runtime and command selection, while each ecosystem owns its
transitive lock.

### Pixi

Pixi has the strongest reproducibility story among the native candidates when
the environment is naturally expressible in Conda packages. It solves and
locks exact artifacts per target platform and works well for Python, native
libraries, and mixed Conda/PyPI projects.

It is not the best default for this repository. The current inventory is a
standalone Rust CLI, a Nix formatter, and a Node CLI. Using Conda as the primary
distribution path would make conda-forge packaging availability and lag part
of the repository's toolchain contract. It still cannot provide an official
native `nixfmt` binary. Pixi should be reconsidered if Python, CUDA, scientific
native libraries, or Conda packages become a material part of the project.

### Scoop and WinGet

Both are useful one-time bootstrap and machine-management layers. They can
install native Windows applications and verify hashes from manifests. Scoop
also permits a repository-owned bucket and therefore offers more control than
a community WinGet package.

Neither naturally gives this repository the complete project-local contract.
Their default model mutates a user or machine installation. Side-by-side
project versions, directory-sensitive selection, environment activation, and
ecosystem dependency locks require additional conventions. Pinning a WinGet
package also pins a catalog version, not the complete environment in which it
runs.

Use WinGet to bootstrap mise on ordinary Windows hosts. A checksum-pinned
PowerShell bootstrap is the fallback when catalog availability or version lag
is unacceptable. Scoop is reasonable for user workstation packages, but it
should not become a second project environment manager without a concrete
need.

### Aqua

Aqua is attractive for release-asset CLIs because its registry carries asset
selection and checksum information. It is a credible focused manager for
`just`, and mise can consume Aqua packages, avoiding a separate activation
layer.

Aqua is not by itself a replacement for the current environment. Node/npm
dependency management remains external, and `nixfmt` has no official native
Windows release artifact. The best use here is as a checksum-aware mise
backend, not as another top-level manager.

### Language-specific managers

Volta, Corepack, npm, uv, and similar tools are strongest inside their own
ecosystems. They should retain ownership of transitive dependencies rather
than being hidden behind a general manager. For this repository that means an
exact Node version selected by mise, a committed `package-lock.json`, and
`npm ci` for `markdownlint-cli2`.

## Empirical mise probe

mise 2026.8.2 for `windows-x64` was downloaded from the official GitHub
release and verified against the release `SHASUMS256.txt`. The experiment used
isolated `MISE_DATA_DIR`, `MISE_CACHE_DIR`, `MISE_STATE_DIR`, and
`MISE_CONFIG_DIR` values. Project directories contained spaces.

The test declaration requested:

```toml
min_version = "2026.8.2"

[settings]
lockfile = true

[tools]
"aqua:casey/just" = "1.57.0"
node = "24.13.0"
"npm:markdownlint-cli2" = "0.22.1"
```

Observed results:

* mise accepted and trusted the project path containing spaces.
* `mise lock` generated entries for Linux, macOS, and Windows platforms. It
  resolved 14 platform entries and explicitly reported seven skipped entries.
* The core Node backend downloaded `node-v24.13.0-win-x64.zip`, performed its
  checksum step, and began extraction.
* The Aqua backend resolved `just` and selected
  `just-1.57.0-x86_64-pc-windows-msvc.zip`.
* The built-in `npm:` backend repeatedly failed while fetching
  `https://registry.npmjs.org/markdownlint-cli2` through `aube`. The same
  package and registry were reachable through the already installed npm in
  the broader environment, so the probe does not establish an upstream npm
  outage.
* A follow-up isolated run stalled during the Aqua release download. The
  command was terminated rather than treating a partial install as success.

The network behavior on this non-isolated development machine prevented
credible cold/warm timing, version-switch, rollback, and disk-usage numbers.
No such numbers are claimed. More importantly, the test exposed an operational
risk: a single mise declaration can aggregate several backends, but backend
fetch behavior and reliability are not uniform.

The failed npm backend supports a simpler ownership model. Do not install the
project's Node CLI through `npm:` in mise. Let mise install Node, then let
ordinary `npm ci` consume a committed npm lockfile. This gives contributors a
familiar diagnostic path and avoids coupling npm dependency installation to
an additional implementation.

## The `nixfmt` boundary

`nixfmt` is the decisive native-coverage gap. Its upstream releases do not
publish a supported Windows executable, and the current Nix package is a Linux
artifact. Downloading a third-party build, cross-compiling an unmaintained
binary, or silently substituting another formatter would weaken the contract
more than it helps.

Keep formatting Nix files behind an explicit WSL Nix command. This is a small
and honest boundary because:

* Nix files are already Linux environment definitions;
* the formatter version remains fixed by the existing nixpkgs pin;
* ordinary Windows tasks such as Markdown linting need not pay WSL/Nix startup
  cost; and
* CI can continue to use the authoritative Nix environment.

The fallback should be command-scoped, for example a `just` recipe that calls
the existing WSL execution helper. Linux developers can continue to execute
`nixfmt` directly. Do not export `/nix/store` paths into Win32 `PATH`.

## Recommended target model

Adopt a layered contract:

| Layer | Owner | Repository state | Responsibility |
|---|---|---|---|
| Bootstrap | WinGet or checksum-pinned PowerShell | documented mise version | Install the primary manager |
| Project selection | mise | `mise.toml` and `mise.lock` where useful | Select native Node and standalone CLI versions; expose tasks and environment |
| Node dependencies | npm | `package.json` and `package-lock.json` | Install and lock `markdownlint-cli2` with `npm ci` |
| Task interface | `just` | existing `justfile` | Stable commands for humans and agents |
| Linux-only tools | WSL Nix | existing flake, shell, and npins pin | `nixfmt` and Linux parity checks |
| CI authority | Nix initially | existing Linux environment | Detect divergence during migration |

The initial Windows declaration should conceptually be:

```toml
min_version = "<reviewed mise version>"

[settings]
lockfile = true

[tools]
"aqua:casey/just" = "1.57.0"
node = "24.13.0"

[tasks.install]
run = "npm ci"

[tasks.lint]
run = "npm exec --no -- markdownlint-cli2 \"**/*.md\""
```

Exact mise and Node versions should be chosen when implementation starts, not
copied blindly from this time-bound experiment. The Nix and Windows versions
should be intentionally reconciled because the host's preinstalled Node
24.13.0 is not evidence that the pinned nixpkgs closure contains the same
release.

For child-process visibility, prefer one of two explicit modes:

* configure mise shims in the user's PowerShell environment so VS Code and
  agent child processes resolve project versions by working directory; or
* invoke automation through `mise exec -- ...` or `mise run ...`.

Do not rely only on interactive shell activation. VS Code extensions and
coding-agent subprocesses are not guaranteed to inherit a shell hook that was
loaded after the editor started.

## Migration plan

1. Add `mise.toml` with `just` and Node only. Pin the minimum mise version.
2. Add a development-only `package.json` and committed `package-lock.json`
   containing `markdownlint-cli2@0.22.1`; use `npm ci`.
3. Keep the existing Nix files unchanged and authoritative during the trial.
4. Add Windows-focused smoke checks for a path containing spaces, a clean
   `pwsh -NoProfile` child, explicit `mise exec`, and two fixtures requesting
   different `just` versions.
5. Route only `nixfmt` and Linux parity checks through WSL Nix.
6. Run both native Windows lint and Nix lint in CI until output parity and
   upgrade procedures are understood.
7. After a trial period, decide whether Nix remains the CI authority, becomes
   Linux-only compatibility configuration, or is reduced further.

Rollback is straightforward while the Nix environment remains intact: remove
the native declaration and lockfiles, clear the project mise install, and
return task execution to `nix develop` or the established WSL helper. This is
another reason not to delete or rewrite the Nix files in the first migration.

## Risks and controls

| Risk | Control |
|---|---|
| mise backend behavior differs | Keep ecosystem installation in its native manager; test each backend used |
| Top-level pin is mistaken for closure reproducibility | Document ownership and commit ecosystem lockfiles |
| Registry or release asset is unavailable | Cache in CI where appropriate; retain checksums and WSL Nix fallback |
| VS Code or agent does not inherit activation | Use shims configured before editor launch or explicit `mise exec` tasks |
| Windows and Nix versions drift | Add a parity check that prints and compares intended tool versions |
| `nixfmt` has no native artifact | Keep an explicit WSL Nix recipe; do not use an unofficial substitute silently |
| WinGet catalog drifts or lags | Pin a reviewed bootstrap version or use a checksum-pinned official archive |
| Multiple managers confuse contributors | Define one owner per layer and expose daily operations through `just` |

## Recommendation

Use **mise as the primary Windows project orchestrator**, not as a claim of
Nix-equivalent closure reproducibility. Use **Aqua through mise for `just`**,
**mise for Node selection**, and **npm lockfiles plus `npm ci` for
`markdownlint-cli2`**. Keep **WSL Nix as the explicit `nixfmt` and Linux-parity
fallback**. Use WinGet only to bootstrap mise.

Pixi is the stronger alternative when a repository's center of gravity is a
Conda/Python/native-library environment. It is not the strongest fit for this
three-tool inventory. Scoop and WinGet remain machine package managers, not
the repository's environment contract.

This recommendation deliberately trades Nix's unified immutable closure for
native Windows execution, faster ordinary process startup, and compatibility
with Windows-hosted editors and agents. The trade is acceptable only while
the repository keeps explicit version, checksum, lockfile, and Linux-fallback
boundaries.

## Sources

Primary documentation and release metadata consulted on 2026-08-08:

* [mise: Windows support](https://mise.jdx.dev/installing-mise.html#windows)
* [mise: configuration](https://mise.jdx.dev/configuration.html)
* [mise: lockfiles](https://mise.jdx.dev/dev-tools/mise-lock.html)
* [mise: backends](https://mise.jdx.dev/dev-tools/backends/)
* [mise releases](https://github.com/jdx/mise/releases)
* [Pixi: installation](https://pixi.sh/latest/installation/)
* [Pixi: lock files](https://pixi.sh/latest/workspace/lockfile/)
* [Pixi releases](https://github.com/prefix-dev/pixi/releases)
* [Aqua documentation](https://aquaproj.github.io/docs/)
* [Aqua registry](https://github.com/aquaproj/aqua-registry)
* [Scoop manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
* [WinGet configuration](https://learn.microsoft.com/windows/package-manager/configuration/)
* [Volta project pinning](https://docs.volta.sh/guide/understanding#managing-your-project)
* [npm lockfiles](https://docs.npmjs.com/cli/configuring-npm/package-lock-json)
* [npm ci](https://docs.npmjs.com/cli/commands/npm-ci)
* [uv project management](https://docs.astral.sh/uv/guides/projects/)
* [Nix supported platforms](https://nix.dev/manual/nix/latest/installation/supported-platforms)
* [nixfmt releases](https://github.com/NixOS/nixfmt/releases)
* [Devbox installation](https://www.jetify.com/docs/devbox/installing_devbox/)
* [Flox installation](https://flox.dev/docs/install-flox/)

Secondary context in this repository:

* `docs/research/2026-07-29-windows-wslc-devshell-delegation.md`
* `docs/research/2026-08-07-windows-wsl-direnv-project-shell.md`
