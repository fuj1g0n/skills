---
name: skill-management
description: Manages agent skill distribution and installation through APM. Use when adding, updating, removing, or evaluating skills, user-wide or per-project, or when editing skills in the personal skills repository.
---

# Skill Management

Use APM for personal and third-party skills, including Agent Plugins.
Use a manually managed Copilot marketplace only for a reproduced APM
compatibility problem. Keep the failure and workaround documented in the
consumer repository. Install targets such as `~/.apm/apm_modules/`,
`~/.copilot/installed-plugins/`, and `~/.agents/skills/` are managed output.

For exact `apm.yml` syntax and CLI details, defer to the `apm-usage` skill
(from `microsoft/apm/packages/apm-guide`).

## Layout

- **Personal skills repo**: github.com/fuj1g0n/skills
  (clone: `~/workspace/github.com/fuj1g0n/skills`, layout: root
  `plugin.json` plus `skills/<name>/SKILL.md`)
- **User scope APM manifest source**:
  `~/workspace/github.com/fuj1g0n/.dotfiles/apm/.apm/apm.yml`, symlinked to
  `~/.apm/apm.yml`. Agent Plugins register as native plugins such as
  `skills@apm`; other skills deploy to `~/.agents/skills/`.
- **Marketplace exceptions**: `.github/plugin/marketplace.json` in
  github.com/fuj1g0n/.dotfiles, marketplace name `dotfiles`.
- **Project scope APM manifest**: `apm.yml` in the repo; commit `apm.yml` and
  `apm.lock.yaml`, gitignore `apm_modules/`

## Editing personal skills

1. Edit under `~/workspace/github.com/fuj1g0n/skills/skills/<name>/`.
2. Commit and land the change on `main` (push, or merge the PR), then
   `git switch main && git pull --ff-only` so `HEAD` is the landed commit.
3. Pin that commit in the dotfiles APM manifest source, then
   land the dotfiles change on its `main`:

   ```yaml
   dependencies:
     apm:
       - fuj1g0n/skills#<full-40-char-sha>
   ```

4. Refresh the install:

   ```sh
   cd ~/workspace/github.com/fuj1g0n/.dotfiles && apm install -g
   ```

   If `skills@dotfiles` is still installed, uninstall it before switching
   to APM. APM owns `skills@apm`; do not update it with `copilot plugin`.

## Adopting third-party skills

Skills are cheap on disk but not free: every installed skill consumes context
in every conversation. Install deliberately.

1. **Check existing skills first**: personal repo README and already
   installed skills (`copilot plugin list`, `ls ~/.agents/skills/`). Do not
   install near-duplicates.
2. **Only install for recurring needs.** One-off tasks are solved inline.
3. **Read the SKILL.md before installing.** Descriptions can oversell;
   check that the instructions fit this environment (WSL2, bash, the
   project toolchains owned by `project-toolchain-selection`) and do not
   contradict installed skills.
4. **Check the license.** If the upstream repo has no license, do not copy
   its text into the personal repo; either install it as-is, or write an
   original skill inspired by the concepts.
5. Prefer **forking into fuj1g0n/skills** (rewritten, adapted) when
   customization for this environment is needed. For upstream skills used
   as-is, install via APM, including when upstream ships an Agent Plugin
   (e.g., `fuj1g0n/skills`).
6. Install via APM with a full-SHA pin:

   ```sh
   SHA=$(gh api repos/<owner>/<repo>/commits/<branch> --jq .sha)
   apm install -g "<owner>/<repo>[/path]#$SHA"
   ```

The personal plugin carries no dependencies; declare each third-party skill
directly in the consumer's APM manifest, including
`microsoft/apm/packages/apm-guide` for `apm-usage`.

## Scope decision

| Situation | Scope |
|-----------|-------|
| Personal workflow, applies everywhere | user (`apm install -g` from `~/.apm/apm.yml`) |
| Project/team convention, tied to one repo | project (`apm.yml` in repo, commit lockfile) |
| Unclear | project scope inside the repository the skill serves, otherwise user scope; report the choice |

## Removing skills

- Personal plugin: remove `fuj1g0n/skills` from the dotfiles APM manifest
  source and run `apm install -g`.
- A skill inside the personal plugin: delete `skills/<name>/` and release
  as in Editing personal skills.
- APM dependency: `apm uninstall -g <owner>/<repo>`, then verify the
  directory is gone from `~/.agents/skills/`. If a skill was hand-modified
  after deployment, APM refuses to remove it; inspect and back it up before
  removing it.

## Invariants

- Edit sources, never installed copies under `~/.copilot/installed-plugins/`
  or `~/.agents/skills/`, because updates overwrite them and APM refuses to
  remove hand-modified output.
- Pin every marketplace entry and APM dependency to a full 40-char commit
  SHA (APM also accepts a release tag), because floating branches drift and
  short SHAs do not resolve reliably.
- No unlicensed upstream text in the personal repo, because only MIT/Apache
  text may be adapted; install it as-is or write an original instead.

## Done when

- The dotfiles APM manifest pins the landed commit's full SHA,
  and that change is on the dotfiles `main`.
- `copilot plugin list` shows `skills@apm`, and
  `~/.apm/apm_modules/fuj1g0n/skills/skills/` holds the new
  content (or no longer holds a removed skill).
- APM changes: `apm install -g` lists them, and `~/.agents/skills/` matches.
