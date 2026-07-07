---
status: accepted
date: 2026-07-06
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Use the .apm/skills package layout and re-export third-party skills as APM dependencies

## Context and Problem Statement

Beyond hosting self-authored skills, this repository should act as the single
point of dependency management: third-party skills used as-is (e.g. the
official `apm-usage` guide from `microsoft/apm/packages/apm-guide`) should be
declared here and propagate to machines transitively, so that `~/.apm/apm.yml`
only ever depends on `fuj1g0n/skills`. Which repository layout supports this?

## Considered Options

* Bare `skills/<name>/SKILL.md` layout (skill bundle)
* `.apm/skills/<name>/` layout with a root `apm.yml` (APM package)

## Decision Outcome

Chosen option: "`.apm/skills/<name>/` layout with a root `apm.yml`", because
empirical testing showed it is the only layout where dependency re-export
works:

* A bare `skills/<name>/SKILL.md` layout is classified by APM as a
  `skill_bundle`, and in that mode the repository's `apm.yml` dependencies
  are **ignored** (the first attempt left `apm-usage` orphaned).
* The `.apm/skills/<name>/` layout plus a root `apm.yml` makes the repository
  a proper APM package whose dependencies are resolved transitively
  (`apm deps tree` shows `fuj1g0n/skills → microsoft/apm/packages/apm-guide`).
* A single skill can still be installed alone as a *virtual subdirectory
  package* (`apm install -g "fuj1g0n/skills/.apm/skills/<name>#<full-sha>"`);
  in that mode no transitive dependencies come along. Verified on a real
  install.

Third-party skills used as-is are declared as full-SHA-pinned dependencies in
this repository's `apm.yml` (re-export). Both install modes (whole package
with re-exports, single skill without) are documented in the README.

### Consequences

* Good, because adopting a third-party skill is a one-line, SHA-pinned change
  to this repository's `apm.yml`; `apm install -g` propagates it.
* Good, because consumers can choose "everything + re-exports" or "one skill
  only".
* Bad, because the layout constraint is non-obvious; it is recorded here and
  in the `skill-management` skill to prevent regressions to the bundle
  layout.
