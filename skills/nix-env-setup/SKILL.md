---
name: nix-env-setup
description: Set up user-level and repository-level development environments with Nix. Use when installing CLI tools for the user, bootstrapping a new project's dev environment, adding tools to an existing project, or when asked how a tool should be installed or managed.
---

# Nix Environment Setup

All environment setup is done with Nix (Determinate Nix). Never use `apt-get`,
`brew`, or language-specific global installers. devbox is deprecated in this
environment; do not use it.

## User level: `nix profile`

Global CLI tools live in the user profile (`~/.nix-profile/bin`).

```sh
nix profile install nixpkgs#<package>   # install
nix profile list                        # inspect
nix profile upgrade --all               # upgrade everything
nix profile remove <name>               # remove
```

Rules:

- Only install a tool at user level when it is used across many projects
  (editors, git tooling, shells, ripgrep-class utilities).
- Never use `nix-env -i`; it hides state and breaks reproducibility.
- Upgrade Nix itself with `sudo determinate-nixd upgrade`.

## Repository level: flake devShell + direnv + just

Every project provides its tools through a `flake.nix` devShell.

```nix
# flake.nix
{
  description = "dev shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems
        (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            # project toolchain here
          ];
        };
      });
    };
}
```

```sh
# .envrc
use flake
```

```sh
direnv allow      # activate on cd
nix develop       # manual entry without direnv
```

Rules:

- Commit `flake.nix` and `flake.lock`.
- Always include `just` in the devShell; the project task runner is a
  `justfile` (never Make).
- Python projects: provide `uv` in the devShell and manage Python itself and
  dependencies through uv (`uv python`, `uv sync`, `uv run`). Do not put
  Python packages in the flake.
- For low-latency `nix develop`, consider the zero-inputs flake + npins layout
  (see srid's nix-for-dev pattern) on projects where cold-start time matters.

## Ad-hoc, one-off tools

Do not install for one-off use:

```sh
nix run nixpkgs#<package> -- <args>
nix shell nixpkgs#<package> --command <command>
```

## Decision table

| Need | Action |
|------|--------|
| Tool for this project | Add to `flake.nix` devShell, `direnv allow` |
| Tool used everywhere | `nix profile install nixpkgs#<pkg>` |
| Tool needed once | `nix run` / `nix shell` |
| Python interpreter or package | uv inside the devShell |
| System package (`apt-get`) | Forbidden; find the nixpkgs equivalent |
