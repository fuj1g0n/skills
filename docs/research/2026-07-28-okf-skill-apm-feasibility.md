---
type: Research Snapshot
generated:
  by: github-copilot-cli/claude-fable-5
  at: "2026-07-28T12:40:00Z"
---

# Survey: OKF skills via APM — feasibility and policy fit

Point-in-time snapshot, 2026-07-28. Supports
[ADR-0018](../adr/0018-integrate-okf-conventions-instead-of-okf-skill.md).
Two research passes (OKF skill/tooling deep-dive; APM dependency mechanics
with live install verification on this machine) plus a local empirical run
of the upstream validator against this repository's `docs/` bundle.
Companions:
[2026-07-28-documentation-formats-landscape.md](2026-07-28-documentation-formats-landscape.md)
(OKF spec), [2026-07-28-documentation-skill-ecosystem.md](2026-07-28-documentation-skill-ecosystem.md)
(first-pass skill survey). This file is immutable; a re-survey is a new
file (per ADR-0006).

## 1. scaccogatto/okf-skills (deep dive)

MIT, 110 stars, 3 contributors (28 commits), created 2026-06-14, last push
2026-07-27. Distribution: Claude Code plugin (`.claude-plugin/plugin.json`
v0.6.0) + skills.sh (`npx skills add`). **No `apm.yml`.** Release tags
follow APM's marketplace pattern `okf--vX.Y.Z`; during this survey the
latest tag moved to `okf--v0.4.0` — multiple releases per week.

Three skills, all with trigger-focused descriptions, procedural bodies,
and sizes within skill-authoring limits:

| Skill | Size | Writes? | Content |
|---|---|---|---|
| `okf` | ~100 lines + vendored SPEC.md (37,952 B, v0.2 @ `3fcbb9f`) + `okf_init.py` + templates | yes | produce/maintain/consume modes; reads vendored spec before non-trivial work |
| `validate` | ~55 lines + `okf_validate.py` (565 lines, deterministic §11 checker, `--strict`, `--json`, `--migrate` v0.1→v0.2) | no (except `--migrate`) | run checker, fix ERRORs; warnings never block |
| `visualize` | ~43 lines + `okf_visualize.py` | viz.html only | bundle → interactive HTML graph |

The repo also ships a composite GitHub Action (`action.yml`: inputs
`bundle`, `strict`, `max-warnings`; runs the same validator via
`astral-sh/setup-uv@v5` — note the **floating inner tag** inside the
otherwise pinnable composite; inputs pass through env, not `${{ }}`
interpolation, with an explicit injection-hardening comment).

**Policy conflict (authoring skill).** `skills/okf/SKILL.md` instructs,
verbatim:

> 5. Add/refresh `index.md` per directory (and `okf_version: "0.2"` in the
>    root index). Append a dated entry to `log.md`. (produce mode)

> 3. Update the relevant `index.md` files and append a dated `log.md`
>    entry describing what changed. (maintain mode)

Both steps are unconditional and directly contradict ADR-0017's policy
(reserved files not used beyond the root marker; git is the log). No MADR
awareness anywhere — lifecycle guidance uses OKF `draft|stable|deprecated`
only. The description triggers on "any work in a repo that has an OKF
bundle", i.e. it would fire permanently inside this repository.

**`validate` has no policy conflict**: absence of per-directory indexes
and unknown `status` values are warnings, not errors (verified in source:
`report.warn` for §5.4 unknown status, §8 index frontmatter; `RESERVED`
handling matches spec).

`apm audit` on a test install reports 3 warning-severity hidden-character
findings (U+FEFF mid-file) in the `okf` and `visualize` scripts.

## 2. serradura/okf-gem

Apache-2.0, 111 stars, single author (282 commits in 47 days), gem
v1.12.0 (2026-07-24). Rich Ruby CLI (validate/lint/search/server/render) +
1 SKILL.md + 9 playbooks. **Vendored spec is v0.1 — Draft** (`ee67a5c`);
playbooks still use `timestamp` (v0.1 field) and scaffold
`okf_version: "0.1"` root indexes; conformance references §9 (v0.1
numbering). Same unconditional index/log maintenance instructions as
above, plus the version mismatch. No public issue/PR tracking a v0.2
upgrade. Disqualified for a v0.2 bundle as of this snapshot.

## 3. Spec-side facts (GoogleCloudPlatform/knowledge-catalog)

- Ships **no agent skills or authoring guidance** — spec + example
  bundles only; its reference agent is explicitly a proof of concept.
- §8: "An `index.md` file **MAY** appear in any directory"; "consumers
  MAY synthesize one on the fly when none is present". §9: `log.md`
  "MAY appear". §11: consumers MUST NOT reject a bundle for missing
  optional fields, unknown `type`, unknown keys, broken links, or
  **missing `index.md` files**. This repository's no-index/no-log policy
  is squarely inside the spec.
- Stability: §12 defines minor = backward-compatible, but §13 admits
  v0.2 was "a minor version bump except for two deliberate breaking
  changes". Two spec commits on 2026-07-24 alone; churn risk from
  ADR-0017 remains real.

## 4. Other tooling (scan)

- **okforge** (npm, MIT, v1.0.12, ~1.9k dl/mo): Claude Code SKILL.md
  installer; scaffold mode creates `index.md` + `log.md`. GitHub repo
  404 (source not auditable) — disqualifying for adoption.
- **pumblus/okf-harness** (`@okf-harness/*`, Apache-2.0, 26 stars):
  agent-first harness; guidance in CONTEXT.md/AGENTS.md, **no SKILL.md
  found** in the public tree.
- **@docmd/plugin-okf** (MIT, 7.9k dl/mo): site-generator plugin that
  emits OKF bundles; not an agent skill.
- **PyPI `okf`** v0.1.0: 1.5 KB placeholder, no code. (Unrelated to the
  Ruby gem; both unrelated to the Open Knowledge Foundation.)

## 5. APM mechanics (verified with live installs, apm 0.23.1)

- `dependencies.apm` entries do **not** require an upstream `apm.yml`:
  APM probes the path — `SKILL.md` directory installs as a virtual
  `claude_skill`; a repo root with `.claude-plugin/` classifies as
  `marketplace_plugin`. Verified:
  `scaccogatto/okf-skills/skills/okf#<40-sha>` installs cleanly; the
  whole subtree (SKILL.md, vendored SPEC.md, Apache-2.0 notice, scripts,
  templates) is **copied** to `~/.agents/skills/okf/` (no symlinks);
  lockfile records deployed files + sha256 content hash.
- **Re-export works with non-APM upstreams**: a test APM package
  declaring the subdir dependency delivered the upstream skill
  transitively to a consumer (`apm deps tree` shows the chain). The
  ADR-0002 pattern would be a one-line, SHA-pinned addition.
- Failure modes: upstream path restructure fails **loudly** but only on
  cold-cache/refresh/update; locked SHAs replay offline. Tags are
  mutable; full 40-char SHA remains the only immutable pin. `apm update`
  can move SHA pins to the latest `{name}--v{semver}` tag.
- Governance: `apm audit` covers hidden Unicode + source↔deploy drift,
  not semantic changes; no license gate; skill payload scripts deploy as
  inert files outside APM's executable-trust prompt.

## 6. Empirical validation of this repository's bundle

`okf_validate.py` (upstream @ `4477dd4`) against `docs/`:
**`✓ conformant` — 0 errors, 115 warnings.** Warning composition: §4.1
recommended fields absent (`title`, `description`, `tags`) and §5.2
`generated` absent on pre-migration files; §5.4 "unknown `status`" for
every MADR status value. All are the documented ADR-0017 deviations;
none block, including under the composite Action's default (non-strict)
mode. `--strict` would fail the bundle by design — unusable here.

## 7. Fit summary

| Candidate | Spec version | APM-installable | Policy fit |
|---|---|---|---|
| scaccogatto `okf` (authoring) | v0.2 | yes (verified) | **conflicts**: unconditional index/log upkeep, OKF-only status, always-on trigger here |
| scaccogatto `validate` | v0.2 | yes (same repo) | clean (warnings tolerate deviations); but need is CI-shaped, not conversational |
| scaccogatto `visualize` | v0.2 | yes | clean; no recurring need |
| serradura gem/skill | **v0.1** | no (gem/plugin) | conflicts + version mismatch |
| okforge / okf-harness / PyPI okf | n/a | no | source unauditable / no SKILL.md / placeholder |

## Gaps

- okforge SKILL.md text unverifiable (repo 404); conflict pattern
  inferred from npm README only.
- serradura v0.2 upgrade timing unknown (active author, no public
  tracker).
- knowledge-catalog star count not retrieved (unauthenticated API).
- Whether a skills.sh package can wrap as an APM dependency untested
  (moot — direct subdir dependency verified).
