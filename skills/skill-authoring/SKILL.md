---
name: skill-authoring
description: Guides authoring, editing, and auditing agent skills (SKILL.md). Use when creating or editing a skill, writing skill frontmatter or descriptions, splitting a skill into references, testing a skill, or auditing the whole skill collection.
---

# Skill Authoring

Quality rules for writing skills and keeping the collection healthy. This
skill owns *how to write* a skill; the `skill-management` skill owns *how to
deploy* one (plugin marketplace, pinning, install) — follow it for every release.

## When a new skill is warranted

Add a skill only when recurring work needs a specialised workflow, local
references, command sequences, or policy that should load on demand.
Otherwise extend an existing skill. Every skill's metadata is preloaded into
every conversation — each addition taxes all sessions.

## Frontmatter

```yaml
---
name: skill-name
description: One or two sentences. What the skill does and when to use it.
---
```

- `name`: ≤ 64 chars, lowercase letters / numbers / hyphens only, no
  `anthropic` or `claude`.
- `description`: ≤ 1024 chars hard limit; aim for ~20–35 words. What the
  skill does and when to trigger, no workflow summary: given one, agents
  follow the description instead of reading the body (obra/superpowers).
  Full policy and examples: [references/contract.md](references/contract.md)
  ("Descriptions").

## Body

Keep the body procedural and specific: exact commands with flags, files to
read by path, local conventions, expected validation, one small good/bad
example per common mistake. Do not explain what the model already knows.

Length thresholds:

- **~150 lines — consider splitting.** Move conditional or long-form detail
  into `references/*.md`, linked one level deep from SKILL.md with a pointer
  naming the trigger condition ("When a patch fails, read
  references/git-apply.md").
- **~500 lines — hard ceiling** (Anthropic guidance). Split before this.
- Split out: platform-specific guidance, example galleries, failure
  playbooks, command catalogues, tables > ~30 lines. Keep inline: anything
  consulted on every run, and chunks < ~20 lines (the file read costs more
  than it saves).

Documentation by reference, never by paste: link the canonical docs URL,
point at files the package ships locally, or name repo files by path. Pasted
copies go stale and cost tokens.

Scripts: deterministic, repeated, or fragile operations go in `scripts/` —
executed, not loaded; only stdout costs tokens.

## Authoring contract

Write every gate, handoff, completion condition, and absolute rule with the
verbs and sections in [references/contract.md](references/contract.md):
Ask, Hand off, Block, `## Done when`, and `## Invariants`. Read it before
writing or substantially editing a skill. `scripts/audit.sh` enforces the
rules in `references/contract-rules.tsv`.

## Overlap between skills

When two skills touch the same ground, pick the lightest fix: **cross-link**
by skill name (one home for the detail) or **merge** only when neither earns
its own trigger. Never paste the same instructions into two skills.

## Iteration 0 — consistency check

After writing or substantially editing a skill, before any deployment: read
the triggers the `description` claims, read the scope the body actually
covers, and reconcile any gap. A mismatched pair produces false confidence —
an executor will "reinterpret" the body to match the description
(mizchi/skills, empirical-prompt-tuning).

## Testing a skill

When a change touches an Ask, an invariant, a `## Done when` bullet, or a
description, run the cross-model evaluation in
[references/testing-skills.md](references/testing-skills.md). Other edits
need only `mise run audit`.

## Auditing the collection

Periodically, or after several skills changed, audit the whole collection:

```
Skill audit:
- [ ] 1. Run `mise run audit` for the mechanical pass
- [ ] 2. Audit flagged skills against references/audit-checks.md
- [ ] 3. Cross-skill duplication pass (link or merge)
- [ ] 4. Documentation & repo-file references pass
- [ ] 5. Fix the findings, then re-run `mise run audit`
```

`mise run audit` runs `scripts/test-audit.sh` (fixtures for every contract
rule), `scripts/audit.sh [SKILLS_DIR]` (default `skills/` of this
repository: one row per skill with line count, name/description lengths,
references/scripts presence, then contract findings), and the
`project-toolchain-selection` routing validators. The audit exits 1 on any
hard (`!`) flag or fail-level finding; warnings need review but do not
fail. The judgement checks live in
[references/audit-checks.md](references/audit-checks.md). Find duplication
candidates with:

```bash
rg -N '^description:' skills/*/SKILL.md
```

## Release checks

Before committing a skill change, run `mise run audit`; then release via the
`skill-management` workflow.

## Done when

- `mise run audit` exits 0.
- Every description trigger maps to scope the body covers (Iteration 0).
- Cross-model evaluation passed when the change required it.

## Attribution

- Backbone workflow, frontmatter/body rules, and the audit script/checklist
  adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles)
  `skill-creator` + `skill-maintenance` (MIT).
- Description discipline (no workflow summaries; keyword coverage) and the
  pressure-test methodology adapted from
  [obra/superpowers](https://github.com/obra/superpowers) `writing-skills`
  (MIT).
- Iteration-0 check and two-sided evaluation adapted from
  [mizchi/skills](https://github.com/mizchi/skills)
  `meta/empirical-prompt-tuning` (MIT).
- Progressive-disclosure framing from
  [anthropics/skills](https://github.com/anthropics/skills) `skill-creator`
  (Apache 2.0).
- Authoring contract derived from the Anthropic and OpenAI prompting guides
  linked in `references/contract.md`.
