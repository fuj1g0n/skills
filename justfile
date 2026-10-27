default:
    @just --list

# Format Nix files (npins/ is generated, not formatted)
fmt:
    nixfmt flake.nix shell.nix nix/*.nix

# Lint Markdown files
lint:
    markdownlint-cli2 "**/*.md"

# Audit skills: contract rules and their fixtures, then routing corpus
audit:
    .apm/skills/skill-authoring/scripts/test-audit.sh
    .apm/skills/skill-authoring/scripts/audit.sh
    .apm/skills/project-toolchain-selection/scripts/validate-taxonomy.sh
