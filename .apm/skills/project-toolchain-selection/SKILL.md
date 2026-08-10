---
name: project-toolchain-selection
description: Selects the authoritative project development toolchain. Use when initializing a project, choosing Nix versus mise+Aqua, detecting toolchain ownership, or resolving mixed toolchain markers.
---

# Project Toolchain Selection

This skill owns the choice of project development toolchain. It does not
initialize or mutate either toolchain.

## Selection workflow

1. Decide whether the project is new or already has authoritative manifests.
2. Inspect active project files and CI, excluding examples, fixtures, generated
   files, vendored dependencies, and historical documentation. Read
   [references/selection-evidence.md](references/selection-evidence.md) when
   markers are ambiguous or Nix outputs may exist.
3. Apply this precedence, in order:
   1. Authoritative Nix package outputs are a hard Nix constraint.
   2. Both Nix and mise development markers require a stop and clarification;
      do not normalize, migrate, or edit either system.
   3. An existing Nix development setup continues with Nix.
   4. An existing mise setup continues with mise+Aqua.
   5. A new project has no default until the user confirms the choice.
4. Report the evidence, recommendation, consequences, and intended owner.
5. Obtain confirmation before initializing a new project, then hand off to
   `nix-project-toolchain` or `mise-project-toolchain`.

## New projects

Infer platform needs from the project's purpose and expected developers,
agents, editors, and automation. A Linux deployment target alone does not
make a project Linux-only.

- When development and execution are guaranteed Linux-only, recommend Nix.
- When Windows may participate natively, including GHCP or other agents,
  recommend mise+Aqua.
- Discuss both choices and wait for explicit confirmation before creating
  manifests or initializing either toolchain.

## Hard boundaries

- Existing intent precedes platform preference.
- A project with authoritative Nix `packages`, `apps`, `checks`, derivations,
  Nix-built OCI images, or release outputs must use Nix for development too.
  A mise toolchain plus package-output-only flake is forbidden.
- Aqua is a mise backend, never an independent project toolchain.
- Language-local managers and lockfiles remain valid under either toolchain
  and are not mixed-toolchain markers.
- Installing `just` or another runner belongs to the selected project
  toolchain. Editing recipes or workflow orchestration is normal repository
  work, not owned by either toolchain skill.
- Package output definitions belong to `nix-package-outputs`, but their
  presence constrains this selection.
- Migration is explicit-only and belongs to
  `nix-to-mise-project-toolchain`; never infer migration from Windows use.
- A selected wslc execution bridge belongs to `nix-wslc-devshell`; it does
  not own Nix/mise selection or the Nix development manifests.

For the routing corpus, RED/GREEN pressure cases, and blank-slate executor
checklist, read [references/routing-tests.md](references/routing-tests.md).
