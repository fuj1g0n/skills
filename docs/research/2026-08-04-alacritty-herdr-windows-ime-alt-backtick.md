# Research: Alt+backtick leaks into Herdr when toggling the Windows Japanese IME

Date: 2026-08-04
Author: @fuj1g0n (with GitHub Copilot CLI)
Status: immutable snapshot

## Question

Why does pressing `Alt+backtick`, the Windows Japanese IME toggle on a
US keyboard layout, insert a literal backtick while Alacritty is
attached to a remote Herdr session, even though the same shortcut does
not insert anything in a local Git Bash prompt?

The keyboard layout must remain US. The desired behavior is for
Windows to toggle the IME without delivering a backtick to the
terminal application.

## Environment

Observed on 2026-08-04:

* Windows 11 with the Microsoft Japanese IME and a US keyboard layout
* Alacritty 0.17.0
* Windows Alacritty config starts Git Bash
* Windows Herdr 0.7.5 preview
* WSL Herdr 0.7.5
* Remote devbox Herdr 0.7.5
* Outer terminal `TERM=xterm-256color`
* WSL and remote locale `C.UTF-8`

The devbox launcher does not run a conventional interactive SSH
session. Its effective path is:

```text
Alacritty
  -> Git Bash
  -> wsl.exe
  -> herdr --remote devbox
  -> SSH remote-client-bridge
  -> remote Herdr server
  -> pane PTY
```

The WSL client is significant because Herdr compiles its Unix terminal
setup path there. The native Windows client intentionally skips the
same keyboard-enhancement request.

## Findings

### Herdr enables Kitty keyboard progressive enhancement

Herdr 0.7.5 calls `PushKeyboardEnhancementFlags` on non-Windows
clients. The requested flags are:

* `DISAMBIGUATE_ESCAPE_CODES`
* `REPORT_EVENT_TYPES`
* `REPORT_ALTERNATE_KEYS`

This activates Kitty keyboard protocol handling in Alacritty. Herdr
does not currently expose a configuration option to disable these host
keyboard enhancements.

`modifyOtherKeys` is not the cause in this environment.
`ALACRITTY_WINDOW_ID` is not propagated into WSL, and Herdr enables
that fallback only when it detects Alacritty, WezTerm, or tmux through
their environment markers.

### Alacritty changes its behavior when Kitty disambiguation is active

Windows consumes `Alt+backtick` as an IME command, so the key event has
no committed text. In Alacritty's legacy keyboard mode, a character
key with no text does not produce a usable legacy sequence and no
bytes reach Git Bash. This explains the correct local behavior.

When `DISAMBIGUATE_ESCAPE_CODES` is active, Alacritty constructs a
Kitty CSI-u sequence from the logical key and modifiers even when the
event has no committed text. For the US-layout grave key with Alt, the
press is encoded as:

```text
ESC [ 96 ; 3 u
```

`96` is the Unicode code point for backtick. Kitty modifier value `3`
means `1 + Alt`.

Alacritty can additionally report the release event because Herdr
requested event types:

```text
ESC [ 96 ; 3 : 3 u
```

### Herdr converts the reconstructed key back to legacy pane input

Herdr parses the CSI-u sequence as:

```text
KeyCode::Char('`') + ALT
```

For a pane that has not negotiated Kitty keyboard reporting, Herdr's
legacy encoder emits an ESC-prefixed Alt character:

```text
ESC `
```

The pane shell therefore receives an Alt-backtick key after Windows
has already used the same physical chord to toggle the IME. In the
observed Git Bash/readline configuration, the escape prefix has no
visible representation and the backtick appears at the prompt.

## Root cause

The root cause is the interaction between Windows IME consumption and
Alacritty's Kitty keyboard disambiguation:

1. Windows handles `Alt+backtick` as the Japanese IME toggle and
   produces no committed text.
2. Herdr has asked Alacritty to report disambiguated keys.
3. Alacritty reconstructs a logical Alt-backtick event despite the
   absence of committed text.
4. Herdr preserves and re-encodes that event for the remote pane.

SSH, the remote locale, and the US keyboard layout are not
misconfigured. Remote attach exposes the problem because its WSL Herdr
client enables the keyboard protocol that local Git Bash does not.

## Mitigations considered

### Suppress Alt+backtick in Alacritty

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

Alacritty documents `None` as inhibiting any action. Windows processes
the IME shortcut before Alacritty's terminal binding, while the
binding prevents the reconstructed key from reaching the PTY.

Advantages:

* Small, local, and reversible.
* Preserves the US keyboard layout and existing IME shortcut.
* Does not disable Kitty keyboard reporting for other keys.

Trade-off:

* Intentional Alt-backtick input is suppressed in every Alacritty
  application, not only Herdr. This is acceptable because the chord is
  reserved for IME toggling in this environment.

### Use a plain devbox shell

`devbox.sh sh` avoids the Herdr UI and therefore avoids Herdr's
keyboard enhancement request. It is useful for diagnosis but loses
the persistent Herdr workspace and is not an acceptable primary
workflow.

### Change the Windows IME shortcut

Assigning another toggle chord avoids the collision without changing
the keyboard layout. It changes established muscle memory and leaves
the terminal interoperability defect unresolved.

### Add a Herdr legacy-host-keyboard option

Herdr could expose an opt-out such as
`host_keyboard_protocol = "legacy"` and skip
`PushKeyboardEnhancementFlags`. This is the preferred upstream escape
hatch, but it would reduce modified-key disambiguation and key-event
reporting for the whole client.

### Change Alacritty's Kitty behavior around consumed IME keys

Alacritty could avoid reconstructing this key when Windows has
consumed it as an IME command. This is the most precise upstream fix
but requires Windows/IME-specific event semantics and may conflict
with the protocol's goal of preserving modified keys.

## Sources

* Herdr 0.7.5 `src/main.rs`:
  <https://github.com/herdrdev/herdr/blob/v0.7.5/src/main.rs>
* Herdr 0.7.5 `src/input/model.rs`:
  <https://github.com/herdrdev/herdr/blob/v0.7.5/src/input/model.rs>
* Herdr 0.7.5 `src/input/parse.rs`:
  <https://github.com/herdrdev/herdr/blob/v0.7.5/src/input/parse.rs>
* Herdr 0.7.5 `src/input/encode.rs`:
  <https://github.com/herdrdev/herdr/blob/v0.7.5/src/input/encode.rs>
* Alacritty 0.17.0 keyboard input implementation:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/alacritty/src/input/keyboard.rs>
* Alacritty 0.17.0 binding configuration:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/extra/man/alacritty.5.scd>
* Kitty keyboard protocol:
  <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>

