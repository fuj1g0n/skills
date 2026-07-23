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

# Upstream nix.sh silently does nothing when $USER is unset (its first line
# guards on both HOME and USER), and lifecycle scripts are not guaranteed a
# login environment. Pin it explicitly.
export USER="${USER:-$(id -un)}"

# Pinned upstream Nix installer (hash-verified; the script embeds per-arch
# tarball sha256s, so verification chains through to the Nix tarball).
NIX_VERSION=2.31.2
NIX_INSTALLER_SHA256=078e2ffeddf6a9c1f22adf41458ccc46a58bb26911a9e01579645314f9982994

# Store path of the bootstrap Nix, recorded inside the /nix volume so a
# rebuilt container can restore the user profile offline and
# deterministically (the user profile symlink lives under $HOME and is lost
# on container re-creation; the store survives in the volume).
BOOTSTRAP_MANIFEST=/nix/.bootstrap-paths

# The /nix volume mount point is created root-owned; hand it to the container
# user once (non-recursive, O(1)). This is the only step that needs root:
# the installer itself runs as vscode and creates a vscode-owned store.
if [ ! -w /nix ]; then
  sudo chown vscode: /nix
fi

if [ ! -e ~/.nix-profile ]; then
  bootstrap_nix=""
  if [ -f "${BOOTSTRAP_MANIFEST}" ]; then
    bootstrap_nix=$(head -n 1 "${BOOTSTRAP_MANIFEST}")
  fi
  if [ -n "${bootstrap_nix}" ] && [ -x "${bootstrap_nix}/bin/nix-env" ]; then
    # Reused /nix volume: rebuild the user profile from the exact store
    # path recorded at install time (no network, no globbing heuristics).
    echo "Reusing existing /nix volume; rebuilding user profile from the store..."
    "${bootstrap_nix}/bin/nix-env" -i "${bootstrap_nix}"
  else
    # Fresh /nix volume, a volume from a pre-manifest script version, or a
    # missing/corrupt manifest: run the pinned upstream installer as vscode.
    # It tolerates an existing /nix, copying missing store paths and
    # rebuilding the profile.
    # --no-daemon: single-user mode; the invoking user owns the store.
    echo "Installing Nix ${NIX_VERSION} (single-user)..."
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
      "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
      -o /tmp/nix-install.sh
    echo "${NIX_INSTALLER_SHA256}  /tmp/nix-install.sh" | sha256sum -c -
    sh /tmp/nix-install.sh --no-daemon --yes --no-channel-add --no-modify-profile
    rm /tmp/nix-install.sh
  fi
fi

# Record the bootstrap store path for the next container re-creation
# (idempotent; resolved through the profile symlink, so always current).
# The single-user installer puts only the nix package in the profile;
# TLS certs come from the base image via nix.sh's /etc/ssl fallback.
nix_bin=$(readlink -f ~/.nix-profile/bin/nix)
echo "${nix_bin%/bin/nix}" > "${BOOTSTRAP_MANIFEST}"

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

# Install user-wide packages from this flake (pinned by flake.lock), each
# individually guarded so a partial previous state is repaired instead of
# skipped (nix profile add errors on packages that are already installed).
# - direnv/nix-direnv cannot live only in the devShell: they must exist
#   before the shell loads (bootstrap problem).
# - nil and nixfmt are user-wide as a pair: the VS Code Nix extension
#   launches nil outside the direnv environment, and nil in turn spawns
#   nixfmt (see nix.serverSettings in devcontainer.json), so both must
#   resolve without the devShell on PATH.
echo "Installing global packages via Nix profile..."
command -v direnv > /dev/null 2>&1 || nix profile add .#direnv
[ -e ~/.nix-profile/share/nix-direnv/direnvrc ] || nix profile add .#nix-direnv
command -v nil > /dev/null 2>&1 || nix profile add .#nil
command -v nixfmt > /dev/null 2>&1 || nix profile add .#nixfmt

# nix-direnv: cache devShell evaluation for fast direnv loads
# ($HOME is ephemeral, so written idempotently).
mkdir -p ~/.config/direnv
cat > ~/.config/direnv/direnvrc <<'DIRENVRC'
# Use nix-direnv for cached `use flake`.
source $HOME/.nix-profile/share/nix-direnv/direnvrc
DIRENVRC

# shellcheck disable=SC2016
if ! grep -q "direnv hook bash" ~/.bashrc; then
  echo "Configuring direnv hook for bash..."
  echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
fi

# Build the devShell now so the first terminal is instant. Run it in a
# subprocess instead of eval'ing print-dev-env into this script, which
# would leak the devShell environment (PATH etc.) into the remaining steps.
echo "Building Nix development environment..."
nix develop --command true

echo "Allowing direnv for future shell sessions..."
direnv allow

echo "Setup complete!"
