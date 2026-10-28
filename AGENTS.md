# Repository instructions

## Scope

These instructions apply to contributors working in `fuj1g0n/skills`.
They are not user-level instructions for people who install its skills.

Keep distributed workflows under `skills/` usable in an adopter's own
repository. Do not require the author's checkout paths, dotfiles, task
runner, release branches, or evaluation models. Package identity and
attribution may name their actual owners.

Keep this collection's maintenance commands and release procedures in
repository instructions and the [README](README.md), not in distributed
skills or their bundled references. The
[instruction-scope design](docs/design/skill-instruction-scopes.md)
records workflow ownership and acceptance scenarios.

## Package and publication

The distribution is an Agent Plugins package with a root
[`plugin.json`](plugin.json) and `skills/<name>/SKILL.md`.
Edit source files, not installed or generated copies.
Do not add an APM manifest just to select a consumer's installer.

Writing a skill, publishing this package, and adopting it in a consumer are
separate tasks. A source change does not authorize publication, installation,
or a pin update in `fuj1g0n/.dotfiles`.
Follow the requested release scope and the repository's existing conventions.
Preserve licenses and attribution for adapted material.

## Validation

Use the tools and tasks declared in [`mise.toml`](mise.toml) and pinned in
`mise.lock`. Do not add a different toolchain or install prerequisites
implicitly.

- For skill or validator changes, run `mise run audit` from this repository's
  root. It runs authoring-contract fixtures, the collection audit,
  instruction-scope regressions, and the toolchain-routing corpus.
- For Markdown changes, use `mise run lint` or the configured linter with
  the changed paths. Its exclusions do not validate skill bodies.
- For changes to triggers, invariants, or completion conditions, follow
  the [behavior-evaluation guidance](skills/skill-authoring/references/testing-skills.md)
  and this repository's [evaluation profile](README.md#evaluation-profile).
  Keep that profile out of distributed skill instructions.
- Run `git diff --check` before committing. Report unavailable behavior
  evaluations separately from passing mechanical checks.

Documentation conventions are recorded in [docs/index.md](docs/index.md).
Keep research snapshots immutable and preserve existing identifiers.
