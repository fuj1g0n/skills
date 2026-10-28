# Design Documents

Use a design document to resolve ambiguity, compare meaningful alternatives,
or communicate a change across boundaries. If the answer is already obvious
and only implementation steps remain, use the existing task/plan instead.
Honor an explicit document request without padding it into a larger design.

## Minimum useful content

Follow a local template first. For a fresh document, use only the sections
the question needs:

- **Context and scope:** current behavior, the problem, constraints, and
  evidence. Link discoverable background instead of reproducing the repo.
- **Goals and non-goals:** observable desired behavior and deliberate
  exclusions, including compatibility requirements.
- **Proposed design:** ownership, boundaries, relevant data/control flow,
  interface semantics, and failure behavior.
- **Alternatives and trade-offs:** credible alternatives actually examined,
  the reason for the recommendation, costs, and unresolved risks.
- **Validation and rollout:** how to demonstrate the design works; migration,
  compatibility, rollback, security/privacy/observability when affected.
- **Open questions:** assumptions that still need a decision or experiment,
  who/what can resolve them, and when they matter.

Start with the problem and caller-visible behavior, then show enough shape
to assess the trade-offs. Sketch the API or data representation where its
semantics matter; link authoritative definitions rather than copying entire
schemas, class lists, or source code. Small examples or novel-algorithm
pseudocode can be useful evidence, not a second implementation.

Good: document the stated duplicate-request handling and key retention,
leave unapproved response/expiry policies open, and name the safety test.
Bad: enumerate every private method while leaving retry semantics unstated.

## Depth and lifecycle

A narrow change may need a paragraph or a short mini-doc. Split a large
design by independently understandable questions instead of filling a page
quota. Human design-review documents explain choices; executable plans
also need commands, observable outcomes, and restart state. Keep those
execution details in the existing plan rather than forcing them into an ADR.

Use `proposed` or the repository's equivalent until the choice is settled.
Capture design issues early while changing the approach is cheap; a
prototype can precede or be part of the document. For an existing system,
label reconstructed rationale and current-state documentation honestly;
do not invent a prior review.

As implementation changes the design, reconcile the live document and link
accepted deviations or replacement decisions. Preserve unresolved deviations
as unresolved. Keep historical ADRs separate from the current-state view:
an old decision can remain historically accurate while no longer describing
the running system.

An active pstack architect rationale/type sketch can already satisfy this
need. Improve it in place instead of adding a second parallel design doc.
