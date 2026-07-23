{
  description = "Development environment for fuj1g0n/skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            nixfmt
            markdownlint-cli2
          ];
        };
      });

      # For global installation via `nix profile add .#<name>` in the
      # devcontainer postCreateCommand. Versions are pinned by flake.lock.
      packages = forAllSystems (pkgs: {
        direnv = pkgs.direnv;
        nix-direnv = pkgs.nix-direnv;
        nil = pkgs.nil;
        nixfmt = pkgs.nixfmt;
      });
    };
}
