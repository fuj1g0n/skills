#!/usr/bin/env bash
# Regression tests for audit.sh: one positive and one negative fixture per
# contract rule, plus CRLF frontmatter parsing. Fixtures are generated in a
# temporary directory so no fake SKILL.md ships with the skill.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
rules_file="$script_dir/../references/contract-rules.tsv"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
failures=0
covered=()

# Write a skill whose body is "$3" under fixture tree "$1".
make_skill() {
  local tree="$1" name="$2" body="$3" desc="${4:-Handles fixture work. Use when a test needs a fixture skill.}"
  mkdir -p "$root/$tree/$name"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# Fixture\n\n%s\n' \
    "$name" "$desc" "$body" >"$root/$tree/$name/SKILL.md"
}

audit_output() {
  "$script_dir/audit.sh" "$root/$1" 2>&1 || true
}

# expect <id> <tree> <present|absent>
expect() {
  local id="$1" tree="$2" want="$3" out
  out="$(audit_output "$tree")"
  covered+=("$id")
  if grep -qE ": $id (fail|warn):" <<<"$out"; then
    [[ $want == present ]] && return 0
  else
    [[ $want == absent ]] && return 0
  fi
  echo "FAIL: $id expected $want in $tree" >&2
  echo "$out" >&2
  failures=$((failures + 1))
}

done_when=$'## Done when\n\n- The fixture exists.'

for args in none extra; do
  status=0
  if [[ $args == none ]]; then
    out="$("$script_dir/audit.sh" 2>&1)" || status=$?
  else
    out="$("$script_dir/audit.sh" "$root" "$root" 2>&1)" || status=$?
  fi
  if [[ $status != 2 || $out != *"explicit source collection required"* ]]; then
    echo "FAIL: $args arguments must fail with usage, not audit another source" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
done

make_skill c01p s "Do NOT run this."
make_skill c01n s $'Run `NOT_A_FLAG` safely.\n\n```sh\necho NEVER\n```'
expect C01 c01p present
expect C01 c01n absent

make_skill c02p s "You are a cleanup assistant."
make_skill c02n s "Clean up the cache."
expect C02 c02p present
expect C02 c02n absent

make_skill c03p s "If markers conflict, stop and invoke the selector."
make_skill c03n s 'If markers conflict, hand off to `s`.'
expect C03 c03p present
expect C03 c03n absent

make_skill c04p s "Stop here."
make_skill c04n s "End the workflow here."
expect C04 c04p present
expect C04 c04n absent

make_skill c05p s "Confirm the request is global."
make_skill c05n s "Ask the user to confirm the plan, presenting the diff."
expect C05 c05p present
expect C05 c05n absent

make_skill c06p s "Self-review the file before handing off."
make_skill c06n s "Report the files created."
expect C06 c06p present
expect C06 c06n absent

make_skill c07p s "Do the work."
make_skill c07n s "$done_when"
expect C07 c07p present
expect C07 c07n absent

make_skill c08p s $'## Avoid\n\n- Floating versions.'
make_skill c08n s $'## Invariants\n\n- No floating versions, because pins drift.'
expect C08 c08p present
expect C08 c08n absent

make_skill c09p s $'## Invariants\n\n- No floating versions.'
make_skill c09n s $'## Invariants\n\n- No floating versions, because pins drift.'
make_skill c09w s $'## Invariants\n\n- No floating versions,\n  because pins drift.'
expect C09 c09p present
expect C09 c09n absent
expect C09 c09w absent

make_skill c10p s $'Ask the user to approve A.\nAsk the user to approve B.\nAsk the user to approve C.'
make_skill c10n s $'Ask the user to approve A.\nAsk the user to approve B.'
expect C10 c10p present
expect C10 c10n absent

make_skill c11p s "When in doubt, ask the user."
make_skill c11n s "Default to one-shot use and report the default."
make_skill c11t s $'| Situation | Scope |\n|---|---|\n| Unclear | ask the user |'
make_skill c11d s $'| Situation | Scope |\n|---|---|\n| Unclear | user scope; report it |'
expect C11 c11p present
expect C11 c11n absent
make_skill c11b s "Show the path and ask before deciding."
expect C11 c11b present
expect C11 c11t present
expect C11 c11d absent

make_skill c12p s "Body." "Writes records. Use even when the user does not name it."
make_skill c12n s "Body." "Writes records. Use when the user records a decision."
expect C12 c12p present
expect C12 c12n absent

make_skill c13p s 'Hand off to `missing-skill`.'
make_skill c13n s 'Hand off to `other`.'
make_skill c13n other "Other fixture."
expect C13 c13p present
expect C13 c13n absent

make_skill c14p software-design "Body."
mkdir -p "$root/c14p/software-design/references"
printf 'Use MUST here.\n' >"$root/c14p/software-design/references/notes.md"
make_skill c14n software-design "Body."
mkdir -p "$root/c14n/software-design/references"
printf 'Use MUST here.\n' >"$root/c14n/software-design/references/madr-template.md"
expect C01 c14p present
expect C01 c14n absent
covered+=("C14")

make_skill c15p s "See ADR-0021 for the rule."
make_skill c15n s "Use one project toolchain, because mixed owners drift."
expect C15 c15p present
expect C15 c15n absent

# Every rule in the table needs a fixture above.
while IFS=$'\t' read -r id _; do
  [[ $id == id || -z $id ]] && continue
  if [[ " ${covered[*]} " != *" $id "* ]]; then
    echo "FAIL: rule $id has no fixture" >&2
    failures=$((failures + 1))
  fi
done <"$rules_file"

# Exit status: fail-level findings fail, warnings alone do not.
make_skill exitwarn s $'Stop here.\n\n'"$done_when"
if ! "$script_dir/audit.sh" "$root/exitwarn" >/dev/null; then
  echo "FAIL: warnings alone must exit 0" >&2
  failures=$((failures + 1))
fi
if "$script_dir/audit.sh" "$root/c07p" >/dev/null; then
  echo "FAIL: a fail-level finding must exit 1" >&2
  failures=$((failures + 1))
fi

# CRLF frontmatter is parsed.
mkdir -p "$root/crlf/crlf-skill"
printf '%s\r\n' \
  '---' \
  'name: crlf-skill' \
  'description: Reads a CRLF frontmatter fixture for audit regression coverage.' \
  '---' \
  '' \
  '# CRLF skill' >"$root/crlf/crlf-skill/SKILL.md"
out="$(audit_output crlf)"
if ! grep -Eq '^crlf-skill[[:space:]]+6[[:space:]]+10[[:space:]]+[1-9][0-9]*' <<<"$out" ||
  grep -Eq 'name-missing|desc-missing' <<<"$out"; then
  echo "FAIL: CRLF frontmatter was not parsed" >&2
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "$failures audit test(s) failed." >&2
  exit 1
fi
echo "PASS: audit contract rules and CRLF parsing."
