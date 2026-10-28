#!/usr/bin/env bash
set -euo pipefail

forbidden='~/workspace/github[.]com/fuj1g0n/|~/[.]apm/apm_modules/fuj1g0n/|[Tt]he dotfiles (APM manifest|main)|mise run audit|Claude Opus 5[.]5.*medium|GPT-6[.]1 Sol.*medium|Use a tool-native marketplace only for a reproduced APM'

for fixture in \
  'cd ~/workspace/github.com/fuj1g0n/.dotfiles && apm install -g' \
  'The dotfiles APM manifest pins the landed commit.' \
  'Run mise run audit before finishing.' \
  '| Claude Opus 5.5 | medium |' \
  'Use a tool-native marketplace only for a reproduced APM problem.'
do
  if ! grep -qE "$forbidden" <<<"$fixture"; then
    echo "FAIL: missed an author-specific operational requirement: $fixture" >&2
    exit 1
  fi
done

if grep -qE "$forbidden" <<<'Attribution: https://github.com/fuj1g0n/skills, author fuj1g0n'; then
  echo "FAIL: package identity or attribution is not an operational requirement" >&2
  exit 1
fi

status=0
grep -nE "$forbidden" \
  skills/skill-management/SKILL.md \
  skills/skill-authoring/SKILL.md \
  skills/skill-authoring/references/*.md || status=$?
case "$status" in
  0) echo "FAIL: move author-specific requirements to repository instructions" >&2; exit 1 ;;
  1) echo "PASS: shared workflows have no known author-specific requirements." ;;
  *) echo "FAIL: instruction-scope check could not read its inputs" >&2; exit "$status" ;;
esac
