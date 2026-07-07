---
name: adr
description: >
  Writes and maintains Architecture Decision Records (MADR format). Use when
  the user wants to record, revise, supersede, or amend an architecture,
  technology, or process decision — "write an ADR", "we decided X over Y",
  "start a decision log" — even without the acronym ADR; offer proactively
  when a conversation produces a significant decision.
---

# Architecture Decision Records (MADR)

This skill maintains a project's decision log: one Markdown file per
architecturally significant decision. The deliverable is files on disk — a
new `NNNN-slug.md`, plus minimal status edits to any ADR it supersedes.
The format is [MADR 4.0](https://adr.github.io/madr/); read
`references/madr-template.md` before writing your first ADR of the session.

## The bar is high

An ADR records a decision that is expensive to reverse or that future
developers will otherwise re-litigate: structure, key dependencies,
interfaces, data storage, security posture, cross-cutting conventions,
build/deploy strategy. Most decisions do not clear the bar.

| Write an ADR | Do not write an ADR |
|---|---|
| Adopting/replacing a framework, database, or protocol | Minor version upgrades |
| API or data-model design pattern | Bug fixes, refactors |
| Security or auth architecture | Implementation details |
| Team-wide convention (repo layout, release process) | One-off configuration changes |
| Rejecting a seriously considered option | Choices with no real alternative |

When in doubt, ask the user whether the decision should be recorded. A
rejected option is worth an ADR (`rejected`) when the rejection must stick.

## The contract

1. **Record, don't invent.** The ADR documents a real decision and the real
   reasons. Never fabricate options, drivers, metrics, or consequences the
   user or repository did not establish. Polishing the user's words into
   good prose is your job; supplying missing facts is not.
2. **One ADR, one decision.** Two decisions described means two ADRs.
3. **Accepted ADRs are immutable except their status.** A changed or reversed
   decision gets a *new* ADR that supersedes the old one; the only legitimate
   edits to an existing ADR are status changes and supersede links.
4. **Scaffolding stays canonical English.** Frontmatter keys, status values
   (`proposed`, `accepted`, `rejected`, `deprecated`, `superseded by
   ADR-NNNN`), and MADR section headings stay in English so tooling
   (Backstage, Structurizr `!adrs madr`) parses them. Prose follows the
   log's existing language; for a fresh log, the conversation language.
5. **Decision before implementation.** The ADR goes in the same PR as the
   code change or an earlier one — never document a decision only after
   quietly implementing it.

## File conventions

- **Filename**: `NNNN-title-with-dashes.md` — next sequential 4-digit number,
  slug from the title. The seed ADR of a fresh log is `0000`.
- **H1**: the short title only (no number prefix) — representative of both
  problem and solution, a noun phrase ("Use PostgreSQL for user data").
- **Frontmatter**: `status` and `date` (ISO 8601) always; `decision-makers`
  when known; `consulted` / `informed` only if the project uses them.
- **Sections**: `## Context and Problem Statement` and `## Decision Outcome`
  always; `## Considered Options` whenever more than one option was on the
  table (almost always); `## Decision Drivers`, `### Consequences`,
  `### Confirmation`, `## Pros and Cons of the Options`, `## More
  Information` as the substance warrants. Use the minimal template
  (`references/madr-template-minimal.md`) for small decisions and the full
  template for contested or high-impact ones.

## Workflow

### 1. Locate the decision log

In order: an existing ADR collection (`NNNN-*.md` under `docs/adr/`,
`docs/decisions/`, `doc/adr/`, `docs/architecture/decisions/`, `adr/`); a
`.adr-dir` file at the repo root naming the directory; otherwise this is a
fresh log — default to `docs/adr/`. Peek at one existing ADR before writing:
if the log follows a different template (e.g. Nygard, no frontmatter), match
the log's own format and tell the user — a log in two formats is worse than
either. Offer MADR migration only if the user asks.

### 2. Read the neighbors

Read the two or three most recent ADRs and any ADR the new one supersedes:
this gives the next number, exact titles for link text, and the house tone.

### 3. Get the substance — or ask

An honest ADR needs: **the problem** (why decide now), **the options**
seriously considered, **the outcome and its justification**, and **the
trade-offs**. If the conversation already gave all of these, write; if any
are missing, ask 2–4 targeted questions first — but don't ask what the
repository already answers. Treat a decision with zero downsides as a red
flag: ask for the accepted trade-off rather than writing a sales pitch.

### 4. Write the ADR

Follow `references/madr-template.md` (or the minimal variant). Beyond the
template:

- **Context**: neutral — pose the problem, don't advocate the answer.
- **Decision Outcome**: `Chosen option: "<option title>", because ...` with
  the justification tied to the drivers.
- **Consequences**: `* Good, because ...` / `* Bad, because ...` — at least
  one honest `Bad` in every non-trivial ADR.
- **Length**: half a page to two pages. Shorter records get read.

**Research material** is handled in three tiers: decision-relevant essence
embedded in the ADR body (the ADR alone must support re-litigation);
long-form raw research as a dated, immutable snapshot in the repository
(default `docs/research/YYYY-MM-DD-topic.md`) linked from `## More
Information`; ephemeral notes in PR descriptions, uncommitted. Never leave
essential justification only behind an external link — link rot voids it.

### 5. Initialize a fresh log

Mirror the MADR convention: create the directory, seed it with
`references/0000-use-markdown-architectural-decision-records.md` (adjust the
`Decision Outcome` bullets to the project's actual reasons if given); the
user's decision becomes `0001`. Tell the user about the seed file.

### 6. Supersede an old ADR

When the new decision replaces an old one, follow the exact link/status
surgery in [references/supersede-workflow.md](references/supersede-workflow.md) —
the old ADR gets status and `More Information` edits only.

### 7. Self-review and hand off

Check: filename number matches the sequence; frontmatter parses as YAML;
status is one of the canonical values; headings are the literal MADR English
headings; Context is neutral; at least one negative consequence; nothing in
the file that the user or repository didn't establish; superseded files show
diffs in status/More Information only. If the log keeps a README index,
update it. Report every file created or edited, by path.

## Reference files

| File | Read it when |
|---|---|
| `references/madr-template.md` | Before writing — the full MADR 4.0 template with embedded guidance. |
| `references/madr-template-minimal.md` | For small, uncontested decisions. |
| `references/0000-use-markdown-architectural-decision-records.md` | When initializing a fresh log. |
| `references/supersede-workflow.md` | When a new decision replaces an old ADR. |

## Attribution

See [NOTICE.md](NOTICE.md) for adapted sources and licenses.
