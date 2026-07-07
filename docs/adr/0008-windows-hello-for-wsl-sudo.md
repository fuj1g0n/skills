---
status: rejected
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Windows Hello authentication for sudo inside WSL

## Context and Problem Statement

When GitHub Copilot CLI runs inside WSL2 and an operation requires `sudo`,
the user must type the Linux password. It would be more convenient to
approve such requests through Windows Hello (face, fingerprint, PIN) on the
Windows host instead. Can and should such a mechanism be adopted?

Survey outcome: the de-facto (and effectively only) solution is
[WSL-Hello-sudo](https://github.com/nullpo-head/WSL-Hello-sudo), a
community PAM module. A Linux PAM module plus a small Windows helper show a
Windows Hello dialog on the host via WSL interop; authentication is proven
by a Hello-signed RSA challenge verified by the PAM module, so biometric
data never crosses into Linux. It works with current WSL2/Windows 11 per
continued community reports, but it is not supported by Microsoft, and
upstream development has been largely stalled since 2021–22.

## Decision Drivers

* `sudo` authentication is a system-privilege security boundary; components
  wired into PAM at this boundary must be trustworthy long-term.
* No official Microsoft solution exists for Windows Hello → WSL sudo; the
  only candidate is an unofficial community project with stalled upstream
  maintenance.

## Considered Options

* Adopt WSL-Hello-sudo (community PAM module bridging sudo to Windows Hello)
* Keep standard password-based sudo (status quo)

## Decision Outcome

Rejected option: "Adopt WSL-Hello-sudo". Standard password-based sudo is
kept. Although the mechanism is technically sound (host-side Hello dialog,
challenge-response, no secrets entering Linux) and fits the Copilot CLI
approval use case, inserting an unofficial, largely unmaintained
community module into the PAM stack of a system-privilege path is an
unacceptable trust trade-off. This rejection should stick unless an
officially supported solution appears.

### Consequences

* Good, because the PAM stack for sudo contains only distribution-supported
  components.
* Bad, because approving Copilot-initiated sudo operations still requires
  typing the Linux password, which is less convenient than a Windows Hello
  prompt.

## More Information

Survey performed 2026-07-07 in conversation with GitHub Copilot CLI; the
decision-relevant essence is embedded above (ADR-0006 tier-1, no separate
research snapshot).
