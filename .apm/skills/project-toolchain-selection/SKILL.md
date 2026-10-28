---
name: project-toolchain-selection
description: Selects the authoritative project development toolchain. Use when initializing a project, choosing Nix versus mise, changing tools in a Nix devShell project without package outputs, detecting toolchain ownership, or resolving mixed toolchain markers.
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
   1. Authoritative Nix package outputs are a hard Nix constraint; the owner
      is `project-nix-distribution`.
   2. Both Nix and mise development markers active: Ask the user which
      explicit recovery plan applies, presenting the evidence for each
      authority. Edit neither system meanwhile.
   3. A Nix devShell without package outputs is a migration candidate. For a
      tool change there, Ask the user to approve migration to mise,
      presenting the markers and the absent outputs; on approval hand off to
      `project-toolchain-migration`, otherwise Block: report it and end
      without changes. Running the existing devShell is not a tool change.
   4. An existing mise setup continues with mise.
   5. A new project defaults to mise; see New projects.
4. If the user explicitly asks to migrate from mise to Nix, Block: no skill
   owns that migration. Report the request and the current markers and end
   without changes.
5. Report the evidence, recommendation, consequences, and intended owner.
6. Once the owner is settled, hand off to `project-dev-tools` or
   `project-nix-distribution`.

## New projects

Select mise by default and name the default in the report. Select Nix only
when the project will define Nix package outputs (rule 1). A request for a
Nix devShell without planned outputs would create a migration candidate:
Block, report that Nix development requires Nix distribution, and end
without changes. Linux-only development or a Linux deployment target alone
does not select Nix.

## Invariants

- Existing intent precedes platform preference, because changing an
  established toolchain is a migration that only the user's approval
  authorizes.
- A project with authoritative Nix `packages`, `apps`, `checks`,
  derivations, Nix-built OCI images, or release outputs uses Nix for
  development too, and never a mise toolchain plus package-output-only
  flake, because those outputs depend on the Nix build environment and two
  development authorities drift.
- The standalone aqua CLI and `aqua.yaml` are never a project toolchain,
  because mise's `aqua:` backend needs neither and a second manifest splits
  tool ownership.
- Migration needs the user's approval and only Nix-to-mise is supported,
  through `project-toolchain-migration`; Windows use alone is not a
  migration request, because Nix projects already run on Windows through
  WSL, a Dev Container, or wslc.

## Ownership boundaries

- Language-local managers and lockfiles remain valid under either toolchain
  and are not mixed-toolchain markers.
- Installing `just` or another runner belongs to the selected project
  toolchain. Editing recipes or workflow orchestration is normal repository
  work, not owned by either toolchain skill.
- Nix package outputs and their devShell belong to
  `project-nix-distribution`; their presence constrains this selection.
- A selected wslc execution bridge belongs to `windows-wslc-project-shell`;
  it does not own Nix/mise selection or the Nix development manifests.

## Done when

- The report names the evidence, the selected toolchain, and the owning
  skill.
- For mixed markers or a migration candidate, the user approved the plan
  before any manifest changed, or the request was blocked.
- Control is handed to the owning skill.

For the routing corpus, RED/GREEN pressure cases, and blank-slate executor
checklist, read [references/routing-tests.md](references/routing-tests.md).
