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

```sh
apm install -g fuj1g0n/skills
```

Pin to a commit in `~/.apm/apm.yml`:

```yaml
dependencies:
  apm:
    - fuj1g0n/skills#<sha>
```
