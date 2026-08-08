# Research: Using Nix devShells from Windows-managed projects via WSL

Date: 2026-07-29
Author: @fuj1g0n (with GitHub Copilot CLI)
Status: immutable snapshot

## Question

Projects are managed on the Windows filesystem (NTFS) and worked on with
GitHub Copilot CLI (GHCP CLI) running on Windows. The skills in this
repository (`nix-for-dev`, `nix-manager`, etc.) assume Nix devShells.
Nix does not run on Windows natively, but WSL has Nix installed. Hard
constraints:

* GHCP CLI and the user's interactive shell stay on Windows.
* The project working tree stays on the Windows filesystem.
* devShell changes made in any Linux environment must be visible in the
  Windows working tree immediately (same files, not a copy).

Can we delegate tool execution to WSL or a container while keeping
project management on Windows?

## Environment

* Windows 11 (26200.8893), WSL 2.9.4.0, kernel 6.18.35.2-1
* Ubuntu-24.04 with Determinate Nix 3.21.2 (nix 2.34.7),
  `lazy-trees = true` confirmed via `nix config show`
* Repository available both at `C:\Users\...\skills` (NTFS) and
  `~/workspace/github.com/fuj1g0n/skills` (ext4, comparison baseline)

## Part 1: The flake source-copy problem and lazy trees

The historical blocker for "run `nix develop` against a big working
tree" is that flake evaluation copies the entire source tree into
`/nix/store` (NAR-hash + copy) before evaluating. Canonical references:

* NixOS/nix #5551 — flakes: avoid copying local flake to the store.
* NixOS/nix #6530 — original "lazy trees" PR (superseded).
* NixOS/nix #13225 — "lazy trees v2" (Eelco Dolstra), virtual store
  paths; open upstream as of mid-2025, not merged into CppNix.
* NixOS/nix #10627 — double-copy of `src = ./.` under lazy trees.
* Determinate Nix shipped lazy trees opt-in in 3.5.2 (2025-05),
  progressive rollout from 3.6.7, default-on by our 3.21.2.

With lazy trees, evaluation mounts the source as a virtual store path
and only "devirtualizes" (actually copies) when a derivation or string
context references the source. A devShell that only pulls tools from
nixpkgs (the `nix-for-dev` zero-inputs layout) never copies the project
tree. Remaining copy triggers: `src = ./.;`, `src = self;`,
`toString ./path`, and any build that consumes the source.

Git-awareness still applies: `nix develop .` in a git repo considers
only tracked files (untracked `node_modules` etc. never contribute);
`nix develop path:.` bypasses git and hashes everything — avoid.

Consequence: the "intermediate build artifacts get copied" concern is
already solved on this machine by lazy trees + git-aware fetching +
the zero-inputs devShell layout. It is not the bottleneck anymore.

## Part 2: Measured baselines (this repository)

Times are wall-clock, warm unless noted. The devShell is the repo's
zero-inputs flake (just, nixfmt, markdownlint-cli2).

| Operation | ext4 (WSL home) | /mnt/c 9P | /mnt/c virtiofs |
|---|---|---|---|
| `nix develop -c true` (flake) | 5.3–7.1 s | 9–25 s | 7–25 s (high variance) |
| `nix develop -f shell.nix -c true` | 11–13 s | 9–12 s | 7.4 s |
| Tool via absolute store path | ~ms | ~ms | ~ms |
| `git status --porcelain` | 0.01 s | 4.1 s | 1.3 s |
| `markdownlint-cli2 "**/*.md"` | 1.2 s | 2.8 s | 1.1 s |

Notes:

* virtiofs was enabled with `virtiofs=true` under `[wsl2]` in
  `.wslconfig` on WSL 2.9.4 (newer key; older guides use
  `[experimental] autoMountType=virtiofs`). After `wsl --shutdown`,
  `mount` shows `/mnt/c type virtiofs`. Cross-OS metadata I/O improved
  ~3x; tool runs approach ext4 speed.
* `nix develop` latency is dominated by evaluation and registry/tarball
  checks, not source copying (lazy trees). It never gets close to the
  sub-second targets of `nix-for-dev`, so per-command `nix develop -c`
  is unacceptable as the everyday path.
* A `nix develop --profile <p>` run pins the devShell as a GC root;
  afterwards tools can be invoked directly by store path at
  millisecond cost. This is the basis of the "shim" option.
* File-watching (inotify) does NOT propagate from Windows-side writes
  to Linux watchers on either 9P or virtiofs. Watch/hot-reload loops
  are structurally broken for cross-OS mounts.

## Part 3: Options considered

### Option A: per-command `nix develop -c` over `wsl.exe`

Correct and simple; 7–25 s per command. Acceptable only for rare tasks
(CI parity checks), not for interactive agent loops.

### Option B: Windows shims onto store paths ("shim approach")

Setup resolves the devShell once
(`nix develop --profile ~/.local/state/devshells/<proj>`), extracts
tool store paths, generates `.cmd` shims that call
`wsl -e /nix/store/...-tool/bin/tool %*`. Millisecond-class overhead
(~0.1–0.2 s for `wsl.exe` startup).

Critique (fatal for the general case):

* Discards the devShell environment: env vars from `env.nix`,
  shellHooks, setup hooks (PYTHONPATH, pkg-config, LD_LIBRARY_PATH),
  `writeShellApplication` wrappers still work, but anything relying on
  the composed shell env breaks. Recoverable via `nix print-dev-env`
  snapshots (what nix-direnv does), but…
* Toolchain outputs become Linux artifacts (venvs, node_modules,
  target/) inside a Windows-managed tree: Windows-side tools cannot
  execute them, and NTFS lacks exec bits/symlink fidelity for them.
* inotify problem unsolved.
* Freshness drift after `shell.nix`/npins updates unless a hash-check
  is added to every shim (eroding the speed advantage).
* Effectively re-implements nix-direnv for Windows as bespoke
  infrastructure; scales poorly across N projects.

Verdict: valid only for self-contained CLI tools (just/fmt/lint), not
as the general mechanism the skills assume.

### Option C: devcontainer with docker/podman in WSL

The repo already standardizes a devcontainer (ADR-0010..0013, 0015)
with `/nix` in a named volume. Without VS Code, the devcontainer CLI
can drive it (`devcontainer up/exec`). Solves env fidelity and keeps
Linux artifacts inside the container. Blockers found: no Docker
Desktop on this machine (only rootless podman in WSL — devcontainer
CLI compatibility risk), exec latency of `devcontainer exec` (config
re-resolution per call), and the general cross-OS issues (inotify,
bind-mount I/O) remain for the mounted tree.

### Option D: wslc (WSL Containers, public preview) + GHCP CLI hooks

`wslc.exe` ships with WSL prerelease (`wsl --update --pre-release`):
Docker-like CLI (`wslc run/exec/build/ps`, `-p`, `--gpus`, volume
mounts), OCI images, per-session lightweight utility VMs, virtiofs as
the default filesystem, no Docker Desktop license. Constraints: no
Docker socket (devcontainer CLI cannot target it today), no compose,
preview quality. Also exposes a Windows API
(`Microsoft.WSL.Containers` NuGet).

On the GHCP side, there is no setting to replace the shell used by the
`powershell` tool (only `powershellFlags`), and shell tools spawn a
fresh process per command — "point the CLI at a container shell" does
not exist as a feature. However, the hooks system provides an
equivalent, officially documented mechanism:

* `preToolUse` command hooks receive `{toolName, toolArgs}` and can
  return `modifiedArgs` — substitute tool arguments. A hook can rewrite
  every shell command into
  `wslc exec <container> bash -lc '<command>'` (with path mapping).
* Command `preToolUse` hooks are fail-closed on error: if the hook
  crashes, the tool call is denied. This gives an enforcement
  guarantee that instruction files (AGENTS.md) and PATH shims cannot.
  (Caveat: hook timeouts are fail-open by design.)
* `sessionStart` hooks can ensure the container is up.

Critique:

* The model emits PowerShell-flavored commands while execution happens
  in bash: the hook must stay a thin transport and AGENTS.md must
  instruct POSIX-sh command style; residual mismatches will surface.
* An exception routing list is needed (git/gh/credential operations
  stay on Windows), which becomes maintained infrastructure.
* Latency budget per tool call: hook (pwsh spawn ~0.3 s) + `wslc exec`
  (measured in Part 5: 0.23–0.39 s warm end-to-end).
* wslc is preview software; CLI surface may change.
* inotify from Windows-side edits into the container remains unsolved;
  however if edits themselves are rerouted through the container
  (agent edits via hook-wrapped commands), watchers inside the
  container see them.

## Part 4: Layered recommendation (pre-PoC)

| Layer | Scope | Mechanism |
|---|---|---|
| 1 | Self-contained CLI tools (just, fmt, lint) | Store-path shims or per-command exec |
| 2 | Full devShell loop (toolchains, watchers, services) | Container (wslc preferred; podman/docker fallback), GHCP hook rerouting |
| 3 | Doesn't fit | Windows-native tools or declared unsupported |

Open questions deferred to the PoC:

1. `wslc exec` latency and stability.
2. Nix devShell inside a wslc container with a persistent `/nix`
   volume and the project mounted from `C:\`.
3. `preToolUse` `modifiedArgs` behavior with the real payload format.
4. End-to-end: agent turn quality when all shell goes through the
   reroute (PowerShell-vs-bash mismatch rate).

## Part 5: PoC results (2026-07-30, this repository)

Setup: wslc 2.9.4.0 (already shipped with WSL 2.9.4; no pre-release
update needed), container `poc-skills` from
`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`, project
bind-mounted `C:\...\skills -> /workspaces/skills` (virtiofs), named
volume `nix-store-poc -> /nix`. Nix installed by running the existing
`.devcontainer/postCreateCommand.sh` (ADR-0012/0013) as user `vscode`.

Measured:

* Bare `wslc exec` round-trip: 0.19–0.36 s.
* End-to-end from Windows, warm nix-direnv cache:
  `wslc exec -u vscode -e USER=vscode poc-skills bash -c
  '. ~/.nix-profile/etc/profile.d/nix.sh && cd /workspaces/skills &&
  direnv exec . just --version'` = 0.23–0.39 s
  (in-container portion ~0.15 s).
* `/nix` volume reuse: `container rm` + re-create with the same
  volume, then `postCreateCommand.sh` took the ADR-0013 bootstrap
  manifest fast path and finished in ~58 s wall.
* Hook PoC script:
  [assets/2026-07-29-wslc-reroute-hook.ps1](assets/2026-07-29-wslc-reroute-hook.ps1).
  Fed stdin JSON payloads, it rewrote
  `just --version` into the `wslc exec ...` form via
  `{"modifiedArgs":{"command":...}}`; the rewritten command executed
  successfully; malformed payload exits non-zero (fail-closed);
  `git`/`gh` commands pass through unmodified (Windows-side exception
  list).
* Bind semantics: files written inside the container appeared in the
  Windows tree immediately.

Pitfalls found and mitigations:

* CRLF working tree (`core.autocrlf=true`) breaks `bash` scripts and
  `.envrc` in the container. Mitigation: `.gitattributes` with
  `eol=lf` for `*.sh`, `*.nix`, `.envrc` (PoC used `tr -d '\r'`).
* virtiofs mounts reject `chmod`, breaking direnv's default
  `.direnv/bin` layout. Mitigation: override `direnv_layout_dir()` in
  the container's `~/.config/direnv/direnvrc` to point at
  `~/.cache/direnv/layouts/<sha1(PWD)>` (also keeps `.direnv/` off
  NTFS). The override file must still `source` nix-direnv's direnvrc,
  or caching silently degrades to plain `nix develop` per call
  (observed: 0.3 s -> ~2 s).
* `wslc exec` does not set `USER`; `nix.sh` no-ops without it — pass
  `-e USER=vscode` explicitly. `bash -lc` does not pick up the Nix
  profile either (installer uses `--no-modify-profile`), so source
  `nix.sh` explicitly.
* Stale wslc sessions cause `network is unreachable` on pulls; fix
  with `wslc system session terminate`.
* wslc has no `cp` subcommand; move files via the bind mount or
  base64-over-exec.

## Sources

* https://github.com/NixOS/nix/issues/5551, /pull/6530, /pull/13225,
  /issues/10627
* https://determinate.systems/blog/changelog-determinate-nix-352/
  (and 3.6.7, 3.8.0 changelogs)
* https://discourse.nixos.org/t/determinate-nix-3-5-introducing-lazy-trees/64350
* https://learn.microsoft.com/en-us/windows/wsl/wsl-container
* https://devblogs.microsoft.com/commandline/wsl-container-is-now-available-for-public-preview/
* https://www.boxofcables.dev/wsl2-per-device-swiotlb-pools-for-virtiofs-and-virtioproxy/
* https://softantenna.com/blog/wsl2-virtiofs-speedup/
* GitHub Docs: Copilot CLI configuration directory reference; hooks
  reference (preToolUse `modifiedArgs`, fail-closed semantics)
* Local benchmarks: this document, Part 2 (2026-07-29/30)
