# Slim zero-inputs wrapper (ADR-0014): nixpkgs is pinned by npins, not by
# flake inputs, to keep cold `nix develop` evaluation fast.
{
  description = "Development environment for fuj1g0n/skills";

  outputs =
    { self, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f (import ./nix/nixpkgs.nix { inherit system; });
          }) systems
        );
    in
    {
      devShells = eachSystem (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
    };
}
