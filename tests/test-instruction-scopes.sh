#!/usr/bin/env bash
set -euo pipefail

forbidden='~/workspace/github[.]com/fuj1g0n/|~/[.]apm/apm_modules/fuj1g0n/'

for fixture in \
  'cd ~/workspace/github.com/fuj1g0n/.dotfiles && apm install -g' \
  'Read ~/.apm/apm_modules/fuj1g0n/skills/skills/skill-authoring/SKILL.md.'
do
  if ! grep -qE "$forbidden" <<<"$fixture"; then
    echo "FAIL: missed an author-specific local path: $fixture" >&2
    exit 1
  fi
done

for fixture in \
  'Attribution: https://github.com/fuj1g0n/skills, author fuj1g0n' \
  'In a mise project, run mise run audit if that project defines the task.' \
  'If the adopter selects Claude Opus 5.5, use its requested medium effort.'
do
  if grep -qE "$forbidden" <<<"$fixture"; then
    echo "FAIL: text without an author-specific local path was rejected: $fixture" >&2
    exit 1
  fi
done

status=0
grep -nE "$forbidden" \
  skills/skill-management/SKILL.md \
  skills/skill-authoring/SKILL.md \
  skills/skill-authoring/references/*.md || status=$?
case "$status" in
  0) echo "FAIL: move author-specific local paths to repository instructions" >&2; exit 1 ;;
  1) echo "PASS: shared workflows contain no known author-specific local paths." ;;
  *) echo "FAIL: instruction-scope check could not read its inputs" >&2; exit "$status" ;;
esac
