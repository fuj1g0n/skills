# Sub-flakes for non-user-facing Nix

Module integration tests (home-manager, NixOS, Darwin) genuinely need
`flake-parts`-style inputs. Nest them under `nix/<name>/flake.nix`; CI builds
with `--override-input` pointing back at the parent:

```nix
# nix/home/example/flake.nix
{
  inputs = {
    self_pkg.url     = "github:owner/repo";   # parent; CI passes --override-input
    nixpkgs.url      = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nixpkgs, home-manager, self_pkg, ... }: {
    # nixosConfigurations / checks that exercise self_pkg modules
  };
}
```

Users running `nix develop` / `nix run` on the top-level flake never evaluate
this graph. Only CI does, e.g.:

```bash
nix build ./nix/home/example --override-input self_pkg .
```
