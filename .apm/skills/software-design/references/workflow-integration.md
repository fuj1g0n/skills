# Workflow Integration

These are adapters to optional installed plugins, not dependencies to
install. Read the active workflow's current instructions if its behavior
differs; this skill consumes its outputs without patching plugin files.

## Ownership

| Active surface | It owns | This skill adds only when needed |
|---|---|---|
| Ponytail lite/full/ultra | Session-wide simplicity and implementation constraints | A proportionate design artifact consistent with the active level |
| pstack architect | Architecture analysis, alternatives, synthesized type/module sketch and rationale, implementation reconciliation | Durable formatting or a requested independent decision record |
| pstack how | Explanation of existing architecture, layering and ownership | A requested current-state design document, not a redesign |
| pstack interrogate | Requested adversarial examination and evidence | Integration of its actual findings, not another automatic review |
| pstack sharpen | Refining the request | The resulting scope as input, not a competing requirements interview |
| pstack show-me-your-work | Execution/checkpoint decision trail for an active long-running or unattended workflow | A link to relevant trail evidence, not a second trail |

### When architect is active

Reuse its problem/caller usage, chosen shape and ownership, alternatives,
trade-offs, open questions, and next implementation step. Its synthesized
rationale and sketch are already the primary design artifact.
Reconcile implementation deviations there; retain unresolved disagreement
as unresolved rather than declaring the document accepted.

Preserve its existing checkpoint choice: default architect execution has
no added human checkpoint, while an explicit checkpoint request is honored.
Do not restart how, arena, or interrogate to populate a template or request
approval again for a settled choice. Missing analysis returns to the
active owner; do not silently substitute a competing design.

If a durable, independently revisitable decision warrants an ADR, extract
only that decision and link its evidence. Keep current design in the
primary artifact and decision history in the record; do not maintain two
copies of the same living plan.

### When Ponytail is active

Preserve the selected level; this skill does not raise/lower it. Lite
keeps the requested build and identifies a smaller alternative briefly;
ultra can challenge unjustified scope. A document request does not opt
into ultra or add a premise-attack ceremony.

Prefer the first sufficient design and existing layers/patterns. Record
deliberate non-goals instead of inventing extension points or "for later"
options. Simplicity does not remove requested behavior, affected callers,
tests, trust-boundary validation, data-loss prevention, security, or
accessibility. Carry an established shortcut's limit and upgrade trigger
into the artifact when it affects the design.

### When a decision trail is active

The trail belongs to its owner. Point at relevant evidence and outcomes;
do not rewrite append-only rows or treat an `open`/inconclusive result as
an accepted architectural choice. An ADR and a trail row serve different
readers and lifecycles.

Do not activate show-me-your-work or create `decisions.tsv` for an ordinary
ADR. Its working trail is local by default; persisting an ADR does not
authorize committing the trail or launching its transcript-audit workflow.

## Without those plugins

Use the main skill's lightweight design path. Do not install a plugin,
invent a missing pstack artifact, or require its review stages.
For a design-only request, return the design. For an implementation
request, return the result to the already-authorized implementation work.
