---
name: github-fetch-rate-limit
description: Prevents and handles GitHub API rate limits when Nix fetches GitHub-backed inputs. Use when Nix, flakes, nixpkgs commands, or comma may fetch GitHub-backed inputs.
---

# GitHub Fetch Rate Limit

Use this skill before running Nix commands that may fetch GitHub-backed flakes
or packages, especially `nix flake update`, `nix run github:...`,
`nix run nixpkgs#...`, `nix build`, `nix shell`, and comma.

## Default Approach

Prefer ephemeral token injection from the authenticated GitHub CLI. Shell
history records the literal command substitution rather than the expanded
token:

```sh
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix run github:<owner>/<repo>
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix run nixpkgs#<package> -- <args>
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix build
```

If `GITHUB_TOKEN` is already present in the environment, bridge it into Nix's
documented `access-tokens` setting by name:

```sh
NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" nix flake update
```

## Workflow

1. If the command may cause Nix to fetch from GitHub, check that `gh` is
   authenticated:

   ```sh
   gh auth status
   ```

2. If `gh` is unauthenticated and no `GITHUB_TOKEN` exists, run the command
   without a token and tell the user that `gh auth login` would raise the
   limit. Credentials are entered by the user, never captured or supplied
   by the agent.
3. If a GitHub API rate limit error appears (`HTTP error 403` from
   `api.github.com`), retry once with the safest available token source;
   if none exists, Ask the user to run `gh auth login`, presenting the 403
   output.

## Invariants

- No raw token in command text, shell history, process lists, terminal
  output, tool invocation logs, agent transcripts, logs, summaries, commits,
  PR descriptions, or issue comments, because each of these is stored or
  shared beyond the command. Reference tokens only as `$(gh auth token)` or
  an existing variable name such as `$GITHUB_TOKEN`; never assign or echo
  the value.
- No token passed through `--access-tokens` or another command argument,
  because process listings expose arguments.
- No token stored in `nix.conf`, repository files, skill files, dotfiles,
  shell config, exported variables, or direnv files, because stored tokens
  outlive the command and leak through backups and sync.
- No broad PAT scopes, because public GitHub fetches need no repository
  permissions.
- If a raw token was exposed, tell the user to rotate or revoke it, because
  deleting shell history does not remove other copies.

## Notes

- Unauthenticated GitHub REST API requests are rate limited much more
  aggressively than authenticated requests. Check remaining quota with
  `gh api rate_limit --jq '.resources.core | "\(.remaining)/\(.limit)"'`.
- `NIX_CONFIG` keeps the token out of the command arguments, but environment
  variables can still be visible to sufficiently privileged local processes.
  Use it only for short-lived commands.
- If `GITHUB_TOKEN` is already provided by CI or a controlled environment,
  Nix may use it, but do not create or persist it just for local interactive
  use.
- WSL2 note: in this environment (mirrored networking behind Global Secure
  Access), a hanging fetch to `api.github.com` is a DNS/GSA issue rather than
  rate limiting; a 403 is rate limiting, a timeout is the network.

## Done when

- The Nix command succeeded, or the report distinguishes a 403 rate limit
  from a network timeout and names the next step.
- No token value appears in any command, output, or file.
