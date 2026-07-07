# Skill Audit Checks

The per-dimension checklist for the collection audit. The authoring rules
these checks enforce live in `SKILL.md` — read it for the *why* and the fix
patterns; this file is the *what to verify*. `scripts/audit.sh` covers the
countable parts (lengths, references/ and scripts/ presence); the rest are
judgement calls.

Adapted from ryoppippi/dotfiles skill-maintenance/references/audit-checks.md
(MIT).

## Contents

- 1. Best-practices adherence
- 2. Name and description
- 3. Cross-skill duplication (link or merge)
- 4. Documentation and repo-file references
- 5. SKILL.md length and splitting
- 6. Description/body consistency (Iteration 0)

## 1. Best-practices adherence

Check each skill against Anthropic's best practices
(<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>):

- Body is procedural and concise — no explaining things the model already knows.
- Consistent terminology throughout (one term per concept).
- No time-sensitive content; use an "old patterns" section instead.
- Examples are concrete, not abstract.
- One default per task, not a menu of options.
- Forward-slash paths only.
- Reference links are one level deep from SKILL.md (agents only preview
  nested files).

## 2. Name and description

- `name`: ≤ 64 chars, lowercase/numbers/hyphens, no `anthropic`/`claude`.
  (Hard-checked by the script.)
- `description`: ≤ 1024 chars hard limit, but **aim for ~20–35 words
  (~100–250 chars)**. The script flags > 350 — anything flagged should be
  trimmed unless every clause earns a trigger.
- Third person; states both **what** and **when**; **no workflow summary**
  (triggers only — see SKILL.md "Frontmatter").
- Correct track: domain skills pushy, meta skills explicit-only.
- The whole metadata set is preloaded into every session, so over-long
  descriptions tax all work, not just this skill.

## 3. Cross-skill duplication (link or merge)

The collection-wide check that single-skill authoring misses. For each pair
of skills that touch the same topic, pick the lightest fix (see SKILL.md
"Overlap between skills"):

- **Cross-link** when both skills stay distinct but overlap — replace the
  duplicated prose in one with a pointer to the other *by skill name*. One
  home for the detail, links from the rest.
- **Merge** only when two skills are genuinely the same workflow and neither
  earns its own trigger. Fold one in and delete the empty directory.

Find candidates:

```bash
rg -N '^description:' .apm/skills/*/SKILL.md   # overlapping triggers
rg -l '<topic or command>' .apm/skills          # same topic across skills
```

Report each overlap as: the two skills, link or merge, and which one keeps
the canonical content.

## 4. Documentation and repo-file references

For every skill, confirm it points at sources of truth instead of embedding
copies:

- **Public docs**: a library/tool skill should carry the canonical docs URL.
- **Locally shipped docs**: if the skill targets an installed package, it
  should tell the agent to read the docs the package ships rather than
  restating the API.
- **Repo files**: if concrete files are the source of truth, the skill
  should name them by path. Skim for files the skill *should* point at but
  doesn't.

Flag skills that paste doc/API content inline, hardcode values that drift
from a real file, or omit an obvious local reference.

## 5. SKILL.md length and splitting

- The script flags SKILL.md > 150 lines (soft) and > 500 lines (hard).
- For each soft-flagged skill, decide whether to split: platform-specific
  guidance, example galleries, failure playbooks, command catalogues, or
  large tables go to `references/*.md`, leaving a one-line pointer that
  names the trigger.
- Don't split content consulted on every run, or chunks < ~20 lines.
- Hard violations (> 500) must be split.

## 6. Description/body consistency (Iteration 0)

For each skill changed since the last audit: do the triggers claimed by the
description match the scope the body actually covers? A description that
promises more than the body delivers produces false-positive behavior — the
agent improvises the missing part. Reconcile description or body.
