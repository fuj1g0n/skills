# Skill and MCP configuration across AI coding agents (survey snapshot)

Date: 2026-07-07. Immutable research snapshot (ADR-0006 tier 2).
Companion to [2026-07-07-per-project-mcp-config.md](2026-07-07-per-project-mcp-config.md),
which covers the GitHub Copilot family in depth; this snapshot extends the
survey beyond the Copilot family to the wider agent ecosystem, on the same
two axes (user-global / project) for two artifact types (Agent Skills /
MCP servers). All claims below were verified against primary sources
(official docs, vendor doc sites, upstream repos, APM source code); vendor
doc URLs were fetched directly on 2026-07-07.

## 1. The Agent Skills standard and its directory conventions

* The spec lives at <https://agentskills.io/specification> (GitHub org
  `agentskills`, not Anthropic); Anthropic's `anthropics/skills` repo is an
  example/production skill collection whose `spec/agent-skills-spec.md`
  redirects to agentskills.io.
* **The spec itself does not mandate installation directories** — it only
  defines what goes *inside* a skill directory (SKILL.md + optional
  scripts/references/assets).
* The client-implementation guide
  (agentskills.io/client-implementation/adding-skills-support.md)
  recommends, as a non-normative convention:
  * client-specific: `<project>/.<client>/skills/`, `~/.<client>/skills/`
  * cross-client interop: `<project>/.agents/skills/`, `~/.agents/skills/`
  > "The `.agents/skills/` paths have emerged as a widely-adopted
  > convention for cross-client skill sharing."

## 2. Skills: tool × scope (verified 2026-07-07)

| Tool | Skills project | Skills user-global | Reads cross-tool `.agents/skills/`? |
|---|---|---|---|
| GitHub Copilot (CLI/App/cloud agent/code review/VS Code/JetBrains agent mode) | `.github/skills`, `.claude/skills`, `.agents/skills` | `~/.copilot/skills`, `~/.agents/skills` | **Yes** (both scopes) |
| Claude Code | `.claude/skills/` (also nested + parent dirs up to repo root) | `~/.claude/skills/` (+ enterprise managed, plugins) | **No** — zero hits in docs and anthropics/claude-code |
| Claude Desktop / claude.ai | — (zip upload via Settings > Features, per-user) | same | No (not filesystem-based) |
| OpenAI Codex CLI/IDE/app | `.agents/skills` scanned from CWD up to repo root | `~/.agents/skills` (+ `/etc/codex/skills` ADMIN, SYSTEM bundled) | **Yes** (its only layout) |
| Cursor | `.agents/skills/`, `.cursor/skills/` (recursive) | `~/.agents/skills/`, `~/.cursor/skills/` | **Yes**; also compat-reads `.claude/skills/`, `.codex/skills/` both scopes |
| Gemini CLI | `.gemini/skills/` or `.agents/skills/` alias | `~/.gemini/skills/` or `~/.agents/skills/` alias | **Yes** (alias wins over `.gemini/skills/` within a tier) |
| Windsurf / Devin Desktop | `.windsurf/skills/` | `~/.codeium/windsurf/skills/` | **Yes** (`.agents/skills/`, `~/.agents/skills/`; optionally `.claude/skills/`) |
| OpenCode | `.opencode/skills/` (walk-up to git worktree) | `~/.config/opencode/skills/` | **Yes**; also `.claude/skills/` compat, both scopes |
| Kiro | `.kiro/skills/` | `~/.kiro/skills/` | No (own dirs only; standard-compliant format) |
| Cline | `.cline/skills/` | `~/.cline/skills/` | No |
| Zed, Roo Code, Amazon Q CLI, goose | no SKILL.md mechanism (rules/steering/hints only) | — | — |

Sources: docs.github.com about-agent-skills; code.claude.com/docs/en/skills;
developers.openai.com/codex/skills; cursor.com/docs/skills;
geminicli.com/docs/cli/skills; docs.devin.ai/desktop/cascade/skills;
opencode.ai/docs/skills; kiro.dev/docs/skills; cline/cline
docs/getting-started/config.mdx.

**Precedence patterns**: workspace/project overrides user in Kiro and
Gemini (higher tier wins); Claude Code inverts this (enterprise > personal
> project); Codex does not merge same-name skills (both listed).

**Finding**: `.agents/skills/` (project + user) is now the de-facto
cross-vendor standard, adopted by GitHub Copilot, Codex, Cursor, Gemini
CLI, OpenCode and Windsurf/Devin. The notable holdouts are Claude Code
itself (`.claude/skills/` only — though most other tools compat-read that
path) and Kiro/Cline (own directories, standard file format).

## 3. MCP: tool × scope (verified 2026-07-07)

| Tool | MCP project | MCP user-global | Key/format |
|---|---|---|---|
| Copilot CLI/App | `.mcp.json` (root), `.github/mcp.json` | `~/.copilot/mcp-config.json` | `mcpServers` |
| VS Code | `.vscode/mcp.json` (`servers`), root `.mcp.json` (discovery) | profile `mcp.json` | mixed |
| Claude Code | `.mcp.json` (root; `--scope project`) | `~/.claude.json` (user + local scopes; + `managed-mcp.json` enterprise) | `mcpServers`; precedence local > project > user; project servers approval-gated (`claude mcp reset-project-choices`) |
| Claude Desktop | — none | `claude_desktop_config.json` (`~/Library/Application Support/Claude/` / `%APPDATA%\Claude\`) | `mcpServers` |
| Codex CLI | `.codex/config.toml` `[mcp_servers]` | `~/.codex/config.toml` `[mcp_servers]` | TOML |
| Gemini CLI | `.gemini/settings.json` | `~/.gemini/settings.json` (+ `/etc/gemini-cli/` system layers) | `mcpServers` |
| Cursor | `.cursor/mcp.json` | `~/.cursor/mcp.json` | `mcpServers` |
| Windsurf/Devin | — none documented | `~/.codeium/windsurf/mcp_config.json` | `mcpServers` |
| OpenCode | `opencode.json` root | `~/.config/opencode/opencode.json` | `mcp` key, own schema |
| Kiro | `.kiro/settings/mcp.json` | `~/.kiro/settings/mcp.json` | `mcpServers`; workspace wins on merge |
| Zed | `.zed/settings.json` | `~/.config/zed/settings.json` | `context_servers` key |
| Cline | `.cline/` (CLI); none for VS Code ext | `~/.cline/data/settings/cline_mcp_settings.json` (CLI) / VS Code globalStorage (ext) | own |
| Roo Code | `.roo/mcp.json` | VS Code globalStorage `mcp_settings.json` | `mcpServers`; project wins |
| Amazon Q CLI | `.amazonq/mcp.json` (legacy, `useLegacyMcpJson`) | `~/.aws/amazonq/mcp.json` (legacy) / `~/.aws/amazonq/cli-agents/*.json` (new agent format) | `mcpServers` |
| goose | — none (`.goosehints`/`AGENT.md` instructions only) | `~/.config/goose/config.yaml` `extensions` | YAML |

**Finding**: unlike skills, **MCP has no cross-vendor config location**.
Root `.mcp.json` is read only by the Claude Code family, Copilot CLI/App,
and VS Code (discovery); every other tool uses its own file. Most tools do
converge on the `{"mcpServers": ...}` *schema* inside their own files, and
almost all now offer both scopes (exceptions: Windsurf/Devin and goose —
user-global only; Claude Desktop — user-global only).

## 4. APM's implementation of both axes (apm 0.23.1 source, verified locally)

`apm_cli/integration/targets.py` (`KNOWN_TARGETS`) and
`apm_cli/adapters/client/*.py`:

* **Skills**: every target uses `format_id="skill_standard"` (SKILL.md).
  copilot, cursor, codex, gemini, windsurf, opencode deploy with
  `deploy_root=".agents"` → project `.agents/skills/`; claude → `.claude/skills/`;
  kiro → `.kiro/skills/`; the explicit `agent-skills` target → `.agents/skills/`
  (project) / `~/.agents/skills/` (user). This matches the vendor adoption
  matrix in §2 — APM already treats `.agents/skills/` as the convergence
  point and keeps claude/kiro on their native dirs.
* **MCP adapters**: claude → project `.mcp.json` / user `~/.claude.json`
  (claude.py:141,144 — the claude adapter already supports the project
  axis); cursor → `.cursor/mcp.json`; kiro → `.kiro/settings/mcp.json` both
  scopes; gemini → `.gemini/settings.json` both scopes; codex →
  `.codex/config.toml` both scopes; opencode → project `opencode.json`;
  windsurf → `~/.codeium/windsurf/mcp_config.json` (global only, matching
  the tool); vscode → `.vscode/mcp.json`; **copilot → user-global
  `~/.copilot/mcp-config.json` only** (copilot.py:106-113) — the sole
  adapter lagging its tool's project-axis support (microsoft/apm#2047).

## 5. Cross-cutting conclusion

The two artifact types are converging at different speeds and in opposite
directions:

* **Skills**: strong convergence on the Agent Skills open standard *and*
  on the `.agents/skills/` + `~/.agents/skills/` directory pair. A skill
  placed there reaches GitHub Copilot, Codex, Cursor, Gemini CLI, OpenCode
  and Windsurf/Devin on both axes; only Claude Code (`.claude/skills/`)
  and Kiro/Cline need their native paths — and most adopters compat-read
  `.claude/skills/` too.
* **MCP**: schema convergence (`mcpServers`) without location convergence.
  Per project, root `.mcp.json` covers only the Claude/Copilot/VS Code
  cluster; user-global has no shared location at all. Multi-tool MCP setup
  therefore requires a generator/manager (APM's per-adapter model is the
  right architecture; its copilot adapter's missing project axis is the
  one gap, tracked in #2047).

This asymmetry means: distribute *skills* as the portable unit
(`.agents/skills/`), and treat *MCP config* as a per-tool render target.

## 6. Corrections against secondary reporting

A research pass based on older doc snapshots claimed Codex, Cursor, Gemini
CLI and OpenCode had "no native skills mechanism". Direct fetches of the
current official docs (URLs in §2) disprove this — all four now document
first-class Agent Skills support including the `.agents/skills/` paths.
Skills support in these tools is recent; treat any pre-2026 secondary
source on this topic as stale.
