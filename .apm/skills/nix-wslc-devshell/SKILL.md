---
name: nix-wslc-devshell
description: Runs an existing Nix project's devShell in a wslc container while its repository stays on Windows. Use only when wslc is selected for Windows-hosted Nix execution.
---

# Nix devShell via wslc

This skill owns wslc-specific provisioning and command delegation. It does
not own the project development toolchain: `nix-project-toolchain` remains
authoritative for developer tools, pins, activation semantics, and validation.

## Entry gate

- Require an existing Nix project toolchain and an explicit choice to use
  wslc for Windows-hosted execution.
- Use `project-toolchain-selection` when authority is unknown or mixed.
- General Windows continuation through WSL or a Dev Container belongs to
  `nix-project-toolchain`, not this skill.

## Scope contract

Own:

- provision and diagnose the per-project wslc container;
- keep the repository on NTFS while mounting it into the Linux container;
- execute the existing devShell inside the container without leaking
  `/nix/store` paths into native Win32 `PATH`.

Do not own:

- adding, pinning, or removing project development tools;
- Nix package outputs, application builds, or release definitions;
- task or recipe definitions and workflow orchestration;
- Nix-to-mise migration or selection between Nix and mise+Aqua.

## Workflow

1. Check that `wslc version` succeeds and the existing Nix project is the
   selected authority.
2. Require LF for shell, Nix, and direnv files consumed in the container.
3. Inspect the project's accepted wslc image, mounts, persistent Nix volume,
   user, activation command, and wrapper. If no bridge exists, draft one and
   Ask the user to approve adding it, presenting the image, mounts, volume,
   user, and wrapper; it changes the repository architecture.
4. Provision or start the accepted per-project container without changing the
   Nix tool pins, then run existing devShell commands through its wrapper.
   Keep Git, GitHub authentication, and native repository operations on
   Windows.

Existing task recipes may be run for validation, but this skill does not edit
them. Hand off to `nix-project-toolchain` for devShell changes and to
`nix-package-outputs` for package outputs.

## Invariants

- No `/nix/store` path in Win32 `PATH`, because native Windows tools would
  resolve Linux binaries.

## Done when

- The command runs in Linux, resolves tools from the Nix devShell, and keeps
  the working directory.
- Win32 `PATH` and the Nix tool pins are unchanged.
