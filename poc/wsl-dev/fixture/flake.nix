{
  description = "WSL direnv project-shell proof of concept";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      wsl-probe = pkgs.writeShellApplication {
        name = "wsl-probe";
        runtimeInputs = [ pkgs.python313 ];
        text = builtins.replaceStrings [ "\r" ] [ "" ] ''
          python -c 'import json, os, sys; args = sys.argv[1:]; print(json.dumps({"argv": args, "cwd": os.getcwd(), "stdin": sys.stdin.read() if "--read-stdin" in args else ""}, ensure_ascii=False)); print("probe-stderr", file=sys.stderr); raise SystemExit(23 if "--fail" in args else 0)' "$@"
        '';
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          nodejs
          python313
          uv
          wsl-probe
        ];
        POC_DEV_SHELL = "wsl-direnv";
      };
    };
}
