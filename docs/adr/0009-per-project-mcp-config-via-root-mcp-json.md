---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Use project-root .mcp.json for per-project MCP configuration

## Context and Problem Statement

APM packages can declare MCP servers as dependencies (e.g.
`microsoft/azure-skills` self-defines the `azure` server), and the intent is
project-scoped availability: the server should exist for the project that
depends on the package, not pollute every session globally. But where should
the MCP configuration actually live so that GitHub Copilot CLI — the primary
agent runtime — picks it up per project?

Survey findings (full snapshot:
[docs/research/2026-07-07-per-project-mcp-config.md](../research/2026-07-07-per-project-mcp-config.md)):

* APM's `copilot` adapter writes MCP config **only** to the global
  `~/.copilot/mcp-config.json`; its project-scoped output for the copilot
  target is `.vscode/mcp.json`, which Copilot CLI stopped reading in v1.0.22.
* Copilot CLI itself reads workspace MCP config from project-root
  `.mcp.json` (since ~v1.0.12) and `.github/mcp.json` (since v1.0.61), both
  in `{"mcpServers": {...}}` format, gated by the folder-trust dialog.
  Verified live on v1.0.69. Neither file is covered by the official docs
  (changelog-documented only).
* VS Code also discovers project-root `.mcp.json` (Claude-style format,
  unconditional discovery with trust confirmation) since 2026-04-23
  (microsoft/vscode PR #312234), alongside its documented `.vscode/mcp.json`.
* APM upstream accepted feature request microsoft/apm#2047 (2026-07-06):
  the copilot adapter will default to writing **project-root `.mcp.json`**,
  going global only with `-g`. Unimplemented as of v0.24.0.

## Decision Drivers

* MCP servers must be project-scoped; the global
  `~/.copilot/mcp-config.json` stays empty (azure MCP was removed from it
  on 2026-07-07 for this reason).
* One committed file should serve both Copilot CLI (terminal) and VS Code.
* Whatever is hand-authored now should become APM-managed later without a
  file move.

## Considered Options

* Project-root `.mcp.json` (`mcpServers` format), committed
* `.github/mcp.json`, committed
* Keep APM-generated `.vscode/mcp.json` only
* Per-session `--additional-mcp-config @file` via direnv/alias
* Global `~/.copilot/mcp-config.json` via `apm install -g`

## Decision Outcome

Chosen option: "Project-root `.mcp.json`", because it is the only location
read by both Copilot CLI and VS Code, and it is exactly the file APM's
accepted roadmap (microsoft/apm#2047) will manage for the copilot target —
hand-authoring it now is forward-compatible with letting `apm install` own
it later. `.github/mcp.json` is Copilot-CLI-only and lower in the loading
priority; `.vscode/mcp.json` no longer reaches the CLI; per-session flags
add launcher machinery for no scoping gain; global install is the exact
pollution being avoided.

Until #2047 ships, the `.mcp.json` is hand-authored (copying the server
definition APM records in `apm.lock.yaml` / generates into
`.vscode/mcp.json`) and committed. The APM-generated `.vscode/mcp.json` may
coexist for VS Code users; it is APM-managed and harmless. When #2047 is
implemented, `apm install` takes over the file.

### Consequences

* Good, because one committed file gives project-scoped MCP to both GitHub
  agent surfaces, gated by their folder/workspace trust prompts.
* Good, because the global MCP config stays empty, keeping unrelated
  sessions free of tool-definition overhead.
* Bad, because until microsoft/apm#2047 ships, the hand-authored `.mcp.json`
  duplicates what APM already knows from the dependency graph and can drift
  from `apm.lock.yaml` on package updates.
* Bad, because both workspace files are undocumented in official Copilot CLI
  and VS Code docs; the behavior rests on changelogs and source, and could
  change with weaker notice than documented features.

## More Information

Survey snapshot (ADR-0006 tier-2):
[2026-07-07-per-project-mcp-config.md](../research/2026-07-07-per-project-mcp-config.md).
Re-check microsoft/apm#2047 before hand-authoring new `.mcp.json` files; once
implemented, prefer `apm install` as the owner of the file.
