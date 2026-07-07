# Troubleshooting

## Slow Nix Operations

Diagnosis:

```bash
nix store info             # check store size
nix store gc --dry-run     # see what can be cleaned
```

Solutions:

- Run `nix-collect-garbage -d` to remove old generations
- Run `nix store optimise` to deduplicate files
- Clean stale `.direnv` GC roots first (see `nix-gc-direnv`)
- Check network connectivity (binary cache downloads); on this WSL2/GSA
  network a hang is usually DNS, not Nix

## Package Not Found

Error: `error: attribute 'package-name' missing`

1. Search for the package: `nix search nixpkgs package-name`
2. Check if the package was renamed (e.g., `du-dust` → `dust`)
3. Try alternative package names or https://search.nixos.org

## GitHub Rate Limits

`HTTP error 403` from `api.github.com` during fetches: apply the
`nix-github-rate-limit` skill.

## Profile Issues

```bash
nix profile list                # list installed packages
nix profile rollback            # revert to previous generation
nix profile history             # inspect generations
```
