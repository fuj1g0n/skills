---
name: nix-direnv-gc-roots
description: Removes stale nix-direnv GC roots. Use when `.direnv` caches retain Nix store paths, disk reclamation is blocked, or the user asks to inspect or delete direnv roots.
---

# Nix direnv GC roots

Find and remove `.direnv` directories that hold GC roots in the Nix store,
then reclaim the space. Deleting them is safe: direnv recreates `.direnv` the
next time a project with an `.envrc` is entered, at the cost of one devShell
re-evaluation there. Deletion does not affect a dev shell that is already
running.

## Steps

1. List the projects that hold `.direnv` GC roots and report the count and
   paths:

   ```sh
   nix-store --gc --print-roots 2>/dev/null | grep '\.direnv' | sed 's|/.direnv/.*||' | sort -u
   ```

2. Delete the `.direnv` directory of each listed project:

   ```sh
   nix-store --gc --print-roots 2>/dev/null | grep '\.direnv' | sed 's|/.direnv/.*||' | sort -u | while read -r dir; do rm -rf "$dir/.direnv"; done
   ```

3. If the user asked to reclaim disk space, run `nix-store --gc`. Otherwise
   Ask the user whether to run it, presenting the deleted roots; collection
   removes every unreferenced store path, which must be downloaded or rebuilt
   again when needed.

## Done when

- This command prints `0`:

  ```sh
  nix-store --gc --print-roots 2>/dev/null | grep '\.direnv' | wc -l
  ```

- The report lists the projects whose roots were removed and whether
  `nix-store --gc` ran.
