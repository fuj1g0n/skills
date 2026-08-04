# Research: Windows IME key release is encoded as a Kitty repeat

Date: 2026-08-04
Author: @fuj1g0n (with GitHub Copilot CLI)
Status: immutable snapshot

## Question

Earlier captures established that Alacritty emits a modifier-free Kitty
backtick Repeat after the Microsoft Japanese IME consumes
`Alt+backtick`. Does Herdr cause the event, or is it already malformed
inside the Alacritty/winit Windows input path?

No upstream issue should be filed from this investigation without
explicit user approval.

## Environment

* Windows 11 with Microsoft Japanese IME
* US keyboard layout
* Alacritty 0.17.0
* winit 0.30.13
* Git Bash as the Alacritty shell
* WSL Herdr client 0.7.5
* Remote Herdr server 0.7.5
* `TERM=xterm-256color`
* Alacritty `Alt+backtick` `None` binding

## Alacritty event trace

Full Alacritty and winit event logging was enabled during the normal
Herdr workflow. The literal backtick was reproduced twice.

The decisive event sequence was:

```text
ModifiersChanged: ALT
AltLeft Pressed, repeat=false
Backquote physical key, logical_key=KanjiMode,
  state=Pressed, repeat=false
ModifiersChanged: none
AltLeft Released, repeat=false
Backquote physical key, logical_key=Character("`"),
  state=Released, repeat=true
```

The second reproduction had the same lifecycle. The Backquote press
was reported as `KanjiMode`, in that instance with `repeat=true`, and
the release again changed to `Character("`")` with
`state=Released, repeat=true`.

This trace was recorded before Alacritty wrote terminal input bytes.
It therefore rules out Herdr, SSH, and the remote server as the source
of the malformed key lifecycle.

## How the release becomes visible input

Alacritty 0.17.0 chooses the Kitty keyboard event type with:

```rust
let event_type = match key.state {
    _ if key.repeat => '2',
    ElementState::Pressed => '1',
    ElementState::Released => '3',
};
```

Because `repeat` is tested before `Released`, the anomalous
`Released + repeat=true` event is encoded as event type `2` (Repeat),
not event type `3` (Release):

```text
ESC [ 96 ; 1 : 2 u
```

Alacritty also returns before processing configured key bindings for
release events. The configured `Alt+backtick` binding can consume the
ordinary press event, but it cannot consume this later release. At
that point winit also reports no Alt modifier and a logical backtick,
so the original binding would not match in any case.

Herdr receives a complete Kitty sequence and correctly decodes it as:

```text
Backquote, modifiers=none, kind=Repeat
```

It then forwards the semantic Repeat to the active pane. Herdr exposes
the problem, but does not create it.

## Why winit marks the release as a repeat

winit 0.30.13 derives `KeyEvent.repeat` from the Windows key-message
`lParam` state bits:

```rust
let previous_state = (lparam >> 30) & 0x01;
let transition_state = (lparam >> 31) & 0x01;
is_repeat: (previous_state ^ transition_state) != 0,
```

For normal keyboard messages, this identifies repeated key-down
messages while leaving a normal key-up message non-repeated. During
this IME transformation, however, Windows supplies a release whose
state bits make the expression true. winit forwards the result without
constraining repeats to `ElementState::Pressed`.

winit documents `repeat=true` as an event caused by key repetition.
The observed `Released + repeat=true` event does not represent a
usable repeated key-down event, regardless of whether its unusual
state bits originate in Windows or the IME.

## Current upstream status

The relevant behavior is unchanged on both upstream default branches
as inspected on 2026-08-04:

* winit `master` still assigns `lparam_struct.is_repeat` directly to
  every `KeyEvent`, and still calculates it as
  `previous_state XOR transition_state`;
* Alacritty `master` still tests `key.repeat` before
  `ElementState::Released` when selecting the Kitty event type.

No existing upstream change therefore appears to resolve this exact
path.

## Attribution

| Component | Role | Assessment |
| --- | --- | --- |
| Windows / Microsoft IME | Produces an unusual transformed Backquote release lifecycle | Triggering platform behavior |
| winit | Exposes the release as `repeat=true` and changes its logical key from `KanjiMode` to backtick | Primary normalization defect |
| Alacritty | Encodes the repeat flag before the release state and bypasses bindings for releases | Primary terminal-encoding defect |
| Herdr | Enables Kitty event reporting, parses the resulting CSI-u sequence, and forwards it | Reveals the defect; not its origin |
| SSH / remote server | Transports already encoded input | Not causal |

The issue is therefore in the Alacritty/winit Windows input stack, not
primarily in Herdr. The most precise attribution is shared:

1. winit should not expose a release as a repeat event.
2. Alacritty should not encode any released key as a Kitty Repeat,
   even if an upstream event contains an inconsistent repeat flag.

Herdr can add defensive filtering, but that would be robustness
against malformed terminal input rather than the root fix.

## Fix candidates

### winit: constrain repeat to pressed events

winit can normalize `repeat` to false for
`ElementState::Released`. This aligns the event with winit's documented
meaning and prevents downstream applications from treating a key-up
message as repeated text input.

This is the earliest generally useful fix.

### Alacritty: prioritize release over repeat

Alacritty can select the Kitty event type in this order:

```rust
let event_type = match key.state {
    ElementState::Released => '3',
    _ if key.repeat => '2',
    ElementState::Pressed => '1',
};
```

This is a narrow defensive fix. A malformed winit release would remain
visible to Alacritty, but Kitty-aware applications would receive a
Release instead of a text-producing Repeat.

### Alacritty: suppress the complete consumed key lifecycle

Alacritty could retain suppression for the physical key from a matched
press through its release. This would make the existing binding robust
against modifier and logical-key changes, but it is a larger input
state-machine change than correcting the event type.

### Herdr: reject orphan repeats

Herdr could ignore a Repeat when it has not observed a corresponding
Press. This may protect panes from malformed host events, but requires
care around attach boundaries, focus changes, dropped events, and
legitimate terminal repeat streams. It is not the preferred primary
fix.

## Workaround assessment

The deployed Alacritty binding remains only a frequency-reducing
mitigation:

```toml
[[keyboard.bindings]]
key = "`"
mods = "Alt"
action = "None"
```

There is no safe configuration-only rule that suppresses the later
modifier-free backtick without also disabling legitimate backtick
input. Until an implementation fix is available, complete local
workarounds require either changing the IME shortcut, avoiding Kitty
event reporting for this workflow, or running a patched terminal
build. The first option conflicts with the stated user preference, and
Herdr currently offers no configuration to select the second.

## Conclusion

The direct cause of the inserted backtick is not Herdr. An
IME-transformed Backquote release reaches Alacritty from winit as
`Released + repeat=true`; Alacritty then prioritizes the repeat flag
and emits a modifier-free Kitty Repeat. Herdr parses that valid wire
representation as instructed.

The strongest fix is defense in depth: normalize release events in
winit and prioritize release state in Alacritty's Kitty encoder. No
upstream issue or pull request has been created.

## Sources

* Local Alacritty/winit event trace recorded on 2026-08-04
* Local Herdr raw-byte trace recorded on 2026-08-04
* Alacritty 0.17.0 keyboard input implementation:
  <https://github.com/alacritty/alacritty/blob/v0.17.0/alacritty/src/input/keyboard.rs>
* Current Alacritty keyboard input implementation:
  <https://github.com/alacritty/alacritty/blob/master/alacritty/src/input/keyboard.rs>
* winit 0.30.13 Windows keyboard implementation:
  <https://github.com/rust-windowing/winit/blob/v0.30.13/src/platform_impl/windows/keyboard.rs>
* Current winit Windows keyboard implementation:
  <https://github.com/rust-windowing/winit/blob/master/winit-win32/src/keyboard.rs>
* Kitty keyboard protocol:
  <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>
* Prior raw-byte capture:
  [2026-08-04-alacritty-windows-ime-orphan-repeat-capture](2026-08-04-alacritty-windows-ime-orphan-repeat-capture.md)
