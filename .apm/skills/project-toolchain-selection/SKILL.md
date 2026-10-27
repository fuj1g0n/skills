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
   2. Both Nix and mise development markers active: Ask the user which
      explicit recovery plan applies, presenting the evidence for each
      authority. Edit neither system meanwhile.
   3. An existing Nix development setup continues with Nix.
   4. An existing mise setup continues with mise+Aqua.
   5. A new project has no default: Ask the user to approve a toolchain,
      presenting the evidence, recommendation, and consequences of both.
4. Report the evidence, recommendation, consequences, and intended owner.
5. Once the owner is settled, hand off to `nix-project-toolchain` or
   `mise-project-toolchain`.

## New projects

Infer platform needs from the project's purpose and expected developers,
agents, editors, and automation. A Linux deployment target alone does not
make a project Linux-only.

- When development and execution are guaranteed Linux-only, recommend Nix.
- When Windows may participate natively, including GHCP or other agents,
  recommend mise+Aqua.
- Discuss both choices in the new-project Ask; create no manifests before
  the user approves.

## Invariants

- Existing intent precedes platform preference, because changing an
  established toolchain is a migration that only an explicit request
  authorizes.
- A project with authoritative Nix `packages`, `apps`, `checks`,
  derivations, Nix-built OCI images, or release outputs uses Nix for
  development too, and never a mise toolchain plus package-output-only
  flake, because those outputs depend on the Nix build environment and two
  development authorities drift.
- Aqua is a mise backend, never an independent project toolchain, because a
  second manifest splits tool ownership.
- Migration is explicit-only and belongs to
  `nix-to-mise-project-toolchain`; Windows use alone is not a migration
  request, because Nix projects already run on Windows through WSL, a Dev
  Container, or wslc.

## Ownership boundaries

- Language-local managers and lockfiles remain valid under either toolchain
  and are not mixed-toolchain markers.
- Installing `just` or another runner belongs to the selected project
  toolchain. Editing recipes or workflow orchestration is normal repository
  work, not owned by either toolchain skill.
- Package output definitions belong to `nix-package-outputs`, but their
  presence constrains this selection.
- A selected wslc execution bridge belongs to `nix-wslc-devshell`; it does
  not own Nix/mise selection or the Nix development manifests.

## Done when

- The report names the evidence, the selected toolchain, and the owning
  skill.
- For a new project or mixed markers, the user approved the toolchain
  before any manifest changed.
- Control is handed to the owning skill.

For the routing corpus, RED/GREEN pressure cases, and blank-slate executor
checklist, read [references/routing-tests.md](references/routing-tests.md).
