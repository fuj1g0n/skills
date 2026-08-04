# Research: Alacritty emits a modifier-free repeat after the Windows Japanese IME shortcut

Date: 2026-08-04
Author: @fuj1g0n (with GitHub Copilot CLI)
Status: superseded
Superseded by:
[2026-08-04-alacritty-winit-ime-release-repeat-trace](2026-08-04-alacritty-winit-ime-release-repeat-trace.md)

## Supersession notice

This document remains the authoritative raw-byte capture, but its
component attribution was incomplete before Alacritty event tracing
was available. The final trace established that winit supplied a
Backquote event with `state=Released, repeat=true`, and Alacritty
encoded it as a Kitty Repeat because `repeat` takes precedence over
`Released`.

Use the superseding event-trace research for root-cause attribution
and fix recommendations.

## Question

An earlier investigation found that pressing `Alt+backtick`, the
Microsoft Japanese IME toggle on a US keyboard layout, can insert a
literal backtick while Alacritty is attached to Herdr. An Alacritty
binding was deployed to suppress the chord:

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

The binding reduced the frequency but did not eliminate the insertion.
Which component emits the remaining input, and why is the behavior
intermittent?

## Environment

* Windows 11 with Microsoft Japanese IME
* US keyboard layout
* Alacritty 0.17.0
* Git Bash as the Alacritty shell
* WSL Herdr client 0.7.5
* Remote Herdr server 0.7.5
* `TERM=xterm-256color`
* Alacritty binding shown above

No upstream issue should be filed from this investigation without
explicit user approval.

## Experiment 1: Is the binding loaded and effective?

A diagnostic Alacritty window was launched with the user config
specified explicitly. Its child process:

1. enabled Kitty keyboard flags value 7 with `CSI > 7 u`;
2. put the PTY in raw, no-echo mode;
3. copied stdin bytes to a capture file for 20 seconds.

Pressing the IME shortcut produced a zero-length capture.

The experiment was repeated without `--config-file`, using Alacritty's
normal Windows config discovery. It also produced a zero-length
capture.

These results establish that:

* `%APPDATA%\alacritty\alacritty.toml` is loaded during normal startup;
* the `Alt+backtick` `None` binding matches and suppresses the ordinary
  Alt-modified event;
* enabling Kitty flags alone is insufficient to reproduce the leak
  after the binding is installed.

## Experiment 2: Capture the complete Herdr path

The normal devbox workflow was launched in a dedicated Alacritty
window:

```text
Alacritty
  -> Git Bash
  -> devbox.sh
  -> wsl.exe
  -> herdr --remote devbox
  -> remote Herdr server
```

The WSL client used:

```text
HERDR_LOG=herdr::raw_input=debug,herdr::client::input=debug
```

Pressing the same IME shortcut inserted a backtick. Herdr's local
raw-input log captured:

```text
raw_bytes=[27, 91, 57, 54, 59, 49, 58, 50, 117]
event=Key(TerminalKey {
  code: Char('`'),
  modifiers: KeyModifiers(0x0),
  kind: Repeat,
  shifted_codepoint: None
})
```

The bytes decode to:

```text
ESC [ 96 ; 1 : 2 u
```

Under the Kitty keyboard protocol:

* `96` is the backtick code point;
* modifier value `1` means no modifiers;
* event type `2` means Repeat.

The same sequence appeared more than once during the diagnostic
session:

```text
2026-08-04T01:52:21.300207Z ESC [ 96 ; 1 : 2 u
2026-08-04T01:52:27.745794Z ESC [ 96 ; 1 : 2 u
```

## Interpretation

The remaining input originates before Herdr's parser. Herdr receives a
fully formed Kitty CSI-u sequence from its outer terminal and decodes
it according to the protocol.

The observed lifecycle is:

1. The user presses `Alt+backtick`.
2. The Alacritty `Alt+backtick` binding suppresses the ordinary
   Alt-modified event.
3. Depending on Windows IME and key-event timing, a later event is
   reported as a backtick Repeat with no Alt modifier.
4. The binding no longer matches because the modifier set is empty.
5. Alacritty encodes the event as `CSI 96;1:2 u`.
6. Herdr parses and forwards the backtick to the pane.

This explains the intermittent result: it depends on whether the
modifier-free Repeat is generated, not on whether the configuration
was loaded.

## Component attribution

The primary defect is in the Alacritty/winit Windows input path, not in
Herdr, SSH, or the remote server:

* Alacritty is the component that emits the modifier-free Kitty
  sequence.
* Subsequent event tracing proved that winit supplied a Backquote
  release with `repeat=true`.
* Alacritty encoded that release as Kitty Repeat because its encoder
  checks `repeat` before `Released`.
* Alacritty release events bypass normal key-binding processing, so the
  configured binding cannot suppress the anomalous event.

Herdr could defensively ignore a Repeat without a previously observed
Press, but that would be resilience against malformed or incomplete
host input rather than the origin of the event. Herdr 0.8.0's input
lease implementation intentionally reprocesses semantic repeats when
no lease exists, so upgrading alone is not expected to hide this host
event.

## Workaround assessment

The existing Alacritty binding is a partial mitigation:

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

It suppresses the initial Alt-modified event but cannot match the
later modifier-free Repeat. Adding a no-modifier backtick binding would
also suppress legitimate backtick typing and is therefore not
acceptable.

A complete fix should preserve suppression across the physical key
lifecycle, or prevent Windows IME-consumed Alt+backtick events from
being encoded as Kitty repeats. This belongs primarily in
Alacritty/winit. No Alacritty issue has been filed pending explicit
approval.

## Relationship to the other research

The earlier snapshot
[2026-08-04-alacritty-herdr-windows-ime-alt-backtick](2026-08-04-alacritty-herdr-windows-ime-alt-backtick.md)
contained an unsupported mechanism: it inferred an Alt-modified
backtick press that was not present in the final event trace. It also
overestimated the Alacritty binding and assigned too much causal
responsibility to Herdr.

This raw-byte capture disproved part of that initial hypothesis. The
later
[event-trace research](2026-08-04-alacritty-winit-ime-release-repeat-trace.md)
completed the attribution between winit and Alacritty and supersedes
this document's original uncertainty.

## Sources

* Local raw-byte and Herdr debug captures recorded on 2026-08-04
* Alacritty 0.17.0 keyboard input implementation:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/alacritty/src/input/keyboard.rs>
* Alacritty 0.17.0 binding configuration:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/extra/man/alacritty.5.scd>
* Kitty keyboard protocol:
  <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>
* Herdr 0.8.0 input leases:
  <https://github.com/herdrdev/herdr/blob/v0.8.0/src/app/input/lease.rs>
* Herdr 0.8.0 input runtime:
  <https://github.com/herdrdev/herdr/blob/v0.8.0/src/app/runtime.rs>
