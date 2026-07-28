---
type: Architecture Decision Record
status: accepted
date: 2026-07-28
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Adopt the Open Knowledge Format for repository documentation

## Context and Problem Statement

This repository's documentation is knowledge produced for and by coding
agents: a MADR 4.0 decision log (`docs/adr/`, per
[ADR-0004](0004-adopt-madr-format.md)) and immutable research snapshots
(`docs/research/`, per [ADR-0006](0006-manage-adr-research-material.md)),
written with agents and read back by them when skills are authored. The
2026-07-28 survey
([snapshot](../research/2026-07-28-documentation-formats-landscape.md))
covered the Open Knowledge Format (OKF): a Google-released (2026-05),
Apache-2.0 specification, currently v0.2, that formalizes the "LLM wiki"
pattern — a directory of Markdown concepts with YAML frontmatter (`type`
as the only required key), per-directory `index.md` listings, a `log.md`
history, and tolerant conformance rules (consumers must not reject unknown
keys, unknown values, broken links, or missing indexes). Should this
documentation adopt OKF, and if so, how — without giving up MADR, the
research-snapshot rules, or GitHub rendering?

The initial ADR-0016 draft proposed deferring OKF because the spec is
pre-1.0 and broke compatibility (v0.1 → v0.2) within its first three
months. In review, the decision maker directed adoption for the
repository's own documentation and authorized a one-time exception to
document immutability, because the change concerns documentation
management itself.

## Decision Drivers

* The docs tree is agent-consumed knowledge — OKF's stated use case
  ("an OKF bundle for what the team knows — shared, structured, and
  shippable"); the surveyed benchmark measured higher ground-truth
  accuracy for agents given an OKF bundle (85% vs 77%).
* Existing commitments must survive intact: MADR 4.0 scaffolding with
  canonical status values (ADR-0004, `adr` skill contract), the
  three-tier research rule and snapshot immutability going forward
  (ADR-0006), and GitHub-native rendering of all links.
* Conformance cost must stay proportional: metadata-only edits, no
  content rewrites, no link breakage.
* Standardizing early is cheaper than migrating later: the tree is 23
  documents today.

## Considered Options

* Adopt OKF v0.2 now: make `docs/` a conformant bundle via a
  metadata-only migration
* Defer adoption and watch the spec (the initial draft's proposal)
* Full restructure to OKF idioms (file moves/renames, bundle-relative
  links)
* Adopt an OKF authoring skill without migrating this repository

## Decision Outcome

Chosen option: "Adopt OKF v0.2 now via a metadata-only migration",
overriding the draft's deferral: the decision maker accepts the pre-1.0
churn risk in exchange for standardizing while the tree is small — the
documentation is already OKF-shaped Markdown (frontmattered ADRs, dated
snapshots, an index-like README listing), and OKF's tolerance rules make
conformance purely additive, so MADR and GitHub rendering are unaffected.

Implementation (this change):

* `docs/` is the bundle root. `docs/index.md` declares
  `okf_version: "0.2"` (its only frontmatter, per spec) as the bundle's
  version marker — the root index is the only sanctioned place for that
  declaration. The reserved files are otherwise **not used**: both are
  optional and consumers must tolerate their absence; per-directory
  `index.md` listings duplicate the self-describing numbered and dated
  filenames, and `log.md` duplicates git commit history, which is the
  authoritative update log. Policy: reserved files beyond the root
  version marker are not created except in special cases; `index.md` and
  `log.md` remain reserved names and must not be used for ordinary
  concepts.
* Every ADR gains `type: Architecture Decision Record` as its first
  frontmatter key. All MADR keys and canonical status values are
  unchanged: the `status` key keeps MADR vocabulary
  (proposed/accepted/rejected/…) rather than OKF's
  draft/stable/deprecated. This is a documented deviation, legal because
  OKF consumers must tolerate unknown values; the mapping for OKF
  consumers is proposed → draft, accepted/rejected → stable (a rejection
  is a stable record), deprecated or superseded → deprecated.
* Every research snapshot gains `type: Research Snapshot`. The two
  2026-07-28 snapshots additionally record
  `generated: { by: github-copilot-cli/claude-fable-5, at: … }` because
  their provenance is precisely known at migration time; older snapshots
  keep provenance in their prose headers — no `generated`/`verified`
  entries are fabricated retroactively.
* Links stay document-relative — valid OKF and GitHub-renderable.
  Bundle-relative links (`/adr/…`) were rejected because GitHub resolves
  them from the repository root. No files move or rename: OKF imposes no
  naming scheme and the existing tree already matches its directory
  model, so "re-placement" is realized as the root version marker and
  frontmatter.
* The README's hand-maintained ADR and research listings are removed; the
  README only notes that `docs/` is an OKF bundle (the copy had already
  drifted; the bundle root index is the entry point).
* One-time immutability waiver: accepted ADRs (0001–0014, rejected 0008)
  and existing snapshots receive this metadata-only edit; bodies are
  untouched. ADR-0004 and ADR-0006 remain in force — new ADRs and
  snapshots are born OKF-conformant, and snapshot content immutability
  re-applies after this migration.

Rejection of the alternatives: deferral leaves the repository's own
knowledge non-conformant while the ecosystem it participates in ships OKF
tooling — and was explicitly overridden; full restructure breaks inbound
links and GitHub rendering for zero conformance gain; an OKF authoring
skill without migration gets the order backwards, and skill adoption
remains a separate skill-management decision (fit upstreams identified:
scaccogatto/okf-skills MIT vendoring spec v0.2, serradura/okf-gem
Apache-2.0 at v0.1).

### Consequences

* Good, because the documentation becomes a conformant, agent-consumable
  OKF bundle at metadata-only cost, with MADR, the ADR-0006 rules, and
  GitHub rendering preserved.
* Good, because dropping every hand-maintained listing (the drifted
  README copy; per-directory indexes) removes a recurring drift surface —
  numbered, dated filenames and git history carry the same information
  for free.
* Bad, because the spec is pre-1.0: future breaking revisions (like
  v0.1 → v0.2) will require repo-wide metadata migrations — accepted
  knowingly.
* Bad, because the `status`-key vocabulary deviation means plain OKF
  consumers cannot read lifecycle state without the mapping documented
  here.
* Bad, because without curated indexes and a `log.md`, plain OKF
  consumers get no in-bundle listing or update history and must walk the
  tree; the spec's tolerance rules make this legal, and git remains the
  authoritative log.
* Bad, because the one-time immutability exception complicates the
  otherwise simple "accepted ADRs are immutable except status" guarantee;
  this ADR is the audit trail for why ADR-0001…0015 and older snapshots
  show metadata diffs.

### Confirmation

Verified mechanically at migration time: every non-reserved `.md` under
`docs/` has parseable YAML frontmatter with a non-empty `type`; the only
reserved file present is the root `docs/index.md`, whose sole frontmatter
is `okf_version`; `markdownlint-cli2` passes for the newly linted file
(`docs/index.md`). Follow-ups: teach the `adr` skill OKF-awareness (add
`type` frontmatter on new ADRs) and consider
`okf lint` (serradura/okf-gem) as an optional CI gate once its vendored
spec catches up to v0.2.

## More Information

Research snapshots (ADR-0006 tier 2):
[documentation formats landscape — OKF deep-dive](../research/2026-07-28-documentation-formats-landscape.md)
(spec structure, ecosystem, maturity flags) and
[documentation-skill ecosystem](../research/2026-07-28-documentation-skill-ecosystem.md)
(OKF skill upstreams).

Related decisions: [ADR-0004](0004-adopt-madr-format.md) (MADR — remains
the ADR format; OKF adds a metadata layer),
[ADR-0006](0006-manage-adr-research-material.md) (three-tier rule —
unchanged; the one-time metadata waiver is recorded here),
[ADR-0016](0016-author-original-documentation-skill.md) (documentation
skill; its earlier draft's OKF deferral was split out and replaced by this
decision during review).
