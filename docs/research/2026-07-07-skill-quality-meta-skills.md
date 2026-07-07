# Survey: meta-skills and tooling for improving agent-skill quality

Point-in-time snapshot, 2026-07-07. Supports
[ADR-0007](../adr/0007-author-original-skill-authoring-skill.md). Conducted as
two research passes (famous collections; broad GitHub/web search), with
primary-source fetches of every SKILL.md cited. This file is immutable; a
re-survey is a new file (per ADR-0006).

## 1. Meta-skills in the famous collections

### anthropics/skills `skill-creator` (Apache 2.0)

`skills/skill-creator/SKILL.md` (~33 KB) plus bundled eval infra (`agents/`
analyzer/comparator/grader, `eval-viewer/`, `scripts/`).

- Full eval-driven authoring loop: capture intent → interview → write →
  create test prompts (`evals/evals.json`) → spawn parallel subagents (with
  skill vs baseline) → draft objective assertions → grade via grader subagent
  (`grading.json`) → eval-viewer HTML → iterate until qualitative + quantitative
  plateau → scale up → run description optimizer.
- Progressive disclosure: L1 metadata ~100 words / L2 body <500 lines /
  L3 bundled resources unbounded; `scripts/` executed not loaded.
- Description doctrine: what + when; make descriptions "a little bit pushy"
  to combat systematic undertriggering.
- Eval infra presupposes Claude Code subagents.

### obra/superpowers `writing-skills` (MIT)

`skills/writing-skills/SKILL.md` (~26 KB) + `testing-skills-with-subagents.md`
(12.6 KB) + `anthropic-best-practices.md` (46 KB) + persuasion-principles.

- **TDD for skills**: test case = pressure scenario; RED = agent violates
  rule without skill; GREEN = complies with skill; REFACTOR = close loopholes
  via a rationalization table (document the exact excuses agents used, add
  explicit negations and red-flag sections).
- **Empirically tested description rule**: if the description summarizes the
  workflow, agents may follow the description *instead of reading the skill
  body*. Descriptions must state triggering conditions only ("Use when ..."),
  third person, with symptom/synonym/tool-name keyword coverage.
- Token budgets: frequently-loaded skills <150–200 words, others <500 words.
- Pressure-scenario testing: combine 3+ pressure types (time, sunk cost,
  authority, economic, exhaustion, social, pragmatic) with forced A/B/C
  choices; meta-test by asking the agent how the skill could have prevented
  its choice.

### ryoppippi/dotfiles `skill-creator` + `skill-maintenance` (MIT)

`agents/skills/skill-creator/SKILL.md` (140 lines),
`agents/skills/skill-maintenance/SKILL.md` (64 lines) +
`scripts/audit.sh` (109 lines) + `references/audit-checks.md` (74 lines).

- creator: description ~20–35 words (~100–250 chars), third person,
  what + when; name ≤64 chars lowercase-hyphen, no `anthropic`/`claude`;
  ~150-line soft split threshold / ~500-line hard ceiling; split triggers
  (platform-specific guidance, example galleries, failure playbooks, command
  catalogues, >30-line tables); stop-splitting rules (<20 lines, or consulted
  every run); documentation-by-reference (canonical docs URL /
  `node_modules/<pkg>/README.md` / repo files by path — never stale pastes);
  overlap protocol (cross-link by skill name first, merge only when neither
  earns its own trigger); dynamic context injection.
- maintenance: the only *collection-wide* auditor found. Checklist workflow:
  mechanical pass (`audit.sh`: line counts, name/desc lengths, refs/scripts
  presence, `!` for hard violations) → per-skill judgement audit
  (`audit-checks.md`) → cross-skill duplication pass
  (`rg '^description:'`) → references pass → report and fix, re-run script.
  "It is the auditor; `skill-creator` is the rulebook."

### mizchi/skills `meta/` (MIT — README: skills without explicit license default to MIT)

8 meta-skills; the relevant ones:

- `optimizing-descriptions` (11.6 KB): **two-track description policy** —
  *project* skills get pushy auto-trigger descriptions ("Trigger on
  [symptoms] even if user does not name [domain]"); *meta* skills get
  explicit-only descriptions ("Invoke ONLY when the user explicitly asks ...
  Do NOT auto-invoke"). Batch audit workflow with 12 real before/after
  rewrites.
- `empirical-prompt-tuning` (19.9 KB, has SKILL-ja.md): bias-free executor
  loop. Key elements: **Iteration 0** static description/body consistency
  check (skipping it lets the executor "reinterpret" the body to match the
  description → false-positive accuracy); blank-slate subagent execution with
  a fixed requirements checklist (≥1 `[critical]` item); two-sided evaluation
  (executor self-report of unclear points / discretionary fill-ins +
  instruction-side metrics: success, accuracy %, `tool_uses`, `duration_ms`,
  retries); failure pattern ledger (`Issue / Cause / General Fix Rule`);
  `tool_uses` 3–5x outlier across scenarios = low self-containment signal;
  convergence = 2 consecutive iterations with zero new unclear points.
  Qualitative primary, quantitative auxiliary.
- `waxa-eval` (16.6 KB): operating manual for `@mizchi/waxa` npm CLI
  (extends `microsoft/waza`) — automated grader pairs (regex + LLM),
  four-stage iteration pattern.
- `retrospective-codify` (12.8 KB): post-task lesson extraction → classify
  as ast-grep rule / CLAUDE.md rule / skill / note, with mandatory dedup grep.

### github/awesome-copilot

No skill-authoring meta-skills found in `skills/` (two code searches, zero
hits). Domain skills only.

### Anthropic engineering blog (canonical guidance)

"Equipping agents for the real world with Agent Skills": progressive
disclosure 3-level model; start from evaluation (build skills for observed
shortcomings, not anticipated ones); monitor real usage of `name` +
`description`; iterate by asking the agent to self-reflect and fold lessons
back in. Follow-up blog (2026-03) "Improving skill-creator": eval mode
(parallel subagents + pass/fail grading with evidence), benchmark mode
(N runs, mean/stddev), blind comparator agents, description tuning against
8–12 should-trigger + 5–8 should-NOT-trigger queries; capability-uplift vs
encoded-preference eval distinction.

## 2. Broad-search findings (outside the famous collections)

| Resource | License | What it is |
|---|---|---|
| `skill-tools/skill-tools` | Apache 2.0 | The only dedicated SKILL.md static-analysis CLI found: 20 spec checks + 10 deterministic lint rules (no-secrets, no-hardcoded-paths, description-specificity, trigger keywords, 50–300-char description sweet spot, progressive-disclosure >500 lines, examples/error-handling presence) + 0–100 scoring across 5 dimensions; `npx skill-tools check`, GitHub Action, SARIF. ~7 stars (new but functionally mature). |
| `openai/skills` `skill-creator` + `quick_validate.py` | Apache 2.0 | Codex-official authoring skill. "Context window is a public good"; Degrees of Freedom (Exact → Pattern → Principle); strict frontmatter whitelist (`name`, `description`, `license`, `allowed-tools`, `metadata`); ~100-line Python validator (name format, desc ≤1024 chars, no angle brackets). |
| `getsentry/skills` `skill-writer` | MIT | Production-grade router skill with 35+ reference files (design principles, layouts, description-optimization, skill-evals, iteration-evidence). Dense; presupposes its own reference tree. |
| `DMoneyOH/skills-basin` `skill-creator` | GPL-3 | Merged "super skill" with full Python eval harness (`run_eval.py`, `run_loop.py`, benchmark aggregation, documented JSON schemas). GPL-3 → concepts only. |
| `blastum/AgentSkills` `skill-authoring` | no license | Token-economy-focused 3-level hierarchy. Concepts only. |
| microsoft/GitHub-Copilot-for-Azure `skill-authoring` + `sensei` | MIT (SAML-blocked) | agentskills.io-compliance authoring guidelines + token optimizer. Frontmatter confirmed via code search only. |
| `apm audit` (microsoft/apm) | — | Already in the toolchain: hidden-Unicode scan, hand-edit diff detection, `--ci` flag. APM docs recommend `USE FOR: / DO NOT USE FOR:` description format. |
| spboyer gist (SKILL.md compliance audit) | no license | Audit of 26 Microsoft skills: 0/26 high adherence; 46% lacked clear triggers. Three-tier rubric (triggers + anti-triggers + compatibility). Concepts only. |

## 3. Quality-dimension coverage matrix

| Source | Description/trigger | Structure | Token economy | Testing/evals | Collection maintenance |
|---|---|---|---|---|---|
| anthropics skill-creator | strong (pushy) | strong (3-level) | yes | strongest (full infra) | – |
| obra writing-skills | strongest (SDO rule) | yes | strong (word counts) | strong (TDD/pressure) | – |
| ryoppippi creator+maintenance | yes (20–35 words) | yes (150/500) | yes (doc-by-ref) | – | strongest (audit.sh) |
| mizchi optimizing-descriptions | strongest (two-track) | – | – | – | batch audit |
| mizchi empirical-prompt-tuning | yes (Iter 0) | – | yes (tool_uses) | strong (7 axes) | – |
| skill-tools CLI | lint rules | spec checks | line budget | – | CI gate |
| apm audit | – | – | – | – | security/CI |

## 4. Notable gaps

- No single upstream covers all five dimensions; the strongest testing infra
  (anthropics, DMoneyOH) is Claude-Code- or API-bound.
- Collection-wide maintenance exists only in ryoppippi (skill form) and
  static CLIs (tool form).
- No Codex/Copilot-native automated eval harness found.
