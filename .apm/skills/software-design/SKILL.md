---
name: software-design
description: >
  Develops software designs and maintains design documents and decision records.
  Use when explicitly designing a system or change, comparing architectural
  options, writing a design doc or ADR, or revising a recorded decision.
---

# Software Design

Resolve the design question and preserve the reasoning where it will be used.
The output can be an inline answer, an updated design artifact, a design
document, or an ADR; creating a file is not the objective by itself.
Routine implementation requests do not start a separate design workflow.

## 1. Find the existing owner and evidence

Read repository instructions, the affected code and interfaces, and any
existing proposal, decision, or implementation plan relevant to the request.
Use code to establish current behavior; use the user and recorded decisions
to establish intent. Distinguish facts, proposed options, and unknowns.

When another workflow already owns design or execution, consume its current
artifact rather than restarting analysis or introducing another checkpoint.
For Ponytail modes and pstack's architect, how, interrogate, and decision
trail, read [references/workflow-integration.md](references/workflow-integration.md).
Those plugins are optional; their absence does not block standalone work.

Classify the request:

- **Explore/design:** resolve an actual uncertainty or compare alternatives.
- **Document:** express an existing design without reopening its decisions.
- **Record/revise:** capture an established decision or its replacement.

## 2. Choose the smallest useful output

Follow the repository's document policy and an explicit requested format.
Otherwise choose by the reader's need:

| Need | Output |
|---|---|
| Local, obvious change; no durable rationale to preserve | Inline answer or the existing PR/task, no new file |
| Uncertain design, meaningful trade-offs, cross-component agreement | Existing design artifact, or a focused design document |
| One significant choice whose rationale future maintainers need | ADR or an equivalent entry in the existing decision collection |
| Execution order, progress, restart state, or task checkpoints | The active workflow's implementation plan or trail |

A refactor or bug fix can expose an architectural decision; its task label
does not determine whether it needs a record. Significance includes
structure, interfaces, dependencies, data lifecycle, operational risk, and
cross-cutting conventions. One design document may cover several decisions;
separate ADRs are useful when those decisions need independent lifecycles.

Do not generate both a design document and ADR by default. Keep the primary
rationale in one place; extract a durable decision only when it needs a
separate lifecycle, with links back to evidence rather than copied history.
An explicit request for a short document or draft is honored without
inventing a bigger decision to justify it.

## 3. Resolve only the design work that remains

For exploration, state the desired behavior, scope/non-goals, constraints,
and the question that code alone cannot answer. Compare plausible options
against those constraints; include the simpler option when it fully works.
Use a bounded prototype or measurement when it can resolve a material
unknown. Label estimates and untested risks instead of presenting them as
results. Add detail where a wrong choice would affect behavior or ownership,
not incidental helpers or a speculative future architecture.

For documentation or recording, use the existing rationale and evidence;
do not manufacture alternatives or rerun a completed design review.
In document-only work, preserve the source's precision and omissions.
Only behavior established by the supplied rationale or code is approved;
plausible inferences about parameters, processing order, or state writes
are proposals, not source facts. A bounded guarantee leaves behavior outside
its bound unspecified. Keep additions separate with their next check.
If a missing fact does not prevent a useful draft, mark it as unresolved
with its consequence and next check.

Ask the user to decide a material unresolved product or architectural
choice, presenting the current artifact, alternatives, trade-offs, and a
recommendation, before treating it as settled or implementing that choice.
An explicit choice or approval already given satisfies this gate. Drafting,
read-only investigation, and work independent of that choice can proceed.

## 4. Write or update the selected artifact

- For a design document, read
  [references/design-documents.md](references/design-documents.md).
- For an ADR, read
  [references/decision-records.md](references/decision-records.md), then the
  [minimal MADR template](references/madr-template-minimal.md) for a fresh
  MADR log; use the [full template](references/madr-template.md) only when
  the substance warrants its optional sections.
- When replacing an accepted record, read
  [references/supersede-workflow.md](references/supersede-workflow.md).
- For the evidence behind these defaults and its limits, read
  [references/evidence.md](references/evidence.md).

Use the existing location, language, headings, status semantics, and format.
For a fresh artifact, follow repository/contributor language instructions.
Default locations are `docs/design/<topic>.md` and `docs/adr/NNNN-<topic>.md`
when a persistent document is warranted. `documentation` owns surrounding
README/OKF conventions, not a second design analysis.

## 5. Return to the owning workflow

Report the selected output and why that level was sufficient, the decision
or remaining unknowns, changed paths, and the next validation or revisit
condition. If no file was warranted, say so without creating a skip log.
Return the artifact to the active workflow and continue work already
authorized by the request. A design-only request does not authorize code
changes; a completed decision does not require another approval ritual.

## Invariants

- Separate established facts, proposals, and unresolved matters, because
  invented drivers, approval, measurements, or downsides corrupt the record.
- Keep one authoritative home for each rationale and preserve accepted
  decision history, because duplicate plans and rewritten outcomes mislead
  future implementers.
- Preserve the active workflow's execution scope and checkpoints, because
  a document-writing skill does not authorize implementation or replace
  the user's existing approval.

## Done when

- The requested design question is answered, or an explicitly requested
  draft identifies the unresolved choices and their next checks.
- The smallest requested/useful artifact exists or the inline result
  explains why no new document was needed; existing owners and links agree.
- Created or updated documents distinguish current state from proposals,
  preserve decision history, and pass the repository's applicable checks.
- The result is returned to the owning workflow without an extra design
  cycle, approval gate, execution plan, or out-of-scope implementation.

## Attribution

See [NOTICE.md](NOTICE.md) for adapted sources and licenses.
