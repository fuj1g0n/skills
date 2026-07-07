---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Author an original skill-authoring skill combining audited upstream practices

## Context and Problem Statement

The skills in this repository were written without a codified quality
process: no description-quality rules, no length discipline, no
collection-wide audit, no way to test whether a skill actually changes agent
behavior. The ecosystem was surveyed for meta-skills and tooling that raise
skill quality (full survey:
[docs/research/2026-07-07-skill-quality-meta-skills.md](../research/2026-07-07-skill-quality-meta-skills.md)).
How should skill-quality practice be brought into this repository?

Key survey outcomes: no single upstream covers all five quality dimensions
(description/trigger, structure, token economy, testing, collection
maintenance); the strongest eval infrastructures (anthropics/skills,
DMoneyOH) are Claude-Code- or API-bound and heavy; the only collection-wide
auditor in skill form is ryoppippi/dotfiles' `skill-maintenance` (MIT); the
sharpest empirically-tested rules are obra/superpowers' description
discipline and pressure-testing (MIT) and mizchi/skills'
Iteration-0 consistency check and two-sided evaluation (MIT per repository
README default).

## Decision Drivers

* The installed skill set must stay small and its always-loaded metadata
  cheap (ADR-0001/0003); a 33 KB skill-creator is out of proportion for a
  ~10-skill personal collection.
* Licensing hygiene: adapt only MIT/Apache-2.0 text; unlicensed and GPL-3
  sources contribute concepts at most (ADR-0003).
* Mechanical checks should run as tools, not consume skill context;
  `apm audit` is already in the toolchain.
* This environment is Copilot CLI + APM, not Claude Code plugins.

## Considered Options

* Re-export an upstream meta-skill as-is (anthropics `skill-creator`,
  obra `writing-skills`, or ryoppippi's pair)
* Author an original `skill-authoring` skill combining audited practices
  from several MIT/Apache sources
* Rely on static tooling only (`apm audit`, `skill-tools` CLI), no skill

## Decision Outcome

Chosen option: "Author an original `skill-authoring` skill", because no
upstream fits as-is — anthropics' and obra's skills are an order of
magnitude larger than this collection warrants and partly Claude-Code-bound,
ryoppippi's pair lacks testing entirely, and tooling-only covers just the
countable checks — while all the strong sources are MIT/Apache and can be
combined legally into a skill sized for this repository (the same rationale
as ADR-0005 for the `adr` skill).

The skill lives at `.apm/skills/skill-authoring/`, one skill covering both
authoring and collection audit (a separate auditor skill does not earn its
own metadata slot at this collection size):

* **From ryoppippi (MIT), the backbone**: authoring workflow and rules
  (description 20–35 words, third person, what + when; 150-line soft /
  500-line hard ceiling with split/stop-splitting triggers;
  documentation-by-reference; overlap protocol) and the collection audit
  (adapted `scripts/audit.sh` + `references/audit-checks.md`).
* **From obra (MIT)**: the description rule that a workflow summary in the
  description makes agents skip the body — triggers only; keyword coverage;
  and the pressure-test methodology (RED/GREEN/REFACTOR with rationalization
  table) in `references/testing-skills.md`.
* **From mizchi (MIT)**: the two-track description policy (project skills
  pushy, meta skills explicit-only) and, from `empirical-prompt-tuning`, the
  Iteration-0 description/body consistency check plus a trimmed two-sided
  evaluation loop (blank-slate subagent, fixed requirements checklist with
  `[critical]` items, self-reported unclear points / discretionary
  fill-ins). The full apparatus (failure-pattern ledger, waxa CLI, metric
  convergence thresholds) is **not** adopted: at this collection size the
  bookkeeping costs more than it returns. Judgment recorded here so it can
  be revisited if the collection grows.
* **From anthropics (Apache 2.0)**: progressive-disclosure framing and the
  "pushy description" doctrine, folded into the two-track policy.
* **Mechanical checks stay in tools**: `apm audit` (hidden Unicode,
  tamper detection) before every release; the adapted `audit.sh` for
  countable conventions. The `skill-tools` CLI (Apache 2.0) is noted as an
  optional CI gate but not adopted now (7-star project; audit.sh + apm audit
  cover current needs).

### Consequences

* Good, because all five quality dimensions get coverage sized to this
  collection, with clean licensing and attribution.
* Good, because deterministic checks run as scripts (executed, not loaded),
  keeping the always-loaded surface at one description.
* Bad, because an original skill gets no upstream fixes; sources should be
  re-checked when they evolve (same trade-off as ADR-0005).
* Bad, because the trimmed evaluation loop is weaker than the full
  anthropics/mizchi infrastructure; regressions in skill effectiveness may
  go unnoticed between manual test runs.

## More Information

Survey snapshot:
[2026-07-07-skill-quality-meta-skills.md](../research/2026-07-07-skill-quality-meta-skills.md)
(first application of the ADR-0006 tier-2 rule). Sources adapted per this
decision are attributed in the skill's own Attribution section.
