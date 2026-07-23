#!/bin/sh
# PoC install script: runs at image build time. Only copies the setup
# script into the image; the actual Nix install runs at container-create
# time via the onCreateCommand lifecycle hook (ADR-0015).
set -e
mkdir -p /usr/local/share/nix-devshell
cp "$(dirname "$0")/setup.sh" /usr/local/share/nix-devshell/setup.sh
chmod 755 /usr/local/share/nix-devshell/setup.sh
echo "nix-devshell feature staged; Nix installs at onCreateCommand time."
