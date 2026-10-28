---
name: missing-tools
description: Triages CLI install requests and resolves one-shot needs without persistent mutation. Use on command-not-found errors, or when a request to install or run a tool does not say whether it is one-shot, per-project, or user-wide.
---

# Missing Tools

Use this workflow before searching arbitrary paths or installing anything.
This skill owns one-shot recovery and scope triage, not persistent tool state.

## Workflow

1. Re-check the current shell. Activation may have reset between commands.
2. Inspect authoritative project markers through
   `project-toolchain-selection` without changing them.
3. Classify the need. Default to one-shot when the request does not say
   otherwise, and name the recurring-tool option in the final report so a
   recurring dependency is not hidden behind an ephemeral command.
   - **one-shot**: continue here;
   - **recurring project tool**: hand off to the authoritative owner,
     `nix-project-toolchain` or `mise-project-toolchain`;
   - **explicit user-wide request**: hand off to `nix-user-tools` in Linux
     or WSL, or to `windows-user-tools` on native Windows.

## One-shot execution

First reuse the current authority:

```sh
direnv exec . <command>        # activated project environment
nix develop --command <command>
mise exec -- <command>
```

If the tool is not already provisioned, use an exact ephemeral version from a
trusted source compatible with the current authority, normally the newest
release the backend lists. Nix projects may use an
exact pinned flake/package reference; mise projects may use exact
`mise exec <tool>@<version> -- ...` resolution under their backend policy.
Do not add or edit project manifests for a one-shot request.

For npm tools, use an already committed exact dependency and lockfile after
`npm ci`. If none exists, Ask the user to approve adding a persistent project
dependency, presenting the package, an admitted exact version, and the
manifest change under the `mise-project-toolchain` supply-chain policy.

## Invariants

- No global install or user configuration change, because one-shot recovery
  leaves no state for later sessions to inherit. A download cache from an
  exact ephemeral run is not activated anywhere and is allowed.
- No project manifest, lockfile, task recipe, or package-output change,
  because persistent changes belong to the toolchain owners.
- No toolchain migration or Nix/mise normalization, because migration is
  explicit-only.
- No floating `latest`, floating `npx` download, unpinned download, registry
  bypass, or verification downgrade, because each defeats the supply-chain
  policy.
- No `/nix/store` paths in Win32 `PATH`, because native Windows tools would
  resolve Linux binaries; an existing Nix project on Windows continues
  inside WSL, a Dev Container, or wslc.

## Done when

- The requested command ran through the current authority or an exact
  ephemeral version, and its output was reported.
- `git status` shows no manifest, lockfile, or recipe change.

Use `nix-github-rate-limit` when an approved Nix one-shot may fetch from
GitHub.
