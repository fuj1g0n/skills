# Nix Output Boundaries

## Included outputs

Authoritative evaluated `packages`, `apps`, and `checks` are included even
when their derivations are imported from other files. So are derivations
consumed by active `nix build` release automation, Nix-built OCI images, and
published closure artifacts.

Common implementation signals include `stdenv.mkDerivation`, language
builders, `callPackage`, overlays that expose build products, and
`dockerTools` image builders. Signals become authoritative through project
location and active consumers, not through text occurrence alone.

## Excluded surfaces

- `devShells`, `mkShell`, `.envrc`, shell activation, and development tools
  belong to `nix-project-toolchain`.
- `justfile`, mise `[tasks]`, CI workflow orchestration, and release recipes
  remain normal repository task or workflow work.
- Language package manifests and locks remain owned by their language
  workflow, even when a Nix builder consumes them.
- Examples, fixtures, generated output, vendored files, ADRs, and research do
  not establish current output ownership.

## Constraint and handoff

The presence of included outputs is a hard selection constraint: development
must remain Nix. Output definition is still handled here, while developer
tool changes are handed to `nix-project-toolchain`.

Removing or replacing outputs for a migration is not an incidental cleanup.
It requires a separately authorized plan before
`nix-to-mise-project-toolchain` may proceed.
