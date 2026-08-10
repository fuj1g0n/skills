---
type: Architecture Decision Record
status: accepted
date: 2026-08-10
decision-makers: "@fuj1g0n (with GitHub Copilot)"
---

# Select one authoritative project development toolchain

## Context and Problem Statement

The skill collection previously routed recurring project tools to Nix by
default. `nix-for-dev` also combined devShell provisioning, package builds,
and task-runner conventions, while `missing-tools` used floating ecosystem
runners. Issue [#17](https://github.com/fuj1g0n/skills/issues/17) proposed a
mise/Aqua route for Windows-native work, but its initial model allowed Nix and
mise to remain authoritative for different project scopes.

That split is unreliable when Nix produces package, application, check, OCI,
or release outputs. Those outputs depend in practice on Nix's linker, dynamic
library, runtime, and closure model; developing the same product outside the
Nix environment commonly diverges from what is built. The taxonomy therefore
needs deterministic selection, continuity for existing projects, and one
development source of truth without absorbing package or task ownership.

## Decision Drivers

* Preserve existing project intent unless migration is explicitly authorized.
* Support native Windows developers, editors, and agents without leaking
  Linux Nix paths into Win32.
* Keep Nix package-output builds and their development environment coherent.
* Assign one primary owner to every representative prompt.
* Keep task orchestration, language dependency graphs, and package outputs in
  their proper ownership boundaries.
* Make new-project initialization and destructive migration consent-driven.

## Considered Options

* Select one development toolchain using continuity, package constraints, and
  participant platforms
* Select only from the deployment target or current host platform
* Allow mise development alongside a Nix package-output-only flake
* Keep the previous Nix-default routing and add ad hoc exceptions

## Decision Outcome

Chosen option: "Select one development toolchain using continuity, package
constraints, and participant platforms", because it preserves project intent,
keeps Nix-built products aligned with their runtime model, supports native
Windows participation where appropriate, and gives each workflow one primary
owner.

Selection applies this precedence:

1. Authoritative Nix package outputs are a hard Nix constraint.
2. Active Nix and mise development markers together require a stop and user
   clarification; no skill silently normalizes them.
3. An existing Nix development setup continues with Nix.
4. An existing mise setup continues with mise+Aqua.
5. For a new project, infer participant platforms from purpose, discuss both
   options, and obtain confirmation before initialization. Recommend Nix only
   when development and execution are guaranteed Linux-only; recommend
   mise+Aqua when Windows may participate. A Linux deployment target alone is
   insufficient evidence for Nix.

The project development source of truth is exactly one of Nix or mise+Aqua.
Aqua is a mise backend, not a third toolchain. Language-local managers and
locks remain valid under either choice and do not constitute mixing.

`nix-project-toolchain` and `mise-project-toolchain` own exact developer tool
versions, project environment and activation, install/lock/update/remove,
diagnosis, visibility to shells/editors/GHCP, and source validation. They may
install and pin `just` or another runner, but do not define recipes, mise
`[tasks]`, or workflow orchestration. Existing tasks may be invoked for
validation. No generic task-runner skill is added because the repository has
not demonstrated a separate repeatable domain workflow.

`nix-package-outputs` separately owns flake `packages`, `apps`, `checks`,
derivations, Nix-built OCI images, and release outputs. It excludes devShells
and task recipes. Although output definitions are out of scope for
`nix-project-toolchain`, their authoritative presence requires the Nix
development toolchain. A package-output-only flake may not coexist with mise
development.

Nix-to-mise migration is explicit-only and transactional:

1. assess current authority and outputs;
2. obtain project-specific consent;
3. plan exact source and validation mappings;
4. build an isolated candidate;
5. validate tools, environment, IDE/agent visibility, and existing workflows;
6. cut over and remove the old Nix development toolchain in the same change;
7. verify a clean checkout has one authority;
8. roll back the whole transaction on failure.

Package outputs create a stop gate. Migration proceeds only after a separate,
explicitly authorized plan removes or replaces every authoritative output.
Persistent mixed development manifests are never a migration phase or
rollback strategy.

An existing Nix project opened from Windows continues through WSL, a Dev
Container, or wslc; it does not silently migrate and never exports
`/nix/store` into Win32 `PATH`. `nix-wslc-devshell` is the narrow owner for an
already selected wslc execution bridge. It does not take selection,
development-manifest, migration, task, or package-output ownership. Draft PR
[#16](https://github.com/fuj1g0n/skills/pull/16) originally contained a broader
experimental implementation. The rejected
[WSL direnv project shell decision](0019-wsl-direnv-project-shell-for-windows-hosted-projects.md)
records its outcome; the cleanup retains research evidence but removes the
provisional implementation and does not adopt its provisioning scripts.

### Consequences

* Good, because existing intent takes precedence over platform preference.
* Good, because Nix package outputs and development share one linker/runtime
  model.
* Good, because native Windows projects can use deterministic mise+Aqua
  provisioning without a standalone Aqua authority.
* Good, because routing tests can assert one primary owner and explicit
  forbidden outcomes.
* Bad, because package outputs prevent incremental Nix-to-mise migration; a
  separate replacement plan may be substantial.
* Bad, because new projects require a user decision before automation can
  initialize the environment.
* Bad, because task and language dependency changes may require explicit
  handoffs rather than one skill completing an entire broad request.
* Neutral, because accepted ADRs and research retain historical skill names;
  active-reference validation explicitly allowlists only those directories.

### Confirmation

The collection is checked by the repository-local skill audit, APM audit,
Markdown lint, directory/frontmatter validation, active old-name search,
`git diff --check`, and the routing corpus. The corpus covers new and existing
projects, package constraints, mixed markers, Windows continuation,
full-cutover migration, runner/task boundaries, package output ownership,
explicit global scopes, one-shot recovery, corporate npm quarantine, and
pressure cases for every prohibited shortcut.

## Pros and Cons of the Options

### Select one toolchain using continuity, constraints, and participants

* Good, because it captures both existing intent and real development hosts.
* Good, because package-output coherence is a non-negotiable constraint.
* Bad, because selection requires more evidence than checking one manifest.

### Select from deployment target or current host

* Good, because it is simple to automate.
* Bad, because Linux deployment does not exclude Windows-native developers or
  agents.
* Bad, because opening a Nix project on Windows could be mistaken for migration
  consent.

### Allow mise with a package-output-only flake

* Good, because it appears to offer native developer convenience.
* Bad, because it creates two environment models for the same built product.
* Bad, because linker, DLL, runtime, and closure differences make development
  outside Nix unreliable.

### Keep Nix-default routing with exceptions

* Good, because it changes fewer existing skills.
* Bad, because generic missing-tool requests continue to select Nix even for
  native Windows participation.
* Bad, because package and task ownership remain overlapping.

## More Information

The executable corpus and evaluation guidance live under
`.apm/skills/project-toolchain-selection/`. Historical accepted ADRs and
research remain immutable; active cross-references use the renamed skill
owners.
