# skills

Home for everything involved in developing agent skills that reproduce
@fuj1g0n's development environment and process: the research
([docs/research/](docs/research/)), the decisions ([docs/adr/](docs/adr/)),
and the resulting skills (`.apm/skills/`), which are the deliverables.
Skills are deployed user-wide via
[Microsoft APM](https://github.com/microsoft/apm) to `~/.agents/skills/`.

Not every investigation yields a skill — rejected decisions (e.g. ADR-0008)
are kept as records; accepted environment decisions are expected to
eventually materialize as skills.

## Skills

| Skill | Purpose | Adapted from |
|-------|---------|--------------|
| [skill-management](.apm/skills/skill-management/SKILL.md) | Operational rules: all skill deployment via APM, full-SHA pinning, adoption criteria | original (concepts from mizchi/skills skill-selector) |
| [skill-authoring](.apm/skills/skill-authoring/SKILL.md) | Quality rules for writing skills: description discipline, length thresholds, collection audit (`audit.sh`), subagent-based testing | original (adapted from [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles), [obra/superpowers](https://github.com/obra/superpowers), [mizchi/skills](https://github.com/mizchi/skills), all MIT; concepts from [anthropics/skills](https://github.com/anthropics/skills), Apache 2.0) |
| [adr](.apm/skills/adr/SKILL.md) | Write and maintain Architecture Decision Records in MADR 4.0 format (trigger calibration, supersede workflow, vendored MADR templates) | original (adapted from [cassiobotaro/skills](https://github.com/cassiobotaro/skills), [wshobson/agents](https://github.com/wshobson/agents), [github/awesome-copilot](https://github.com/github/awesome-copilot), all MIT; MADR templates from [adr/madr](https://github.com/adr/madr)) |
| [nix-manager](.apm/skills/nix-manager/SKILL.md) | User-level package management with `nix profile` (Determinate Nix patterns) | [wcygan/dotfiles](https://github.com/wcygan/dotfiles) |
| [nix-for-dev](.apm/skills/nix-for-dev/SKILL.md) | Repository-level dev environment: zero-inputs flake + npins + devShell + direnv + just | [srid/emanote](https://github.com/srid/emanote) |
| [missing-tools](.apm/skills/missing-tools/SKILL.md) | Resolve missing CLI tools: triage scope (one-shot / project / user-wide), run one-shots ephemerally (uvx, npx, go run, comma, nix run), delegate persistent installs to nix-for-dev / nix-manager | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [nix-github-rate-limit](.apm/skills/nix-github-rate-limit/SKILL.md) | Safe token injection via `gh auth token` for GitHub-backed Nix fetches | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
| [nix-gc-direnv](.apm/skills/nix-gc-direnv/SKILL.md) | Clean up `.direnv` GC roots to reclaim Nix store space | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |

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

[docs/](docs/index.md) is an Open Knowledge Format (OKF) v0.2 bundle (see
ADR-0017).
