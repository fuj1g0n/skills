{
  pkgs ? import ./nix/nixpkgs.nix { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    just
    nixfmt
    markdownlint-cli2
  ];
}
