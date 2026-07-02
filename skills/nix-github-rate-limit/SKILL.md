---
name: nix-github-rate-limit
description: Prevents and handles GitHub API rate limits when Nix fetches GitHub-backed flakes or packages. Use before or after nix flake update, nix run github:..., nix run nixpkgs#..., nix build, or nix shell hits rate limits.
---

# Nix GitHub Rate Limit

Nix fetches flake inputs anonymously from the GitHub API by default and hits
the 60 req/h unauthenticated limit quickly. Inject a token from the
authenticated GitHub CLI at invocation time.

## Default Approach

```sh
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix run github:<owner>/<repo>
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix build
```

Shell history records the command substitution, not the expanded token.

If `GITHUB_TOKEN` is already set in the environment:

```sh
NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" nix flake update
```

## Rules

- Never write tokens to `nix.conf`, repository files, skill files, shell
  config, or literal command arguments.
- Never paste a raw token into a terminal or an agent tool call.
- Only add the token when the command actually fetches from GitHub
  (`nix flake update`, first fetch of an input, `nix run github:...`).
  Cached evaluations do not need it.

## Diagnosing

Rate limiting shows up as:

```
error: unable to download 'https://api.github.com/...': HTTP error 403
```

Check remaining quota:

```sh
gh api rate_limit --jq '.resources.core | "\(.remaining)/\(.limit)"'
```

## WSL2 note

In this environment (WSL2 mirrored networking behind Global Secure Access),
a hanging fetch to `api.github.com` may be a DNS/GSA issue rather than rate
limiting; a 403 is rate limiting, a timeout is the network.
