# Cutover Transaction

## 1. Assess

Inventory Nix development markers, package outputs, activation, CI/editor
entry points, exact tool versions, environment variables, task-runner
executables, and validation commands. Classify language-local files as
neutral. Record any uncertainty.

Stop when authoritative `packages`, `apps`, `checks`, derivations, Nix-built
OCI images, or Nix release outputs exist. Their removal or replacement is a
separate plan requiring explicit authorization.

## 2. Consent

Present scope, losses, source changes, rollback, and the no-coexistence rule.
Obtain explicit approval for this project and plan. Do not treat approval to
investigate as approval to cut over.

## 3. Plan

Map each development tool and environment variable to an exact mise source.
Identify Aqua provenance/checksum requirements and corporate npm admission
constraints. Separate task recipes, application build logic, and language
dependency graphs from the toolchain change.

## 4. Candidate

Create the mise candidate in an isolated branch or worktree. Keep temporary
comparison state out of the merge result. Never use floating versions or
silently substitute unavailable tools.

## 5. Validate

Validate clean installation, lock resolution, shell/IDE/GHCP visibility,
tool versions, environment variables, and existing build/lint/test commands.
On Windows, verify that no `/nix/store` path enters Win32 `PATH`.

## 6. Cut over

Remove every Nix development marker and development-only integration in the
same transaction that makes mise authoritative. Remove a root flake only when
it has no package, release, or other retained Nix ownership.

## 7. Verify clean authority

From a clean checkout, prove that mise alone provisions development tools and
that repository validation passes. Search for active mixed markers and
classify every remaining Nix reference.

## 8. Roll back

If validation fails, revert the entire candidate to the pre-migration Nix
state. Do not leave both systems active as a partial rollback.
