default:
    @just --list

# Format Nix files (npins/ is generated, not formatted)
fmt:
    nixfmt flake.nix shell.nix nix/*.nix

# Lint Markdown files
lint:
    markdownlint-cli2 "**/*.md"
