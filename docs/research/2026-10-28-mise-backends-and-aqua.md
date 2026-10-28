---
type: Research Snapshot
---

# mise backends: "mise" versus "mise+Aqua"

Point-in-time snapshot, 2026-10-28. Supports the backend order in
`mise-project-toolchain` and the decision to call the project toolchain
"mise" rather than "mise+Aqua". Primary sources only, fetched on the
snapshot date. This file is immutable; a re-survey is a new file.

## Question

The 2026-08-08 Windows tool-management study chose `aqua:casey/just`
because the aqua registry carries release-asset selection and checksum
metadata, and it kept Aqua as a mise backend rather than a separate
manager. The skills then named the toolchain "mise+Aqua". Is that
distinction still meaningful for the main use cases: native Windows plus
Linux or WSL projects that pin standalone CLIs (just, gh, jq, shellcheck,
ripgrep), language runtimes, and npm-distributed CLIs under a corporate
seven-day release-age gate?

## Sources

- mise, [Backends](https://mise.jdx.dev/dev-tools/backends/)
- mise, [aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html)
- mise, [github backend](https://mise.jdx.dev/dev-tools/backends/github.html)
- mise, [asdf backend](https://mise.jdx.dev/dev-tools/backends/asdf.html),
  [vfox backend](https://mise.jdx.dev/dev-tools/backends/vfox.html),
  [ubi backend](https://mise.jdx.dev/dev-tools/backends/ubi.html)
- mise, [Registry](https://mise.jdx.dev/registry.html) and
  [registry contribution tiers](https://mise.jdx.dev/contributing/registry.html)
- mise, [Settings](https://mise.jdx.dev/configuration/settings.html)
- mise, [mise.lock](https://mise.jdx.dev/dev-tools/mise-lock.html) and
  [mise.lock reference](https://mise.jdx.dev/dev-tools/mise-lock-reference.html)
- jdx/mise registry entries:
  [just](https://raw.githubusercontent.com/jdx/mise/main/registry/just.toml),
  [jq](https://raw.githubusercontent.com/jdx/mise/main/registry/jq.toml),
  [ripgrep](https://raw.githubusercontent.com/jdx/mise/main/registry/ripgrep.toml),
  [shellcheck](https://raw.githubusercontent.com/jdx/mise/main/registry/shellcheck.toml),
  [github-cli](https://raw.githubusercontent.com/jdx/mise/main/registry/github-cli.toml),
  [node](https://raw.githubusercontent.com/jdx/mise/main/registry/node.toml)

## Findings

### Short names already resolve to aqua

- Registry entries list backends in order. `just` is
  `["aqua:casey/just", "asdf:olofvndrhr/asdf-just", "cargo:just"]`; `jq`,
  `ripgrep`, `shellcheck`, and `gh` also list `aqua:` first. Runtimes such
  as node, python, and go list only `core:`.
- For a short name, mise uses the first registry backend that runs on the
  platform, is not disabled, and supports the requested version, unless an
  environment override, `[tool_alias]`, plugin, `mise.lock` entry, or
  installed plugin decides first. `mise tool <tool> --backend` shows the
  result.
- So `mise use just` already installs through the aqua backend. "mise
  alone" and "mise+Aqua" are the same configuration for these tools.

### The aqua backend needs no aqua tooling

- mise reads the aqua registry recipes itself and implements checksum,
  GitHub artifact attestation, Cosign, SLSA, and Minisign verification;
  neither the aqua CLI nor the signing CLIs are required. Which checks run
  depends on each recipe.
- The aqua verification settings (`aqua.cosign`, `aqua.github_attestations`,
  `aqua.minisign`, `aqua.slsa`) default to on.
- No mise documentation recommends installing the aqua CLI or adding
  `aqua.yaml` beside mise.

### Backend order in mise's own guidance

When choosing a backend explicitly, the Backends page orders:

1. `packslip:` when the publisher signs releases with packslip manifests;
2. `aqua:`, or `github:`, `gitlab:`, `forgejo:` for forge release assets;
3. `http:` or `s3:` for self-hosted archives;
4. a language package backend when the tool ships only as a package;
5. a plugin only when installation needs custom logic.

The registry contribution policy accepts `packslip` first, `aqua`, `github`,
and `gitlab` routinely, language package backends only with a high bar, and
never `asdf`, `vfox`, or `ubi` for new entries.

### Backends to avoid

- `asdf:` is legacy, runs shell-script plugins with the user's permissions,
  and does not run on native Windows; mise skips it there and moves to the
  next registry backend.
- `vfox:` runs on Windows but executes plugin Lua code that may run
  external commands.
- `ubi:` is deprecated, warns on use, and is removed in mise 2027.1.0;
  `github:` replaces it.
- A registry fallback can reach `asdf:` on Linux when the aqua entry does
  not cover the requested version, so the resolved backend must be checked.

### Lock data and Windows

- `mise.lock` records download URLs and checksums where the backend
  provides them; release backends such as aqua, github, and packslip can
  also record the signer. `core:` entries record URL and checksum.
- With `lockfile_platforms` unset, a new lockfile resolves Linux, macOS,
  and `windows-x64` targets plus the current platform, so one lock can
  cover Windows and Linux or WSL for release backends.
- Backends that do not lock URLs, such as cargo, go, gem, and asdf, record
  only the version.

### Release age

`minimum_release_age` (default `24h`) holds back newly published versions
for every backend that knows release dates, and the npm and pypi backends
pass the cutoff to transitive resolution. It filters only version requests
such as `node@22` or `latest`; exact versions and versions recorded in
`mise.lock` are not filtered. It may complement, but does not replace, the
corporate registry, which remains authoritative for npm admission.

## Conclusion

The aqua choice from 2026-08-08 still holds, but it is the mise registry
default rather than a separate component. Name the toolchain "mise" and
state a backend order: `core:` for runtimes, then `packslip:`, `aqua:`,
`github:`/`gitlab:`, and language package backends only for package-only
tools. Forbid `asdf:`, `vfox:`, and `ubi:`, and check the resolved backend
of short names.
