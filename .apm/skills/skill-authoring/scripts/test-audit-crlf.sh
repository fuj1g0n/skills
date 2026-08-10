#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

mkdir -p "$fixture_dir/crlf-skill"
printf '%s\r\n' \
  '---' \
  'name: crlf-skill' \
  'description: Reads a CRLF frontmatter fixture for audit regression coverage.' \
  '---' \
  '' \
  '# CRLF skill' >"$fixture_dir/crlf-skill/SKILL.md"

output="$("$script_dir/audit.sh" "$fixture_dir")"
grep -Eq '^crlf-skill[[:space:]]+6[[:space:]]+10[[:space:]]+[1-9][0-9]*' <<<"$output"
if grep -Eq 'name-missing|desc-missing' <<<"$output"; then
  echo "CRLF frontmatter was not parsed" >&2
  exit 1
fi

echo "PASS: audit parses CRLF frontmatter."
