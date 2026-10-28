# Nix Development File Patterns

Preserve a project's established Nix layout. For a newly approved Nix
toolchain, this repository prefers a zero-inputs flake with npins-pinned
nixpkgs and a separate development shell.

## Development-only flake wrapper

```nix
{
  outputs = { self, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = f: builtins.listToAttrs (map
        (system: {
          name = system;
          value = f (import ./nix/nixpkgs.nix { inherit system; });
        })
        systems);
    in
    {
      devShells = eachSystem (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
    };
}
```

`nix/nixpkgs.nix` imports the committed npins source. `shell.nix` uses
`pkgs.mkShell` and contains only development tools and environment variables.
Commit source pins and activation files.

If the project already has `packages`, `apps`, `checks`, derivations, or
Nix-built release outputs, do not rewrite them from this reference. Their
presence constrains development to Nix, while edits belong to
`project-nix-distribution`.

Do not introduce task definitions into the flake. A task runner may be a
devShell tool, but recipes stay in the repository's existing task surface.
