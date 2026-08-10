---
name: nix-package-outputs
description: Defines and validates Nix package, app, check, derivation, OCI, and release outputs. Use when changing build products; excludes devShells, developer tools, and task recipes.
---

# Nix Package Outputs

This skill owns Nix-built products, not the project development toolchain.
Its authoritative presence nevertheless requires
`nix-project-toolchain` for project development.

## Entry gate

Read the marker rules in `project-toolchain-selection` when output ownership
is uncertain. If the project currently uses mise for development, do not add
a package-only flake. Return to selection and obtain approval for Nix to
become the development toolchain before defining outputs.

## Own

- flake `packages`, `apps`, and `checks`;
- derivations and reusable `callPackage` expressions;
- Nix-built OCI images and release artifacts;
- build, evaluation, and output-specific release validation.

## Do not own

- `devShells`, developer CLI provisioning, activation, or IDE/GHCP setup;
- task-runner recipes or workflow orchestration;
- language dependency graphs and locks;
- Nix-to-mise migration.

Read [references/output-boundaries.md](references/output-boundaries.md) for
marker classification and handoffs.

## Workflow

1. Confirm Nix is the authoritative project toolchain and identify the
   requested output and consumers.
2. Follow the repository's existing flake, pinning, and `callPackage`
   conventions. Do not reshape the devShell while adding an output.
3. Define the smallest output-specific expression and preserve exact source
   pins, checksums, runtime closure, metadata, and supported systems.
4. Evaluate output names, build the requested output, and run relevant checks.
   Prefer `nix flake show`, `nix build .#<attribute>`, and
   `nix flake check` when the repository supports them.
5. Invoke existing release or task commands only for validation; do not edit
   their definitions.

Use `nix-github-rate-limit` for GitHub-backed fetches. A request to add or pin
development tools belongs to `nix-project-toolchain`.
