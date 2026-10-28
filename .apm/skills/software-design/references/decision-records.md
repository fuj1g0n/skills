# Decision Records

An ADR preserves one significant decision and why it was made. It is not
an implementation checklist, whole-system description, or transcript.
Record a choice when its impact or easily lost rationale matters to future
work. Rejecting a serious option can qualify when the rejection itself
needs to persist. An ordinary local edit does not need an ADR by default.

## Find the collection and format

Read repository policy, `.adr-dir` if present, and existing collections such
as `docs/adr/`, `docs/decisions/`, `doc/adr/`, or `adr/`. Read two or three
relevant/recent records and any record being replaced, not the whole log.
Follow local naming, status values, headings, and language.

For a fresh log, default to MADR with Markdown filenames
`NNNN-title-with-dashes.md`, starting at `0001`. Select the next unused
number after the highest existing number; preserve gaps and old filenames.
Do not create a format-adoption/seed ADR unless the user requested that
decision or repository policy requires it.

Fresh MADR records use a short title, `status` and ISO date frontmatter,
`Context and Problem Statement`, `Considered Options` when alternatives
were considered, `Decision Outcome`, and consequences when known.
Include decision-makers only when established. Omit unused template
sections rather than filling them with generic prose.

In an OKF bundle, add `type: Architecture Decision Record` without replacing
MADR status metadata; `documentation` owns the bundle conventions.
An established Nygard log needs neither a MADR migration nor new frontmatter.

## Record facts and actual choices

- Describe the problem neutrally, including why a decision matters now.
- Record options actually considered and connect the outcome to the
  established constraints. A considered option need not get its own ADR.
- Include known positive, negative, and neutral consequences. A downside is
  not mandatory; if a material trade-off has not been evaluated, mark it as
  unknown and name the next check rather than fabricate a `Bad` bullet.
- Keep decision-critical rationale in the record and link detailed evidence
  at its authoritative location. A raw research snapshot is not an automatic
  extra deliverable.
- Use a concise record that can be read independently; roughly one or two
  pages is a useful original convention, not a model-specific limit.

Good: "We chose the existing queue because retry semantics already match
the billing boundary; throughput at peak load remains unmeasured."
Bad: invented latency figures or a fictional rejected database to make
the template look complete.

## Draft, accept, reconstruct, replace

Default new unresolved choices to `proposed`. The user saying "we decided
X; record why" is decision evidence, not a reason to run approval again.
Use `accepted` when the user or recorded project process establishes
acceptance; do not infer acceptance from code existing or from a draft
being committed.

A request for a draft is complete with clearly marked gaps and next checks.
Use the skill's single decision gate only if the task needs the unresolved
choice settled. Missing optional metadata is not a gate.

Write alongside or before implementation when possible. A retrospective
record is valid: label the reconstruction, cite implementation/history,
and distinguish what is known from what was not recorded. Do not backdate
acceptance or imply that a review happened.

Revise a proposal in place. For established accepted history, use a new
record for a materially changed or reversed decision and update status
and replacement links in the old record. In-place editorial corrections
follow the project's history policy; default to preserving accepted
substance. Deprecation without a replacement can use the local deprecated
status and a factual reason.

Update an existing index if the collection maintains one. Do not create an
index or OKF log merely to satisfy the record format.
