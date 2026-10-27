# Selection Evidence

Use evidence from active project manifests and automation. Prefer structured
parsing or evaluation over text matching when tooling is available.

## Evidence scope

Treat a marker as authoritative when it is in a root or declared project
manifest, or when active build/release automation consumes it. Exclude:

- `.git/`, dependency caches, vendored trees, and generated output;
- `fixtures/`, `examples/`, `samples/`, and `testdata/` unless the user says
  that directory is the project being changed;
- documentation, accepted ADRs, research snapshots, and quoted snippets;
- disabled or archival CI files.

When scope is uncertain, count the path as active and name it with its
classification in the report; a missed marker is costlier than an extra one.

## Nix development markers

Strong markers include active `devShells` or `devShell` outputs, `shell.nix`,
`default.nix` used by `nix-shell`, `.envrc` containing `use flake` or
`use nix`, and active CI/editor commands that enter `nix develop`.

A root `flake.nix` alone proves Nix involvement, but not whether it owns only
development, package outputs, or both. Inspect its evaluated outputs and the
files imported by the output function.

## Nix package-output markers

The following are hard Nix constraints when they are authoritative:

- evaluated flake outputs under `packages`, `apps`, or `checks`;
- expressions producing derivations through `stdenv.mkDerivation`,
  `buildGoModule`, `buildRustPackage`, `buildNpmPackage`, `callPackage`, or
  equivalent builders and exposed to build/release automation;
- `dockerTools.buildImage`, `dockerTools.buildLayeredImage`, or other
  Nix-built OCI outputs;
- release jobs that publish results of `nix build`.

Do not classify a comment, attribute name in a fixture, or documentation
example as an output. `devShells` alone is not a package-output marker.
Conversely, an output imported from another Nix file still counts even when
the words `packages` or `checks` do not appear in the root flake.

When package outputs exist, select Nix and hand output edits to
`nix-package-outputs`. Migration to mise is blocked until a separately
authorized plan removes or replaces every authoritative package output.

## mise development markers

Strong markers are active `mise.toml` or `.mise.toml`, committed `mise.lock`,
and CI/editor activation through `mise install`, `mise exec`, or
`mise activate`. Aqua registry entries inside mise configuration are mise
evidence, not a separate toolchain.

## Neutral evidence

Language files such as `package.json`, `package-lock.json`, `pyproject.toml`,
`uv.lock`, `go.mod`, and `Cargo.lock` do not select Nix or mise. Neither do a
`justfile`, task scripts, application build files, or deployment targets.

## Evidence report

Before handoff, state:

```text
Project state: new | existing
Authoritative markers: <paths and meanings>
Ignored candidates: <paths and reason>
Package-output constraint: present | absent | uncertain
Recommendation: Nix | mise+Aqua | stop and clarify
Confirmation required: yes | no
Primary owner after selection: <skill name>
```
