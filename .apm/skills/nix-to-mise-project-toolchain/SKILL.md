---
name: nix-to-mise-project-toolchain
description: Performs explicit full-cutover Nix-to-mise project migrations. Use when the user explicitly asks to migrate a project's development toolchain from Nix to mise+Aqua.
---

# Nix-to-mise Project Toolchain Migration

Migration is a complete cutover between project development authorities.

## Entry gates

- The user's explicit migration request is the precondition. Windows
  participation alone is not a request; without one, hand off to
  `project-toolchain-selection`.
- Inspect authoritative Nix package outputs using the marker rules in
  `project-toolchain-selection`. If any exist, Block: report them and end
  without changes; a separate authorized plan must remove or replace them
  first.
- Leave task recipes and language dependencies unchanged unless separately
  authorized; their existing files survive the toolchain transaction.

## Transaction

Read [references/cutover-transaction.md](references/cutover-transaction.md),
then execute: assess, plan, build and validate a candidate, Ask for cutover
approval, cut over and remove the old development toolchain, and retain a
rollback path. Keep the transaction steps as a task list and work through
them without pausing between steps; the cutover Ask is the only pause.

The candidate may temporarily represent both systems only in an isolated
branch or worktree during comparison.

At cutover, remove Nix development markers such as `devShells`, development
`shell.nix`, `use flake` activation, and development-only Nix CI/editor hooks.
Do not remove ambiguous Nix files until package-output and release ownership
has been conclusively ruled out.

Install and pin task runners as tools in mise, but do not translate recipes
into mise `[tasks]` or edit task orchestration. Preserve language-local
managers and locks unless a separate dependency migration was approved.

## Invariants

- No committed or merged state where Nix and mise are both project
  development sources of truth, because mixed authorities have no single
  owner.
- No package-output-only flake beside mise, because the outputs need Nix as
  the development authority.

## Done when

- From a clean checkout, mise alone provisions the development tools and
  repository validation passes.
- No active Nix development marker remains, and every remaining Nix
  reference is classified.
- The report names the rollback path.
