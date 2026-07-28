---
type: Research Snapshot
generated:
  by: github-copilot-cli/claude-fable-5
  at: "2026-07-28T11:31:51Z"
---

# Survey: documentation-writing skills in the agent-skill ecosystem

Point-in-time snapshot, 2026-07-28. Supports
[ADR-0016](../adr/0016-author-original-documentation-skill.md) and
[ADR-0017](../adr/0017-adopt-okf-for-repository-documentation.md).
License-focused survey
of existing documentation-writing skills (SKILL.md and agent definitions),
conducted as one research pass over the famous collections, the
majiayu000/claude-skill-registry index, and GitHub code search, with
primary-source reads of every SKILL.md cited. Companion snapshot:
[2026-07-28-documentation-formats-landscape.md](2026-07-28-documentation-formats-landscape.md)
(methodologies and OKF spec). This file is immutable; a re-survey is a new
file (per ADR-0006).

## 1. Collections surveyed

| Repo | Stars | License | Documentation-relevant content |
|---|---|---|---|
| anthropics/skills | 164,716 | Apache-2.0 (most; docx/pdf/pptx/xlsx are source-available, NOT OSS) | `doc-coauthoring`, `internal-comms` |
| obra/superpowers | 262,444 | MIT | none (only `writing-skills`, a SKILL.md-authoring meta-skill) |
| obra/superpowers-skills | 734 | MIT | archived 2025-10 |
| mizchi/skills | ~200 | MIT | none (frontend/AWS/SQL focus) |
| ryoppippi/dotfiles | 251 | MIT | none |
| wcygan/dotfiles | 193 | no license | none |
| github/awesome-copilot | 37,132 | MIT | `prd`, `acreadiness-generate-instructions` skills; SE Tech Writer / ADR Generator / Gem Documentation Writer agents |
| wshobson/agents | — | MIT | `changelog-automation`, `architecture-decision-records`, `hads`, `openapi-spec-generation` |
| cassiobotaro/skills | — | MIT | `adr`, `design-doc` |
| medusajs/medusa | 35,426 | MIT | `writing-docs`, `writing-releases`, `writing-tutorials` (project-specific) |
| metabase/metabase | 44,733 | MIT | `docs-write`, `docs-review` (project-specific) |

skills.sh is not browsable without JavaScript (CLI-only responses);
majiayu000/claude-skill-registry (MIT, 162k+ indexed skills, updated
2026-07-13) was used as the registry index instead.

## 2. Key candidates

### General-purpose

- **anthropics/skills `doc-coauthoring`** — Apache-2.0 by repo README, but
  no per-skill LICENSE.txt (`internal-comms` has one; this does not) —
  treat as Apache-2.0 with noted ambiguity. 15.8 KB single SKILL.md.
  Three-stage co-authoring workflow (context gathering → section-by-section
  brainstorm/curate/draft → fresh-reader test) for PRDs, specs, RFCs,
  decision docs. High quality; does NOT cover README, CHANGELOG, docs/
  structure, Diátaxis, or docs-as-code tooling. Repo pushed 2026-07-24.
- **wshobson/agents `changelog-automation`** — MIT. ~50-line SKILL.md +
  `references/details.md`. Explicitly Keep a Changelog 1.1.0 + Conventional
  Commits; release-type classification; section ordering; tools
  (standard-changelog, release-it, changesets). Medium quality: actionable
  tables, but detail deferred and no bundled automation.
- **wshobson/agents `architecture-decision-records`** — MIT. MADR-format
  ADRs, frontmatter template, lifecycle, adr-tools commands. Template-first,
  less procedurally disciplined than cassiobotaro's. (This category is
  already settled locally: ADR-0005.)
- **wshobson/agents `hads`** — MIT. "Human-AI Document Standard": custom
  `[SPEC]`/`[NOTE]`/`[BUG]`/`[?]` block-tagging convention (v1.0.0,
  author's own standard, no external adoption found).
- **wshobson/agents `openapi-spec-generation`** — MIT. OpenAPI 3.1 only.
- **cassiobotaro/skills `adr`** — MIT. Nygard format, adr-tools/Structurizr
  compatible; best-in-class discipline (already adapted into the local
  `adr` skill per ADR-0005).
- **cassiobotaro/skills `design-doc`** — MIT. Interactive design-doc
  drafting; trade-off-centered; unusually rigorous anti-fabrication rules.
  Very high quality; separate category from repo documentation formats.
- **github/awesome-copilot `prd`** — MIT. PRD schema + discovery interview.
- **github/awesome-copilot `acreadiness-generate-instructions`** — MIT.
  Generates `.github/copilot-instructions.md` / `AGENTS.md` /
  `.github/instructions/*.instructions.md` / `CLAUDE.md`, flat or nested —
  but tightly coupled to the AgentRC CLI (`agentrc.config.json`).
- **github/awesome-copilot agents** (not portable skills): SE Tech Writer
  (template collection: blog/docs/tutorial/ADR), ADR Generator (coded
  bullets POS-001...), Gem Documentation Writer (covers README, but a
  hidden `user-invocable: false` subagent of an orchestration system).

### Project-specific (not reusable, noted for patterns)

- **medusajs/medusa** `writing-docs` (MDX conventions for 5 doc projects),
  `writing-releases` (release-type classification and section ordering —
  transferable concepts), `writing-tutorials` (build-first-then-document;
  distinguishes how-to tutorials vs integration guides, Diátaxis-adjacent).
  Older Diátaxis-like skills (`tutorial`, `how-to`, `recipe`) were
  reorganized away and no longer exist on `develop`.
- **metabase/metabase** `docs-write` — good prose principles ("state your
  point" headings, word-substitution table) wrapped in Metabase-specific
  paths/tooling.

### OKF skills (detail in companion snapshot)

- **scaccogatto/okf-skills** — MIT, 104 stars, vendors OKF spec v0.2,
  Claude Code plugin + GitHub Action CI gate, distributed via skills.sh.
- **serradura/okf-gem** — Apache-2.0, 111 stars, Ruby CLI + Claude Code
  plugin, vendors spec v0.1 (one spec version behind).

## 3. Gap analysis

| Need | Coverage found | Best candidate | Viable path per ADR-0003 |
|---|---|---|---|
| Diátaxis-structured docs/ guidance | **none** (only Diátaxis-adjacent fragments inside project-specific skills) | — | original |
| README conventions | **none** standalone (only inside a non-installable subagent) | — | original |
| CHANGELOG / Keep a Changelog | thin | wshobson `changelog-automation` (MIT) | fork-adapt or concepts into original |
| docs-as-code tooling (MkDocs/Docusaurus/Sphinx) | **none** | — | original (if ever needed) |
| AGENTS.md / instructions authoring | one, tool-coupled | awesome-copilot `acreadiness-generate-instructions` (MIT, AgentRC-bound) | concepts only |
| ADR writing | good | cassiobotaro `adr` (MIT) | settled: ADR-0005 |
| Design docs / PRD / doc co-authoring | good | cassiobotaro `design-doc` (MIT), anthropics `doc-coauthoring` (Apache-2.0) | future separate adoption decisions |
| OKF bundle authoring | good | scaccogatto/okf-skills (MIT) | re-export/fork when needed |

## 4. Conclusions

1. **No canonical documentation skill exists**; the space is fragmented and
   thin. The only subcategory with multiple mature options is ADR writing.
2. **Diátaxis as a framework, README standards, and docs-as-code tooling
   are absent** across every surveyed collection and the 162k-skill
   registry index — an original skill would fill a genuine gap.
3. Project-specific documentation skills (medusa, metabase, remotion,
   next.js) dominate the registry hits and are not designed for reuse.
4. All strong general-purpose candidates are MIT or Apache-2.0; the only
   license flags are anthropics' per-skill LICENSE ambiguity for
   `doc-coauthoring`, wcygan/dotfiles (no license), and anthropics'
   docx/pdf/pptx/xlsx being source-available-only.

## Gaps and uncertainties

- skills.sh could not be enumerated directly; coverage relies on the
  registry mirror and direct repo sweeps.
- Star counts and activity dates are as reported on 2026-07-28.
- wshobson/agents `references/details.md` files were not fully read; depth
  of the changelog skill's deferred material is estimated from its SKILL.md.
