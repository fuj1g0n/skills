# nix/ file patterns

The three files under `nix/` that make the zero-inputs layout work.

## nix/nixpkgs.nix — pinned nixpkgs import

```nix
# Pinned nixpkgs import — managed by npins.
# To update: npins update nixpkgs
let
  sources = import ../npins;
  nixpkgs = import sources.nixpkgs;
in
args: nixpkgs (args // {
  overlays = (args.overlays or [ ]) ++ [ (import ./overlay.nix) ];
})
```

## nix/overlay.nix — leaf packages

Pure callPackage-style packages live in `nix/packages/<name>/default.nix` and
are auto-injected via the overlay:

```nix
# nix/overlay.nix
final: _prev: {
  my-tool = final.callPackage ./packages/my-tool { };
}
```

Packages that need per-invocation arguments (commit hash, build-time env)
stay in the top-level `default.nix` — overlays are for things that
legitimately belong on `pkgs`.

## nix/env.nix — shared env vars

Define a single `nix/env.nix` returning an attrset; both the build derivation
and the devShell spread it into their `env`. This prevents drift between
`nix build` and `nix develop`.

```nix
# nix/env.nix
{ pkgs }: {
  MY_TOOL_DIR = pkgs.my-tool;
  MY_GH_BIN   = "${pkgs.gh}/bin/gh";
}
```
