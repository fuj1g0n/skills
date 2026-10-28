# Testing Skills with Subagents

Two complementary tests, both run with fresh subagents (Task tool or
equivalent). Never substitute a self-reread: the author structurally cannot
read their own text with a blank slate.

Adapted from obra/superpowers `writing-skills` /
`testing-skills-with-subagents.md` (MIT) and mizchi/skills
`meta/empirical-prompt-tuning` (MIT).

## Contents

- 0. When to run and on which models
- 1. Pressure test (for invariants)
- 2. Two-sided evaluation (for workflow/reference skills)
- 3. Iteration discipline

## 0. When to run and on which models

Run an evaluation when a change touches an Ask, an invariant, a
`## Done when` bullet, or a description. Other edits rely on source checks;
testing more than the change needs costs time without new signal.

Select models and runtimes from the adopter's task and applicable project
policy. Keep any repository-specific model profile outside the distributed
skill. Use the harness's configured model selection and supported effort.
Do not assume another adopter can access the author's models.

Every scenario uses a fresh subagent for each selected target. A change
passes for that target only when its required scenarios pass.
Report which models and runtimes actually ran. Repeated runs on one model
do not establish cross-model behavior. If a required target or fresh-agent
runner is unavailable, report that coverage as unverified.

Add these items to every scenario's frozen checklist:

- `[critical]` No question or approval request outside the skill's declared
  Asks.
- `[critical]` Reached every `## Done when` bullet without ending early on a
  progress report.
- No verification beyond what `## Done when` and the task need.
- No work outside the request.
- If the executor paused or asked, it quotes the SKILL.md line that caused
  it and says whether the line requires the pause or the executor inferred
  it.

## 1. Pressure test (RED/GREEN/REFACTOR)

For invariants the agent might rationalize away (e.g. "never rewrite
history", "always pin SHAs"). This is TDD applied to process documentation:

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
2. RED: run the scenario on a subagent *without* the skill. Check that it
   violates the rule. If it doesn't, the invariant may be unnecessary
   (capability the model already has); delete it.
3. GREEN: run the same scenario on a fresh subagent *with* the skill text
   included. Check compliance.
4. REFACTOR: when the subagent still violates, record the **exact excuse**
   it used, then repair the cause: sharpen the invariant's reason, move the
   Ask to where its artifact exists, or replace an ambiguous verb. Do not
   add a second wording of the rule or a list of negations; closely
   following models treat extra lines as extra instructions and pause on
   overlap. Re-run.
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
- The loop ends when an iteration surfaces **zero new unclear points**; for
  high-importance skills, require two consecutive clean iterations.
- Skip evaluation entirely for one-off or trivial skills — the cost does
  not pay off.
- For a description change, add one prompt that should load the skill and
  one near-miss that should not, on every target model.
