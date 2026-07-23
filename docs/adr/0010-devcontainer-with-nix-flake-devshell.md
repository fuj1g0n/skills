---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Development environment using a Nix Flake devShell inside a Dev Container

## Context and Problem Statement

We want the development environment of this repository to be Dev
Container based. The user's host environment is built on Nix (language
runtimes are supplied one-shot via nix shell or flake devShells), and this
Nix-based provisioning should be preserved after containerization.

The motivations for containerizing are:

* Run AI agents autonomously in an environment isolated from the host.
* Distribute the development environment with high reproducibility.

The question is how to combine Nix with Dev Containers. References:
[Combining Nix Flakes with Dev Containers (Qiita)](https://qiita.com/sigma_devsecops/items/8c33553be0f123413c41),
[Building a Nix Flake environment on a DevContainer (ncaq)](https://www.ncaq.net/2026/01/16/14/18/49/).

## Decision Drivers

* Isolation from the host: reduce the risk of host contamination from
  autonomous AI agent runs and downloaded files.
* Reproducibility: carry the commit/hash-based dependency pinning of
  flake.lock over to the distributed environment as-is.
* Consistency with the host's Nix-based workflow: centralize tool
  definitions in flake.nix; do not maintain a separate tool list in a
  Dockerfile for the container.

## Considered Options

* Approach 1: install Nix via postCreateCommand inside a generic
  devcontainer image and persist /nix in a volume
* Approach 2: build the container image itself with Nix (dockerTools in
  flake.nix) and connect to it from Dev Containers
* Keep the current workflow of running nix develop directly on the host
  (no containerization)

## Decision Outcome

Chosen option: "Approach 1: install Nix via postCreateCommand inside a
generic devcontainer image and persist /nix in a volume", because the
referenced write-ups verified that Approach 1 works in practice, and it
lets us use an official devcontainer image where the VS Code Server runs
while keeping tool definitions centralized in flake.nix. Approach 2 has
significant friction with Dev Containers requirements (VS Code Server
operation etc.), just like the `nixos/nix` image. Staying uncontainerized
fails the isolation driver.

Implementation outline (following the referenced articles):

* Base image is an official `mcr.microsoft.com/devcontainers/base` image.
* Nix is installed via postCreateCommand using the same Determinate Nix
  as the host. Since the container has no systemd, use the Determinate
  Nix Installer's `--init none` planner, create no build users with
  `--nix-build-user-count 0`, and after installation chown `/nix` to the
  container user to operate in single-user (daemonless) mode. Build users
  are what the root daemon uses for sandboxed builds; in single-user mode
  where the store is owned by the user, neither the daemon nor build
  users are needed. Set `sandbox = false` because the container itself
  provides isolation. Pin the installer version and verify its sha256.
* Mount `/nix` as a named volume to persist the store and avoid
  re-downloads on container re-creation. `/etc/nix` lives outside the
  volume, so restore it from a backup kept inside the volume on container
  re-creation.
* Use direnv + nix-direnv so the flake devShell is loaded automatically
  at shell startup. direnv itself does not work if merely put into the
  devShell, so install it globally via nix profile.
* Define tools in the flake.nix devShell.

### Consequences

* Good, because AI agents can run autonomously in an environment isolated
  from the host.
* Good, because flake.lock reproduces the identical development
  environment at distribution targets.
* Good, because tool definitions are centralized in flake.nix with no
  duplicate management in a Dockerfile.
* Bad, because the first container creation runs the Nix install and
  devShell build, making startup slow (mitigated from the second time on
  by the persisted /nix volume).
* Bad, because the postCreateCommand setup script becomes complex and
  needs Dev Container-specific handling such as restoring /etc/nix when
  the /nix volume is reused.
* Bad, because compared to running directly on the host there are more
  layers, and more things to debug such as VS Code's non-login-shell
  issue.

### Confirmation

Create the devcontainer (Reopen in Container) and confirm that the flake
devShell tools are on PATH in a terminal, and that after container
re-creation the /nix volume is reused with no re-downloading.

## More Information

See the [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md)
for the detailed investigation.
Of the implementation outline, the installer selection (Determinate Nix
Installer + root install + chown + `/etc/nix` restore) was superseded by
[ADR-0012](0012-use-upstream-installer-single-user-mode.md) (upstream
official installer in single-user mode). The core decision (Approach 1)
remains in effect.

* [Distributing a secure, highly reproducible development environment by combining Nix Flakes and Dev Containers (Qiita)](https://qiita.com/sigma_devsecops/items/8c33553be0f123413c41) — comparative verification of Approach 1 / Approach 2.
* [Building a Nix Flake environment on a DevContainer (ncaq)](https://www.ncaq.net/2026/01/16/14/18/49/) — implementation details of Approach 1 (postCreateCommand.sh, nix-direnv, Cachix netrc, etc.).
