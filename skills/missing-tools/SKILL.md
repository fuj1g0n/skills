---
name: missing-tools
description: Resolves missing CLI tools. Use when a command is unavailable, a shell reports command not found, or a tool must be run without installing it globally.
---

# Missing Tools

Use this workflow when a command is unavailable in the current shell.

## Priority Order

1. Try the current project's direnv environment:

   ```sh
   direnv exec . <command>
   ```

2. Use [comma](https://github.com/nix-community/comma) for tools from nixpkgs,
   if `,` is available:

   ```sh
   , <command>
   ```

   When comma may fetch from GitHub, also use the `nix-github-rate-limit` skill.

3. Use `nix run` when a specific nixpkgs package is needed:

   ```sh
   nix run nixpkgs#<package> -- <args>
   ```

   When the command may fetch from GitHub, also use the `nix-github-rate-limit` skill.

4. Use `nix shell` as the last resort:

   ```sh
   nix shell nixpkgs#<package> --command <command>
   ```

   When the command may fetch from GitHub, also use the `nix-github-rate-limit` skill.

## Python tools

For Python CLIs, prefer uv over Nix:

```sh
uvx <tool>            # one-off run of a Python CLI
uv run <command>      # inside a uv-managed project
```

## Notes

- Never install missing tools globally. Do not use commands such as
  `apt-get install`, `npm install -g`, `npm i -g`, `pnpm add -g`,
  `yarn global add`, `bun add -g`, `uv tool install`, `brew install`, or
  language-specific global installers to resolve a missing command.
- Prefer `direnv exec .` first because project-local dev shells often already
  provide the right tool version and environment variables.
- Comma automatically finds and runs the nixpkgs package containing the
  requested command. Package name differs from command name sometimes; search
  with `nix search nixpkgs <command>` or https://search.nixos.org.
- If the tool will be needed repeatedly, stop and persist it instead: add it
  to the project's flake devShell (see `nix-for-dev`) or install it user-wide
  (see `nix-manager`). Ask the user when the scope is unclear.
