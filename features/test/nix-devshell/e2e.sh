#!/usr/bin/env bash
# E2E test for the nix-devshell Feature (ADR-0015 Confirmation 1-2).
# Simulates a consuming repository: a fixture workspace whose
# devcontainer.json references only a base image and the Feature, brought
# up with the devcontainer CLI. Run from the repository root.
set -euo pipefail

FIXTURE_SRC=features/test/nix-devshell/fixture
WORKSPACE=$(mktemp -d)
trap 'docker rm -f "${CONTAINER_ID:-}" > /dev/null 2>&1 || true; rm -rf "${WORKSPACE}"' EXIT

# Stage the fixture outside the repo so the workspace looks like an
# independent consuming repository, and inject the Feature source under
# .devcontainer/ for a local file reference (pre-publish testing).
cp -r "${FIXTURE_SRC}/." "${WORKSPACE}/"
cp -r features/src/nix-devshell "${WORKSPACE}/.devcontainer/nix-devshell"

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
