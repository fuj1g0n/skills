# skills

Personal agent skills for @fuj1g0n, deployed user-wide via
[Microsoft APM](https://github.com/microsoft/apm) to `~/.agents/skills/`.

## Skills

| Skill | Purpose |
|-------|---------|
| [nix-env-setup](skills/nix-env-setup/SKILL.md) | User-level (`nix profile`) and repository-level (flake devShell + direnv + just) environment setup with Nix |
| [missing-tools](skills/missing-tools/SKILL.md) | Resolve missing CLI tools without global installs (`direnv exec` → `nix run` → `nix shell` → uvx) |
| [nix-github-rate-limit](skills/nix-github-rate-limit/SKILL.md) | Token injection via `gh auth token` for GitHub-backed Nix fetches |
| [nix-gc-direnv](skills/nix-gc-direnv/SKILL.md) | Clean up `.direnv` GC roots to reclaim Nix store space |

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

## Credits

Adapted from patterns in
[ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles),
[wcygan/dotfiles](https://github.com/wcygan/dotfiles), and
[srid/emanote](https://github.com/srid/emanote) (`nix-for-dev`).
