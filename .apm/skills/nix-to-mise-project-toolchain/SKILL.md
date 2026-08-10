---
name: nix-to-mise-project-toolchain
description: Performs explicit full-cutover Nix-to-mise project migrations. Invoke only when the user authorizes migration; block when Nix package outputs remain or replacement is not separately approved.
---

# Nix-to-mise Project Toolchain Migration

Migration is a complete cutover between project development authorities.
Persistent mixed Nix and mise development toolchains are forbidden.

## Entry gates

- Require an explicit user request or approval to migrate. Windows
  participation alone is not consent.
- Inspect authoritative Nix package outputs using
  `project-toolchain-selection`. If any exist, stop. Continue only after a
  separate authorized plan removes or replaces all package outputs.
- Do not propose or retain a package-output-only flake beside mise.
- Freeze task recipe and language dependency changes unless separately
  authorized; their existing files survive the toolchain transaction.

## Transaction

Read [references/cutover-transaction.md](references/cutover-transaction.md),
then execute: assess, obtain consent, plan, build a candidate, validate, cut
over and remove the old development toolchain, verify the clean authority,
and retain a rollback path.

The candidate may temporarily represent both systems only in an isolated
branch or worktree during comparison. Do not commit or merge a state where
both are project development sources of truth.

At cutover, remove Nix development markers such as `devShells`, development
`shell.nix`, `use flake` activation, and development-only Nix CI/editor hooks.
Do not remove ambiguous Nix files until package-output and release ownership
has been conclusively ruled out.

Install and pin task runners as tools in mise, but do not translate recipes
into mise `[tasks]` or edit task orchestration. Preserve language-local
managers and locks unless a separate dependency migration was approved.
