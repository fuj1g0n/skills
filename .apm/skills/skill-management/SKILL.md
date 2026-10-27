---
name: skill-management
description: Operational rules for managing agent skills via APM (Agent Package Manager). Use when adding, updating, removing, or evaluating skills — user-wide or per-project — or when editing skills in the personal skills repository.
---

# Skill Management via APM

All skill deployment goes through APM; deploy targets such as
`~/.agents/skills/` and `.claude/skills/` are APM-managed output.

For exact `apm.yml` syntax and CLI details, defer to the `apm-usage` skill
(from `microsoft/apm/packages/apm-guide`).

## Layout

- **Personal skills repo**: github.com/fuj1g0n/skills
  (clone: `~/workspace/github.com/fuj1g0n/skills`, layout: `.apm/skills/<name>/SKILL.md`)
- **User scope manifest**: `~/.apm/apm.yml`; deploys to `~/.agents/skills/`
- **Project scope manifest**: `apm.yml` in the repo; commit `apm.yml` and
  `apm.lock.yaml`, gitignore `apm_modules/`

## Editing personal skills

1. Edit under `~/workspace/github.com/fuj1g0n/skills/.apm/skills/<name>/`.
2. Commit and land the change on `main` (push, or merge the PR), then
   `git switch main && git pull --ff-only` so `HEAD` is the landed commit.
3. Update the pin in `~/.apm/apm.yml`:

   ```sh
   cd ~/workspace/github.com/fuj1g0n/skills && FULL=$(git rev-parse HEAD)
   sed -i "s|fuj1g0n/skills#[0-9a-f]*|fuj1g0n/skills#$FULL|" ~/.apm/apm.yml
   cd ~/.apm && apm install -g
   ```

4. If APM reports a skipped removal ("not owned by APM or modified"), remove
   the stale directory manually and re-run.

## Adopting third-party skills

Skills are cheap on disk but not free: every installed skill consumes context
in every conversation. Install deliberately.

1. **Check existing skills first** — personal repo README and already
   installed skills (`ls ~/.agents/skills/`). Do not install near-duplicates.
2. **Only install for recurring needs.** One-off tasks are solved inline.
3. **Read the SKILL.md before installing.** Descriptions can oversell;
   check that the instructions fit this environment (WSL2, bash, the
   project toolchains owned by `project-toolchain-selection`) and do not
   contradict installed skills.
4. **Check the license.** If the upstream repo has no license, do not copy
   its text into the personal repo — either install it as an APM dependency
   as-is, or write an original skill inspired by the concepts.
5. Prefer **forking into fuj1g0n/skills** (rewritten, adapted) over direct
   dependency when customization for this environment is needed; prefer
   **direct APM dependency** for well-maintained upstream skills used as-is
   (e.g., `microsoft/apm/packages/apm-guide`).
6. Install with a full-SHA pin:

   ```sh
   SHA=$(gh api repos/<owner>/<repo>/commits/<branch> --jq .sha)
   apm install -g "<owner>/<repo>[/path]#$SHA"
   ```

## Re-exporting third-party skills

The personal repo is an APM package (`apm.yml` at root, skills under
`.apm/skills/`). Third-party skills used as-is are declared as dependencies in
the repo's `apm.yml` and re-exported transitively — the machine's
`~/.apm/apm.yml` only depends on `fuj1g0n/skills`:

```yaml
# fuj1g0n/skills apm.yml
dependencies:
  apm:
    - microsoft/apm/packages/apm-guide#<full-sha>
```

Verify resolution with `apm deps tree` (run in `~/.apm`). Note: the
`.apm/skills/` layout is required — a bare `skills/<name>/SKILL.md` repo is
classified as `skill_bundle` and its `apm.yml` dependencies are ignored.

## Scope decision

| Situation | Scope |
|-----------|-------|
| Personal workflow, applies everywhere | user (`apm install -g`, `~/.apm/apm.yml`) |
| Project/team convention, tied to one repo | project (`apm.yml` in repo, commit lockfile) |
| Unclear | project scope inside the repository the skill serves, otherwise user scope; report the choice |

## Removing skills

```sh
apm uninstall -g <owner>/<repo>
```

Then verify the deploy directory is gone from `~/.agents/skills/`. If a skill
was hand-modified after deployment, APM refuses to remove it — delete
manually.

## Invariants

- Edit sources, never deploy targets, because APM overwrites or refuses to
  remove hand-modified output.
- Pin every dependency to a full 40-char commit SHA or a release tag,
  because floating branches drift and APM clones with `--branch=<ref>`,
  which resolves only branch/tag names and full SHAs.
- No unlicensed upstream text in the personal repo, because only MIT/Apache
  text may be adapted; depend on it via APM or write an original instead.

## Done when

- `~/.apm/apm.yml` pins the pushed commit's full SHA.
- `apm install -g` lists the changed skills, and `~/.agents/skills/` holds
  the new content (or no longer holds a removed skill).
