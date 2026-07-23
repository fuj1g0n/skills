#!/usr/bin/env bash
# Install upstream Nix in single-user mode (store owned by the container
# user, no daemon, no build users; ADR-0012) and set up direnv + nix-direnv
# so the flake devShell loads automatically.
set -euo pipefail

# Constraint (ADR-0011): the container user is fixed to vscode (UID 1000).
# The Nix store is owned by this user; a different user or a rewritten UID
# (updateRemoteUserUID on a host whose UID is not 1000) would break the
# single-user store, so fail fast instead of breaking implicitly.
if [ "$(id -un)" != "vscode" ] || [ "$(id -u)" != "1000" ]; then
  echo "ERROR: this devcontainer requires user vscode with UID 1000 (got $(id -un)/$(id -u))." >&2
  echo "Your host user's UID is probably not 1000; see docs/adr/0011-fix-devcontainer-user-to-vscode-uid-1000.md." >&2
  exit 1
fi

# Pinned upstream Nix installer (hash-verified; the script embeds per-arch
# tarball sha256s, so verification chains through to the Nix tarball).
NIX_VERSION=2.31.2
NIX_INSTALLER_SHA256=078e2ffeddf6a9c1f22adf41458ccc46a58bb26911a9e01579645314f9982994

# The /nix volume mount point is created root-owned; hand it to the container
# user once (non-recursive, O(1)). This is the only step that needs root:
# the installer itself runs as vscode and creates a vscode-owned store.
if [ ! -w /nix ]; then
  sudo chown vscode: /nix
fi

if [ ! -e ~/.nix-profile ]; then
  # In single-user mode the nix CLI lives in the user profile, which sits
  # under $HOME and is lost when the container is rebuilt. The store in the
  # /nix volume survives, so rebuild the profile from it without network.
  nix_pkg=$(compgen -G "/nix/store/*-nix-${NIX_VERSION}" | head -n1 || true)
  if [ -n "${nix_pkg}" ]; then
    echo "Reusing existing /nix volume; rebuilding user profile from the store..."
    cacert_pkg=$(compgen -G "/nix/store/*-nss-cacert-*" | grep -v '\.drv$' | head -n1)
    "${nix_pkg}/bin/nix-env" -i "${nix_pkg}" "${cacert_pkg}"
  else
    # Fresh /nix volume: run the pinned upstream installer as vscode.
    # --no-daemon: single-user mode; the invoking user owns the store.
    echo "Installing Nix ${NIX_VERSION} (single-user)..."
    curl --proto '=https' --tlsv1.2 -fsSL \
      "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
      -o /tmp/nix-install.sh
    echo "${NIX_INSTALLER_SHA256}  /tmp/nix-install.sh" | sha256sum -c -
    sh /tmp/nix-install.sh --no-daemon --yes --no-channel-add --no-modify-profile
    rm /tmp/nix-install.sh
  fi
fi

# User-level Nix configuration ($HOME is ephemeral, so written idempotently).
# - flakes are still experimental in upstream Nix;
# - Nix sandboxing needs root or unprivileged user namespaces; the container
#   itself provides the isolation (ADR-0010).
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf <<'NIXCONF'
experimental-features = nix-command flakes
sandbox = false
NIXCONF

# Load Nix into this script's environment.
# shellcheck source=/dev/null
. ~/.nix-profile/etc/profile.d/nix.sh

# VS Code terminals are non-login shells, so ~/.profile is not read;
# load Nix from .bashrc instead.
if ! grep -q "nix.sh" ~/.bashrc; then
  echo "Configuring Nix profile for bash..."
  echo '[ -e ~/.nix-profile/etc/profile.d/nix.sh ] && . ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
fi

# Install direnv/nix-direnv/nil user-wide from this flake (pinned by
# flake.lock). direnv cannot live only in the devShell: it must exist before
# the shell loads.
echo "Installing global packages via Nix profile..."
if ! command -v direnv > /dev/null 2>&1; then
  nix profile add .#direnv .#nix-direnv
fi
# nil is user-wide because the VS Code Nix extension does not see the direnv env.
if ! command -v nil > /dev/null 2>&1; then
  nix profile add .#nil
fi

# nix-direnv: cache devShell evaluation for fast direnv loads.
if [ ! -f ~/.config/direnv/direnvrc ] || ! grep -q "nix-direnv" ~/.config/direnv/direnvrc; then
  echo "Configuring nix-direnv..."
  mkdir -p ~/.config/direnv
  cat >> ~/.config/direnv/direnvrc <<'DIRENVRC'
# Use nix-direnv for cached `use flake`.
source $HOME/.nix-profile/share/nix-direnv/direnvrc
DIRENVRC
fi

# shellcheck disable=SC2016
if ! grep -q "direnv hook bash" ~/.bashrc; then
  echo "Configuring direnv hook for bash..."
  echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
fi

# Build the devShell now so the first terminal is instant.
echo "Building Nix development environment..."
eval "$(nix print-dev-env)"

echo "Allowing direnv for future shell sessions..."
direnv allow

echo "Setup complete!"
