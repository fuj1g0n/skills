---
name: windows-user-tools
description: Manages explicit user-wide native Windows tools through officially recommended self-upgrading installers or WinGet user-scope and portable packages. Use only for requested global installs, updates, removals, or diagnosis on native Windows.
---

# Windows User Tools

This is the explicit-only owner of user-wide tools on native Windows. User
scope uses a self-upgrading official installer or WinGet; mise is a project
toolchain.

## Workflow

1. Check that the user explicitly asked for a user-wide change on native
   Windows. Otherwise hand off to `missing-tools` for a one-shot need, to
   the project toolchain owner, or to `nix-user-tools` for Linux or WSL.
2. If the request names Scoop, Chocolatey, or mise as the user-wide
   manager, Block: no skill owns that channel. Report the supported route
   and end without changes.
3. Find the package ID with `winget search <name>`, then inspect
   `winget --info`, `winget list --id <id> -e`, and `Get-Command <tool>` to
   find the current install channel. An install request for a tool already
   present through the same channel changes nothing; report the available
   upgrade. From WSL, call `winget.exe` and
   `powershell.exe -NoProfile -Command ...`.
4. For a new install, read the tool's official Windows installation docs,
   not its Linux docs. When they offer a per-user installer that needs no
   elevation, and the tool updates itself through a command or a built-in
   updater, follow the self-upgrading installer path below even if WinGet
   also lists it. A tool already installed through another channel stays
   there; name the other option in the report.
5. On the WinGet path, if WinGet commands fail because of a device policy,
   Block: report the policy and end without changes.
6. Resolve the exact package with `winget show --id <id> -e --scope user`,
   which lists only installers that support user scope, and read its
   installer type and dependencies. Prefer `portable`, `msix`, or `msi`
   installers; `exe`, `inno`, `nullsoft`, and `burn` installers may still
   require elevation.
7. If no user-scope installer exists, or a missing dependency would need
   machine scope, Block: report it and end without changes. Otherwise
   install with `--scope user`; upgrade and remove by ID.
8. Report the package ID, version, installer type, and the upgrade and
   removal commands.

```powershell
winget show --id <id> -e --scope user
winget install --id <id> -e --scope user
winget upgrade --id <id> -e
winget uninstall --id <id> -e
winget list --id <id> -e
```

Portable packages land under `%LOCALAPPDATA%\Microsoft\WinGet\Packages`
with links in `%LOCALAPPDATA%\Microsoft\WinGet\Links`. When a
configuration repository declares the user's WinGet packages, through a
`winget export` file or a `winget configure` file, change that source first
and apply it from there.

## Self-upgrading installers

The tool owns its own updates, and WinGet detects installed versions from
the Windows app list, so a second channel misreports or replaces them.

- Run the officially documented per-user installer or release asset as
  the current user. Verify the downloaded artifact against its published
  checksum or signature when the project provides one, and state in the
  report when it provides none.
- Update with the tool's self-upgrade command.
- Remove with the official uninstall instructions.
- If the install directory is not on the user `PATH` after the installer
  ran, report it and leave `PATH` unchanged.

## Invariants

- No global change inferred from a project need or missing command,
  because user-wide state outlives the request and affects every project.
- No tool managed through two channels, because each channel overwrites or
  misreads the other's version.
- No machine-scope install, elevation, or Scoop, Chocolatey, or mise global
  configuration, because machine state needs administrator approval and
  each extra channel is outside device management.
- No manual edits to user or system `PATH`, and no `/nix/store` path in
  Win32 `PATH`, because installers and WinGet own the entries they add and
  native Windows tools would resolve Linux binaries.

## Done when

- For WinGet, `winget list --id <id> -e` shows the requested version, and
  `Get-Command <tool>` resolves under the user profile.
- For a self-upgrading installer, `Get-Command <tool>` resolves to the
  documented user directory and the tool reports its version.
- The report names the channel, the upgrade command, and the removal
  command.

Canonical references: [WinGet install](https://learn.microsoft.com/windows/package-manager/winget/install)
and [WinGet scope troubleshooting](https://learn.microsoft.com/windows/package-manager/winget/troubleshooting#scope-for-specific-user-vs-machine-wide).
