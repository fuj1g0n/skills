# Testing Skills with Subagents

Two complementary tests, both run with fresh subagents (Task tool or
equivalent). Never substitute a self-reread: the author structurally cannot
read their own text with a blank slate.

Adapted from obra/superpowers `writing-skills` /
`testing-skills-with-subagents.md` (MIT) and mizchi/skills
`meta/empirical-prompt-tuning` (MIT), trimmed for a small personal
collection — no failure-pattern ledger, no automated grader CLI, no
convergence metrics. Revisit the full upstream apparatus if the collection
grows past ~20 skills.

## Contents

- 1. Pressure test (for rule/discipline skills)
- 2. Two-sided evaluation (for workflow/reference skills)
- 3. Iteration discipline

## 1. Pressure test (RED/GREEN/REFACTOR)

For skills that enforce a rule or discipline the agent might rationalize
away (e.g. "never rewrite history", "always pin SHAs"). This is TDD applied
to process documentation:

| TDD | Skill testing |
|---|---|
| Test case | Pressure scenario given to a subagent |
| RED | Subagent violates the rule *without* the skill loaded |
| GREEN | Subagent complies *with* the skill loaded |
| REFACTOR | Close the loopholes the subagent found |

Procedure:

1. Write a scenario that tempts violation. Strong scenarios combine **3+
   pressure types** — time ("release in 10 minutes"), sunk cost ("we already
   spent 2 days"), authority ("the lead said just do it"), economic,
   exhaustion, social, pragmatic — and force a concrete A/B/C choice, not an
   essay.
2. RED: run the scenario on a subagent *without* the skill. Confirm it
   violates the rule. If it doesn't, the skill may be unnecessary
   (capability the model already has).
3. GREEN: run the same scenario on a fresh subagent *with* the skill text
   included. Confirm compliance.
4. REFACTOR: when the subagent still violates, record the **exact excuse**
   it used (a rationalization table), then add an explicit negation or
   red-flag line to the skill for that excuse. Re-run.
5. Meta-test: ask the failing subagent "how could this skill have been
   written to prevent your choice?" — its answer is often the fix.

## 2. Two-sided evaluation (blank-slate executor)

For skills whose value is completing a workflow correctly. One iteration:

1. **Prepare** 2–3 scenarios (1 median + 1–2 edge) and, per scenario, a
   fixed requirements checklist of 3–7 items with **at least one tagged
   `[critical]`**. Freeze the checklist before running; success = all
   `[critical]` items pass.
2. **Execute**: dispatch a fresh subagent per scenario (parallel when
   possible) with: the skill body (or path to read), the scenario, the
   checklist, and instructions to report back:
   - the deliverable (or execution summary)
   - per-item pass/partial/fail with reason
   - **unclear points** — places the instruction was ambiguous
   - **discretionary fill-ins** — decisions the instruction did not fix
3. **Evaluate two-sidedly**: the executor's self-report (qualitative,
   primary) plus what you observe from the run (steps taken, retries,
   wrong turns — auxiliary). If one scenario takes several times more tool
   calls than the others, that part of the workflow has no recipe in the
   skill — add an inline minimum example rather than more references.
4. **Fix**: one theme per iteration, minimum diff that removes the unclear
   points. State explicitly which checklist item or ambiguity each fix
   addresses before applying it.
5. **Re-run** with a *new* subagent (the old one has learned the answers).

## 3. Iteration discipline

- Run Iteration 0 (description/body consistency, see SKILL.md) before any
  subagent dispatch — otherwise executors reinterpret the body to match the
  description and results are falsely positive.
- Stop when an iteration surfaces **zero new unclear points**; for
  high-importance skills, require two consecutive clean iterations.
- Skip evaluation entirely for one-off or trivial skills — the cost does
  not pay off.
