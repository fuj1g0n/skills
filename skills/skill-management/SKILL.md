---
name: skill-management
description: Operational rules for distributing agent skills as Copilot plugins and installing third-party skills via APM. Use when adding, updating, removing, or evaluating skills, user-wide or per-project, or when editing skills in the personal skills repository.
---

# Skill Management

The personal skills repo is an Agent Plugin installed through the user's
Copilot plugin marketplace. Third-party skills used unmodified come from APM,
or from a marketplace entry when upstream ships a plugin. Install targets such
as `~/.copilot/installed-plugins/` and `~/.agents/skills/` are managed output.

For exact `apm.yml` syntax and CLI details, defer to the `apm-usage` skill
(from `microsoft/apm/packages/apm-guide`).

## Layout

- **Personal skills repo**: github.com/fuj1g0n/skills
  (clone: `~/workspace/github.com/fuj1g0n/skills`, layout: root
  `plugin.json` plus `skills/<name>/SKILL.md`)
- **Marketplace**: `.github/plugin/marketplace.json` in
  github.com/fuj1g0n/.dotfiles (clone: `~/workspace/github.com/fuj1g0n/.dotfiles`),
  marketplace name `dotfiles`; Copilot reads it from GitHub, not the clone
- **User scope APM manifest**: `~/.apm/apm.yml`; deploys to `~/.agents/skills/`
- **Project scope APM manifest**: `apm.yml` in the repo; commit `apm.yml` and
  `apm.lock.yaml`, gitignore `apm_modules/`

## Editing personal skills

1. Edit under `~/workspace/github.com/fuj1g0n/skills/skills/<name>/`.
2. Commit and land the change on `main` (push, or merge the PR), then
   `git switch main && git pull --ff-only` so `HEAD` is the landed commit.
3. Pin that commit in the `skills` entry of the dotfiles marketplace, then
   land the dotfiles change on its `main`:

   ```json
   {
     "name": "skills",
     "source": {
       "source": "github",
       "repo": "fuj1g0n/skills",
       "sha": "<full-40-char-sha>"
     }
   }
   ```

4. Refresh the install:

   ```sh
   copilot plugin marketplace update dotfiles && copilot plugin update skills@dotfiles
   ```

   On a machine without the plugin, run
   `copilot plugin install skills@dotfiles` instead.

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
   as-is, add a full-SHA marketplace entry when upstream ships a plugin;
   otherwise install via APM (e.g., `microsoft/apm/packages/apm-guide`).
6. Install via APM with a full-SHA pin:

   ```sh
   SHA=$(gh api repos/<owner>/<repo>/commits/<branch> --jq .sha)
   apm install -g "<owner>/<repo>[/path]#$SHA"
   ```

The personal plugin carries no dependencies; declare each third-party skill
directly in the consumer's manifest (`~/.apm/apm.yml` or the marketplace).

## Scope decision

| Situation | Scope |
|-----------|-------|
| Personal workflow, applies everywhere | user (`skills@dotfiles` plugin, or `apm install -g` into `~/.apm/apm.yml`) |
| Project/team convention, tied to one repo | project (`apm.yml` in repo, commit lockfile) |
| Unclear | project scope inside the repository the skill serves, otherwise user scope; report the choice |

## Removing skills

- Personal plugin: `copilot plugin uninstall skills@dotfiles`, then remove
  its marketplace entry if it should stay gone.
- A skill inside the personal plugin: delete `skills/<name>/` and release
  as in Editing personal skills.
- APM dependency: `apm uninstall -g <owner>/<repo>`, then verify the
  directory is gone from `~/.agents/skills/`. If a skill was hand-modified
  after deployment, APM refuses to remove it; delete it manually.

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

- The dotfiles marketplace `skills` entry pins the landed commit's full SHA,
  and that change is on the dotfiles `main`.
- `copilot plugin list` shows `skills@dotfiles`, and
  `~/.copilot/installed-plugins/dotfiles/skills/skills/` holds the new
  content (or no longer holds a removed skill).
- APM changes: `apm install -g` lists them, and `~/.agents/skills/` matches.
