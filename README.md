# skills

Personal agent skills for @fuj1g0n, deployed user-wide via
[Microsoft APM](https://github.com/microsoft/apm) to `~/.agents/skills/`.

## Skills

| Skill | Purpose | Adapted from |
|-------|---------|--------------|
| [skill-management](.apm/skills/skill-management/SKILL.md) | Operational rules: all skill deployment via APM, full-SHA pinning, adoption criteria | original (concepts from mizchi/skills skill-selector) |
| [nix-manager](.apm/skills/nix-manager/SKILL.md) | User-level package management with `nix profile` (Determinate Nix patterns) | [wcygan/dotfiles](https://github.com/wcygan/dotfiles) |
| [nix-for-dev](.apm/skills/nix-for-dev/SKILL.md) | Repository-level dev environment: zero-inputs flake + npins + devShell + direnv + just | [srid/emanote](https://github.com/srid/emanote) |
| [missing-tools](.apm/skills/missing-tools/SKILL.md) | Resolve missing CLI tools without global installs (direnv exec → comma → nix run → nix shell, uvx for Python) | [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) |
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

## Decisions

Architecture decision records live in [docs/adr/](docs/adr/):

- [0001](docs/adr/0001-manage-user-global-skills-with-apm.md) — Manage user-global agent skills with Microsoft APM and a personal skills repository
- [0002](docs/adr/0002-apm-package-layout-and-reexport.md) — Use the `.apm/skills/` package layout and re-export third-party skills as APM dependencies
- [0003](docs/adr/0003-curated-skill-set-external-survey.md) — Curated skill set for development process and environment setup (external landscape survey)
