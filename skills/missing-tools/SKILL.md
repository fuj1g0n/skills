---
name: missing-tools
description: Resolves missing CLI tools without global installation. Use when a command is unavailable, a shell reports command not found, or a tool must be run without installing it.
---

# Missing Tools

Use this workflow when a command is unavailable in the current shell.

## Priority Order

1. Try the current project's direnv environment:

   ```sh
   direnv exec . <command>
   ```

2. Run it ephemerally from nixpkgs:

   ```sh
   nix run nixpkgs#<package> -- <args>
   ```

3. Use `nix shell` when several commands from the package are needed:

   ```sh
   nix shell nixpkgs#<package> --command <command>
   ```

4. Python tools: use uv instead of Nix:

   ```sh
   uvx <tool>            # one-off run of a Python CLI
   uv run <command>      # inside a uv-managed project
   ```

5. If the tool will be needed repeatedly, stop and apply the `nix-env-setup`
   skill: add it to the project's flake devShell (project-scoped) or
   `nix profile install` (user-scoped). Ask the user when the scope is
   unclear.

## Notes

- Never install missing tools globally. Do not use `apt-get install`,
  `npm i -g`, `pnpm add -g`, `yarn global add`, `bun add -g`,
  `uv tool install`, `pip install --user`, or `brew install`.
- Prefer `direnv exec .` first because project devShells often already provide
  the right tool version and environment variables.
- When a `nix run` / `nix shell` invocation fetches from GitHub and hits rate
  limits, apply the `nix-github-rate-limit` skill.
- Package name differs from command name sometimes; search with
  `nix search nixpkgs <command>` or https://search.nixos.org.
