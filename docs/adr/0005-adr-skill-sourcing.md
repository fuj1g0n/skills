---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Author an original adr skill adapted from MIT-licensed sources

## Context and Problem Statement

A reusable agent skill is wanted that makes coding agents write proper ADRs
as part of a generic development process. The external skill ecosystem was
surveyed (GitHub code search plus explicit checks of the major collections)
for existing ADR-writing skills. Should one be adopted as-is, forked, or
written originally?

Survey findings (2026-07):

| Candidate | License | Format | Notes |
|---|---|---|---|
| cassiobotaro/skills `adr` | MIT (+ NOTICE.md) | Nygard / adr-tools exact | Best workflow discipline (record-don't-invent contract, supersede surgery, i18n prose/scaffolding split); targets the abandoned adr-tools ecosystem. |
| musingfox/cc-plugins `adr` + `adr-ref-guard` | MIT | MADR 4.0 | Best lifecycle management (7-step supersession, 4-layer cross-reference scan, consistency checker). |
| github/awesome-copilot `create-architectural-decision-record` | MIT (GitHub, Inc.) | Custom hybrid | Native SKILL.md; frontmatter with `supersedes`/`superseded_by`; coded bullets (POS-001...) for machine parsing; input validation. |
| wshobson/agents `architecture-decision-records` | MIT | MADR primary + 4 alt templates | Most comprehensive reference: when-to-write table, index template, review checklist, lifecycle. |
| tclem/dotfiles `adr-author` | **No license** | Nygard-inspired | Best editorial principles ("the bar is high" trigger calibration, ADR PR before implementation PR); text not copyable. |
| osteel, ljmerza, benchalmers, davidamitchell, camilooscargbaptista, angga30 | No license | various | Substantive but unlicensed. |

The major curated collections carry **no ADR skill**: anthropics/skills,
obra/superpowers, mizchi/skills, awesome-claude-code, travisvn/
awesome-claude-skills, awesome-cursorrules, iannuttall/claude-agents.
github/awesome-copilot and wshobson/agents were the only hits among the
famous collections.

## Considered Options

* Adopt one upstream skill as-is (APM dependency / re-export)
* Fork one upstream skill and adapt it
* Author an original skill, adapting concepts and MIT-licensed material from
  several sources

## Decision Outcome

Chosen option: "Author an original skill, adapting from several sources",
because no single upstream matches the chosen format and constraints: the
best-disciplined skill (cassiobotaro) targets the abandoned adr-tools
ecosystem rather than MADR ([ADR-0004](0004-adopt-madr-format.md)); the
best-edited one (tclem) is unlicensed; the MADR ones (musingfox, wshobson)
are Claude-Code plugin-shaped and heavier than needed. All strong sources are
MIT (or concepts-only), so a focused original that combines them is both
legal and better fitted.

The skill lives at `.apm/skills/adr/` in this repository:

* **Format**: MADR 4.0; official templates shipped verbatim in `references/`
  (MIT OR CC0-1.0).
* **From cassiobotaro** (MIT): the contract (record-don't-invent, one ADR one
  decision, immutability except status), directory discovery, neighbor
  reading, ask-before-writing, English-scaffolding rule, self-review.
* **From wshobson** (MIT): when-to-write table, index maintenance, honest
  trade-offs emphasis.
* **From github/awesome-copilot** (MIT): input validation stance,
  supersede/superseded-by traceability in frontmatter.
* **From tclem** (concepts only): "the bar is high" trigger calibration,
  decision-before-implementation (ADR in the same or earlier PR).
* Attribution recorded in the skill's own Attribution section.

### Consequences

* Good, because the skill matches this environment exactly (APM layout, MADR
  format, GitHub-native rendering) with clean licensing.
* Good, because MADR templates are vendored verbatim, so format drift from
  the standard is visible in diffs.
* Bad, because an original skill gets no upstream fixes; the source skills
  should be re-checked when they evolve.

## More Information

Survey conducted 2026-07-07 by two research passes (general GitHub code
search; explicit sweep of famous collections including github/awesome-copilot
and awesome-claude-code), with primary-source reads of each candidate
SKILL.md.
