#!/usr/bin/env bash
# E2E test for the nix-devshell Feature (ADR-0015 Confirmation 1-2).
# Simulates a consuming repository: a fixture workspace whose
# devcontainer.json references only a base image and the Feature, brought
# up with the devcontainer CLI. Run from the repository root.
#
# FEATURE_REF selects what to test:
#   - unset/empty: the local Feature source in features/src (pre-publish)
#   - an OCI ref (e.g. ghcr.io/fuj1g0n/skills/nix-devshell:latest):
#     the published Feature, pulled from the registry (post-publish)
set -euo pipefail

FIXTURE_SRC=features/test/nix-devshell/fixture
FEATURE_REF="${FEATURE_REF:-}"
WORKSPACE=$(mktemp -d)
trap 'docker rm -f "${CONTAINER_ID:-}" > /dev/null 2>&1 || true; rm -rf "${WORKSPACE}"' EXIT

# Stage the fixture outside the repo so the workspace looks like an
# independent consuming repository.
cp -r "${FIXTURE_SRC}/." "${WORKSPACE}/"
if [ -z "${FEATURE_REF}" ]; then
  # Inject the Feature source under .devcontainer/ for the fixture's
  # local file reference ("./nix-devshell").
  cp -r features/src/nix-devshell "${WORKSPACE}/.devcontainer/nix-devshell"
  echo "=== Testing local Feature source ==="
else
  # Point the fixture at the published Feature instead.
  sed -i "s|\"./nix-devshell\"|\"${FEATURE_REF}\"|" \
    "${WORKSPACE}/.devcontainer/devcontainer.json"
  echo "=== Testing published Feature: ${FEATURE_REF} ==="
fi

# mktemp creates a 700 dir owned by the CI user (UID 1001); the container
# user vscode (UID 1000, updateRemoteUserUID=false) must be able to read
# the bind-mounted workspace.
chmod -R a+rX "${WORKSPACE}"

up() {
  devcontainer up --workspace-folder "${WORKSPACE}" "$@"
}

exec_in() {
  devcontainer exec --workspace-folder "${WORKSPACE}" bash -lc "$*"
}

echo "=== Confirmation (1): first creation with a fresh volume ==="
up 2>&1 | tee /tmp/up-first.log
CONTAINER_ID=$(docker ps -q --filter "label=devcontainer.local_folder=${WORKSPACE}")

echo "--- feature-contributed /nix volume mount is applied"
docker inspect "${CONTAINER_ID}" --format '{{json .Mounts}}' | grep -q '"Destination":"/nix"'

echo "--- installer ran (fresh volume path)"
grep -q "Installing Nix" /tmp/up-first.log

echo "--- tools on PATH (nix, direnv, nil, nixfmt)"
exec_in 'command -v nix direnv nil nixfmt'
exec_in 'nix --version && direnv --version'

echo "--- direnv hook and nix-direnv wired"
exec_in 'grep -q "direnv hook bash" ~/.bashrc && test -f ~/.config/direnv/direnvrc'

echo "--- devShell was warmed up and provides the project tool"
exec_in 'nix develop --command hello'

echo "--- direnv allowed for the workspace"
exec_in 'direnv status | grep -q "Found RC allowed 0\|Found RC allowed true"'

echo "=== Confirmation (2): volume reuse on container re-creation ==="
docker rm -f "${CONTAINER_ID}" > /dev/null
up --remove-existing-container 2>&1 | tee /tmp/up-second.log
CONTAINER_ID=$(docker ps -q --filter "label=devcontainer.local_folder=${WORKSPACE}")

echo "--- bootstrap manifest reuse path taken (no reinstall)"
grep -q "Reusing existing /nix volume" /tmp/up-second.log
! grep -q "Installing Nix" /tmp/up-second.log

echo "--- tools still on PATH after profile rebuild"
exec_in 'command -v nix direnv nil nixfmt && nix develop --command hello'

echo "=== E2E test passed ==="
