# ADR 0001: Manage user-global agent skills with Microsoft APM and a personal skills repository

- Status: Accepted
- Date: 2026-07-02 (investigated and decided), recorded 2026-07-06
- Deciders: @fuj1g0n (with GitHub Copilot CLI)

## Context

GitHub Copilot CLI (and other coding agents) load user-global agent skills
from `~/.agents/skills/`. Skills were initially hand-copied there, which has
no provenance, no versioning, and no reproducibility across machines.

Options considered for managing that directory:

1. **Manual copies** — no versioning, silently drifts, rejected.
2. **Co-locate skills in dotfiles** — common in the wild (ryoppippi/dotfiles
   `agents/skills/`, wcygan/dotfiles `.codex/skills/`), but couples skill
   evolution to dotfiles history and offers no dependency resolution.
3. **Microsoft APM (Agent Package Manager)** — declarative manifest
   (`~/.apm/apm.yml`), deploys to `~/.agents/skills/` via `apm install -g`,
   supports Git-based dependencies with commit pinning and transitive
   resolution.

A survey of how the community names personal skill repositories showed:

- `<user>/skills` is the dominant convention (ryoppippi/skills, srid/skills,
  iuliandita/skills, and the official anthropics/skills).
- `<user>/agent-skills` (e.g. addyosmani/agent-skills) is used to signal
  agent-agnostic scope.
- Some keep skills inside dotfiles only; a few use brand names
  (e.g. obra's `superpowers`).

The APM CLI itself is installed via Nix
(`nix profile`, from `github:numtide/llm-agents.nix#apm`), consistent with
the machine-wide policy of managing tooling with Nix instead of ad-hoc
installers.

## Decision

- Manage all user-global agent skills through **Microsoft APM**. The deploy
  target `~/.agents/skills/` is APM-managed output and is never edited
  directly.
- Keep skill sources in a dedicated personal repository, **fuj1g0n/skills**
  (this repository), following the `<user>/skills` naming convention.
- The machine's user-scope manifest `~/.apm/apm.yml` depends on this
  repository; deployment is `apm install -g`.
- Pin all dependencies to a **full 40-character commit SHA** (or release
  tag). Short SHAs do not work because APM clones with `--branch=<ref>`,
  which only resolves branch/tag names and full SHAs. Floating branches
  drift and are not allowed.
- The edit workflow is: edit in this repo → commit and push → update the pin
  in `~/.apm/apm.yml` → `apm install -g` → verify the deploy directory.

## Consequences

- Skill state on any machine is reproducible from `~/.apm/apm.yml` alone.
- Every skill has provenance (source repo + commit) and reviewable history.
- Forgetting to re-pin after a push leaves the deployed skill silently
  stale; the workflow above must be followed on every change (encoded in
  the `skill-management` skill).
- Skills consume context in every conversation, so adoption must stay
  deliberate (see ADR 0003).
