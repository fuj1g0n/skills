# skills

Home for everything involved in developing agent skills that reproduce
@fuj1g0n's development environment and process: the research
([docs/research/](docs/research/)) and the resulting skills
(`.apm/skills/`), which are the deliverables.
Skills are deployed user-wide via
[Microsoft APM](https://github.com/microsoft/apm) to `~/.agents/skills/`.

Not every investigation yields a skill; research snapshots are kept as
records either way.

## Skills

| Skill | Purpose | Adapted from |
|-------|---------|--------------|
| [skill-management](.apm/skills/skill-management/SKILL.md) | Operational rules: all skill deployment via APM, full-SHA pinning, adoption criteria | original (concepts from mizchi/skills skill-selector) |
| [skill-authoring](.apm/skills/skill-authoring/SKILL.md) | Quality rules for writing skills: authoring contract (Ask, Hand off, Block, Done when, Invariants) enforced by `just audit`, description discipline, cross-model subagent testing | original (adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles), [obra/superpowers](https://github.com/obra/superpowers), [mizchi/skills](https://github.com/mizchi/skills), all MIT; concepts from [anthropics/skills](https://github.com/anthropics/skills), Apache 2.0) |
| [adr](.apm/skills/adr/SKILL.md) | Write and maintain Architecture Decision Records in MADR 4.0 format (trigger calibration, supersede workflow, vendored MADR templates) | original (adapted from [cassiobotaro/skills](https://github.com/cassiobotaro/skills), [wshobson/agents](https://github.com/wshobson/agents), [github/awesome-copilot](https://github.com/github/awesome-copilot), all MIT; MADR templates from [adr/madr](https://github.com/adr/madr)) |
| [documentation](.apm/skills/documentation/SKILL.md) | Project documentation formats: Diátaxis docs/ organization, standard-readme, Keep a Changelog, docs-as-code hygiene, OKF bundle conventions | original (adapted from [RichardLitt/standard-readme](https://github.com/RichardLitt/standard-readme) and [wshobson/agents](https://github.com/wshobson/agents), both MIT; concepts from [diataxis.fr](https://diataxis.fr/) and [keepachangelog.com](https://keepachangelog.com/)) |
| [project-toolchain-selection](.apm/skills/project-toolchain-selection/SKILL.md) | Select one authoritative Nix or mise project development toolchain using continuity, package constraints, and participant platforms | original |
| [missing-tools](.apm/skills/missing-tools/SKILL.md) | Recover one-shot missing commands without persistent mutation; route recurring and explicit global needs to their current owner | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [nix-project-toolchain](.apm/skills/nix-project-toolchain/SKILL.md) | Manage project developer tools, environment, activation, and visibility through Nix devShells | [srid/emanote](https://github.com/srid/emanote) |
| [nix-wslc-devshell](.apm/skills/nix-wslc-devshell/SKILL.md) | Run an existing Nix project's devShell through its selected Windows-hosted wslc bridge | original |
| [mise-project-toolchain](.apm/skills/mise-project-toolchain/SKILL.md) | Manage cross-platform project developer tools and environment through mise, preferring verified release backends such as `aqua:` | original |
| [nix-user-tools](.apm/skills/nix-user-tools/SKILL.md) | Manage explicit user-wide Linux/WSL tools with `nix profile`, preferring officially recommended self-upgrading binaries in `~/.local/bin` | [wcygan/dotfiles](https://github.com/wcygan/dotfiles) |
| [windows-user-tools](.apm/skills/windows-user-tools/SKILL.md) | Manage explicit user-wide native Windows tools with self-upgrading official installers or WinGet user-scope packages | original |
| [nix-to-mise-project-toolchain](.apm/skills/nix-to-mise-project-toolchain/SKILL.md) | Perform explicit full-cutover Nix-to-mise migrations; block while Nix package outputs remain | original |
| [nix-package-outputs](.apm/skills/nix-package-outputs/SKILL.md) | Define and validate Nix packages, apps, checks, derivations, OCI images, and release outputs without owning devShells or tasks | original |
| [nix-github-rate-limit](.apm/skills/nix-github-rate-limit/SKILL.md) | Safe token injection via `gh auth token` for GitHub-backed Nix fetches | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [nix-direnv-gc-roots](.apm/skills/nix-direnv-gc-roots/SKILL.md) | Clean up `.direnv` GC roots to reclaim Nix store space | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |

Project development has exactly one source of truth: Nix or mise. New
projects default to mise; Nix package outputs require Nix development, and
package-only flakes cannot accompany a mise toolchain. Only Nix-to-mise
migration is supported. User-wide tools prefer an officially recommended
self-upgrading binary, otherwise Nix in Linux or WSL and WinGet user scope on
native Windows. Toolchain skills may pin a task runner but do not define
recipes. See `project-toolchain-selection`.

## Install

### Whole package

Installs all skills plus re-exported dependencies (`apm.yml` transitive deps,
e.g. `apm-usage` from microsoft/apm):

```sh
apm install -g fuj1g0n/skills
```

Pin to a commit in `~/.apm/apm.yml`:

```yaml
dependencies:
  apm:
    - fuj1g0n/skills#<full-40-char-sha>
```

### Single skill

Install only one skill as a virtual subdirectory package (no transitive
dependencies come along):

```sh
apm install -g "fuj1g0n/skills/.apm/skills/<name>#<full-40-char-sha>"
```

Or in `apm.yml` (object form):

```yaml
dependencies:
  apm:
    - git: fuj1g0n/skills
      path: .apm/skills/<name>
      ref: <full-40-char-sha>
```

Note: pin with a full 40-char commit SHA (or a tag); short SHAs and floating
branches do not resolve reliably.

## Documentation

[docs/](docs/index.md) is an Open Knowledge Format (OKF) v0.2 bundle.
