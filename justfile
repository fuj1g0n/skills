default:
    @just --list

# Format Nix files
fmt:
    nixfmt flake.nix

# Lint Markdown files
lint:
    markdownlint-cli2 "**/*.md"
