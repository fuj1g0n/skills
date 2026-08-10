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

1. Confirm `wslc version` succeeds and the existing Nix project is the
   selected authority.
2. Require LF for shell, Nix, and direnv files consumed in the container.
3. Inspect the project's accepted wslc image, mounts, persistent Nix volume,
   user, activation command, and wrapper. If no bridge exists, stop and obtain
   approval for that repository architecture change before adding one.
4. Provision or start the accepted per-project container without changing the
   Nix tool pins, then run existing devShell commands through its wrapper.
   Keep Git, GitHub authentication, and native repository operations on
   Windows.
5. Verify the command executes in Linux, resolves tools from the Nix
   devShell, preserves the working directory, and does not mutate Win32
   `PATH`.

Existing task recipes may be run for validation, but this skill must not edit
them. Requests to change the devShell hand off to `nix-project-toolchain`;
requests to add package outputs hand off to `nix-package-outputs`.
