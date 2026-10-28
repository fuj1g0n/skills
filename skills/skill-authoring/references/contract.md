# Authoring Contract

How a skill moves control and states its limits. Current frontier models
follow skill text closely: an extra gate gets honored, an ambiguous verb
can block work, and a verification instruction adds checking the model
already does. The contract keeps that text small and unambiguous. Rule IDs
refer to [contract-rules.tsv](contract-rules.tsv), which `scripts/audit.sh`
enforces; this file explains them.

Sources: [Anthropic prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices),
[Prompting Claude Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5),
[OpenAI: Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model).

## Contents

- Transfer verbs
- Sections
- Descriptions
- Rule notes

## Transfer verbs

Four phrases move control out of a workflow. Each has one meaning.

| Verb | Write | Executor does |
|---|---|---|
| Ask | Ask the user to approve/decide X, presenting Y. | Ends the turn with Y ready to review and one decision. |
| Hand off | Hand off to `<skill>` when ... | Loads that skill and continues in the same turn. Not a pause. |
| Block | Block: condition. Report evidence and end without changes. | Ends without changes; only a separate explicit decision lifts it. |
| Done when | `## Done when` bullets | Keeps working until every bullet holds. |

Placement rules:

- Read-only and reversible steps proceed without asking.
- Put an Ask where its artifact exists: after the plan, diff, or candidate
  it presents, and before the first irreversible action. An Ask before the
  work is ready makes the user approve something they cannot review.
- An Ask is for irreversible, architecture-changing, product, or credential
  decisions. Keep at most two per skill (C10). A request that already
  authorizes the workflow is a precondition, not a second Ask.
- Replace `ask when unclear` with a stated default that the final report
  names (C11). If no default is defensible, the decision is a real Ask with
  an artifact.
- `stop` (C03, C04) and bare `confirm` (C05) are ambiguous between asking
  the user and handing off. Use a verb above, or "verify" for checking
  external state.

## Sections

- `## Done when` (required, C07): observable end state, for example a
  command result, a file property, or a deploy directory. It replaces
  generic self-checking steps (C06); the executor already checks its own work.
- `## Invariants` (when absolute rules exist, C08): one bullet per rule,
  each with its reason ("because ...", C09). Workflow steps refer to an
  invariant instead of restating it. Reserve invariants for rules whose
  violation is unsafe, irreversible, or breaks an ownership boundary; make
  everything else a workflow default.
- No uppercase emphasis (C01) or role prompt (C02). The reason carries the
  weight.
- Skills are deployed away from this repository, so cite no repository
  decision records (C15); state the rule itself.
- Keep required evaluation models and effort settings in the adopter's
  project policy, not in shared instructions. Citations are not runtime
  requirements. Use [testing-skills.md](testing-skills.md) for the method.

Good:

```markdown
## Invariants

- No floating versions such as `latest`, because an unpinned tool is a
  different tool on the next run.

## Done when

- `mise ls --current` shows the exact pinned version.
```

Bad:

```markdown
## Avoid

- NEVER use latest.

7. Self-review everything and double-check before finishing.
```

## Descriptions

One sentence of what the skill does and one of when to use it, about
20-35 words, third person, triggers only, no workflow summary. Cover the
words users actually say: symptoms, error messages, tool names, synonyms.
No pressure language (C12): models that follow instructions closely
overtrigger on it. A skill meant for explicit requests says so plainly:
"Use when the user explicitly asks to ...".

```yaml
# Good — what + when, triggers only
description: Creates atomic Conventional Commits. Use when committing code changes, splitting hunks into revertable units, or writing detailed commit messages.
# Bad — vague
description: Helps with commits.
# Bad — workflow summary; agent may follow this instead of the body
description: Use when committing - stages hunks one by one, generates a message, then pushes.
```

## Rule notes

- Fenced blocks, inline code, and frontmatter are exempt from pattern
  rules, so quoted examples do not trip them. The handoff check (C13) reads
  inline code to resolve the target skill name.
- Warnings never fail the audit; review each one. A fail-level finding
  exits 1.
- Vendored upstream text is excluded by path (C14).
- Adding a rule: add a row to `contract-rules.tsv`, a positive and a
  negative fixture to `scripts/test-audit.sh`, and a note here if the
  reason is not obvious from the message.
