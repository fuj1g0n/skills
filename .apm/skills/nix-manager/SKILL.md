---
name: nix-manager
description: "Manage user-level Nix packages and configuration using Determinate Nix patterns. Use when installing/updating user CLI tools, troubleshooting Nix issues, or optimizing Nix workflows. Keywords: nix, package, nixpkgs, nix profile, determinate, nix-installer"
---

# Nix Package & Configuration Manager

User-level package management following Determinate Systems best practices.

## Instructions

### 1. Understand the Environment

- **Installer**: Determinate Nix on WSL2 (upgrade with
  `sudo determinate-nixd upgrade`)
- **Package management**: `nix profile` (user-scoped, modern approach);
  installed tools live in `~/.nix-profile/bin`
- **Forbidden**: `apt-get`, `brew`, `nix-env -i`, devbox (removed from this
  system)
- **Scope rule**: only install user-wide when a tool is used across many
  projects; project toolchains belong in flake devShells (see `nix-for-dev`),
  and one-shot needs are run ephemerally instead (see `missing-tools`)

### 2. Package Management Operations

#### Install New Package

```bash
nix search nixpkgs <name>              # find the attribute
nix profile install nixpkgs#<package>
which <command>                        # verify installation
```

#### Update All Packages

```bash
nix profile upgrade --all
nix profile list                       # verify no breakage
```

#### Remove Package

```bash
nix profile list                       # find the entry name
nix profile remove <name>
```

Old packages remain in the store until garbage collection:

```bash
nix-collect-garbage -d
```

### 3. Troubleshooting

For diagnosis and fixes — slow operations (GC, `nix store optimise`, stale
`.direnv` roots), `attribute missing` errors, GitHub rate limits, profile
rollback/history — read
[references/troubleshooting.md](references/troubleshooting.md).

### 4. Best Practices (Determinate Nix Patterns)

#### Use nixos-unstable Instead of master

- `nixos-unstable`: tested, passes Hydra CI
- `master`: untested, may have broken packages

#### Never Use --impure

`--impure` breaks reproducibility by allowing environment variable access.

Correct:

```bash
nix profile install nixpkgs#<pkg>   # pure evaluation
```

Incorrect:

```bash
nix profile install nixpkgs#<pkg> --impure   # BAD: non-reproducible
```

Exception: only use `--impure` if an expression explicitly uses `getEnv` or
similar.

#### Never Use nix-env

`nix-env -i` hides state and breaks reproducibility. Use `nix profile` for
user tools, devShells for project tools, or ad-hoc `nix run` / `nix shell`.

#### Pin Dependencies in Lock Files

Always commit `flake.lock` (and `npins/`) in projects; reproducible builds
across machines are the point.

#### Coexistence with apt

Nix coexists with the system package manager. Do not install development
tools with `apt-get`; reserve it for nothing — system administration on this
host is out of scope for agents.

### 5. Quick Reference

```bash
# Package management
nix search nixpkgs <package>     # search for package
nix profile list                 # list installed packages
nix profile install nixpkgs#<p>  # install
nix profile upgrade --all        # upgrade everything
nix profile rollback             # revert to previous
nix-collect-garbage -d           # clean old generations

# Development
nix develop                      # enter dev shell
nix build                        # build package
nix run nixpkgs#<p> -- <args>    # run without installing
nix shell nixpkgs#<p> --command <cmd>

# Troubleshooting
nix store info                   # store statistics
nix store gc --dry-run           # preview cleanup
nix store optimise               # deduplicate
sudo determinate-nixd upgrade    # upgrade Nix itself
```

## Reference Documentation

- Determinate Installer: https://determinate.systems/blog/determinate-nix-installer/
- Zero to Nix (Flakes): https://zero-to-nix.com/concepts/flakes/
- Nix.dev: https://nix.dev/
