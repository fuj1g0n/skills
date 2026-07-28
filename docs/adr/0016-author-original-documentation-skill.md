---
type: Architecture Decision Record
status: proposed
date: 2026-07-28
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Author an original documentation skill

## Context and Problem Statement

Agent-authored project documentation — README, CHANGELOG, and the contents
of `docs/` — has no codified format guidance in this collection; only
decision records are covered (`adr`, MADR 4.0 per
[ADR-0004](0004-adopt-madr-format.md)). Which documentation-format guidance
should be provided as a skill, and which belongs in existing skills?

Two surveys were run on 2026-07-28 (snapshots per ADR-0006:
[formats landscape](../research/2026-07-28-documentation-formats-landscape.md),
[skill-ecosystem survey](../research/2026-07-28-documentation-skill-ecosystem.md)).
Essence:

| Approach | Status / license | Agent-actionability | Existing skill coverage |
|---|---|---|---|
| Diátaxis (tutorial/how-to/reference/explanation) | active; free, no formal license | high — unambiguous category rules + compass | **none found** |
| Keep a Changelog 1.1.0 | stable; CC BY 4.0 (inferred, verify) | high — exact, testable format | thin (wshobson `changelog-automation`, MIT) |
| standard-readme | active; MIT | high — mechanical section order | **none found** |
| Docs-as-code hygiene (GFM, in-repo docs, PR review, prose/link lint) | dominant practice | high | **none found** |
| arc42 v9 / C4 | active; CC BY-SA 4.0 / free | medium — architecture-doc niche | ADR content already local (`adr`) |
| llms.txt | proposal, modest adoption; not auto-fetched by LLMs | low-medium — publish-side | none |
| DITA / Information Mapping / reStructuredText | niche XML / proprietary / declining | low | none |

The Open Knowledge Format, surveyed in the same pass, is decided separately:
[ADR-0017](0017-adopt-okf-for-repository-documentation.md) adopts it for
this repository's own documentation; whether OKF bundle-authoring guidance
becomes an installed skill is handled under "deferred" below.

The skill ecosystem at large is fragmented: no canonical documentation skill
exists; ADR writing is the only mature subcategory (settled locally by
[ADR-0005](0005-adr-skill-sourcing.md)); adjacent categories (design docs,
doc co-authoring, PRD) have good upstreams (cassiobotaro `design-doc` MIT,
anthropics `doc-coauthoring` Apache-2.0) but are distinct workflows, not
repo-documentation formats.

## Decision Drivers

* Every installed skill's metadata loads into every conversation
  ([ADR-0001](0001-manage-user-global-skills-with-apm.md)/[0003](0003-curated-skill-set-external-survey.md));
  `skill-authoring` policy: add a skill only for recurring work, otherwise
  extend an existing skill.
* One home per detail: overlap resolves by cross-link, never duplication
  (`skill-authoring`); decision records already live in `adr`.
* Ecosystem-first sourcing with license hygiene: depend or fork where a
  fit MIT/Apache upstream exists, author an original otherwise; unlicensed
  sources contribute concepts only (ADR-0003).
* Skills encode conventions expected to hold; emerging proposals with
  unstable adoption are a poor skill substrate.
* Included formats must be agent-actionable: procedural and mechanically
  checkable, not prose philosophy.

## Considered Options

* Author one original documentation skill
* Author several narrow skills (readme / changelog / docs-structure)
* Re-export or fork upstream documentation skills as-is
* No new skill: extend existing skills only, leave formats to per-repo
  AGENTS.md

## Decision Outcome

Proposed option: "Author one original documentation skill", because the
format areas worth encoding (Diátaxis structure, README, CHANGELOG,
docs-as-code hygiene) are exactly the ones with **no fit upstream to depend
on or fork** — the survey found them absent or thin across every collection
and a 162k-skill registry index — while all needed sources are cleanly
licensed or usable as concepts; and the areas share one trigger surface
("write/organize project documentation"), so a single metadata slot covers
them (the sizing judgment of
[ADR-0007](0007-author-original-skill-authoring-skill.md)).

**Provided as a new skill** (working name `documentation`, at
`.apm/skills/documentation/`, in a follow-up PR after this ADR is
accepted):

* Diátaxis as the organizing rule for `docs/` content: the four types,
  the compass, incremental application (concepts only with the canonical
  site linked — the framework has no formal license).
* README conventions per standard-readme (MIT): required/optional
  sections and their fixed order.
* CHANGELOG per Keep a Changelog 1.1.0: six change types, `Unreleased`
  section, commit-log-dump anti-pattern; structural concepts adapted from
  wshobson `changelog-automation` (MIT).
* Docs-as-code hygiene: GFM as default markup, docs reviewed via PR,
  prose/link checks named as tools not pasted.
* Sized per `skill-authoring`: core SKILL.md + `references/` split from
  day one; domain-track (pushy) description.

**Integrated into existing skills — nothing moves, boundaries recorded**:

* Decision records stay solely in `adr`; the documentation skill
  cross-links it and stops there (no MADR duplication). Research-snapshot
  handling likewise stays with `adr` (ADR-0006).
* SKILL.md authoring stays in `skill-authoring`; AGENTS.md /
  copilot-instructions authoring is excluded from the documentation skill
  (the only upstream, awesome-copilot's `acreadiness-generate-instructions`,
  is AgentRC-bound; revisit under skill-management criteria on recurring
  need).

**Deferred / out of scope** (recorded to prevent re-litigation):

* OKF bundle-authoring guidance: OKF itself is adopted for this
  repository's documentation (ADR-0017), but an installed skill for
  authoring/maintaining OKF bundles is a separate adoption decision under
  skill-management criteria; fit upstreams are identified for that day
  (scaccogatto/okf-skills MIT, vendoring spec v0.2; serradura/okf-gem
  Apache-2.0, v0.1).
* llms.txt (publish-side concern, modest adoption, not auto-fetched);
  arc42/C4 full templates (no recurring architecture-doc need beyond
  decision records); DITA and Information Mapping (XML toolchain /
  proprietary, incompatible with docs-as-code); design-doc, doc-coauthoring
  and PRD upstreams (adjacent categories — separate adoption decisions via
  skill-management criteria if a recurring need appears).

### Consequences

* Good, because the collection gains the only empty, high-actionability
  format areas with clean licensing, at the cost of one metadata slot.
* Good, because decision records keep a single home; the cross-link rule
  removes the main duplication risk between `documentation` and `adr`.
* Bad, because always-loaded metadata still grows by one skill in every
  conversation.
* Bad, because an original skill receives no upstream fixes (same
  trade-off as ADR-0005/0007); Diátaxis, Keep a Changelog and
  standard-readme must be re-checked on maintenance.
* Bad, because one broad skill risks outgrowing the 150-line soft ceiling;
  the `references/` split must be enforced from the start.

### Confirmation

Decision before implementation: the skill lands only after this ADR is
accepted. At authoring time the `skill-authoring` release checks apply:
Iteration-0 description/body consistency, `scripts/audit.sh`, `apm audit`,
and deployment via the `skill-management` workflow. The description is
verified to trigger on documentation keywords (README, CHANGELOG, docs
structure, tutorial/how-to) without summarizing the workflow.

## More Information

Research snapshots (ADR-0006 tier 2, both 2026-07-28, immutable):
[documentation formats landscape — OKF deep-dive and methodology survey](../research/2026-07-28-documentation-formats-landscape.md);
[documentation-writing skills in the agent-skill ecosystem](../research/2026-07-28-documentation-skill-ecosystem.md).

An earlier draft of this ADR also proposed deferring OKF adoption; that
question was split out and decided the other way in
[ADR-0017](0017-adopt-okf-for-repository-documentation.md) (one ADR, one
decision).

Related decisions: [ADR-0003](0003-curated-skill-set-external-survey.md)
(adoption criteria: depend / fork / original),
[ADR-0004](0004-adopt-madr-format.md) (MADR for this log),
[ADR-0005](0005-adr-skill-sourcing.md) /
[ADR-0007](0007-author-original-skill-authoring-skill.md) (original-skill
precedents this decision follows).
