#!/usr/bin/env bash
# E2E test for the nix-devshell Feature (ADR-0015 Confirmation 1-3).
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
trap 'docker rm -f "${CONTAINER_ID:-}" > /dev/null 2>&1 || true; docker volume rm "${NIX_VOLUME:-}" > /dev/null 2>&1 || true; rm -rf "${WORKSPACE}"' EXIT

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

# Real consuming repositories are git repositories, and the workspace owner
# (host UID) generally differs from the container user; make the fixture a
# git repo so the e2e exercises git's/nix's ownership check against the
# Feature's safe.directory handling.
git -C "${WORKSPACE}" init -q
git -C "${WORKSPACE}" -c user.name=e2e -c user.email=e2e@example.invalid \
  add -A
git -C "${WORKSPACE}" -c user.name=e2e -c user.email=e2e@example.invalid \
  commit -qm fixture
chmod -R a+rX "${WORKSPACE}/.git"

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

echo "=== Confirmation (3): Feature version bump against the existing volume ==="
if [ -z "${FEATURE_REF}" ]; then
  # Simulate publishing a new Feature version: bump the version and touch
  # the payload so the Feature layer genuinely differs from the one that
  # created the volume.
  sed -i 's/"version": "[^"]*"/"version": "99.0.0"/' \
    "${WORKSPACE}/.devcontainer/nix-devshell/devcontainer-feature.json"
  echo "# simulated version bump marker" \
    >> "${WORKSPACE}/.devcontainer/nix-devshell/setup.sh"
fi

# The named /nix volume survives; capture it before dropping the container.
NIX_VOLUME=$(docker inspect "${CONTAINER_ID}" \
  --format '{{range .Mounts}}{{if eq .Destination "/nix"}}{{.Name}}{{end}}{{end}}')
docker rm -f "${CONTAINER_ID}" > /dev/null

up --remove-existing-container 2>&1 | tee /tmp/up-bump.log
CONTAINER_ID=$(docker ps -q --filter "label=devcontainer.local_folder=${WORKSPACE}")

echo "--- valid manifest is reused across the bump (no reinstall)"
grep -q "Reusing existing /nix volume" /tmp/up-bump.log
! grep -q "Installing Nix" /tmp/up-bump.log

echo "--- profile is not dangling and tools work"
exec_in 'readlink -e ~/.nix-profile > /dev/null'
exec_in 'command -v nix direnv nil nixfmt && nix develop --command hello'

echo "--- corrupt manifest falls back to the installer and repairs"
docker rm -f "${CONTAINER_ID}" > /dev/null
docker run --rm -u 1000:1000 -v "${NIX_VOLUME}:/nix" alpine \
  sh -c 'echo /nix/store/00000000000000000000000000000000-gone > /nix/.bootstrap-paths'
up --remove-existing-container 2>&1 | tee /tmp/up-fallback.log
CONTAINER_ID=$(docker ps -q --filter "label=devcontainer.local_folder=${WORKSPACE}")
grep -q "Installing Nix" /tmp/up-fallback.log
exec_in 'readlink -e ~/.nix-profile > /dev/null'
exec_in 'command -v nix direnv nil nixfmt && nix develop --command hello'

echo "--- manifest was rewritten with valid store paths"
docker run --rm -u 1000:1000 -v "${NIX_VOLUME}:/nix" alpine \
  sh -c 'grep -q "^/nix/store/" /nix/.bootstrap-paths && ! grep -q "gone" /nix/.bootstrap-paths'

echo "=== E2E test passed ==="
