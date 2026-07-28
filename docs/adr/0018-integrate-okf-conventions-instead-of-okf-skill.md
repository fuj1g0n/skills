---
type: Architecture Decision Record
status: accepted
date: 2026-07-28
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Integrate OKF conventions into existing skills instead of adopting an OKF skill

## Context and Problem Statement

[ADR-0017](0017-adopt-okf-for-repository-documentation.md) made `docs/` an
OKF v0.2 bundle with a strict local policy: reserved `index.md`/`log.md`
files are not maintained (git is the log) and ADR `status` keeps MADR
vocabulary. [ADR-0016](0016-author-original-documentation-skill.md)
deferred the follow-on question, now due: should OKF bundle-authoring
guidance come from an existing OKF skill consumed via APM, a fork, or
original content — and where should it live?

A dedicated survey with live verification was run
([snapshot](../research/2026-07-28-okf-skill-apm-feasibility.md)). The
essentials:

| Candidate | Spec | APM-consumable | Policy fit |
|---|---|---|---|
| scaccogatto/okf-skills `okf` (authoring; MIT, 110 stars, active) | v0.2 vendored (38 KB) | **yes — verified live install and transitive re-export** | produce/maintain steps *unconditionally* create per-directory `index.md` and append `log.md`; OKF-only status vocabulary; triggers on "any work in a repo that has an OKF bundle" |
| scaccogatto `validate` (checker script) | v0.2 | yes | clean — our deviations surface as warnings, not errors |
| serradura/okf-gem skill (Apache-2.0) | **v0.1** (stale: `timestamp`, `okf_version: "0.1"` templates) | no (gem/plugin install) | same index/log conflicts plus version mismatch |
| okforge / okf-harness / PyPI `okf` | — | no | source 404 / no SKILL.md / placeholder |

Two empirical facts frame the decision. First, APM mechanics are *not*
the constraint: `scaccogatto/okf-skills/skills/okf#<40-sha>` installs and
re-exports cleanly despite upstream having no `apm.yml` (verified, apm
0.23.1); APM copies the whole subtree, so the conflicting workflow steps
cannot be stripped without forking. Second, this bundle already passes the
upstream validator — `okf_validate.py` reports **conformant, 0 errors**
(115 warnings, all the documented ADR-0017 deviations) — so the missing
piece is not conformance tooling but a few authoring conventions.

## Decision Drivers

* Installed guidance must not contradict repository policy: a skill whose
  core workflow violates ADR-0017 — and whose description fires on every
  conversation in this repository, since `docs/` is a bundle — has
  negative value regardless of quality.
* Every skill's metadata loads into every conversation; `skill-management`
  installs only for recurring needs and requires the SKILL.md to actually
  fit the environment before install.
* The OKF surface this repository uses is deliberately small (ADR-0017:
  `type:` frontmatter, root version marker, no reserved-file upkeep) —
  roughly ten lines of convention.
* One home per detail (`skill-authoring`): ADR frontmatter belongs to the
  `adr` skill; docs-tree conventions belong to the documentation skill
  proposed in ADR-0016.
* Upstream churn is high: scaccogatto tagged v0.1.0 → v0.4.0 within six
  weeks, vendoring the full spec; the spec itself broke compatibility
  within three months (accepted in ADR-0017, but not worth importing as a
  dependency-update treadmill).

## Considered Options

* Depend on scaccogatto/okf-skills via APM and re-export (ADR-0002
  pattern)
* Fork the `okf` skill into `.apm/skills/okf/` and adapt it
* Author an original standalone `okf` skill
* No standalone OKF skill: integrate minimal conventions into the `adr`
  skill and the planned documentation skill

## Decision Outcome

Chosen option: "No standalone OKF skill: integrate minimal conventions
into existing skills", because the only APM-viable upstream fails the fit
test on its core workflow — its produce/maintain modes unconditionally
instruct exactly what ADR-0017 forbids, and APM's copy-whole-tree
semantics offer no way to adopt it partially; because forking would
inherit a 38 KB vendored spec, scripts (with hidden-character audit
warnings), and weekly upstream drift only to delete the workflow that is
the skill's substance; and because an original standalone skill fails the
recurring-need bar when the entire content is ~10 lines that belong in
skills that already trigger at the right moments.

Implementation:

* The `adr` skill gains OKF-bundle awareness (a few lines): when the
  decision log lives inside an OKF bundle (root `index.md` declaring
  `okf_version`), include `type: Architecture Decision Record` in new
  ADRs' frontmatter and follow the repository's stated reserved-file
  policy rather than assuming index/log upkeep. The skill runs a few
  lines past the ~150-line soft mark; accepted — one cohesive bullet
  consulted on every ADR beats a `references/` indirection.
* The documentation skill (ADR-0016) owns bundle-level conventions in a
  short section: bundle detection, `type:` on every concept, deference to
  repo policy on reserved files, canonical spec **linked, never
  vendored** (the staleness lesson from serradura's v0.1 copy).
* ADR-0016's deferred OKF-skill item is resolved by this ADR (edited
  while still proposed).
* No conformance CI gate now: the upstream validator passes this bundle
  in default mode by design (deviations are warnings) so it would assert
  little, and `--strict` is unusable here. Revisit the SHA-pinned
  composite action (noting its floating `setup-uv` inner tag) if the
  bundle gains contributors.

Rejection of the alternatives: the APM dependency is mechanically proven
but semantically wrong — installing instructions the repository must
ignore trains agents to violate ADR-0017 on every docs change; the fork
maximizes maintenance while discarding most upstream value; the original
standalone skill adds a permanent metadata slot for content consulted
only inside this repository's docs workflow.

### Consequences

* Good, because no policy-contradicting guidance is ever loaded, and the
  conventions ride skills that already trigger at the right time (`adr`
  on decisions; documentation skill on docs work).
* Good, because zero new metadata slots and zero coupling to a pre-1.0
  upstream releasing weekly.
* Good, because the adoption path stays open and cheap: the one-line
  SHA-pinned dependency is verified to work if upstream ever makes
  reserved-file upkeep conditional on repo policy.
* Bad, because upstream workflow improvements and spec revisions arrive
  only by manual re-survey; there is no machine-checkable update event
  (accepted — ADR-0017 already prices in spec churn).
* Bad, because OKF guidance spans two skills; mitigated by the one-home
  split (ADR frontmatter in `adr`; bundle conventions in documentation)
  with a cross-link, per `skill-authoring`.
* Bad, because agents without these skills get no OKF nudge beyond the
  bundle's root index note.

### Confirmation

The `adr` skill edit and the documentation skill's OKF section pass the
`skill-authoring` checks (Iteration-0 description/body consistency,
`scripts/audit.sh`, `apm audit`) and deploy via `skill-management`. On
future skill-maintenance passes, re-check scaccogatto/okf-skills for
policy-conditional reserved-file handling and serradura for a v0.2
upgrade; reopen this decision only if OKF authoring becomes recurring
work outside this repository or a fit upstream appears.

## More Information

Research snapshot (ADR-0006 tier 2):
[OKF skills via APM — feasibility and policy fit](../research/2026-07-28-okf-skill-apm-feasibility.md)
(live install/re-export verification, validator run, upstream quotes).

Related: [ADR-0002](0002-apm-package-layout-and-reexport.md) (re-export
mechanics this survey re-verified),
[ADR-0003](0003-curated-skill-set-external-survey.md) (depend / fork /
original criteria applied here),
[ADR-0016](0016-author-original-documentation-skill.md) (documentation
skill that receives the bundle conventions),
[ADR-0017](0017-adopt-okf-for-repository-documentation.md) (the policy
this decision protects).
