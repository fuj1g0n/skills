# Cutover Transaction

Work through the steps in order as one task list. Step 4 is the only point
that waits for the user.

## 1. Assess

Inventory Nix development markers, package outputs, activation, CI/editor
entry points, exact tool versions, environment variables, task-runner
executables, and validation commands. Classify language-local files as
neutral. Record any uncertainty.

Block when authoritative `packages`, `apps`, `checks`, derivations,
Nix-built OCI images, or Nix release outputs exist: report them and end
without changes. Their removal or replacement is a separate plan requiring
explicit authorization.

## 2. Plan

Map each development tool and environment variable to an exact mise source.
Identify Aqua provenance/checksum requirements and corporate npm admission
constraints. Separate task recipes, application build logic, and language
dependency graphs from the toolchain change.

## 3. Candidate and validation

Create the mise candidate in an isolated branch or worktree. Keep temporary
comparison state out of the merge result. Use exact versions only, and
report any tool that has no exact mise source instead of substituting it.

Validate clean installation, lock resolution, shell/IDE/GHCP visibility,
tool versions, environment variables, and existing build/lint/test commands.
On Windows, check that no `/nix/store` path enters Win32 `PATH`.

## 4. Cutover approval

Ask the user to approve the cutover for this project, presenting the
validated candidate diff, scope, losses, source changes, rollback path, and
the no-coexistence rule. The original migration request authorized the
preparation in steps 1-3, not the cutover.

## 5. Cut over

Remove every Nix development marker and development-only integration in the
same transaction that makes mise authoritative. Remove a root flake only when
it has no package, release, or other retained Nix ownership.

## 6. Clean authority

From a clean checkout, show that mise alone provisions development tools and
that repository validation passes. Search for active mixed markers and
classify every remaining Nix reference.

## 7. Roll back

If validation fails, revert the entire candidate to the pre-migration Nix
state. A partial rollback would leave both systems active.
