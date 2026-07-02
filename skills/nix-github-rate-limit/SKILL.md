---
name: nix-github-rate-limit
description: Prevents and handles GitHub API rate limits when Nix fetches GitHub-backed inputs. Use when Nix, flakes, nixpkgs commands, or comma may fetch GitHub-backed inputs.
---

# Nix GitHub Rate Limit

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
documented `access-tokens` setting without exposing the token value in the
command text:

```sh
NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" nix flake update
```

Do not write GitHub tokens to `nix.conf`, repository files, skill files,
shell config, or command arguments.

## Workflow

1. If the command may cause Nix to fetch from GitHub, check that `gh` is
   authenticated:

   ```sh
   gh auth status
   ```

2. If `gh` is unauthenticated, ask the user to run `gh auth login`; do not
   attempt to capture or supply credentials.
3. If no safe token source is available, run the command normally unless the
   user explicitly wants to authenticate first.
4. If a GitHub API rate limit error appears (`HTTP error 403` from
   `api.github.com`), retry once with the safest available token source.

## History Safety

- Command text, shell history, process lists, terminal output, tool
  invocation logs, and coding-agent transcripts must not contain raw tokens.
- Prefer inline command substitution such as `$(gh auth token)` inside the
  command the user runs.
- It is also acceptable to reference an existing environment variable by
  name, such as `$GITHUB_TOKEN`; do not assign the raw value in the command.
- Do not paste a raw token into the terminal, even temporarily.
- Do not run commands like `env NIX_CONFIG="access-tokens = github.com=ghp_..." ...`.
- Do not place raw tokens in agent tool calls, command logs, or explanatory
  messages.
- Do not store a token in exported shell variables, direnv files, or shell
  history cleanup scripts.
- If a raw token was accidentally pasted, tell the user to rotate or revoke
  it. Deleting shell history is not enough.

## Avoid

- Do not use `--access-tokens "github.com=$(gh auth token)"` because command
  arguments can be exposed via process listings.
- Do not store PATs in `~/.config/nix/nix.conf`, `/etc/nix/nix.conf`,
  repository files, or dotfiles by default.
- Do not suggest broad PAT scopes. Public GitHub fetches should not need
  additional repository permissions.
- Do not print tokens, echo tokens, or include them in logs, summaries,
  commits, PR descriptions, or issue comments.

## Notes

- Unauthenticated GitHub REST API requests are rate limited much more
  aggressively than authenticated requests. Check remaining quota with
  `gh api rate_limit --jq '.resources.core | "\(.remaining)/\(.limit)"'`.
- `NIX_CONFIG` keeps the token out of the command arguments, but environment
  variables can still be visible to sufficiently privileged local processes.
  Prefer it only for short-lived commands.
- If `GITHUB_TOKEN` is already provided by CI or a controlled environment,
  Nix may use it, but do not create or persist it just for local interactive
  use.
- WSL2 note: in this environment (mirrored networking behind Global Secure
  Access), a hanging fetch to `api.github.com` is a DNS/GSA issue rather than
  rate limiting; a 403 is rate limiting, a timeout is the network.
