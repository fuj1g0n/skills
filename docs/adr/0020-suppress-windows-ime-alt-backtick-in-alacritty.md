---
type: Architecture Decision Record
status: accepted
date: 2026-08-04
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Suppress Windows IME Alt+backtick terminal input in Alacritty

## Context and Problem Statement

On Windows with a US keyboard layout, `Alt+backtick` toggles the
Microsoft Japanese IME. Alacritty correctly delivers no character to
a local Git Bash prompt, but a remote Herdr workflow inserts a literal
backtick.

The devbox launcher starts `herdr --remote devbox` inside WSL. The Unix
Herdr client enables Kitty keyboard progressive enhancement, causing
Alacritty to reconstruct a CSI-u Alt-backtick key even though Windows
consumed the chord as an IME command and produced no committed text.
Herdr then converts the key to legacy `ESC` plus backtick for the pane.

How should the environment preserve the existing US layout and IME
shortcut without leaking a backtick into Herdr panes?

## Decision Drivers

* Keep the Windows US keyboard layout.
* Keep `Alt+backtick` as the Japanese IME toggle.
* Preserve Herdr remote attach and its other enhanced-key behavior.
* Minimize scope, maintenance, and dependence on unreleased upstream
  changes.
* Make the workaround explicit, reversible, and locally deployable.

## Considered Options

* Suppress `Alt+backtick` with an Alacritty `None` binding
* Use a plain SSH shell instead of Herdr
* Change the Windows IME toggle shortcut
* Disable Kitty keyboard enhancement in Herdr
* Patch Alacritty's handling of Windows IME-consumed keys

## Decision Outcome

Chosen option: "Suppress `Alt+backtick` with an Alacritty `None`
binding", because Windows handles the IME shortcut before Alacritty's
terminal key binding, while Alacritty can prevent the reconstructed
key from reaching the PTY:

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

The binding is deployed in the Windows user configuration at
`%APPDATA%\alacritty\alacritty.toml`.

### Consequences

* Good, because the US keyboard layout and existing IME shortcut stay
  unchanged.
* Good, because Herdr retains Kitty keyboard disambiguation for every
  other key.
* Good, because the workaround is a documented Alacritty feature and
  requires no fork.
* Good, because Alacritty reloads the configuration without replacing
  or restarting the remote Herdr server.
* Bad, because intentional `Alt+backtick` input is suppressed in all
  Alacritty sessions, not only while Herdr is active.
* Bad, because the workaround lives in user-level terminal
  configuration and is not distributed automatically by this
  repository.
* Neutral, because a future Herdr or Alacritty fix may make the
  binding unnecessary; remove it only after reproducing correct
  behavior without the binding.

## Pros and Cons of the Options

### Suppress `Alt+backtick` in Alacritty

* Good, because it targets only the conflicting chord.
* Good, because it preserves the rest of the enhanced keyboard
  protocol.
* Bad, because Alacritty cannot scope a binding to Kitty
  `DISAMBIGUATE_ESCAPE_CODES` mode, so the suppression is global.

### Use a plain SSH shell instead of Herdr

* Good, because a shell that does not enable Kitty keyboard
  enhancement does not reconstruct the consumed key.
* Bad, because it removes persistent Herdr workspace and agent
  management functionality.

### Change the Windows IME toggle shortcut

* Good, because it avoids the key collision at the operating-system
  layer.
* Bad, because it changes an established shortcut and does not address
  the terminal interoperability defect.

### Disable Kitty keyboard enhancement in Herdr

* Good, because it restores legacy Alacritty behavior for the entire
  Herdr client.
* Bad, because Herdr 0.7.5 and 0.8.0 expose no such configuration.
* Bad, because disabling the protocol loses modified-key
  disambiguation and key press/release reporting.

### Patch Alacritty's Windows IME handling

* Good, because it could distinguish an IME-consumed event from an
  intentional terminal key.
* Bad, because it requires an upstream implementation and careful
  compatibility analysis across Windows IMEs and keyboard layouts.

## More Information

Research snapshot:
[2026-08-04-alacritty-herdr-windows-ime-alt-backtick](../research/2026-08-04-alacritty-herdr-windows-ime-alt-backtick.md).

Revisit this decision when Herdr offers a host keyboard protocol
opt-out or Alacritty stops encoding Windows IME-consumed
`Alt+backtick` events under Kitty keyboard disambiguation.

