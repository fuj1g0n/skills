---
name: adr
description: >
  Write and maintain Architecture Decision Records (ADRs) in MADR 4.0 format
  (YAML frontmatter + Context and Problem Statement / Considered Options /
  Decision Outcome), with sequential NNNN-slug.md filenames and a disciplined
  supersede workflow. Use this skill whenever the user wants to record,
  document, revise, supersede, or amend an architecture, technology, or
  process decision — "write an ADR", "document this decision", "we decided to
  use X over Y", "record why we chose Z", "supersede ADR N", "start a decision
  log" — even if they never say the acronym "ADR". Also use it proactively:
  when a conversation produces a decision that meets the bar below, offer to
  record it.
---

# Architecture Decision Records (MADR)

This skill writes and maintains a project's decision log: one Markdown file
per architecturally significant decision. The deliverable of every invocation
is files on disk — a new `NNNN-slug.md`, plus minimal status edits to any ADR
the new decision supersedes.

The format is [MADR 4.0](https://adr.github.io/madr/). Templates are in
`references/` — read `references/madr-template.md` before writing your first
ADR of the session.

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
rejected option is worth an ADR (status `rejected`) when the rejection itself
needs to stick.

## The contract

1. **Record, don't invent.** The ADR documents a real decision and the real
   reasons. Never fabricate options, drivers, metrics, or consequences that
   the user or the repository did not establish. Polishing the user's words
   into good prose is your job; supplying missing facts is not.
2. **One ADR, one decision.** If the user describes two decisions, write two
   ADRs.
3. **Accepted ADRs are immutable except their status.** A changed or reversed
   decision gets a *new* ADR that supersedes the old one. The only legitimate
   edits to an existing ADR are frontmatter status changes and
   supersede/supersede-by links.
4. **Scaffolding stays canonical English.** Frontmatter keys (`status`,
   `date`, `decision-makers`, ...), status values (`proposed`, `accepted`,
   `rejected`, `deprecated`, `superseded by ADR-NNNN`), and the MADR section
   headings stay in English so tooling (Backstage ADR plugin, Structurizr
   `!adrs madr`, MADR tooling) parses them. Prose follows the log's existing
   language; for a fresh log, the conversation language.
5. **Decision before implementation.** When a decision precedes a code
   change, the ADR goes in the same PR or an earlier one — never document a
   decision only after quietly implementing it.

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
fresh log — default to `docs/adr/`.

Peek at one existing ADR before writing. If the log follows a different
template (e.g. Nygard sections, no frontmatter), match the log's own format
and tell the user — a log in two formats is worse than either. Offer MADR
migration only if the user asks.

### 2. Read the neighbors

Read the two or three most recent ADRs and any ADR the new one supersedes.
This gives the next number, exact titles for link text, and the house tone.

### 3. Get the substance — or ask

An honest ADR needs: **the problem** (why a decision is needed now), **the
options** (what was seriously considered), **the outcome and its
justification**, and **the trade-offs** (what becomes harder or riskier). If
the user or the conversation already gave all of these, write. If any are
missing, ask 2–4 targeted questions first. Don't ask what the repository
already answers. Treat a decision with zero downsides as a red flag: ask for
the accepted trade-off rather than writing a sales pitch.

### 4. Write the ADR

Follow `references/madr-template.md` (or the minimal variant). Beyond the
template:

- **Context**: neutral — pose the problem, don't advocate the answer.
- **Decision Outcome**: `Chosen option: "<option title>", because ...` with
  the justification tied to the drivers.
- **Consequences**: `* Good, because ...` / `* Bad, because ...` — at least
  one honest `Bad` in every non-trivial ADR.
- **Length**: half a page to two pages. Shorter records get read.

**Research material.** Surveys and field research behind a decision are
handled in three tiers: the decision-relevant essence (options, drivers,
deciding evidence) is embedded in the ADR body so the ADR alone supports
re-litigation; raw research that would push the ADR past the length ceiling
but has lasting value becomes a dated, immutable snapshot in the repository
(follow the log's existing convention; default
`docs/research/YYYY-MM-DD-topic.md`), linked from `## More Information`;
ephemeral working notes stay in PR descriptions or issues, uncommitted.
Never let essential justification live only behind an external link — link
rot voids the ADR.

### 5. Initialize a fresh log

Mirror the MADR convention: create the directory and seed it with
`references/0000-use-markdown-architectural-decision-records.md` (adjust the
`Decision Outcome` bullets to the project's actual reasons if the user gave
any); the user's decision becomes `0001`. Tell the user about the seed file.

### 6. Supersede an old ADR

When the new decision replaces ADR N:

1. New ADR frontmatter: `status: accepted` and, under `## More Information`,
   a line `Supersedes [ADR-NNNN](NNNN-old-slug.md).`
2. Old ADR frontmatter: change `status` to `superseded by ADR-MMMM`; append
   `Superseded by [ADR-MMMM](MMMM-new-slug.md).` to its `## More Information`
   (create the section if absent). Touch nothing else — verify with a diff.
3. Scan the log (and README index if one exists) for references to the old
   ADR that would now mislead, and update them.

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

## Attribution

- MADR templates in `references/` are copied verbatim from
  [adr/madr](https://github.com/adr/madr) 4.0.0 (MIT OR CC0-1.0).
- Workflow and contract concepts adapted from
  [cassiobotaro/skills](https://github.com/cassiobotaro/skills) `adr` (MIT),
  [wshobson/agents](https://github.com/wshobson/agents)
  `architecture-decision-records` (MIT), and
  [github/awesome-copilot](https://github.com/github/awesome-copilot)
  `create-architectural-decision-record` (MIT); trigger-calibration ideas
  from tclem/dotfiles `adr-author` (concepts only, no text copied).
