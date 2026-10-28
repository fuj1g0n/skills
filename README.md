# skills

Home for everything involved in developing agent skills that reproduce
@fuj1g0n's development environment and process: the research
([docs/research/](docs/research/)) and the resulting skills
(`skills/`), which are the deliverables.
The repository is an [Agent Plugins](https://agent-plugins.org/) package with
a root `plugin.json`. Distribution format and consumption management are
independent: prefer Agent Plugins for a shared, vendor-neutral structure
across compatible tools, and APM for managing dependencies and deployment
across explicitly selected tools. Format portability does not guarantee
support for every component in every tool.

Not every investigation yields a skill; research snapshots are kept as
records either way.

## Skills

| Skill | Purpose | Adapted from |
|-------|---------|--------------|
| [skill-management](skills/skill-management/SKILL.md) | Operational rules: distribution formats, APM-managed consumption, compatibility exceptions, full-SHA pinning, adoption criteria | original (concepts from mizchi/skills skill-selector) |
| [skill-authoring](skills/skill-authoring/SKILL.md) | Quality rules for writing skills: authoring contract, description discipline, explicit-source validation, and behavior evaluation using the adopter's selected targets | original (adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles), [obra/superpowers](https://github.com/obra/superpowers), [mizchi/skills](https://github.com/mizchi/skills), all MIT; concepts from [anthropics/skills](https://github.com/anthropics/skills), Apache 2.0) |
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

### APM

APM is the preferred consumption manager, not the distribution format.
Select targets explicitly in the consumer manifest and verify the components
each tool receives. On the tested Copilot path, APM installs the repository
as a native `skills@apm` Agent Plugin without transitive dependencies.
Declare it in
`apm.yml` (`~/.apm/apm.yml` for user scope) and run `apm install` (`-g` for
user scope); APM rejects imperative installs of Agent Plugins from a local
path.

```yaml
dependencies:
  apm:
    - fuj1g0n/skills#<full-40-char-sha>
```

The `apm-usage` skill that `skill-management` defers to is not bundled;
declare `microsoft/apm/packages/apm-guide#<full-40-char-sha>` separately.

Update the dependency's SHA in the maintained manifest source.
For project scope, run `apm install` from that project.
For user scope, run `apm install -g`.
Do not install or update `skills@apm` with `copilot plugin` commands.
If an older setup installed `skills@dotfiles`, uninstall that plugin before
switching to APM.

Pin with a full 40-char commit SHA; short SHAs and floating branches do not
resolve reliably.

### Native Copilot marketplace

APM is the default recommendation, not a requirement to replace an adopter's
explicit manager policy. A native Copilot marketplace can consume this Agent
Plugins package directly. An APM failure is not a prerequisite.
For a native marketplace, declare `fuj1g0n/skills` as a GitHub source pinned
to a full commit SHA, then use `copilot plugin install skills@<marketplace>`.
Use the [Copilot marketplace reference](https://docs.github.com/en/copilot/reference/plugin-and-marketplace-reference)
for the entry format.
Do not install the same package through two managers in the same tool and
scope. APM's generated marketplace remains APM-managed consumption.
Record compatibility failures and workarounds in the affected consumer.

## Development

The [instruction scopes](docs/design/skill-instruction-scopes.md) separate
reusable adopter workflows from this repository's maintenance procedures
and consumer-specific configuration.
Read [AGENTS.md](AGENTS.md) for contributor instructions.

Development tools and tasks are defined in `mise.toml` and pinned in
`mise.lock`, including the npm dependency graph under `.mise/locks/`.

```sh
mise trust
mise install
mise run audit   # skill contract audit and routing corpus
mise run lint    # Markdown lint
```

### Evaluation profile

This collection's behavior-evaluation profile is a maintainer choice.
It is not a requirement for users of the distributed skills.
Run each required scenario with fresh agents on both targets:

| Target model | Effort |
| --- | --- |
| Claude Opus 5.5 | `medium` |
| GPT-6.1 Sol | `medium` |

Use the [shared evaluation method](skills/skill-authoring/references/testing-skills.md).
Report unavailable targets as unverified. Mechanical checks or repeated runs
on one model do not satisfy this cross-model profile.
Publish only when requested. A release does not itself update any consumer.

## Documentation

[docs/](docs/index.md) is an Open Knowledge Format (OKF) v0.2 bundle.
