---
name: project-toolchain-selection
description: Selects the authoritative project development toolchain. Use when initializing a project, choosing Nix versus mise, detecting toolchain ownership, or resolving mixed toolchain markers.
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
   4. An existing mise setup continues with mise.
   5. A new project defaults to mise; see New projects.
4. If the user explicitly asks to migrate from mise to Nix, Block: no skill
   owns that migration. Report the request and the current markers and end
   without changes.
5. Report the evidence, recommendation, consequences, and intended owner.
6. Once the owner is settled, hand off to `nix-project-toolchain` or
   `mise-project-toolchain`.

## New projects

Select mise by default and name the default in the report. Select Nix
instead only when the project will define Nix package outputs (rule 1) or
the user explicitly asks for Nix. Linux-only development or a Linux
deployment target alone does not select Nix.

## Invariants

- Existing intent precedes platform preference, because changing an
  established toolchain is a migration that only an explicit request
  authorizes.
- A project with authoritative Nix `packages`, `apps`, `checks`,
  derivations, Nix-built OCI images, or release outputs uses Nix for
  development too, and never a mise toolchain plus package-output-only
  flake, because those outputs depend on the Nix build environment and two
  development authorities drift.
- The standalone aqua CLI and `aqua.yaml` are never a project toolchain,
  because mise's `aqua:` backend needs neither and a second manifest splits
  tool ownership.
- Migration is explicit-only and only Nix-to-mise is supported, through
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
- For mixed markers, the user approved the recovery plan before any
  manifest changed.
- Control is handed to the owning skill.

For the routing corpus, RED/GREEN pressure cases, and blank-slate executor
checklist, read [references/routing-tests.md](references/routing-tests.md).
