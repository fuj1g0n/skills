---
type: Research Snapshot
generated:
  by: github-copilot-cli/claude-fable-5
  at: "2026-07-28T11:33:33Z"
---

# Survey: documentation formats — Open Knowledge Format and the methodology landscape

Point-in-time snapshot, 2026-07-28. Supports
[ADR-0016](../adr/0016-author-original-documentation-skill.md) and
[ADR-0017](../adr/0017-adopt-okf-for-repository-documentation.md).
Conducted as two
research passes (Open Knowledge Format deep-dive; broad methodology survey),
with primary-source fetches of specs and official sites. A companion
snapshot covers the skill ecosystem:
[2026-07-28-documentation-skill-ecosystem.md](2026-07-28-documentation-skill-ecosystem.md).
This file is immutable; a re-survey is a new file (per ADR-0006).

## Part A — Open Knowledge Format (OKF)

### Disambiguation

"Open Knowledge Format" as of 2026-07 means one coherent thing: a
vendor-neutral AI/LLM knowledge-organization specification introduced by
Google Cloud in 2026, Apache-2.0, canonical repository
[GoogleCloudPlatform/knowledge-catalog](https://github.com/GoogleCloudPlatform/knowledge-catalog)
(7.9k stars, 653 forks, created 2026-05-04; spec at `okf/SPEC.md`).
Announcement: [Google Cloud blog](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing).
Not related: the Open Knowledge Foundation (okfn.org), whose data
specification is Frictionless Data / [Data Package v2](https://datapackage.org)
— tabular data packaging, not knowledge organization. The GitHub org
`openknowledgeformat` exists but is empty; `okf.dev` and
`openknowledgeformat.org` were unreachable (likely unregistered).

OKF formalizes Karpathy's "LLM wiki" pattern
([gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)):
an LLM incrementally maintains a structured, interlinked collection of
Markdown files, with `index.md` and `log.md` as special files — the exact
reserved names OKF adopted.

### Spec essentials (v0.2, 2026-07-24)

Current version v0.2, merged 2026-07-24
(commit `780fe9d`); v0.1 was the launch draft (2026-05). Self-description:
"a directory of markdown files with YAML frontmatter. There is no schema
registry, no central authority, and no required tooling."

- **Bundle** = directory tree of concept `.md` files, distributed as a git
  repo, tarball, or subdirectory. Concept ID = path minus `.md`.
- **Frontmatter**: `type` is the only REQUIRED key (free-form string, no
  registry). Recommended: `title`, `description`, `resource` (URI of the
  underlying asset), `tags`.
- **Trust/provenance (v0.2)**: `generated: {by, at}`,
  `verified: [{by, at}]`, `sources: [{id, resource, author, usage_count,
  last_modified}]`. Actor convention `<producer>/<version>` |
  `human:<id>` | `process:<id>`; trust tiers unverified →
  machine-confirmed → human-reviewed derived from `verified`.
- **Lifecycle (v0.2)**: `status: draft|stable|deprecated`,
  `stale_after: YYYY-MM-DD`.
- **Reserved files**: `index.md` (per-directory listing; progressive
  disclosure) and `log.md` (ISO-dated update history).
- **Links**: bundle-relative preferred; broken links MUST be tolerated;
  links are edges of a knowledge graph.
- **Attested Computation (v0.2)**: concept type carrying a sanctioned
  computation (`runtime`, `parameters`, `executor`, `receipt`, `attester`)
  so a consumer can verify "the agent ran the approved query" vs.
  improvised.
- **Conformance**: every non-reserved `.md` has parseable frontmatter with
  non-empty `type`; consumers MUST NOT reject unknown types/keys, broken
  links, or missing `index.md`. Version declared as `okf_version` in the
  root `index.md`.
- **v0.1 → v0.2 breaking changes**: `timestamp` → `generated.at`;
  `# Citations` body list → `sources` frontmatter.

### Ecosystem and adoption

97 repos carry the `open-knowledge-format` GitHub topic (2026-07-28). Key:

| Repo | License | Stars | Notes |
|---|---|---|---|
| [GoogleCloudPlatform/knowledge-catalog](https://github.com/GoogleCloudPlatform/knowledge-catalog) | Apache-2.0 | 7,900 | Spec + reference agent (BigQuery metadata → bundle, Gemini/ADK) + Cytoscape visualizer |
| [serradura/okf-gem](https://github.com/serradura/okf-gem) | Apache-2.0 | 111 | Ruby CLI/library (`okf validate/lint/search/server/render`), Claude Code plugin; vendors spec v0.1 |
| [scaccogatto/okf-skills](https://github.com/scaccogatto/okf-skills) | MIT | 104 | Claude Code skills + GitHub Action CI gate; vendors spec v0.2; distributed for 20+ agents via skills.sh |
| [0dust/OKFy](https://github.com/0dust/OKFy) | — | — | Docs → OKF bundle converter (details not retrieved) |

scaccogatto/okf-skills ships a benchmark (12 agents, 6 questions): 85%
ground-truth claims with an OKF bundle vs. 77% without, at +5% token cost —
a quality gain, not a token saving; their summary: "write down what the
code cannot say".

Positioning vs. agent-instruction files, quoted from okf-skills: "Use
`CLAUDE.md` for how to behave, auto-memory for what the agent picked up,
and an OKF bundle for what the team knows — shared, structured, and
shippable." OKF is complementary to SKILL.md/AGENTS.md, not a replacement.

### OKF maturity flags

- Spec is ~3 months old with a breaking change within 2 months
  (v0.1 → v0.2); `major.minor` versioning, still pre-1.0.
- Google-originated, no standards body, no stated governance transition.
- Tooling split across spec versions (okf-gem pins v0.1, okf-skills v0.2).
- Exact blog publication date and v0.1 commit date not confirmed.

## Part B — Methodology landscape

Three clusters: (A) conceptual frameworks for organizing content,
(B) structural templates for specific document types, (C) toolchain and
AI-agent conventions.

### Cluster A — conceptual frameworks

| Framework | Maintainer / status | License | Essence | AI relevance |
|---|---|---|---|---|
| [Diátaxis](https://diataxis.fr/) | Daniele Procida; active, unversioned | free, no formal license | Four mutually exclusive doc types on two axes (study/work × action/cognition): tutorial, how-to, reference, explanation; "compass" decision table; explicitly incremental (one improvement at a time) | Very high — categories are unambiguous rules an agent can follow; adopters incl. Django, Ubuntu, Cloudflare, Gatsby |
| [EPPO](https://everypageispageone.com/the-book/) (Every Page Is Page One, Mark Baker, 2013) | book + site; active as an idea, not a living spec | book | Seven topic characteristics: self-contained, limited purpose, conforms to a type, establishes context, assumes qualified reader, one level, links richly | Moderate — design principles, not a template; tutorials in Diátaxis deliberately violate EPPO |
| Information Mapping (Robert Horn) | Information Mapping, Inc.; commercial, declining in software docs | proprietary | Chunking/labeling/consistency; six information types (procedure, process, principle, concept, structure, fact) | Very low — proprietary, CCMS-oriented, incompatible with docs-as-code |

### Cluster B — structural templates

| Template | Version / status | License | Essence |
|---|---|---|---|
| [arc42](https://arc42.org/) | v9.0 (2025-07); active | CC BY-SA 4.0 | 12-section architecture doc template; section 9 = architecture decisions (ADRs live there); source in AsciiDoc; lean/thorough/essential modes; pairs with C4 in sections 5/7 |
| [C4 model](https://c4model.com/) | unversioned; active | free | Context/Container/Component/Code diagram abstraction levels; notation-independent; Structurizr DSL is the modeling tool and now ships an MCP server marketed for AI generation |
| [DITA](https://docs.oasis-open.org/dita/dita/v1.3/dita-v1.3-part0-overview.html) | 1.3 + Errata 02 (2018); 2.0 in development | OASIS standard; DITA-OT Apache-2.0 | XML topic types (task/concept/reference), maps, conref reuse, conditional profiles; dominant in regulated-industry techpubs, effectively absent from docs-as-code (XML friction, Java toolchain) |
| [The Good Docs Project](https://www.thegooddocsproject.dev/) | active, unversioned | unclear (LICENSE fetch failed — verify before reuse) | Fill-in Markdown templates typed concept/task/reference (API overview, quickstart, reference, how-to, tutorial, explanation); "recipes" combine templates |
| [standard-readme](https://github.com/RichardLitt/standard-readme) | active | MIT | README section order: Title, Description (required); ToC, Background, Install, Usage, API, Maintainers, Contributing, License (optional, fixed order); linter + generator exist |
| [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) | v1.1.0 | CC BY 4.0 (inferred — verify before adapting text) | `CHANGELOG.md`, newest first, ISO dates, `Unreleased` section, six change types (Added/Changed/Deprecated/Removed/Fixed/Security); anti-pattern: commit-log dumps |

GitHub community files (README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY,
ISSUE/PR templates, CODEOWNERS, CITATION.cff) recognized in root, `docs/`,
or `.github/`. Conventional Commits feeds changelog generators
(release-please, git-cliff).

### Cluster C — toolchain and AI-agent conventions

- **Docs-as-code** ([Write the Docs guide](https://www.writethedocs.org/guide/docs-as-code/)):
  the dominant practice — docs in git, plain-text markup, PR review, CI
  checks (Vale/textlint prose lint, lychee link check), SSGs (MkDocs
  Material, Sphinx+MyST, Docusaurus, Hugo).
- **Markup landscape**: CommonMark 0.31.2 / GFM 0.29-gfm is dominant by a
  large margin for new projects and for all agent-instruction files. MyST
  grows inside the Sphinx/Python niche; AsciiDoc is the arc42/book niche;
  reStructuredText is declining (rst-to-myst migration).
- **[llms.txt](https://llmstxt.org/)** (Jeremy Howard, 2024-09): `/llms.txt`
  Markdown index at site root + optional `.md` twins per page. Real but
  modest adoption (fast.ai ecosystem, self-selecting dev-tools sites);
  criticism: LLMs do not proactively fetch it — value only in explicit
  context-stuffing pipelines; no standards body.
- **[AGENTS.md](https://agents.md/)**: "README for AI coding agents",
  free-form Markdown. GitHub Copilot officially supports it (nearest
  ancestor wins) alongside `.github/copilot-instructions.md` and
  path-scoped `.github/instructions/*.instructions.md`; Claude Code
  imports it via `@AGENTS.md` from CLAUDE.md. The closest thing to a
  cross-tool repo-level agent-instruction standard.
- **CLAUDE.md** ([docs](https://code.claude.com/docs/en/memory)): four
  scopes (managed/user/project/local), `@` imports (4 hops),
  `.claude/rules/` path-scoped rules, auto-memory; guidance: keep under
  ~200 lines.
- **Cursor rules**: `.cursor/rules/*.mdc` with
  `description`/`globs`/`alwaysApply` frontmatter (legacy `.cursorrules`);
  parallel conventions: `.windsurf/rules/`, `.clinerules`, `.devin/rules/`.
- **Memory-bank pattern** (Cline community): `memory-bank/` directory
  (projectbrief, productContext, systemPatterns, techContext,
  activeContext, progress); not standardized, being absorbed into
  tool-native memory features. OKF (Part A) is the formalized,
  vendor-backed descendant of this space.

### Fit assessment for agent-authored documentation

| Approach | Actionable for an agent skill | Note |
|---|---|---|
| Diátaxis | High | Category rules + compass fit procedural skill text |
| Keep a Changelog | High | Small, exact, testable format |
| standard-readme | High | MIT; section order is mechanical |
| Good Docs templates | Medium | Useful shapes; license unverified |
| Docs-as-code hygiene | High | Repo conventions, linting, link checks |
| arc42 / C4 | Medium | Architecture-doc niche; ADR skill already covers section 9's content |
| OKF | Medium (watch) | Pre-1.0, moving; existing skills cover it (see companion snapshot) |
| llms.txt | Low-medium | Emerging; publish-side concern, on demand |
| DITA / Information Mapping / EPPO / RST | Low | Niche, proprietary, philosophy-only, or declining |

### Gaps and uncertainties

- Good Docs Project license unverified (fetch failures).
- DITA 2.0 approval date unverified (OASIS site errors).
- llms.txt adoption count comes from the project's own directory.
- Star counts and dates are as reported on 2026-07-28.
