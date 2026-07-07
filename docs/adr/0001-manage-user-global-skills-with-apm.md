---
status: accepted
date: 2026-07-02
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Manage user-global agent skills with Microsoft APM and a personal skills repository

## Context and Problem Statement

GitHub Copilot CLI (and other coding agents) load user-global agent skills
from `~/.agents/skills/`. Skills were initially hand-copied there, which has
no provenance, no versioning, and no reproducibility across machines. How
should the user-global skill set be managed?

## Considered Options

* Manual copies into `~/.agents/skills/`
* Co-locate skills in dotfiles
* Microsoft APM (Agent Package Manager) with a dedicated skills repository

## Decision Outcome

Chosen option: "Microsoft APM with a dedicated skills repository", because it
is the only option with a declarative manifest (`~/.apm/apm.yml`), Git-based
dependencies with commit pinning, and transitive resolution — manual copies
version nothing, and dotfiles co-location (common in the wild:
ryoppippi/dotfiles `agents/skills/`, wcygan/dotfiles `.codex/skills/`)
couples skill evolution to dotfiles history and offers no dependency
resolution.

Details of the decision:

* Skill sources live in **fuj1g0n/skills** (this repository), following the
  dominant `<user>/skills` naming convention (ryoppippi/skills, srid/skills,
  iuliandita/skills, anthropics/skills; `<user>/agent-skills` and dotfiles
  co-location are the minority patterns).
* The deploy target `~/.agents/skills/` is APM-managed output and is never
  edited directly; deployment is `apm install -g`.
* All dependencies are pinned to a **full 40-character commit SHA** (or a
  release tag). Short SHAs do not work: APM clones with `--branch=<ref>`,
  which only resolves branch/tag names and full SHAs. Floating branches
  drift and are not allowed.
* Edit workflow: edit in this repo → commit and push → update the pin in
  `~/.apm/apm.yml` → `apm install -g` → verify the deploy directory.
* The APM CLI itself is installed via Nix (`nix profile`, from
  `github:numtide/llm-agents.nix#apm`), consistent with the machine-wide
  policy of managing tooling with Nix.

### Consequences

* Good, because skill state on any machine is reproducible from
  `~/.apm/apm.yml` alone.
* Good, because every skill has provenance (source repo + commit) and
  reviewable history.
* Bad, because forgetting to re-pin after a push leaves the deployed skill
  silently stale; the workflow above must be followed on every change
  (encoded in the `skill-management` skill).
* Bad, because skills consume context in every conversation, so adoption
  must stay deliberate (see [ADR-0003](0003-curated-skill-set-external-survey.md)).
