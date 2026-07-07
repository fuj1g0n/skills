---
name: skill-authoring
description: Guides authoring, editing, and auditing agent skills (SKILL.md). Use when creating or editing a skill, writing skill frontmatter or descriptions, splitting a skill into references, testing a skill, or auditing the whole skill collection.
---

# Skill Authoring

Quality rules for writing skills and keeping the collection healthy. This
skill owns *how to write* a skill; the `skill-management` skill owns *how to
deploy* one (APM manifest, pinning, install) — follow it for every release.

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
- `description`: ≤ 1024 chars hard limit; **aim for ~20–35 words
  (~100–250 chars)**, third person, no XML tags. State **what** the skill
  does and **when** to trigger.
- **Never summarize the skill's workflow in the description.** Tested
  finding (obra/superpowers): given a workflow summary, agents follow the
  description *instead of reading the body*. Describe triggering conditions
  only, and cover the keywords users actually emit: symptoms, error
  messages, tool names, synonyms.
- **Two-track policy** (mizchi/skills): *domain* skills get pushy
  auto-trigger descriptions — "Use when ... Trigger on [symptoms] even if
  the user does not name [domain]". *Meta* skills that operate on the agent
  or on skills themselves get explicit-only descriptions — "Invoke ONLY when
  the user explicitly asks ...; do NOT auto-invoke on [ambient signals]".

Good / bad:

```yaml
# Good — what + when, triggers only
description: Creates atomic Conventional Commits. Use when committing code changes, splitting hunks into revertable units, or writing detailed commit messages.
# Bad — vague
description: Helps with commits.
# Bad — workflow summary; agent may follow this instead of the body
description: Use when committing - stages hunks one by one, generates a message, then pushes.
```

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

For skills that must hold under pressure or whose value is uncertain, run
the subagent-based tests in
[references/testing-skills.md](references/testing-skills.md): RED/GREEN
pressure scenarios and a trimmed two-sided evaluation (blank-slate executor
+ requirements checklist + self-reported unclear points).

## Auditing the collection

Periodically, or after several skills changed, audit the whole collection:

```
Skill audit:
- [ ] 1. Run scripts/audit.sh for the mechanical pass
- [ ] 2. Audit flagged skills against references/audit-checks.md
- [ ] 3. Cross-skill duplication pass (link or merge)
- [ ] 4. Documentation & repo-file references pass
- [ ] 5. Report findings, then fix with confirmation and re-run audit.sh
```

The script (`scripts/audit.sh [SKILLS_DIR]`, default `.apm/skills/` of this
repository) prints one row per skill — line count, name/description lengths,
references/scripts presence — flagging hard violations with `!`. The
judgement checks live in
[references/audit-checks.md](references/audit-checks.md). Find duplication
candidates with:

```bash
rg -N '^description:' .apm/skills/*/SKILL.md
```

## Release checks

Before committing a skill change, run `apm audit` (hidden Unicode, tampered
generated files); then release via the `skill-management` workflow (commit →
push → re-pin → `apm install -g` → verify the deploy directory).

## Attribution

- Backbone workflow, frontmatter/body rules, and the audit script/checklist
  adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles)
  `skill-creator` + `skill-maintenance` (MIT).
- Description discipline (no workflow summaries; keyword coverage) and the
  pressure-test methodology adapted from
  [obra/superpowers](https://github.com/obra/superpowers) `writing-skills`
  (MIT).
- Two-track description policy, Iteration-0 check, and two-sided evaluation
  adapted from [mizchi/skills](https://github.com/mizchi/skills)
  `meta/optimizing-descriptions` + `meta/empirical-prompt-tuning` (MIT).
- Progressive-disclosure framing and "pushy description" doctrine from
  [anthropics/skills](https://github.com/anthropics/skills) `skill-creator`
  (Apache 2.0).
