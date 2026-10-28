# Skill Audit Checks

The per-dimension checklist for the collection audit. The authoring rules
these checks enforce live in `SKILL.md` and `contract.md`; this file is
the *what to check*. `scripts/audit.sh` covers the countable parts
(lengths, references/ and scripts/ presence, the rules in
`contract-rules.tsv`); the rest are judgement calls.

Adapted from ryoppippi/dotfiles skill-maintenance/references/audit-checks.md
(MIT).

## Contents

- 1. Best-practices adherence
- 2. Name and description
- 3. Cross-skill duplication (link or merge)
- 4. Documentation and repo-file references
- 5. SKILL.md length and splitting
- 6. Description/body consistency (Iteration 0)
- 7. Contract adherence

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
- Neutral trigger language (rule C12 catches the common phrases).
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
rg -N '^description:' "$SOURCE_SKILLS_DIR"/*/SKILL.md
rg -l '<topic or command>' "$SOURCE_SKILLS_DIR"
```

Report each overlap as: the two skills, link or merge, and which one keeps
the canonical content.

## 4. Documentation and repo-file references

For every skill, check that it points at sources of truth instead of embedding
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

## 7. Contract adherence

What the rules in `contract-rules.tsv` cannot decide (see `contract.md`):

- Each Ask presents an artifact that exists at that step and sits before
  the first irreversible action; no two Asks guard the same decision.
- Each Ask guards an irreversible, architecture, product, or credential
  decision. Reversible or read-only work proceeds.
- Invariants hold only rules whose violation is unsafe, irreversible, or
  crosses an ownership boundary; other rules are workflow defaults.
- `## Done when` names observable state and is reachable without the user
  except at declared Asks.
- No two skills state conflicting facts (paths, owners, defaults). Conflicts
  make closely-following models pause.
- Warnings from `audit.sh` are resolved or justified.
