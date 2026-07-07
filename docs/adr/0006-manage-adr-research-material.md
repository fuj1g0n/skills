---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Manage ADR research material with a three-tier rule (embed, snapshot, or link)

## Context and Problem Statement

Drafting ADRs here involves substantial fieldwork: ADR-0003, 0004 and 0005
each rest on external landscape surveys with primary-source verification.
Where should that research material live — inside the ADR, in separate
committed documents, or outside the repository? The ecosystem was surveyed
(2026-07) for how ADR-adjacent processes handle this:

* **MADR** designates `Pros and Cons of the Options` and `## More
  Information` as the in-document home for evidence and provenance; the ADR
  is expected to be self-contained enough to re-litigate.
* **Rust RFCs and Kubernetes KEPs** likewise record `Alternatives` /
  `Prior Art` in the proposal document itself and only *link* discussion
  threads (RFC PR thread; KEP `discussion` metadata).
* **Microsoft code-with-engineering-playbook** externalizes full comparative
  research as a *trade study* document (`docs/trade-studies/`); the ADR
  states the outcome and links to it. Spike write-ups in `docs/spikes/` are
  a common variant; binary artifacts go in `docs/adr/assets/`.
* External links (wikis, drives) as the sole carrier of essential
  justification are widely warned against because link rot voids the ADR.

## Decision Drivers

* An accepted ADR is immutable, which fits research that is a point-in-time
  snapshot — but the ADR must stay half a page to two pages.
* Essential justification must survive inside the repository (link rot).
* Working notes should not accumulate as committed files (precedent: the
  defender-cli verification write-up was moved to a PR description and the
  local markdown deleted).

## Considered Options

* Embed everything in the ADR body
* Externalize all research to separate committed documents
* Three-tier rule: embed the essence, snapshot long research, link ephemera

## Decision Outcome

Chosen option: "Three-tier rule", because embedding everything breaks the
two-page ceiling as surveys grow, while externalizing everything makes ADRs
non-self-contained and re-litigable only via extra files; the tiered rule
matches what MADR, RFC/KEP, and the trade-study practice each do well.

1. **Decision-relevant essence** — options, drivers, and the evidence that
   decided the outcome — is embedded in the ADR body (survey tables in
   Context or `Pros and Cons of the Options`), as ADR-0003/0004/0005 already
   do. The ADR alone must support re-litigation.
2. **Long-form raw research** that exceeds the ADR length ceiling but has
   lasting reference value is committed as a dated point-in-time snapshot at
   `docs/research/YYYY-MM-DD-topic.md`, linked from the ADR's `## More
   Information`, and never updated afterwards (a re-survey is a new file).
3. **Ephemeral working notes** stay in PR descriptions or session artifacts
   and are not committed; the PR may be linked from `## More Information`
   for provenance.

Binary artifacts (measurements, diagrams), if ever needed, go in
`docs/adr/assets/` with ADR-number-prefixed filenames.

### Consequences

* Good, because every ADR remains self-contained and within the length
  ceiling regardless of how large the underlying survey was.
* Good, because essential justification never depends on external links,
  and `docs/research/` snapshots are immutable like the ADRs they support.
* Bad, because splitting a survey into "essence in ADR" vs "rest in
  snapshot" is a judgment call made at writing time; a wrong split cannot
  be fixed later without a new ADR or a new snapshot.
* Bad, because tier-3 material linked via PR descriptions lives on GitHub,
  not in repository history, and is invisible to offline clones.

## More Information

Ecosystem survey conducted 2026-07-07 (MADR template guidance, Rust RFC
template `Alternatives`/`Prior Art`, Kubernetes KEP template and
`discussion` metadata, Microsoft code-with-engineering-playbook trade
studies). ADR-0003/0004/0005 are retroactively the reference examples of
tier 1; no `docs/research/` snapshot exists yet.
