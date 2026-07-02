---
name: skill-management
description: Operational rules for managing agent skills via APM (Agent Package Manager). Use when adding, updating, removing, or evaluating skills — user-wide or per-project — or when editing skills in the personal skills repository.
---

# Skill Management via APM

All skill deployment goes through APM. Never copy skill files manually into
`~/.agents/skills/`, `.claude/skills/`, or other deploy targets — those
directories are APM-managed output.

For exact `apm.yml` syntax and CLI details, defer to the `apm-usage` skill
(from `microsoft/apm/packages/apm-guide`).

## Layout

- **Personal skills repo**: github.com/fuj1g0n/skills
  (clone: `~/workspace/github/skills`, layout: `skills/<name>/SKILL.md`)
- **User scope manifest**: `~/.apm/apm.yml`; deploys to `~/.agents/skills/`
- **Project scope manifest**: `apm.yml` in the repo; commit `apm.yml` and
  `apm.lock.yaml`, gitignore `apm_modules/`

## Pinning rules

- Always pin dependencies to a **full 40-char commit SHA** (or a release
  tag). Floating branches drift.
- Short SHAs do not work: APM clones with `--branch=<ref>`, which only
  resolves branch/tag names and full SHAs.

## Editing personal skills

1. Edit under `~/workspace/github/skills/skills/<name>/SKILL.md`.
2. Commit and push (`main`).
3. Update the pin in `~/.apm/apm.yml`:

   ```sh
   cd ~/workspace/github/skills && FULL=$(git rev-parse HEAD)
   sed -i "s|fuj1g0n/skills#[0-9a-f]*|fuj1g0n/skills#$FULL|" ~/.apm/apm.yml
   cd ~/.apm && apm install -g
   ```

4. Verify: skills listed in the install output and present in
   `~/.agents/skills/`.
5. If APM reports a skipped removal ("not owned by APM or modified"), remove
   the stale directory manually and re-run.

## Adopting third-party skills

Skills are cheap on disk but not free: every installed skill consumes context
in every conversation. Install deliberately.

1. **Check existing skills first** — personal repo README and already
   installed skills (`ls ~/.agents/skills/`). Do not install near-duplicates.
2. **Only install for recurring needs.** One-off tasks are solved inline.
3. **Read the SKILL.md before installing.** Descriptions can oversell;
   verify the instructions actually fit this environment (Nix, WSL2, uv,
   just, bash).
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

## Scope decision

| Situation | Scope |
|-----------|-------|
| Personal workflow, applies everywhere | user (`apm install -g`, `~/.apm/apm.yml`) |
| Project/team convention, tied to one repo | project (`apm.yml` in repo, commit lockfile) |
| Unclear | ask the user |

## Removing skills

```sh
apm uninstall -g <owner>/<repo>
```

Then verify the deploy directory is gone from `~/.agents/skills/`. If a skill
was hand-modified after deployment, APM refuses to remove it — delete
manually.

## Common mistakes

| Mistake | Fix |
|---|---|
| Editing files in `~/.agents/skills/` directly | Edit the source repo, push, re-pin, `apm install -g` |
| Installing skills "just in case" | Install only for a recurring, near-term need |
| Short SHA in `apm.yml` | Use the full 40-char SHA |
| Copying unlicensed skill text into the personal repo | Depend on it via APM, or write an original adaptation |
| Forgetting to update the pin after pushing | The deployed skill silently stays stale; always re-pin and reinstall |
