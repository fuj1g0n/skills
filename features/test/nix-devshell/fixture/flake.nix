{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/421eebfd0ec7bccd4abe826ce62d7e6e83129493";
  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ nixpkgs.legacyPackages.${system}.hello ];
        };
      });
    };
}
