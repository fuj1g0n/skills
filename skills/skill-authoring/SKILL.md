---
name: skill-authoring
description: Guides authoring, editing, and auditing agent skills (SKILL.md). Use when creating or editing a skill, writing skill frontmatter or descriptions, splitting a skill into references, testing a skill, or auditing the whole skill collection.
---

# Skill Authoring

Write and validate skills in the adopter's source repository.
Read its applicable instructions and identify the intended users and task.
This workflow covers authoring, not automatic publication or installation.
For a separately requested package release, use `skill-management` when
available. Its absence does not prevent writing a skill.

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
description, run the behavior evaluation in
[references/testing-skills.md](references/testing-skills.md) using the
adopter's selected models and runtimes. Other edits need the applicable
source checks, not a publication or deployment test.

## Auditing the collection

Periodically, or after several skills changed, audit the whole collection:

```
Skill audit:
- [ ] 1. Run the applicable source validator for the mechanical pass
- [ ] 2. Audit flagged skills against references/audit-checks.md
- [ ] 3. Cross-skill duplication pass (link or merge)
- [ ] 4. Documentation & repo-file references pass
- [ ] 5. Fix the findings, then re-run that validator
```

Use the adopter's existing validator when it covers the change. Otherwise,
set `AUTHORING_DIR` to the directory containing this installed `SKILL.md`
and `SOURCE_SKILLS_DIR` to the source collection whose direct children are
skill directories. Run the bundled validator with that explicit target:

```bash
bash "$AUTHORING_DIR/scripts/audit.sh" "$SOURCE_SKILLS_DIR"
```

The validator exits 1 on hard length flags or fail-level contract findings.
It exits 2 for a missing target argument. Warnings require judgement but do
not fail. It does not prove behavior or discoverability in a client.
Read [references/audit-checks.md](references/audit-checks.md) for judgement
checks. Find duplication candidates in the same source collection:

```bash
rg -N '^description:' "$SOURCE_SKILLS_DIR"/*/SKILL.md
```

For a one-skill change, limit other repository checks to the affected work.
Do not audit the installed package in place of the adopter's source.

## Done when

- The requested source changes pass the applicable source checks.
- Every description trigger maps to scope the body covers (Iteration 0).
- When required, behavior evaluation passes for the selected targets.
  Report unavailable targets as unverified, not passed.
- Publication, consumer pins, and installation remain unchanged unless
  separately requested.

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
