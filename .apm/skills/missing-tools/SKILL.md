---
name: missing-tools
description: Resolves missing CLI tools. Use when a command is unavailable, a shell reports command not found, or a tool must be run without installing it globally.
---

# Missing Tools

Use this workflow when a command is unavailable in the current shell.

## Step 1: Decide the scope

Before running anything, classify why the tool is needed:

| Scope | Signal | Action |
|---|---|---|
| **One-shot** | Needed once or a few times in this session only | Handle here — see below |
| **Project dev tool** | Part of the project's toolchain, needed repeatedly (build, lint, test, codegen) | Delegate to the `nix-for-dev` skill: add it to the flake devShell, then run via `direnv exec .` |
| **User-wide tool** | Used across many projects, independent of any one repo | Delegate to the `nix-manager` skill: install via `nix profile` |

Ask the user when the scope is unclear. Do not quietly resolve a recurring
project dependency with one-shot runs — persist it via the right skill.

## Step 2: One-shot execution

### 2.0 Check the project environment first

The tool may already exist in the project's dev shell:

```sh
direnv exec . <command>
```

### 2.1 Ecosystem-native runners

When the tool belongs to a language ecosystem, prefer that ecosystem's
ephemeral runner:

| Ecosystem | Runner | Example |
|---|---|---|
| Python | `uvx` | `uvx ruff check .` |
| Node.js | `npx -y` (or `pnpm dlx` / `bunx`, matching the project's package manager) | `npx -y prettier --check .` |
| Go | `go run <module>@<version>` | `go run golang.org/x/tools/cmd/goimports@latest -l .` |
| Rust | none (`cargo install` is persistent) | fall through to nixpkgs below |

Inside a uv-managed project, use `uv run <command>` instead of `uvx` so the
project's own environment is used.

### 2.2 Generic fallback: nixpkgs

For tools with no ecosystem runner (or Rust CLIs):

1. [comma](https://github.com/nix-community/comma), if `,` is available —
   automatically finds the nixpkgs package containing the command:

   ```sh
   , <command>
   ```

2. `nix run` when you know the package:

   ```sh
   nix run nixpkgs#<package> -- <args>
   ```

3. `nix shell` as the last resort (multiple tools, or command != package):

   ```sh
   nix shell nixpkgs#<package> --command <command>
   ```

Whenever these may fetch from GitHub, also use the `nix-github-rate-limit`
skill. Package name sometimes differs from command name; search with
`nix search nixpkgs <command>` or https://search.nixos.org.

## Notes

- Never install missing tools globally from this skill. Do not use commands
  such as `apt-get install`, `npm install -g`, `pnpm add -g`,
  `yarn global add`, `bun add -g`, `uv tool install`, `cargo install`,
  `brew install`, or other global installers — persistent installs go
  through `nix-for-dev` (project) or `nix-manager` (user-wide).
