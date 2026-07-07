# Per-project MCP configuration: Copilot CLI, VS Code, and APM (survey snapshot)

Date: 2026-07-07. Immutable research snapshot backing ADR-0009. Sources are
primary: product changelogs, upstream source code, official docs, and live
CLI verification on this machine (Copilot CLI 1.0.69, apm 0.23.1,
microsoft/vscode main).

## 1. GitHub Copilot CLI: MCP configuration sources

From `github/copilot-cli` changelog.md (verified at SHA `08e1930e`) and
`copilot mcp --help` (v1.0.69):

| Source | File | Since |
|---|---|---|
| User (global) | `~/.copilot/mcp-config.json` | early builds |
| Workspace | `.mcp.json` (project root) | ~v1.0.12 (2026-03-26); sole root-level source since v1.0.22 (2026-04-09), which removed `.vscode/mcp.json` and `devcontainer.json` as sources |
| Workspace | `.github/mcp.json` | v1.0.61 (2026-06-09) |
| Plugins | plugin-bundled servers | v0.0.389+ |
| Per-session | `--additional-mcp-config <json|@file>` (repeatable, later overrides earlier) | v0.0.343 (2025-10-16) |

Key changelog entries:

- v0.0.401: "Support Claude-style .mcp.json format without mcpServers wrapper"
- v1.0.10 (2026-03-20): workspace MCP servers "loaded only after folder
  trust is confirmed" — the folder-trust dialog is the only security gate;
  there is no per-server approval prompt.
- v1.0.22: ".vscode/mcp.json and .devcontainer/devcontainer.json removed as
  MCP config sources; CLI now only reads .mcp.json" (migration hint shown).
- v1.0.61: "Auto-load MCP servers from .github/mcp.json workspace config file"

Documentation gap: the official docs page
(docs.github.com .../copilot-cli/customize-copilot/add-mcp-servers) documents
only `~/.copilot/mcp-config.json` and `/mcp add` / `copilot mcp add` (both
write user scope). Workspace files are changelog-documented only. The
loading-priority reference exists at
docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#mcp-server-loading-priority.

Live verification (this machine, 1.0.69): a `.github/mcp.json` and a root
`.mcp.json` with `{"mcpServers": {...}}` schema were each loaded and listed
by `copilot mcp list` as "Workspace servers"; `copilot mcp get` reports
`Source: Workspace (<path>/.mcp.json)`.

## 2. VS Code: does it read root `.mcp.json`?

Yes — confirmed in microsoft/vscode source (main):

- `src/vs/workbench/contrib/mcp/common/discovery/workspaceDotMcpDiscovery.ts`:
  "Discovers MCP servers defined in `.mcp.json` files at workspace folder
  roots. Uses the Claude-style format: `{ "mcpServers": { ... } }`."
- Registered unconditionally in `mcp.contribution.ts` — not gated by
  `chat.mcp.discovery.enabled` (that setting's `DiscoverySource` enum covers
  only claude-desktop, windsurf, cursor-global, cursor-workspace).
- File is watched; changes are picked up automatically.
- `trustBehavior: McpServerTrust.Kind.TrustedOnNonce` — user confirmation
  required on first load and on config change.
- Introduced by commit `20cf0c72`, PR microsoft/vscode#312234 ("mcp: add
  .mcp.json workspace discovery and server collision handling"), merged
  2026-04-23.

Documentation gap: official VS Code docs
(code.visualstudio.com/docs/agent-customization/mcp-servers and
/docs/agents/reference/mcp-configuration) document only `.vscode/mcp.json`
(workspace, `servers` key) and profile-level `mcp.json`.

## 3. APM: MCP config placement per runtime (v0.23.1/v0.24.0)

From https://microsoft.github.io/apm/consumer/install-mcp-servers/ and apm
0.23.1 source (`adapters/client/*.py`):

| Runtime | File written | Scope |
|---|---|---|
| GitHub Copilot CLI (`copilot.py`) | `~/.copilot/mcp-config.json` (hardcoded `Path.home()`) | global only |
| VS Code Copilot (`vscode.py`) | `.vscode/mcp.json` (`servers` key) | project |
| Claude Code (`claude.py`) | `.mcp.json` (project) or `~/.claude.json` (`-g`) | both |
| Cursor | `.cursor/mcp.json` | project |
| JetBrains Copilot (`intellij.py`) | `~/.local/share/github-copilot/intellij/mcp.json` | global |

MCP trust model (`integration/mcp_integrator.py`, docs
microsoft.github.io/apm/reference/cli/install/):

- Self-defined MCP servers (`registry: false`) from **direct** dependencies
  (depth 1) are auto-trusted and installed.
- From **transitive** dependencies (depth > 1) they are skipped with a
  warning unless `--trust-transitive-mcp` is passed or the server is
  re-declared in the root `apm.yml` (root overlays take precedence).
- The `mcp.trust_transitive` policy YAML field is parsed but **not
  enforced** (documented known gap); `mcp.self_defined` (deny|warn|allow)
  IS enforced.

Observed in what-number (fuj1g0n-demo-01): `microsoft/azure-skills` (type:
hybrid, direct dep) self-defines the `azure` server; `apm install` recorded
it in `apm.lock.yaml` (`mcp_servers: [azure]`) and generated
`.vscode/mcp.json` (untracked; mtime matches lock `generated_at` within
seconds). `~/.copilot/mcp-config.json` was not touched at project scope —
Copilot CLI saw no server.

## 4. APM upstream stance: microsoft/apm issue #2047

https://github.com/microsoft/apm/issues/2047 — "[FEATURE] Support
workspace-level (.mcp.json) and global (-g) MCP configurations for Copilot
CLI". Filed 2026-07-06 (day after v0.24.0); labels `status/accepted`,
`type/feature`, `area/mcp-config`, `area/mcp-trust`.

Accepted scope (automated triage comment, 2026-07-06; "silence = approval"
policy, no human override at survey time):

1. Write path (`CopilotClientAdapter`): default to **project-root
   `.mcp.json`**; write `~/.copilot/mcp-config.json` only with `-g`.
2. Read path: implement the official priority `.mcp.json` →
   `.github/mcp.json` → `~/.copilot/mcp-config.json`; handle the
   `mcpServers` root key alongside APM's existing `servers` key.
3. Security constraint for the implementing PR: only load project-local
   `.mcp.json` placed by APM (APM-managed package graph), not from arbitrary
   cloned repos.

Status at survey time: no milestone, no implementing PR; unimplemented in
v0.24.0 and main.

## 5. Cross-cutting conclusion

A single project-root `.mcp.json` in Claude-style `{"mcpServers": {...}}`
format is readable by Copilot CLI (≥1.0.12), VS Code (≥2026-04-23 stable),
and Claude Code, is gated by folder/workspace trust in both GitHub tools,
and is the exact file APM's accepted roadmap (#2047) will manage for the
copilot target. `.github/mcp.json` is Copilot-CLI-only and second in the
loading priority; `.vscode/mcp.json` is VS-Code-only and no longer read by
Copilot CLI (since v1.0.22).
