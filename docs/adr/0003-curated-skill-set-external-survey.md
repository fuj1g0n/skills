---
status: accepted
date: 2026-07-02
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Curate the development-environment skill set from an external landscape survey

## Context and Problem Statement

Before authoring skills from scratch, the external ecosystem was surveyed for
skills that enforce the local policy — "user-level environment via
`nix profile`, repository-level environment via flake devShell + direnv, no
ad-hoc global installs" — and for skills that govern skill management itself.
For each useful upstream skill, how should it be brought into this
repository?

### Survey: Nix environment skills

| Skill | Source | Role | Notes |
|-------|--------|------|-------|
| `nix-for-dev` | srid/emanote (`.agents/skills/nix-for-dev/`) | Repository-level reference | Author is a well-known Nix community figure (nixos.asia, flake-parts). Zero-inputs flake + npins for fast `nix develop` (~1s cold); prescribes `flake.nix`/`shell.nix`/`nix/` layout. |
| `nix-manager` | wcygan/dotfiles (`.codex/skills/nix-manager/`) | User-level reference | Determinate Nix + `nix profile` flake-managed user toolchain (`nix flake update && nix profile upgrade`). Widely mirrored (e.g. majiayu000/claude-skill-registry). |
| `missing-tools` | ryoppippi/dotfiles (`agents/skills/missing-tools/`) | Daily-operation enforcement | Bans global installs (`npm i -g`, `brew install`, `uv tool install`, ...); resolution order `direnv exec .` → `comma` → `nix run nixpkgs#` → `nix shell`. Closest embodiment of the local "no apt-get, everything via Nix" policy. |
| `nix-github-rate-limit` | ryoppippi/dotfiles | Daily operation | Injects GitHub tokens for flake fetches via `gh auth token` without persisting tokens to `nix.conf` or files. |
| `nix-gc-direnv` | ryoppippi/dotfiles (`.claude/skills/`) | Daily operation | Cleanup workflow for `.direnv` directories acting as Nix store GC roots. |
| `nix` / `nixos-btw` | majiayu000/claude-skill-registry, iuliandita/skills | Generic guides | Codify "no `nix-env -i`, prefer declarative"; superseded by the more specific skills above. |

Notably, **no official Nix skill exists** in anthropics/skills,
DeterminateSystems, or numtide repositories — the de-facto standards are
individual-authored skills. srid's `nix-for-dev` (design, repo level) and
wcygan's `nix-manager` (design, user level) complement ryoppippi's three
operational skills; together they cover the full policy.

### Survey: skill-management meta skills

| Skill | Source | Notes |
|-------|--------|-------|
| `apm-usage` | microsoft/apm (`packages/apm-guide`) | Official guide package: `apm.yml` syntax, files to commit (`apm.yml`/`apm.lock.yaml`, gitignore `apm_modules/`), version pinning, auth, audit; 8 reference docs. |
| `skill-selector` (+ `skill-finder`, compact `apm-usage`) | mizchi/skills (`meta/skill-selector`) | Meta skill for disciplined APM-based adoption: two-phase selection (curated catalog → search/evaluate), "no impulsive installs", "every skill costs context per conversation", full SHA/tag pinning, `apm install -g` for global scope. **Repository has no license.** |
| `skill-creator` / `skill-maintenance` | ryoppippi/dotfiles | Authoring/maintenance of skills themselves; APM-independent, complementary. |

## Considered Options

* Fork-and-adapt into this repository (rewrite for this environment)
* Direct APM dependency (re-export as-is, see [ADR-0002](0002-apm-package-layout-and-reexport.md))
* Write an original skill (concepts only, no text copied)

## Decision Outcome

Chosen option: all three, applied per skill by license and customization
need:

* **Fork and adapt** the five Nix skills (`nix-manager`, `nix-for-dev`,
  `missing-tools`, `nix-github-rate-limit`, `nix-gc-direnv`), rebuilt
  faithfully from their reference sources and adjusted for this environment
  (Determinate Nix, WSL2, uv, just, direnv).
* **Re-export** the official `microsoft/apm/packages/apm-guide` (`apm-usage`)
  as an APM dependency, unmodified.
* **Author an original** `skill-management` skill for the operational rules:
  mizchi's `skill-selector` is unlicensed, so its text was not copied; only
  concepts informed an independent write-up.

Adoption criteria going forward (encoded in `skill-management`): recurring
need only, read the SKILL.md before installing, check the license, prefer
fork-and-adapt when environment-specific customization is needed and direct
APM dependency for well-maintained upstreams used as-is.

### Consequences

* Good, because the installed user-global set stays small and policy-aligned
  (context cost per conversation is bounded).
* Good, because the unlicensed-upstream rule (depend or rewrite, never copy)
  protects the repository's licensing hygiene.
* Bad, because forked skills do not auto-track upstream; upstream changes
  must be reviewed and merged manually.
* Bad, because the survey is a point-in-time snapshot (2026-07); the
  ecosystem moves fast and should be re-surveyed when new needs arise.
