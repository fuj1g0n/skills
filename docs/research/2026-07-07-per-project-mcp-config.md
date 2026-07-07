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

## 5. User-global MCP config readable by both Copilot CLI and VS Code?

Surveyed same day (2026-07-07). **No such shared location exists natively.**

Global config per tool:

- Copilot CLI (user scope): `~/.copilot/mcp-config.json` only
  (`mcpServers` key). It reads no other global files.
- VS Code (user scope): profile-level `mcp.json` (**MCP: Open User
  Configuration**; `servers` key), plus opt-in discovery of *other tools'*
  global configs via `chat.mcp.discovery.enabled`.

VS Code's discovery adapters (microsoft/vscode main,
`common/discovery/nativeMcpDiscoveryAdapters.ts`) cover exactly three
global sources, all parsed as Claude-style `mcpServers` via
`claudeConfigToServerDefinition`:

| DiscoverySource | File (Linux) |
|---|---|
| `claude-desktop` | `$XDG_CONFIG_HOME/Claude/claude_desktop_config.json` |
| `windsurf` | `~/.codeium/windsurf/mcp_config.json` |
| `cursor-global` | `~/.cursor/mcp.json` |

There is **no adapter for `~/.copilot/mcp-config.json`** — VS Code cannot
discover Copilot CLI's global config, and Copilot CLI reads none of the
above. APM offers no bridge either: `apm install -g` deploys to
global-capable runtimes (Copilot CLI, Claude Code, ...) and explicitly
skips workspace-only runtimes including VS Code
(microsoft.github.io/apm/reference/cli/install/).

Workaround (hack, not adopted): both `~/.copilot/mcp-config.json` and
`claude_desktop_config.json` use the `mcpServers` schema, so symlinking
`~/.config/Claude/claude_desktop_config.json` →
`~/.copilot/mcp-config.json` and enabling the `claude-desktop` discovery
source would let VS Code mirror the CLI's global servers — mislabeled as
"Claude Desktop", conflicting if the real Claude Desktop is installed, and
dependent on undocumented format tolerance. Maintaining VS Code's own user
`mcp.json` in parallel (dual maintenance) is the honest alternative. Both
reinforce the project-root `.mcp.json` decision as the only true
single-file cross-tool location.

## 6. Upstream issues and discussions (surveyed 2026-07-07)

### github/copilot-cli (issue states verified via `gh issue view`)

| Issue | Title | State |
|---|---|---|
| #39 | Integration of MCP settings with VS Code | CLOSED 2026-02-25 |
| #54 | ...fully integrate and leverage features from VS Code Copilot Chat setup | CLOSED 2026-04-06 |
| #146 | Respect VS Code User Settings for Copilot CLI Configuration (e.g., mcp.json) | **OPEN** (backlog, no maintainer commitment) |
| #225 | Share MCP configuration with VSCode | CLOSED 2025-11-05 as dup of #39 (@ellismg: "duplicate of #39 (and related to #54)") |
| #3019 | Breaking Change: .vscode/mcp.json is no longer supported | **OPEN**, labels `area:configuration`, `area:mcp` |

Narrative: #39 was the canonical "share MCP config with VS Code" request;
it was answered by adding `.vscode/mcp.json` loading (v0.0.407,
2026-02-11) and closed 2026-02-25 — then v1.0.22 (2026-04-09) **removed**
that support in favor of `.mcp.json`, with no linked issue/PR stating the
rationale (changelog entry + migration hint only). #3019 captures the
fallout; late #39 comments show ongoing confusion (docs' "Migrating from
.vscode/mcp.json" section vs. earlier "we now load .vscode/mcp.json"
statements). A #3019 comment claims ".mcp.json (which VSCode doesn't
support)" — already outdated: VS Code gained root `.mcp.json` discovery
on 2026-04-23 (PR #312234, milestone 1.118), two weeks after the CLI's
switch. Convergence on root `.mcp.json` happened across the two tools
within a month, but is documented in neither product's docs.

User-global unification: no maintainer has committed to the CLI reading VS
Code's user-profile `mcp.json` (#146 open in backlog), nor addressed the
`mcpServers` vs `servers` root-key mismatch (also raised in
github.com/orgs/community/discussions/187954, unanswered). No request for
an XDG/`~/.mcp.json` cross-tool location exists in the tracker; the CLI
does honor `XDG_CONFIG_HOME` for its own directory (cf. github/docs#40682).

### microsoft/vscode

- No issue requests discovery of `~/.copilot/mcp-config.json` or Claude
  Code's `~/.claude.json` (searches: `"mcp-config.json"`, `"claude.json"
  mcp`, `label:feature-request mcp discovery` — zero matching).
- PR #312234 (workspace `.mcp.json` discovery) was a proactive addition by
  @connor4312 with **no linked issue** and no cross-tool-global discussion;
  the PR body frames it as "Claude-style format" for shareable workspace
  config.
- #248368 (closed 2025-05-16): @connor4312 confirms
  `chat.mcp.discovery.enabled` takes per-source booleans and that "VS
  Code's own configs are always discovered"; Copilot CLI is not among the
  sources.

### modelcontextprotocol

Discussion modelcontextprotocol#2218 (2026-02-06): community proposal for
a universal `mcp.json` + `mcpServers` standard across tools (its table
lists VS Code's `servers` key as the main divergence). 9 upvotes, no
maintainer response, no SEP; the MCP spec does not address client config
locations.

### Implication for this decision

Project-root `.mcp.json` is the only point of *de facto* convergence, and
it emerged from both vendors independently within weeks (CLI v1.0.22
2026-04-09; VS Code PR #312234 2026-04-23) without a shared standard
behind it. User-global unification has demand (#146, #3019,
community#187954) but no committed direction on either side.

## 7. GitHub Copilot App (desktop) and Copilot cloud agent

Surveyed same day (2026-07-07).

### Copilot App (desktop; GA 2026-06-17)

The GitHub Copilot app (macOS/Windows/Linux, gh.io/app; technical preview
at Build 2026, GA per github.blog changelog 2026-06-17) is built on the
same runtime as Copilot CLI and **has no MCP config surface of its own**.
Official customization docs
(docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app):

> "Any MCP servers configured for your repositories or Copilot CLI are
> automatically available in the GitHub Copilot app. You can also add and
> manage additional MCP servers in the app settings under **MCP Servers**."

— and the page delegates to the CLI's MCP docs. So the App inherits both
axes from the CLI: user-global `~/.copilot/mcp-config.json` and workspace
`.mcp.json` / `.github/mcp.json`. Whether the in-app "MCP Servers" GUI
writes to `~/.copilot/mcp-config.json` or an app-private store is not
documented (inferred: the shared file). Enterprise policy treats the App
under the "Copilot CLI" policy toggle; the MCP-management supported-surface
table does not list the App separately.

APM v0.23.1 has experimental `copilot-app`/`copilot-cowork` integration,
but it only syncs workflows/prompts into the App's SQLite/WS-IPC surface
(`integration/copilot_app_*.py`); it contains no MCP handling at all
(verified by source grep).

### Copilot cloud agent / code review (GitHub.com)

Configured **only** via repository Settings → Copilot → MCP servers
(JSON with `mcpServers` key entered in the UI; shared by cloud agent and
code review; GitHub + Playwright MCP enabled by default; secrets must be
prefixed `COPILOT_MCP_`; OAuth-based remote servers unsupported). It reads
no filesystem config — neither `.mcp.json` nor `~/.copilot/`.
Source: docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/configure-mcp-servers
(fetched directly 2026-07-07).

## 8. Full matrix: tool × scope (as of 2026-07-07)

| Tool | Per-project | User-global |
|---|---|---|
| Copilot CLI (≥1.0.61) | `.mcp.json` (root, priority over) `.github/mcp.json`; folder-trust gated | `~/.copilot/mcp-config.json` |
| Copilot App (GA 2026-06-17) | inherits CLI workspace files for connected repos | inherits `~/.copilot/mcp-config.json`; plus in-app Settings > MCP Servers GUI |
| VS Code | `.vscode/mcp.json` (documented) and root `.mcp.json` (discovery, since 1.118); trust-on-nonce | profile-level user `mcp.json` (`servers` key); discovery of Claude Desktop/Windsurf/Cursor only |
| Copilot cloud agent / code review | — (repository *settings*, not files) | — |
| APM copilot target (0.23.1) | writes `.vscode/mcp.json` only (until #2047: `.mcp.json`) | `apm install -g` → `~/.copilot/mcp-config.json` |

Cross-tool overlap per scope:

* **Per-project**: root `.mcp.json` is read by Copilot CLI, Copilot App
  (via CLI runtime), VS Code (discovery), and Claude Code — the single
  shared location.
* **User-global**: `~/.copilot/mcp-config.json` covers Copilot CLI *and*
  Copilot App, but VS Code cannot read it (section 5) and nothing covers
  VS Code + the GitHub tools together.
* Cloud agent stands alone (server-side settings UI).

## 9. Cross-cutting conclusion

A single project-root `.mcp.json` in Claude-style `{"mcpServers": {...}}`
format is readable by Copilot CLI (≥1.0.12), the Copilot App (via the CLI
runtime), VS Code (≥2026-04-23 stable), and Claude Code, is gated by
folder/workspace trust in the GitHub tools, and is the exact file APM's
accepted roadmap (#2047) will manage for the copilot target.
`.github/mcp.json` is Copilot-CLI/App-only and second in the loading
priority; `.vscode/mcp.json` is VS-Code-only and no longer read by Copilot
CLI (since v1.0.22). At user-global scope no location spans VS Code and
the GitHub CLI/App family; `~/.copilot/mcp-config.json` spans CLI + App
only. The cloud agent is configured exclusively in repository settings.
