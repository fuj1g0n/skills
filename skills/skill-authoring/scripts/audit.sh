#!/usr/bin/env bash
# Audit every skill for the mechanical parts of skill-authoring's conventions:
# SKILL.md length, frontmatter name/description length, references/ and
# scripts/ presence, and the authoring-contract rules in
# references/contract-rules.tsv. Judgement checks live in
# references/audit-checks.md.
#
# Adapted from ryoppippi/dotfiles skill-maintenance/scripts/audit.sh (MIT).
#
# Usage: scripts/audit.sh [SKILLS_DIR]
#   SKILLS_DIR defaults to the .apm/skills directory this script lives under.
# Exit status: 1 when any hard ("!") flag or fail-level contract finding
# exists; warnings never fail.
set -euo pipefail

# Thresholds. Hard limits come from Anthropic's frontmatter validation; soft
# limits encode skill-authoring guidance. See references/audit-checks.md.
readonly LINE_SOFT=150 # consider splitting into references/ above this
readonly LINE_HARD=500 # Anthropic hard ceiling for the SKILL.md body
readonly NAME_MAX=64   # frontmatter name hard limit
readonly DESC_MAX=1024 # frontmatter description hard limit
readonly DESC_SOFT=350 # keep descriptions tight (~20-35 words); flag above this

# Default to .apm/skills (two levels up from this scripts/ directory).
script_dir="$(cd "$(dirname "$0")" && pwd)"
skills_dir="${1:-$(cd "$script_dir/../.." && pwd)}"
rules_file="$script_dir/../references/contract-rules.tsv"

if [[ ! -d $skills_dir ]]; then
  echo "Skills directory not found: $skills_dir" >&2
  exit 1
fi

# Extract a frontmatter value (name: / description:) from a SKILL.md.
# Handles single-line values and block scalars (>, |, >-, |-): continuation
# lines are joined so multi-line descriptions are measured, not read as "1".
# Reads only the block between the first two '---' fences.
frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    { sub(/\r$/, "", $0) }
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    collecting {
      if ($0 ~ /^[[:space:]]/ || $0 == "") {
        line = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") out = out (out == "" ? "" : " ") line
        next
      }
      exit
    }
    in_fm && $0 ~ "^" key ":" {
      val = $0
      sub("^" key ": *", "", val)
      if (val ~ /^[>|][+-]?$/) { collecting = 1; next }
      print val
      exit
    }
    END { if (collecting) print out }
  ' "$file"
}

# --- Contract rules -------------------------------------------------------

RULE_ID=() RULE_KIND=() RULE_TARGET=() RULE_LEVEL=() RULE_PATTERN=() RULE_EXCEPT=() RULE_MSG=()
EXCLUDE_RE=""
FAILS=0
WARNS=0

# Parse contract-rules.tsv. Unknown kinds abort so a typo cannot silently
# disable a rule.
load_rules() {
  local file="$1" id kind target level pattern except msg
  while IFS=$'\t' read -r id kind target level pattern except msg; do
    id="${id%$'\r'}" msg="${msg%$'\r'}"
    [[ $id == id || -z $id ]] && continue
    case "$kind" in
      exclude-path)
        EXCLUDE_RE="${EXCLUDE_RE:+$EXCLUDE_RE|}$pattern"
        continue
        ;;
      forbid | require-heading | section-each | max-count | handoff) ;;
      *)
        echo "Unknown rule kind '$kind' for $id in $file" >&2
        exit 2
        ;;
    esac
    RULE_ID+=("$id") RULE_KIND+=("$kind") RULE_TARGET+=("$target")
    RULE_LEVEL+=("$level") RULE_PATTERN+=("$pattern") RULE_EXCEPT+=("$except")
    RULE_MSG+=("$msg")
  done <"$file"
}

# Print the file with frontmatter and fenced blocks blanked, so grep -n line
# numbers match the source. Inline code spans are removed unless keep_code=1.
body_text() {
  local file="$1" keep_code="${2:-0}"
  awk -v keep_code="$keep_code" '
    { sub(/\r$/, "", $0) }
    NR == 1 && $0 == "---" { in_fm = 1; print ""; next }
    in_fm { if ($0 == "---") in_fm = 0; print ""; next }
    /^[[:space:]]*(```|~~~)/ { in_fence = !in_fence; print ""; next }
    in_fence { print ""; next }
    { if (!keep_code) gsub(/`[^`]*`/, ""); print }
  ' "$file"
}

# Print "<line>:<text>" for each bullet under an exact H2 heading, joining
# indented continuation lines so a wrapped bullet is checked as a whole.
section_bullets() {
  local file="$1" heading="$2"
  body_text "$file" | awk -v h="$heading" '
    function flush() { if (cur != "") print start ":" cur; cur = "" }
    $0 == h { in_s = 1; next }
    /^## / { flush(); in_s = 0 }
    !in_s { next }
    /^[-*] / { flush(); start = NR; cur = $0; next }
    /^[[:space:]]+[^[:space:]]/ && cur != "" { cur = cur " " $0; next }
    { flush() }
    END { flush() }
  '
}

report_finding() {
  local rel="$1" line="$2" idx="$3"
  printf "%s:%s: %s %s: %s\n" "$rel" "$line" "${RULE_ID[$idx]}" \
    "${RULE_LEVEL[$idx]}" "${RULE_MSG[$idx]}"
  if [[ ${RULE_LEVEL[$idx]} == fail ]]; then
    FAILS=$((FAILS + 1))
  else
    WARNS=$((WARNS + 1))
  fi
}

# Apply every rule whose target covers this file.
check_file() {
  local skill_dir="$1" file="$2" is_skill_md="$3"
  local rel="${file#"$skills_dir"/}" idx kind target pattern except line name hits count
  rel="${rel#/}"
  if [[ -n $EXCLUDE_RE ]] && grep -qE "$EXCLUDE_RE" <<<"$rel"; then
    return 0
  fi
  for idx in "${!RULE_ID[@]}"; do
    kind="${RULE_KIND[$idx]}" target="${RULE_TARGET[$idx]}"
    pattern="${RULE_PATTERN[$idx]}" except="${RULE_EXCEPT[$idx]}"
    [[ $target == skill || $target == desc ]] && ((is_skill_md == 0)) && continue
    case "$kind/$target" in
      forbid/desc)
        if grep -qE "$pattern" <<<"$(frontmatter_value "$file" description)"; then
          report_finding "$rel" "-" "$idx"
        fi
        ;;
      forbid/*)
        hits="$(body_text "$file" | grep -nE "$pattern" || true)"
        if [[ -n $hits && $except != - ]]; then
          hits="$(grep -vE "$except" <<<"$hits" || true)"
        fi
        while IFS= read -r line; do
          [[ -n $line ]] && report_finding "$rel" "${line%%:*}" "$idx"
        done <<<"$hits"
        ;;
      require-heading/*)
        body_text "$file" | grep -qE "$pattern" || report_finding "$rel" "-" "$idx"
        ;;
      section-each/*)
        while IFS= read -r line; do
          [[ -z $line ]] && continue
          grep -qE "$pattern" <<<"${line#*:}" || report_finding "$rel" "${line%%:*}" "$idx"
        done <<<"$(section_bullets "$file" "$except")"
        ;;
      max-count/*)
        count="$(body_text "$file" | grep -cE "$pattern" || true)"
        if ((count > except)); then report_finding "$rel" "-" "$idx"; fi
        ;;
      handoff/*)
        while IFS= read -r line; do
          [[ -z $line ]] && continue
          name="${line#*\`}" name="${name%\`}"
          [[ -f "$skills_dir/$name/SKILL.md" ]] || report_finding "$rel" "${line%%:*}" "$idx"
        done <<<"$(body_text "$file" 1 | grep -noE "$pattern" || true)"
        ;;
    esac
  done
  return 0
}

[[ -f $rules_file ]] || {
  echo "Contract rules not found: $rules_file" >&2
  exit 2
}
load_rules "$rules_file"

# --- Length table ---------------------------------------------------------

printf "%-28s %6s %5s %5s  %-4s %-4s\n" "SKILL" "lines" "name" "desc" "refs" "scrp"
printf -- "%.0s-" {1..60}
echo

issues=0
hard=0
for dir in "$skills_dir"/*/; do
  skill="$(basename "$dir")"
  file="$dir/SKILL.md"
  [[ -f $file ]] || {
    printf "%-28s  %s\n" "$skill" "<< no SKILL.md!"
    issues=$((issues + 1))
    hard=$((hard + 1))
    continue
  }

  lines=$(wc -l <"$file" | tr -d ' ')
  name="$(frontmatter_value "$file" name)"
  desc="$(frontmatter_value "$file" description)"
  name_len=${#name}
  desc_len=${#desc}
  has_refs="-"
  [[ -d "$dir/references" ]] && has_refs="yes"
  has_scrp="-"
  [[ -d "$dir/scripts" ]] && has_scrp="yes"

  flags=""
  ((lines > LINE_HARD)) && flags+=" lines>${LINE_HARD}!"
  ((lines > LINE_SOFT && lines <= LINE_HARD)) && flags+=" lines>${LINE_SOFT}"
  ((name_len == 0)) && flags+=" name-missing!"
  ((name_len > NAME_MAX)) && flags+=" name>${NAME_MAX}!"
  ((desc_len == 0)) && flags+=" desc-missing!"
  ((desc_len > DESC_MAX)) && flags+=" desc>${DESC_MAX}!"
  ((desc_len > DESC_SOFT && desc_len <= DESC_MAX)) && flags+=" desc>${DESC_SOFT}"
  if [[ -n $flags ]]; then
    set -- $flags
    issues=$((issues + $#))
    bangs="${flags//[^!]/}"
    hard=$((hard + ${#bangs}))
  fi

  printf "%-28s %6s %5s %5s  %-4s %-4s%s\n" \
    "$skill" "$lines" "$name_len" "$desc_len" "$has_refs" "$has_scrp" \
    "${flags:+   <<$flags}"
done

echo
echo "Contract findings:"
for dir in "$skills_dir"/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  dir="${dir%/}"
  check_file "$dir" "$dir/SKILL.md" 1
  for ref in "$dir"/references/*.md; do
    if [[ -f $ref ]]; then check_file "$dir" "$ref" 0; fi
  done
done

echo
echo "Length flags: $issues ($hard hard). Contract: $FAILS fail, $WARNS warn."
echo "Judgement checks: references/audit-checks.md."
if ((hard > 0 || FAILS > 0)); then
  exit 1
fi
