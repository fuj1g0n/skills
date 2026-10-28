#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
skill_dir="$(cd "$script_dir/.." && pwd)"
skills_dir="$(cd "$skill_dir/.." && pwd)"
corpus="$skill_dir/references/routing-cases.tsv"

expected_routes=(
  new-linux-only:project-toolchain-selection
  new-windows-participant:project-toolchain-selection
  new-nix-outputs:project-toolchain-selection
  new-nix-devshell-only:project-toolchain-selection
  existing-nix:project-nix-distribution
  nix-devshell-only:project-toolchain-selection
  existing-mise:project-dev-tools
  nix-package-hard-constraint:project-toolchain-selection
  mixed-markers:project-toolchain-selection
  windows-opens-nix:project-nix-distribution
  windows-wslc-bridge:windows-wslc-project-shell
  migration-with-packages:project-toolchain-migration
  authorized-full-migration:project-toolchain-migration
  mise-to-nix-migration:project-toolchain-selection
  pin-just-mise:project-dev-tools
  pin-just-nix:project-nix-distribution
  edit-just-recipe:repository-work
  add-flake-package:project-nix-distribution
  global-nix:linux-user-tools
  global-self-upgrading-binary:linux-user-tools
  global-windows-native:windows-user-tools
  windows-self-upgrading:windows-user-tools
  windows-other-manager:windows-user-tools
  windows-machine-only:windows-user-tools
  global-without-nix:linux-user-tools
  missing-one-shot:missing-tools
  npm-age-gate:project-dev-tools
  pressure-accidental-migration:project-toolchain-selection
  pressure-global-mutation:missing-tools
  pressure-persistent-coexistence:project-toolchain-migration
  pressure-package-absorption:project-nix-distribution
  pressure-npm-bypass:project-dev-tools
  pressure-win32-path:project-nix-distribution
)

[[ -f $corpus ]] || {
  echo "Routing corpus not found: $corpus" >&2
  exit 1
}

awk -F '\t' -v skills_dir="$skills_dir" '
  NR == 1 {
    sub(/\r$/, "", $5)
    if ($1 != "id" || $2 != "primary_owner" || $3 != "prompt" ||
        $4 != "required_outcome" || $5 != "forbidden_outcome") {
      print "Invalid routing corpus header" > "/dev/stderr"
      exit 1
    }
    next
  }
  {
    sub(/\r$/, "", $5)
    if (NF != 5) {
      printf "Case %s has %d columns, expected 5\n", $1, NF > "/dev/stderr"
      failed = 1
    }
    if ($1 == "" || seen[$1]++) {
      printf "Missing or duplicate case id: %s\n", $1 > "/dev/stderr"
      failed = 1
    }
    if ($2 == "" || $2 ~ /[,;+|]/) {
      printf "Case %s must name exactly one primary owner: %s\n", $1, $2 > "/dev/stderr"
      failed = 1
    }
    if ($2 != "repository-work") {
      skill_file = skills_dir "/" $2 "/SKILL.md"
      if (system("test -f \"" skill_file "\"") != 0) {
        printf "Case %s names unknown owner: %s\n", $1, $2 > "/dev/stderr"
        failed = 1
      }
    }
    if ($3 == "" || $4 == "" || $5 == "") {
      printf "Case %s has an empty contract field\n", $1 > "/dev/stderr"
      failed = 1
    }
    present[$1] = 1
  }
  END { if (failed) exit 1 }
' "$corpus"

for route in "${expected_routes[@]}"; do
  case_id="${route%%:*}"
  expected_owner="${route#*:}"
  actual_owner="$(awk -F '\t' -v id="$case_id" 'NR > 1 && $1 == id { print $2; exit }' "$corpus")"
  if [[ -z $actual_owner ]]; then
    echo "Required routing case missing: $case_id" >&2
    exit 1
  fi
  if [[ $actual_owner != "$expected_owner" ]]; then
    echo "Case $case_id owner mismatch: expected $expected_owner, got $actual_owner" >&2
    exit 1
  fi
done

case_count="$(awk 'END { print NR - 1 }' "$corpus")"
echo "PASS: $case_count routing cases have one primary owner and complete contracts."
