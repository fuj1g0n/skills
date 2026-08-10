# Research: Initial Windows IME backtick hypothesis (superseded)

Date: 2026-08-04
Author: @fuj1g0n (with GitHub Copilot CLI)
Status: superseded
Superseded by:
[2026-08-04-alacritty-winit-ime-release-repeat-trace](2026-08-04-alacritty-winit-ime-release-repeat-trace.md)

## Correction notice

Do not use this document as the current root-cause analysis.

The initial investigation incorrectly inferred that Alacritty
reconstructed an Alt-modified backtick press and that Herdr then
converted that press to legacy pane input. Later byte-level and
Alacritty event-level captures disproved that mechanism.

The observed event is instead:

```text
Backquote physical key, logical_key=Character("`"),
  state=Released, repeat=true
```

Alacritty encodes this anomalous release as a modifier-free Kitty
Repeat because its event-type selection checks `repeat` before
`Released`:

```text
ESC [ 96 ; 1 : 2 u
```

Herdr correctly parses and forwards that already formed sequence. It
reveals the defect because it enables Kitty event reporting, but it
does not originate the malformed lifecycle.

## Original question

Why does pressing `Alt+backtick`, the Windows Japanese IME toggle on a
US keyboard layout, intermittently insert a literal backtick while
Alacritty is attached to a remote Herdr session, even though the same
shortcut does not insert anything in a local Git Bash prompt?

The keyboard layout must remain US. The desired behavior is for
Windows to toggle the IME without delivering a backtick to the
terminal application.

## Environment

Observed on 2026-08-04:

* Windows 11 with the Microsoft Japanese IME and a US keyboard layout
* Alacritty 0.17.0
* winit 0.30.13
* Windows Alacritty config starts Git Bash
* WSL Herdr client 0.7.5
* Remote devbox Herdr server 0.7.5
* Outer terminal `TERM=xterm-256color`
* WSL and remote locale `C.UTF-8`

The effective path is:

```text
Alacritty
  -> Git Bash
  -> wsl.exe
  -> herdr --remote devbox
  -> SSH remote-client bridge
  -> remote Herdr server
  -> pane PTY
```

## Findings that remain valid

### Herdr enables Kitty keyboard progressive enhancement

Herdr 0.7.5 calls `PushKeyboardEnhancementFlags` on non-Windows
clients. The requested flags are:

* `DISAMBIGUATE_ESCAPE_CODES`
* `REPORT_EVENT_TYPES`
* `REPORT_ALTERNATE_KEYS`

This activates Kitty keyboard protocol handling in Alacritty. Herdr
does not currently expose a configuration option to disable these host
keyboard enhancements.

The protocol changes visibility, not origin: it lets Alacritty express
the anomalous host key event as a typed Kitty Repeat. It does not mean
that Herdr generated the event.

### The emitted bytes are a modifier-free Kitty Repeat

The complete Herdr path captured:

```text
ESC [ 96 ; 1 : 2 u
```

Under the Kitty keyboard protocol:

* `96` is the backtick code point;
* modifier value `1` means no modifiers;
* event type `2` means Repeat.

Herdr decoded those bytes as a modifier-free backtick Repeat. This
behavior is protocol-conformant for the bytes it received.

### The malformed lifecycle exists before Herdr input parsing

Alacritty event tracing recorded the Backquote release as:

```text
logical_key=Character("`"), state=Released, repeat=true
```

winit derives `repeat` from Windows key-message state bits and does
not constrain it to pressed events. Alacritty then prioritizes the
repeat flag over the release state when selecting the Kitty event
type. The inserted character therefore originates in the
Alacritty/winit Windows input stack.

## Corrected root cause

The root cause is a combination of two host-input behaviors:

1. Windows and the Microsoft IME produce an unusual transformed
   Backquote release lifecycle.
2. winit exposes the release with `repeat=true`.
3. Alacritty checks `repeat` before `Released` and emits Kitty event
   type `2` rather than release event type `3`.
4. Herdr parses and forwards the resulting Repeat.

SSH, the remote locale, the US keyboard layout, and Herdr's parser are
not the source of the malformed event.

## Corrected workaround assessment

The deployed binding is only a partial mitigation:

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

It can suppress an Alt-modified press but cannot suppress the later
modifier-free release. Alacritty bypasses normal key-binding
processing for release events. A no-modifier backtick binding would
also disable legitimate backtick input and is not acceptable.

There is no safe configuration-only complete workaround that preserves
both the current IME shortcut and normal backtick input. The preferred
implementation fixes are:

1. winit normalizes `repeat` to false for released keys.
2. Alacritty prioritizes `Released` over `repeat` when encoding Kitty
   event types.

Herdr could reject orphan repeats defensively, but that would be a
robustness measure rather than the primary fix.

## Incorrect conclusions removed

The following claims from the original version are not supported by
the final captures and must not be repeated:

* that Alacritty emitted an Alt-modified `CSI 96;3u` press for the IME
  chord;
* that Herdr's legacy pane encoder was the cause of the visible
  backtick;
* that the `Alt+backtick` `None` binding was a complete workaround;
* that a Herdr host-keyboard opt-out was the preferred root fix.

## Sources

* Final event-level attribution:
  [2026-08-04-alacritty-winit-ime-release-repeat-trace](2026-08-04-alacritty-winit-ime-release-repeat-trace.md)
* Raw-byte capture:
  [2026-08-04-alacritty-windows-ime-orphan-repeat-capture](2026-08-04-alacritty-windows-ime-orphan-repeat-capture.md)
* Alacritty 0.17.0 keyboard input implementation:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/alacritty/src/input/keyboard.rs>
* winit 0.30.13 Windows keyboard implementation:
  <https://github.com/rust-windowing/winit/blob/v0.30.13/src/platform_impl/windows/keyboard.rs>
* Kitty keyboard protocol:
  <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>
