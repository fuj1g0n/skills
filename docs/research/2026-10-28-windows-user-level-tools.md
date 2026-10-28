---
type: Research Snapshot
---

# User-level tool management on native Windows

Point-in-time snapshot, 2026-10-28. Supports the `windows-user-tools`
skill. Primary sources only, fetched on the snapshot date; one field
observation from this machine is marked as such. This file is immutable; a
re-survey is a new file.

## Question

Linux and WSL user-level tools use an officially recommended
self-upgrading binary in `~/.local/bin`, otherwise `nix profile`. Project
tools use mise. What is the equivalent user-level channel on a corporate
managed native Windows 11 machine, and is WinGet enough?

## Sources

- Microsoft Learn, [winget install](https://learn.microsoft.com/windows/package-manager/winget/install)
- Microsoft Learn, [WinGet troubleshooting: scope](https://learn.microsoft.com/windows/package-manager/winget/troubleshooting#scope-for-specific-user-vs-machine-wide)
- Microsoft Learn, [WinGet settings](https://learn.microsoft.com/windows/package-manager/winget/settings)
- Microsoft Learn, [winget pin](https://learn.microsoft.com/windows/package-manager/winget/pinning)
- Microsoft Learn, [winget export](https://learn.microsoft.com/windows/package-manager/winget/export)
  and [WinGet Configuration](https://learn.microsoft.com/windows/package-manager/configuration/)
- Microsoft Learn, [Policy CSP - DesktopAppInstaller](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-desktopappinstaller)
- uv, [Installation](https://docs.astral.sh/uv/getting-started/installation/)
- Deno, [Installation](https://docs.deno.com/runtime/getting_started/installation/)
- Bun, [Installation](https://bun.com/docs/installation)
- GitHub, [copilot-cli README](https://github.com/github/copilot-cli)
- mise, [Installing mise](https://mise.jdx.dev/installing-mise.html)

## Findings

### WinGet scope

- `--scope user` requests a per-user install, but Microsoft documents it as
  installer-dependent: MSIX is reliable, MSI is typically reliable unless
  wrapped in an EXE, and EXE installers are not deterministic. "Packages
  installed in user scope may still require UAC authorization from an
  administrator."
- Portable packages are unpacked under `portablePackageUserRoot`, default
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages`, with command links in
  `%LOCALAPPDATA%\Microsoft\WinGet\Links`. The `installerTypes` preference
  can favor `portable` or `msix`.
- Field observation: `winget.exe --info` runs from WSL on this machine
  (WinGet v1.29.380) and lists the portable roots and the administrator
  settings in effect.

### Updates, pins, and self-updating tools

- `winget pin` limits only WinGet's own upgrades: "A pinned package may
  still upgrade on its own and be upgraded from outside the Windows Package
  Manager."
- Tool vendors treat channels as exclusive. uv: when installed by a method
  other than the standalone installer, "self-updates are disabled. Use the
  package manager's upgrade method instead." Bun: "Scoop users: to avoid
  conflicts with Scoop, use `scoop update bun` instead."
- Therefore one channel per tool; a tool installed by its self-upgrading
  installer is not also installed through WinGet.

### Official Windows channels of common self-upgrading tools

| Tool | Official Windows installer | Self-upgrade | WinGet listed by vendor |
|---|---|---|---|
| uv | `irm https://astral.sh/uv/install.ps1 \| iex` | `uv self update` | yes, `astral-sh.uv` |
| Deno | `irm https://deno.land/install.ps1 \| iex` into `%USERPROFILE%\.deno\bin` | `deno upgrade` | yes, `DenoLand.Deno` |
| Bun | `powershell -c "irm bun.sh/install.ps1\|iex"` | `bun upgrade` | not on the installation page |
| GitHub Copilot CLI | none; WinGet or npm on Windows | built in | yes, `GitHub.Copilot` |
| mise | script available; WinGet is the recommended Windows method | `mise self-update` | yes |

Copilot CLI shows that a tool with a Linux user-directory script may have
no Windows equivalent; the Windows docs, not the Linux docs, decide.

### Declarative state

`winget export` writes a JSON package list, optionally with versions, for
`winget import`. `winget configure` applies a DSC-based YAML configuration
that may live in a repository. Either can be the source of truth in a
configuration repository.

### Device policy

The DesktopAppInstaller Policy CSP includes device-scope policies such as
`EnableWindowsPackageManagerCommandLineInterfaces` and allowed-source
controls, so an administrator can disable the WinGet CLI or restrict its
sources. `winget --info` reports the policies in effect.

### Alternatives

- Scoop installs to the user profile without elevation, uses shims and git
  buckets, and verifies manifest hashes. It is a third-party channel with
  no Policy CSP control, so on a managed device it adds an unmanaged
  supply-chain path.
- `mise use -g` writes a global default under the user profile. It works
  on Windows, but per-directory version switching is mise's purpose, and a
  global mise layer would give mise two jobs on Windows and one on Linux.

## Conclusion

WinGet is a sufficient default on native Windows, with three rules:

1. Prefer the vendor's self-upgrading Windows installer into a user
   directory when the Windows docs recommend one and the tool has a
   self-upgrade command; do not also install it through WinGet.
2. Otherwise use WinGet with `--scope user`, preferring `portable`,
   `msix`, or `msi` installers; treat a package that needs machine scope or
   elevation as out of user scope.
3. Do not use Scoop, Chocolatey, or `mise use -g` for user-level tools on
   a managed device.
