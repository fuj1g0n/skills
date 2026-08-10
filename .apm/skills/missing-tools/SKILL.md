---
name: missing-tools
description: Resolves a missing CLI for one-shot use without persistent mutation. Use on command-not-found errors; route recurring or user-wide needs to the existing authoritative owner.
---

# Missing Tools

Use this workflow before searching arbitrary paths or installing anything.
This skill owns one-shot recovery and scope triage, not persistent tool state.

## Workflow

1. Re-check the current shell. Activation may have reset between commands.
2. Inspect authoritative project markers through
   `project-toolchain-selection` without changing them.
3. Classify the need:
   - **one-shot**: continue here;
   - **recurring project tool**: hand off to the existing
     `nix-project-toolchain` or `mise-project-toolchain` owner;
   - **user-wide tool**: require an explicit global request, then hand off to
     `nix-user-tools` or `mise-user-tools`.
4. Ask when duration or scope is unclear. Do not hide a recurring dependency
   behind an ephemeral command.

## One-shot execution

First reuse the current authority:

```sh
direnv exec . <command>        # activated project environment
nix develop --command <command>
mise exec -- <command>
```

If the tool is not already provisioned, use an exact ephemeral version from a
trusted source compatible with the current authority. Nix projects may use an
exact pinned flake/package reference; mise projects may use exact
`mise exec <tool>@<version> -- ...` resolution under their backend policy.
Do not add or edit project manifests for a one-shot request.

For npm tools, never download through floating `npx`. Use an already committed
exact dependency and lockfile after `npm ci`; if none exists, stop and ask
whether the user wants a persistent project dependency through the normal
Node workflow and `mise-project-toolchain` supply-chain policy.

## Prohibitions

- No global install or user configuration mutation.
- No project manifest, lockfile, task recipe, or package-output mutation.
- No toolchain migration or Nix/mise normalization.
- No floating `latest`, unpinned downloads, registry bypass, or verification
  downgrade.
- No `/nix/store` paths in Win32 `PATH`; an existing Nix project on Windows
  continues inside WSL, a Dev Container, or wslc.

Use `nix-github-rate-limit` when an approved Nix one-shot may fetch from
GitHub.
