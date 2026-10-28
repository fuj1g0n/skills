#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/../../.." && pwd)"
skills_dir="$root/skills"
failed=0

required_skills=(
  project-toolchain-selection missing-tools project-dev-tools
  project-nix-distribution project-toolchain-migration
  linux-user-tools windows-user-tools windows-wslc-project-shell
  project-env-cache-cleanup github-fetch-rate-limit
)

for skill in "${required_skills[@]}"; do
  [[ -f "$skills_dir/$skill/SKILL.md" ]] || {
    echo "Required skill missing: $skill" >&2
    failed=1
  }
done

for skill_file in "$skills_dir"/*/SKILL.md; do
  directory="$(basename "$(dirname "$skill_file")")"
  name="$(awk '
    { sub(/\r$/, "", $0) }
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $0 ~ /^name:/ {
      sub(/^name:[[:space:]]*/, "", $0)
      print
      exit
    }
  ' "$skill_file")"
  if [[ $name != "$directory" ]]; then
    echo "Directory/frontmatter mismatch: $directory != $name" >&2
    failed=1
  fi
done

old_pattern='nix-for''-dev|nix-''manager|nix-gc-''direnv|mise-user''-tools'
old_pattern+='|nix-project''-toolchain|mise-project''-toolchain|nix-package''-outputs'
old_pattern+='|nix-to-mise-project''-toolchain|nix-wslc''-devshell|nix-user''-tools'
old_pattern+='|nix-github''-rate-limit|nix-direnv-gc''-roots'
while IFS= read -r -d '' file; do
  relative="${file#"$root/"}"
  case "$relative" in
    .git/* | docs/research/* | \
      skills/project-toolchain-selection/references/routing-tests.md) continue ;;
  esac
  if grep -InE "$old_pattern" "$file" >/dev/null 2>&1; then
    echo "Old active skill name in $relative" >&2
    failed=1
  fi
done < <(find "$root" -type f -print0)

if grep -RInE --exclude='routing-tests.md' --exclude='validate-taxonomy.sh' \
  'npx -y|@[Ll]atest|--registry([=[:space:]]|$)|registry\.npmjs\.org' \
  "$skills_dir/project-toolchain-selection" \
  "$skills_dir/missing-tools" \
  "$skills_dir/project-dev-tools" \
  "$skills_dir/project-nix-distribution" \
  "$skills_dir/project-toolchain-migration" >/dev/null; then
  echo "Floating or registry-bypass command found in active toolchain guidance" >&2
  failed=1
fi

if grep -RInE '^\[tasks\][[:space:]]*$' \
  "$skills_dir/project-dev-tools" \
  "$skills_dir/project-nix-distribution" >/dev/null; then
  echo "Toolchain skill defines task recipes" >&2
  failed=1
fi

if grep -RInE 'callPackage|mkDerivation|dockerTools\.|build(GoModule|RustPackage|NpmPackage)' \
  "$skills_dir/project-dev-tools" >/dev/null; then
  echo "mise project tools contain Nix package-output guidance" >&2
  failed=1
fi

bash "$script_dir/validate-routing.sh"

if ((failed)); then
  exit 1
fi

echo "PASS: taxonomy names, boundaries, and active references are consistent."
