---
name: nix-gc-direnv
description: Clean up .direnv directories that act as Nix store GC roots, freeing disk space. Use when asked to clean up direnv roots, free Nix store space, or remove stale direnv flake caches.
---

# Nix GC: direnv roots

`.direnv` directories pin flake dev shells as Nix store GC roots, so
`nix-store --gc` cannot reclaim them until the directories are removed.

## Steps

1. List projects holding `.direnv` GC roots:

   ```sh
   nix-store --gc --print-roots 2>/dev/null | grep '\.direnv' | sed 's|/.direnv/.*||' | sort -u
   ```

2. Show the user how many projects have `.direnv` roots and list them.

3. Delete the `.direnv` directories:

   ```sh
   nix-store --gc --print-roots 2>/dev/null | grep '\.direnv' | sed 's|/.direnv/.*||' | sort -u | while read -r dir; do rm -rf "$dir/.direnv"; done
   ```

4. Verify no `.direnv` GC roots remain:

   ```sh
   nix-store --gc --print-roots 2>/dev/null | grep -c '\.direnv'
   ```

5. Ask the user whether to run `nix-store --gc` to actually reclaim disk
   space.

## Notes

- `.direnv` directories are recreated automatically by direnv on the next
  `cd` into a project with an `.envrc`, so deleting them is safe.
- This does not affect the current shell's active dev environment.
