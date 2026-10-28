# skills

Home for everything involved in developing agent skills that reproduce
@fuj1g0n's development environment and process: the research
([docs/research/](docs/research/)) and the resulting skills
(`skills/`), which are the deliverables.
The repository is an [Agent Plugin](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) (root
`plugin.json`), installed user-wide as a Copilot CLI plugin.

Not every investigation yields a skill; research snapshots are kept as
records either way.

## Skills

| Skill | Purpose | Adapted from |
|-------|---------|--------------|
| [skill-management](skills/skill-management/SKILL.md) | Operational rules: plugin marketplace release, APM for third-party skills, full-SHA pinning, adoption criteria | original (concepts from mizchi/skills skill-selector) |
| [skill-authoring](skills/skill-authoring/SKILL.md) | Quality rules for writing skills: authoring contract (Ask, Hand off, Block, Done when, Invariants) enforced by `mise run audit`, description discipline, cross-model subagent testing | original (adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles), [obra/superpowers](https://github.com/obra/superpowers), [mizchi/skills](https://github.com/mizchi/skills), all MIT; concepts from [anthropics/skills](https://github.com/anthropics/skills), Apache 2.0) |
| [software-design](skills/software-design/SKILL.md) | Resolve design questions and preserve the smallest useful artifact: inline reasoning, design document, or ADR; reuse active Ponytail/pstack workflows | original design workflow; ADR concepts adapted from [cassiobotaro/skills](https://github.com/cassiobotaro/skills), [wshobson/agents](https://github.com/wshobson/agents), [github/awesome-copilot](https://github.com/github/awesome-copilot), all MIT; MADR templates from [adr/madr](https://github.com/adr/madr) |
| [documentation](skills/documentation/SKILL.md) | Project documentation formats: Diátaxis docs/ organization, standard-readme, Keep a Changelog, docs-as-code hygiene, OKF bundle conventions | original (adapted from [RichardLitt/standard-readme](https://github.com/RichardLitt/standard-readme) and [wshobson/agents](https://github.com/wshobson/agents), both MIT; concepts from [diataxis.fr](https://diataxis.fr/) and [keepachangelog.com](https://keepachangelog.com/)) |
| [project-toolchain-selection](skills/project-toolchain-selection/SKILL.md) | Select the one project development toolchain: mise by default, Nix only for projects distributed through Nix | original |
| [project-dev-tools](skills/project-dev-tools/SKILL.md) | Manage cross-platform project developer tools and environment through mise, preferring verified release backends such as `aqua:` | original |
| [project-nix-distribution](skills/project-nix-distribution/SKILL.md) | Build and distribute a project through Nix: packages, apps, checks, derivations, OCI images, release outputs, and the devShell that develops them | [srid/emanote](https://github.com/srid/emanote) |
| [project-toolchain-migration](skills/project-toolchain-migration/SKILL.md) | Perform full-cutover Nix-to-mise migrations; block while Nix package outputs remain | original |
| [project-env-cache-cleanup](skills/project-env-cache-cleanup/SKILL.md) | Clean up `.direnv` GC roots to reclaim Nix store space | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [windows-wslc-project-shell](skills/windows-wslc-project-shell/SKILL.md) | Run an existing Nix project's devShell through its selected Windows-hosted wslc bridge | original |
| [missing-tools](skills/missing-tools/SKILL.md) | Recover one-shot missing commands without persistent mutation; route recurring and explicit global needs to their current owner | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [linux-user-tools](skills/linux-user-tools/SKILL.md) | Manage explicit user-wide Linux/WSL tools, preferring official self-upgrading per-user binaries, otherwise `nix profile` | [wcygan/dotfiles](https://github.com/wcygan/dotfiles) |
| [windows-user-tools](skills/windows-user-tools/SKILL.md) | Manage explicit user-wide native Windows tools, preferring official self-upgrading per-user installers, otherwise WinGet user scope | original |
| [github-fetch-rate-limit](skills/github-fetch-rate-limit/SKILL.md) | Safe token injection via `gh auth token` for GitHub-backed Nix fetches | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |

Tool-management skills are named for scope, environment, and use case
(`project-*`, `linux-*`, `windows-*`), not for the package manager behind
them. Project development has exactly one source of truth. It is mise
unless the project is built and distributed through Nix, in which case Nix
also provides the devShell. A Nix devShell without package outputs is a
migration candidate, and only Nix-to-mise migration is supported. User-wide
tools prefer an official self-upgrading per-user binary, otherwise Nix in
Linux or WSL and WinGet user scope on native Windows. Toolchain skills may
pin a task runner but do not define recipes. See
`project-toolchain-selection`.

### Design workflow

`software-design` replaces the former `adr` entry point. Use it for an
explicit design question, design document, or decision record; routine
coding does not require a separate design phase or new document.
ADR remains an output format, with existing collections and templates
preserved. Fresh logs do not automatically get a format-adoption record.

When pstack architect already owns design, its rationale and sketch stay
authoritative; the skill consumes them without repeating analysis or adding
approval. Ponytail's active level continues to constrain scope and
simplicity. See the [integration adapter](skills/software-design/references/workflow-integration.md)
for boundaries, including optional execution decision trails.

Installations obtain the replacement when they update their pin to a
commit that includes it.

## Install

### Copilot CLI plugin

```sh
copilot plugin install fuj1g0n/skills
```

For a pinned install, add an entry with a full 40-char commit SHA to a
plugin marketplace's `.github/plugin/marketplace.json`:

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

```sh
copilot plugin install skills@<marketplace>
```

After bumping the SHA, update with:

```sh
copilot plugin marketplace update <marketplace>
copilot plugin update skills@<marketplace>
```

### APM

APM installs the repository as a plugin collection, without transitive
dependencies:

```sh
apm install -g fuj1g0n/skills#<full-40-char-sha>
```

The `apm-usage` skill that `skill-management` defers to is not bundled;
declare it separately:

```sh
apm install -g microsoft/apm/packages/apm-guide#<full-40-char-sha>
```

Pin with a full 40-char commit SHA; short SHAs and floating branches do not
resolve reliably.

## Development

Development tools and tasks are defined in `mise.toml` and pinned in
`mise.lock`, including the npm dependency graph under `.mise/locks/`.

```sh
mise trust
mise install
mise run audit   # skill contract audit and routing corpus
mise run lint    # Markdown lint
```

## Documentation

[docs/](docs/index.md) is an Open Knowledge Format (OKF) v0.2 bundle.
