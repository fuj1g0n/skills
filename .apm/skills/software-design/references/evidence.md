# Evidence and Limits

The defaults use the following primary sources as concepts, not copied
templates or a requirement to research every design task:

- [Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions):
  one significant choice, context and consequences, concise records, and
  retained superseded history.
- [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/):
  first-hand personal account, not an organization-wide current policy.
  Focus on trade-offs, ambiguity, early feedback, and relevant interfaces
  rather than copied implementation detail; a document can be unnecessary.
- [Coding-agent best practices](https://code.claude.com/docs/en/best-practices):
  supply intent the code cannot reveal; keep always-loaded guidance lean
  and capture unresolved requirements in a task-specific specification.
- [Model-specific prompting guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5):
  calibrate behavior on actual tasks instead of treating a generation change
  as proof that previous settings or document thresholds still apply.
- [Coding-agent maintenance practice](https://developers.openai.com/blog/maintaining-software-with-the-gpt-6-family):
  start with a small evidenced change and compare a suspect context
  instruction with and without that instruction on the same task snapshot.
- [Execution-plan recipe](https://developers.openai.com/cookbook/articles/codex_exec_plans):
  archived, tool/task-specific example for complex work, not a requirement
  for every change. Observable outcomes and restartable plans differ from
  a human-facing design document or historical decision record.
- [Context Matters](https://arxiv.org/abs/2604.03826):
  compares prior-record selection for automated ADR generation. Its
  recent-record window is an input-history finding, not an ADR length
  rule; reference-text similarity is not design correctness.
- [Evaluating repository-level context files](https://arxiv.org/abs/2602.11988):
  unnecessary always-loaded instructions can hurt coding-task performance.
  This does not test whether ADRs or task-specific designs should exist.
- [Codified Context](https://arxiv.org/abs/2602.20478):
  observational single-project evidence about tiered context and stale
  specifications; not a controlled causal evaluation.

Do not turn those studies into universal page/token quotas or assume their
results transfer unchanged across models, repositories, and tasks.
Empirical claims in a project decision should cite the actual measurement
and its conditions, not this skill as evidence.

The integration adapter was checked against installed Ponytail 5.3.2 and
pstack 0.9.107 instructions. These versions are provenance, not runtime
requirements. Their workflow contracts can change; use the active contract
when it differs.
