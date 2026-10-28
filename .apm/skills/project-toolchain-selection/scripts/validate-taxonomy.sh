#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/../../../.." && pwd)"
skills_dir="$root/.apm/skills"
failed=0

required_skills=(
  project-toolchain-selection missing-tools nix-project-toolchain
  mise-project-toolchain nix-user-tools
  nix-to-mise-project-toolchain nix-package-outputs
  nix-wslc-devshell nix-direnv-gc-roots nix-github-rate-limit
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
while IFS= read -r -d '' file; do
  relative="${file#"$root/"}"
  case "$relative" in
    .git/* | docs/research/* | \
      .apm/skills/project-toolchain-selection/references/routing-tests.md) continue ;;
  esac
  if grep -InE "$old_pattern" "$file" >/dev/null 2>&1; then
    echo "Old active skill name in $relative" >&2
    failed=1
  fi
done < <(find "$root" -type f -print0)

if [[ -e "$root/mise.toml" || -e "$root/.mise.toml" ]]; then
  echo "Repository-root mise configuration is forbidden for this taxonomy" >&2
  failed=1
fi

if grep -RInE --exclude='routing-tests.md' --exclude='validate-taxonomy.sh' \
  'npx -y|@[Ll]atest|--registry([=[:space:]]|$)|registry\.npmjs\.org' \
  "$skills_dir/project-toolchain-selection" \
  "$skills_dir/missing-tools" \
  "$skills_dir/mise-project-toolchain" \
  "$skills_dir/nix-project-toolchain" \
  "$skills_dir/nix-to-mise-project-toolchain" \
  "$skills_dir/nix-package-outputs" >/dev/null; then
  echo "Floating or registry-bypass command found in active toolchain guidance" >&2
  failed=1
fi

if grep -RInE '^\[tasks\][[:space:]]*$' \
  "$skills_dir/mise-project-toolchain" \
  "$skills_dir/nix-project-toolchain" >/dev/null; then
  echo "Toolchain skill defines task recipes" >&2
  failed=1
fi

if grep -RInE 'callPackage|mkDerivation|dockerTools\.|build(GoModule|RustPackage|NpmPackage)' \
  "$skills_dir/nix-project-toolchain" >/dev/null; then
  echo "Nix project toolchain contains package-output implementation guidance" >&2
  failed=1
fi

bash "$script_dir/validate-routing.sh"

if ((failed)); then
  exit 1
fi

echo "PASS: taxonomy names, boundaries, and active references are consistent."
