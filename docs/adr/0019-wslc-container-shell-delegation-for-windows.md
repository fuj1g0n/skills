---
type: Architecture Decision Record
status: proposed
date: 2026-07-29
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Delegate shell execution to a wslc container via GHCP CLI hooks for Windows-managed projects

## Context and Problem Statement

Projects are managed on the Windows filesystem and worked on with GitHub
Copilot CLI running on Windows; neither GHCP CLI nor the interactive
shell may move into WSL. The skills in this repository assume Nix
devShells (`nix-for-dev`: env.nix, shellHooks, toolchains, watchers,
services), which require Linux. How do we let such projects use their
devShells while the working tree stays on NTFS and changes remain
directly visible to Windows-side tooling?

Determinate Nix 3.21.2 with lazy trees (default-on) removes the
historical "flake copies the whole tree to the store" problem, and
enabling virtiofs for `/mnt/c` cuts cross-OS I/O cost ~3x, so direct
`nix develop` from WSL against `/mnt/c` works — but at 7–25 s per
command it is unusable as the agent's everyday execution path, and
Linux toolchain artifacts inside an NTFS tree break Windows tooling.

## Decision Drivers

* GHCP CLI and user shell stay on Windows; project tree stays on NTFS.
* devShell fidelity: env vars, shellHooks, wrappers, services must work
  as the skills define them, without a second tool-list.
* Sub-second overhead for routine agent shell commands.
* Changes made by delegated execution must be the same files the
  Windows tree holds (bind semantics, not sync copies).
* Enforcement: the agent must not silently bypass the delegation.
* No Docker Desktop (licensing); prefer first-party tooling.

## Considered Options

* Per-command `wsl nix develop -c` (no persistent delegation)
* Windows `.cmd` shims onto resolved store paths ("shim approach")
* devcontainer CLI with docker/podman inside WSL
* wslc container + `preToolUse` hook rewriting every shell command
* wslc container + skill/wrapper delegation with a `preToolUse` guard

## Decision Outcome

Chosen option: "wslc container + skill/wrapper delegation with a
`preToolUse` guard", because a wslc container is the only execution
substrate that preserves devShell fidelity (a real Linux shell with
direnv/nix-direnv working as the skills assume), keeps Linux artifacts
out of the NTFS tree, and needs no Docker Desktop — and because, among
the two instruction mechanisms on top of it, cooperative delegation
(skill + wrapper) is structurally sounder than transparent rewriting:

* Rewriting is blind string surgery. The model on Windows emits
  PowerShell by default; a hook cannot translate dialects, so the
  rewrite variant *also* needs an instruction layer steering the model
  to POSIX sh — it never stands alone. And the model cannot see the
  rewrite, so mismatched output degrades into undebuggable confusion.
* A skill makes the model a knowing participant: it can run container
  setup, map paths contextually, and emit POSIX commands on purpose.
  Skills are also this repository's existing distribution channel to
  the wide set of consuming projects, whereas hook configs must be
  provisioned per repo or per user.
* A thin wrapper command (`devshell-exec <cmd>`) mechanizes the long
  `wslc exec … direnv exec .` incantation, cutting the model's
  generation error surface to near zero.
* The hook is kept, but demoted from rewriter to guard: it *denies*
  shell commands that invoke devShell-managed tools directly on
  Windows and replies "use devshell-exec". Deny-with-feedback retains
  the fail-closed enforcement that instructions alone lack, avoids the
  dialect-translation problem entirely, and lets the model self-correct
  from the denial message.

Architecture outline:

* A wslc container per project, image with Nix (single-user, per
  ADR-0012), `/nix` on a persistent volume (per ADR-0010), project
  mounted from `C:\` (wslc default filesystem is virtiofs).
* A `devshell-exec` wrapper script (Windows side) encapsulating
  container start-if-needed plus
  `wslc exec -u <user> -e USER=<user> <container> bash -c
  '. nix.sh && cd <mount> && direnv exec . <cmd>'` with
  Windows-to-container path mapping.
* A skill (Windows section of `nix-for-dev` or a companion skill)
  teaching: container provisioning, the CRLF/.gitattributes and direnv
  layout prerequisites, and the rule "all devShell work goes through
  `devshell-exec`; emit POSIX sh inside it".
* An optional `preToolUse` guard hook denying direct Windows-side
  invocation of devShell tool names, added when instruction drift is
  observed; `sessionStart` hook may pre-start the container.
* Layering: self-contained CLI tools may still use direct store-path
  invocation (millisecond shims); workloads that fit neither layer are
  declared unsupported on Windows.

This decision is `proposed`; the PoC below validated wslc availability
and exec latency, devShell-in-wslc with a `/nix` volume and a
`C:\`-mounted tree, and hook `modifiedArgs`/fail-closed behavior
against real payloads (informing the rewriter-vs-guard choice). A
provisional wrapper + skill implementation lives at
`.apm/skills/nix-windows-wslc/` (validated on this repository:
provisioning from scratch, warm exec ~0.8 s end-to-end including
devShell activation, subdirectory cwd mapping, exit-code propagation,
auto-restart of a stopped container). Remaining before acceptance:
guard-hook decision, multi-project validation, and container lifecycle
management.

### Consequences

* Good, because devShell semantics survive intact — no bespoke
  re-implementation of nix-direnv or env snapshots on Windows.
* Good, because enforcement is structural (fail-closed guard hook),
  not only advisory (skill text), while the model remains a knowing
  participant that can self-correct from denial feedback.
* Good, because Docker Desktop is not required and no third-party
  container runtime must be maintained.
* Bad, because wslc is public preview: CLI surface and behavior may
  change; no compose (services must run via process-compose inside the
  devShell, which the skills already prefer).
* Bad, because every delegated tool call pays wrapper + exec overhead
  (measured: 0.23–0.39 s warm end-to-end for
  `wslc exec … direnv exec . <cmd>`), and the PowerShell-emitting
  model must be steered to POSIX sh inside the wrapper, leaving a
  residual command-dialect mismatch rate.
* Bad, because the wrapper, skill text, and guard hook become
  maintained infrastructure of this repository.
* Bad, because inotify from Windows-side edits still does not reach
  container watchers; watch loops only work for changes made through
  the container path.
* Bad, because CRLF working trees (core.autocrlf=true) break shell
  scripts and `.envrc` inside the container; adopting this decision
  requires `.gitattributes` pinning `eol=lf` for `*.sh`, `*.nix`, and
  `.envrc` in participating projects.
* Bad, because virtiofs mounts reject `chmod`, so the direnv layout
  directory must be relocated off the mounted tree (a
  `direnv_layout_dir()` override in the container's direnvrc); this
  also keeps `.direnv/` Linux artifacts out of the NTFS tree.

### Confirmation

PoC executed on this repository (wslc 2.9.4.0, image
`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`, `/nix` on a named
volume, project bind-mounted from `C:\` via virtiofs). All four
criteria passed:

1. Latency budget < 1 s warm: bare `wslc exec` round-trip 0.19–0.36 s;
   end-to-end `wslc exec … direnv exec . just --version` with a warm
   nix-direnv cache 0.23–0.39 s (in-container portion ~0.15 s).
2. devShell tools work against the mounted NTFS tree. `/nix` volume
   reuse confirmed: after `container rm` + re-create with the same
   volume, `.devcontainer/postCreateCommand.sh` rebuilt the profile
   from the bootstrap manifest (ADR-0013 offline path) in ~58 s with
   no image rebuild.
3. A `preToolUse` hook returning
   `{"modifiedArgs":{"command":"wslc exec …"}}` rewrote a shell
   command that then executed in the devShell; the hook exits non-zero
   on malformed payloads (fail-closed) and passes through an
   exception-listed `git` command unmodified.
4. Files written inside the container appeared in the Windows tree
   immediately (bind semantics, no sync step), and the relocated
   direnv layout kept `.direnv/` out of the NTFS tree.

## Pros and Cons of the Options

### Per-command `wsl nix develop -c`

* Good, because zero standing infrastructure and full fidelity.
* Bad, because 7–25 s per command (measured) is unusable
  interactively.

### Windows shims onto store paths

* Good, because millisecond-class overhead (measured).
* Good, because adequate for the self-contained-CLI layer (kept as a
  complementary layer).
* Bad, because it discards composed devShell environment semantics and
  produces Linux artifacts inside the NTFS tree.
* Bad, because freshness drift and per-project shim management
  re-implement nix-direnv as bespoke Windows infrastructure.

### devcontainer CLI with docker/podman inside WSL

* Good, because it reuses the repository's devcontainer standard
  (ADR-0010, ADR-0015) and the devcontainer.json contract.
* Bad, because it requires installing and maintaining a container
  runtime in WSL (rootless podman has known devcontainer-CLI friction;
  docker-ce is third-party infrastructure to manage).
* Bad, because `devcontainer exec` re-resolves configuration per call,
  adding seconds of latency; falling back to raw `docker exec`
  abandons the devcontainer contract anyway.
* Neutral, because it remains the fallback if wslc preview proves too
  unstable; the delegation design is runtime-agnostic.

### wslc container + `preToolUse` hook rewriting every shell command

* Good, because first-party, Docker-Desktop-free, virtiofs-native.
* Good, because fail-closed enforcement of delegation.
* Bad, because rewriting is invisible to the model and cannot
  translate PowerShell to POSIX sh, so it still depends on an
  instruction layer while adding a silent-magic failure mode.
* Bad, because the exception list (git/gh/credentials) is regex-based
  permanent maintenance.

### wslc container + skill/wrapper delegation with a `preToolUse` guard

* Good, because first-party, Docker-Desktop-free, virtiofs-native.
* Good, because the model participates knowingly (setup, path mapping,
  POSIX emission) and the wrapper mechanizes the exec incantation.
* Good, because skills are the repository's existing distribution
  channel to consuming projects; the optional guard hook restores
  fail-closed enforcement without dialect translation.
* Bad, because preview-quality runtime; measured quirks: stale wslc
  sessions break registry pulls until `wslc system session terminate`,
  `wslc exec` does not set `USER`, and there is no `cp` subcommand.

## More Information

Research snapshot:
[2026-07-29-windows-wslc-devshell-delegation](../research/2026-07-29-windows-wslc-devshell-delegation.md)
(benchmarks 9P vs virtiofs vs ext4, lazy trees status, shim critique,
wslc and hooks findings). Related: [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md)
(devcontainer with Nix devShell), [ADR-0012](0012-use-upstream-installer-single-user-mode.md)
(single-user Nix in containers),
[ADR-0014](0014-zero-inputs-flake-with-npins.md) (zero-inputs flake —
prerequisite for lazy-trees-friendly evaluation). Revisit when wslc
reaches general availability or when GHCP CLI gains a native
shell-override setting.
