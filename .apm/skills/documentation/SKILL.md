---
name: documentation
description: >
  Structures and writes project documentation. Use when authoring or
  reorganizing READMEs, CHANGELOGs, docs/ trees, OKF knowledge bundles,
  tutorials, how-to guides, or reference/explanation pages — trigger on
  documentation-format work even when no framework is named.
---

# Project Documentation

This skill owns repository documentation formats: README, CHANGELOG,
`docs/` organization (Diátaxis), docs-as-code hygiene, and OKF bundle
conventions. It does not own decision records (`adr` skill) or SKILL.md
authoring (`skill-authoring` skill).

## Organize docs/ with Diátaxis

Four mutually exclusive types; one page serves one type:

| Type | Serves | Reader is |
|---|---|---|
| Tutorial | learning by doing | a beginner you guide through a safe, works-every-time lesson |
| How-to guide | a task | a competent user with their own goal, in their real context |
| Reference | information | a user at work needing bare, authoritative facts |
| Explanation | understanding | a reader at leisure wanting reasons, context, trade-offs |

- Classify by the reader's need, not the topic. A page mixing types gets
  split, not blended.
- Apply incrementally: improve the page being touched; never launch a
  big-bang restructure of the tree.
- When classification is contested or a page resists typing, read
  [references/diataxis.md](references/diataxis.md) (compass, type
  contracts, classic confusions).
- Canonical source: <https://diataxis.fr/> — link it, do not paste it.

## README

Follow the standard-readme section order. Required: title, short
description directly under it, Install, Usage, Contributing, License
(last). Optional, in their fixed positions: banner, badges, long
description, Table of Contents (recommended unless very short), Security,
Background, API, Maintainers, Thanks, extra sections before API.

- Install and Usage are runnable: exact commands in fenced blocks, in the
  order a new user executes them, stating the environment they assume.
- One home per listing: don't hand-maintain in the README an index that a
  directory or generated page already provides — link it instead.
- Spec: <https://github.com/RichardLitt/standard-readme>.

## CHANGELOG

Keep a Changelog 1.1.0 (<https://keepachangelog.com/en/1.1.0/>):

- One `CHANGELOG.md`, newest first; `## [X.Y.Z] - YYYY-MM-DD` per
  release; an `## [Unreleased]` section on top accumulates the next
  release's notes and makes release cuts a rename.
- Group entries under exactly: `Added`, `Changed`, `Deprecated`,
  `Removed`, `Fixed`, `Security`.
- Entries are for humans: the observable change and its impact, not the
  commit. Never dump `git log` output — that is the anti-pattern the
  format exists to prevent.
- Yanked releases stay listed: `## [X.Y.Z] - YYYY-MM-DD [YANKED]`.

## OKF bundles

A docs tree is an Open Knowledge Format bundle when its root `index.md`
declares `okf_version` in frontmatter (or the repo has a `.okf/`
directory). Inside one:

- Every non-reserved `.md` gets YAML frontmatter with a non-empty `type`
  (free-form string). Never name an ordinary concept `index.md` or
  `log.md` — reserved names.
- Reserved-file upkeep is repo policy, not a spec duty: per-directory
  `index.md` listings and `log.md` are optional, and some repositories
  deliberately maintain neither (git history as the log). Check the root
  index or the repo's ADRs before creating or updating either; do not
  assume.
- Consult the spec at its canonical URL — never vendor a copy:
  <https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md>
- ADRs inside a bundle: the `adr` skill owns their frontmatter (it adds
  `type: Architecture Decision Record`).

## Docs-as-code hygiene

- GFM Markdown is the default markup; docs live in the repo and change in
  the same PR as the code they document; review docs like code.
- Run the checkers the repo already configures (markdownlint-cli2,
  lychee/markdown-link-check, Vale, ...); do not introduce new ones
  unasked.

## Boundaries

- Decision records (MADR, statuses, supersede surgery) → `adr` skill.
- SKILL.md authoring → `skill-authoring` skill.
- AGENTS.md / copilot-instructions authoring: out of scope (ADR-0016).

## Attribution

- README conventions adapted from
  [RichardLitt/standard-readme](https://github.com/RichardLitt/standard-readme) (MIT).
- CHANGELOG rules follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
  (linked, not copied); structural concepts from
  [wshobson/agents](https://github.com/wshobson/agents)
  `changelog-automation` (MIT).
- Diátaxis concepts from [diataxis.fr](https://diataxis.fr/) by Daniele
  Procida (no formal license — concepts only, canonical site linked).
- OKF conventions per ADR-0017/ADR-0018 of the fuj1g0n/skills decision
  log.
