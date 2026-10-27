---
type: Research Snapshot
---

# Official prompting guidance for Claude Opus 5.5 and GPT-6.1 Sol, applied to skills

Point-in-time snapshot, 2026-10-28. Supports the `skill-authoring` rules
for gates, completion criteria, and cross-model evaluation. Primary sources
only, fetched on the snapshot date. This file is immutable; a re-survey is a
new file.

## Sources

- Anthropic, [Prompting Claude Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)
- Anthropic, [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
  (the Opus 5.5 guide states that Opus 5 patterns remain a reasonable
  starting point)
- Anthropic, [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- Anthropic, [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- OpenAI, [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model)
  (family-wide prompting guidance derived from GPT-6 Astra; OpenAI publishes
  no separate GPT-6.1 Sol prompting guide and tells readers to evaluate the
  family prompts on their chosen model)

## Claude Opus 5.5

- Faster and fewer tokens than Opus 5; default effort is `medium`, and
  `medium` matches or beats Opus 5 at `high` on coding and knowledge work.
  Thinking is always on.
- Unattended runs: the model reports progress and may end a turn with text
  only. Treat that as a report, not completion. State the completion
  condition up front and keep the task's parts in a checklist the model
  updates. Name the kinds of early stop that are unwanted and the stops that
  are wanted (nothing can move without the user).
- Inherited from Opus 5:
  - Verifies its own work without being told. Explicit verification
    instructions ("include a final verification step", "use a subagent to
    verify", "double-check", "re-verify") cause over-verification; remove
    them rather than rewrite them.
  - Can widen scope. Recommended scope instruction: deliver what was asked,
    at the scope intended; check in only when different readings would lead
    to materially different work.
  - Delegates to subagents readily; give explicit criteria for delegation and
    keep spawn counts low.
  - Written deliverables run long; calibrate length explicitly.
- General: explain the reason behind a constraint instead of a bare
  prohibition; when an instruction names a model, re-check it on another.

## GPT-6.1 Sol

- Near-Astra performance at lower cost; reasoning effort `low`, `medium`
  (default), `high`, `xhigh`, `max`; no `none`.
- Family behavior (observed on Astra, recommended across GPT-6):
  - Stronger instruction following and more sensitive to instructions in
    skills and files such as `AGENTS.md`. OpenAI "strongly recommend[s]
    auditing skills and other files accessible to your model".
  - Unclear or conflicting guidance in a skill file may cause the model to
    pause and block work early. Make the priority of user instructions over
    skills explicit. When a skill causes a pause, have the model name the
    SKILL.md, quote the instruction, and separate explicit requirements from
    its own interpretation.
  - More likely to ask clarifying questions. Ask for approval only after
    preparing a concrete, reviewable result; reversible and read-only work
    needs no permission. Avoid unsolicited warnings, approval flows, or
    checklists for hypothetical risk.
  - Thorough testing can exceed what small changes need; calibrate tests to
    the change and broaden only when failures or new changes justify it.
  - Tends toward heavy Markdown formatting; state the style when it matters.
  - Delegates less often than some workflows want; state when to delegate.

## Shared implications for this collection

Both families now follow skill text closely, so the cost of a stray
instruction has risen:

1. Every ask-the-user gate is likely to be honored, so gates must be
   reserved for irreversible, architecture-changing, or product decisions,
   and placed after a reviewable result is ready.
2. Generic verification and self-review steps add cost on both families;
   keep only checks of external state that define completion.
3. Ambiguous verbs ("stop", "confirm") that could mean either "ask the user"
   or "hand off to another skill" risk early blocking.
4. Conflicting or stale facts between skills are a direct cause of pauses.
5. Pushy trigger language was a fix for undertriggering on older models and
   now risks overtriggering.
6. Skills should stay model-agnostic; model-specific calibration belongs in
   the evaluation method, which should run on every model the collection
   targets.
