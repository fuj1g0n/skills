---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# MCP configuration placement: project-root .mcp.json per project, minimal per-tool user-global

## Context and Problem Statement

APM packages can declare MCP servers as dependencies (e.g.
`microsoft/azure-skills` self-defines the `azure` server), and MCP servers
are also occasionally wanted across all projects. Where should MCP
configuration live, on both the per-project and the user-global axis, so
that the GitHub Copilot tool family (CLI, desktop App, VS Code) picks it up
with the right scope?

Survey of all tools on both axes (full snapshot:
[docs/research/2026-07-07-per-project-mcp-config.md](../research/2026-07-07-per-project-mcp-config.md)):

* **Copilot CLI** reads workspace `.mcp.json` (root, since ~v1.0.12; the
  sole root-level source since v1.0.22 removed `.vscode/mcp.json`) and
  `.github/mcp.json` (v1.0.61), plus user-global
  `~/.copilot/mcp-config.json`; workspace files are folder-trust gated.
  Verified live on v1.0.69.
* **Copilot App** (desktop, GA 2026-06-17) shares the CLI runtime and has
  no MCP config surface of its own: it inherits `~/.copilot/mcp-config.json`
  and the workspace files, plus an in-app GUI.
* **VS Code** documents `.vscode/mcp.json` (project) and a profile-level
  user `mcp.json` (`servers` key), and additionally discovers project-root
  `.mcp.json` (Claude-style `mcpServers`, trust-on-nonce, since 2026-04-23,
  PR microsoft/vscode#312234). Its global discovery covers only Claude
  Desktop / Windsurf / Cursor — never `~/.copilot/mcp-config.json`.
* **Copilot cloud agent / code review** are configured exclusively in
  repository settings (UI JSON, `mcpServers` key) and read no files.
* **APM** (0.23.1) writes `.vscode/mcp.json` (project) and
  `~/.copilot/mcp-config.json` (`-g`) for the copilot target; accepted
  feature microsoft/apm#2047 will default the copilot adapter to
  project-root `.mcp.json` (unimplemented as of v0.24.0). APM's
  experimental copilot-app integration handles no MCP.
* Upstream demand for user-global unification exists (copilot-cli #146,
  #3019; community#187954) but no side has committed; root `.mcp.json` is
  the only de facto cross-tool convergence point.

## Decision Drivers

* Package-driven MCP servers (APM dependencies) must be project-scoped;
  unrelated sessions must not pay their context and startup cost.
* One committed file should serve Copilot CLI, Copilot App, and VS Code.
* Hand-authored config should become APM-managed later without a file move.
* User-global config should stay minimal and auditable; no fragile
  undocumented bridging between tools.

## Considered Options

Per-project axis:

* Project-root `.mcp.json` (`mcpServers` format), committed
* `.github/mcp.json`, committed
* Keep APM-generated `.vscode/mcp.json` only
* Per-session `--additional-mcp-config @file` via direnv/alias

User-global axis:

* Keep `~/.copilot/mcp-config.json` empty by default; add servers per
  project instead
* Populate `~/.copilot/mcp-config.json` (CLI + App) and dual-maintain VS
  Code's profile `mcp.json` when needed
* Symlink `claude_desktop_config.json` → `~/.copilot/mcp-config.json` and
  enable VS Code's claude-desktop discovery (single-file hack)

## Decision Outcome

**Per project — chosen option: "Project-root `.mcp.json`"**, because it is
the only location read by Copilot CLI, the Copilot App (via the shared
runtime), and VS Code alike, and it is exactly the file APM's accepted
roadmap (microsoft/apm#2047) will manage for the copilot target —
hand-authoring it now is forward-compatible with letting `apm install` own
it later. `.github/mcp.json` is CLI/App-only and lower priority;
`.vscode/mcp.json` no longer reaches the CLI; per-session flags add
launcher machinery for no scoping gain. Until #2047 ships, the file is
hand-authored (copying what APM records in `apm.lock.yaml`) and committed;
the APM-generated `.vscode/mcp.json` may coexist harmlessly for VS Code.

**User-global — chosen option: "Keep `~/.copilot/mcp-config.json` empty by
default"**, because no location spans VS Code and the CLI/App family, and
project scope covers the actual need (azure MCP was removed from the
global file on 2026-07-07 for this reason). When a genuinely cross-project
personal server arises, it goes into `~/.copilot/mcp-config.json` (which
covers both CLI and App) with VS Code's profile `mcp.json` dual-maintained
only if needed there. The symlink hack is rejected: it mislabels servers
as "Claude Desktop", collides with a real Claude Desktop install, and
rests on undocumented format tolerance.

The cloud agent is out of scope for file placement: its MCP servers are
managed in repository settings per repository.

**Countermeasure requirement**: until microsoft/apm#2047 ships, plain
`apm install` in a project with MCP-bearing dependencies writes those
servers back into `~/.copilot/mcp-config.json`, silently violating the
user-global decision above. Any project using APM with MCP-bearing
dependencies must therefore prevent this write-back. Two verified building
blocks are `apm install --exclude copilot` (source-traced to affect MCP
integration only — skills, prompts and instructions deploy unchanged) and a
lifecycle `post-install`/`post-update` script converting `.vscode/mcp.json`
into the root `.mcp.json`. *How* the countermeasure is made durable
(task-runner recipe, wrapper script, alias, …) is left to each project.

### Consequences

* Good, because one committed `.mcp.json` gives project-scoped MCP to all
  three local GitHub agent surfaces, gated by their trust prompts.
* Good, because the global config stays empty and auditable, keeping
  unrelated sessions free of tool-definition overhead.
* Bad, because until microsoft/apm#2047 ships, the hand-authored
  `.mcp.json` duplicates what APM knows from the dependency graph and can
  drift from `apm.lock.yaml` on package updates.
* Bad, because workspace `.mcp.json`/`.github/mcp.json` are undocumented
  in official Copilot CLI and VS Code docs (changelog/source only) and
  could change with weaker notice than documented features.
* Bad, because a future cross-project server costs dual maintenance
  (`~/.copilot/mcp-config.json` + VS Code profile `mcp.json`) if it must
  reach VS Code.
* Bad, because the write-back countermeasure adds a per-project convention
  that anyone running plain `apm install` can accidentally bypass, and it
  becomes obsolete cleanup once microsoft/apm#2047 ships.

## More Information

Survey snapshot (ADR-0006 tier-2), covering both axes, all tools (CLI,
App, VS Code, cloud agent, APM) and upstream issues:
[2026-07-07-per-project-mcp-config.md](../research/2026-07-07-per-project-mcp-config.md).
Re-check microsoft/apm#2047 before hand-authoring new `.mcp.json` files;
once implemented, prefer `apm install` as the owner of the file.

Amended 2026-07-07 (same day as acceptance, before any dependent work): the
original decision covered only the per-project axis; extended to both axes
with the Copilot App included, at the decision-maker's direction. Amended
again later the same day to require a countermeasure against APM's global
MCP write-back (research snapshot §9), mechanism left per project.
