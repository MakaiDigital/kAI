# shellcheck shell=sh disable=SC2154

kai_require_config
kai_gate_args "$@"

if [ "$KAI_LEVEL" -lt 3 ]; then
  printf 'contract: skipped (level %s)\n' "$KAI_LEVEL"
  exit 0
fi
if [ -n "$exempt" ]; then
  printf 'contract: branch %s is exempt\n' "$exempt"
  exit 0
fi
[ -n "$base" ] || base=$(kai_base_ref)
cd "$KAI_REPO_ROOT" || exit 1
tier=$(kai_change_tier "$base")
if [ "$tier" = low ]; then
  printf 'contract: low tier, no contract required\n'
  exit 0
fi
[ -n "$key" ] || kai_die "contract: no ticket key in branch or title (see the ticket-ref gate)"

dir="specs/$key"
problems=
if [ ! -f "$dir/evidence.md" ]; then
  problems="$problems  $dir/evidence.md is missing (run /kai:prove)
"
else
  grep -qxF 'Result: **PASS**' "$dir/evidence.md" && ! grep -q '^Result: \*\*FAIL' "$dir/evidence.md" ||
    problems="$problems  $dir/evidence.md does not record a passing kai verify run (run /kai:prove)
"
  planned=$(awk -F'|' '/^## /{on = ($0 ~ /^## Planned tests/)} on && /^\|/ && !/^\|[-:| ]*$/ {
    criterion = $2; gsub(/^ +| +$/, "", criterion)
    if (criterion != "Criterion") print
  }' "$dir/evidence.md")
  bad=$(printf '%s\n' "$planned" | awk -F'|' 'NF {
    result = $4; output = $5; gsub(/^ +| +$/, "", result); gsub(/^ +| +$/, "", output)
    if (result != "PASS" || output == "") print
  }')
  left_out=
  [ ! -f "$dir/plan.md" ] || left_out=$(printf '%s\n' "$planned" | awk -F'|' '
    NR == FNR { test = $3; gsub(/`|^ +| +$/, "", test); listed[test] = 1; next }
    !/^\|/ { header = 1 }
    /^## / { on = ($0 ~ /^## Tests/) }
    on && /^\|/ && !/^\|[-:| ]*$/ {
      if (header) { header = 0; next }
      test = $3; gsub(/`|^ +| +$/, "", test)
      if (!(test in listed)) print test
    }' - "$dir/plan.md")
  if [ -z "$planned" ]; then
    problems="$problems  $dir/evidence.md has no planned tests table (run /kai:prove)
"
  elif [ -n "$bad" ]; then
    problems="$problems  planned tests not passing in $dir/evidence.md:
$(printf '%s\n' "$bad" | sed 's/^/    /')
"
  fi
  [ -z "$planned" ] || [ -z "$left_out" ] || problems="$problems  tests in $dir/plan.md missing from $dir/evidence.md:
$(printf '%s\n' "$left_out" | sed 's/^/    /')
"
  sha=$(sed -n 's/^kai verify on commit \([0-9a-f]\{7,\}\) at .*/\1/p' "$dir/evidence.md" | head -n 1)
  merge_base=$(git merge-base "$base" HEAD)
  if { git cat-file -e "$merge_base:$dir/evidence.md" 2>/dev/null &&
    git show "$merge_base:$dir/evidence.md" | cmp -s - "$dir/evidence.md"; } ||
    [ -z "$sha" ] || ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null ||
    git merge-base --is-ancestor "$sha" "$base" 2>/dev/null; then
    problems="$problems  $dir/evidence.md was not updated on this branch (run /kai:prove)
"
  fi
fi

criteria=$(git show "$base:$dir/spec.md" 2>/dev/null || :; cat "$dir/spec.md" 2>/dev/null || :)
rows=
[ ! -f "$dir/spec.md" ] || rows=$(awk '/^## /{on = ($0 ~ /^## Contract/)} on && /^\| *C[0-9]+ *\|/' "$dir/spec.md")
for id in $(printf '%s\n' "$criteria" | grep -oE '\*\*C[0-9]+[:.]?\*\*' | tr -d '*:.' | sort -u); do
  printf '%s\n' "$rows" | grep -qE "^\| *$id *\|" || problems="$problems  $id has no contract row
"
done
incomplete=$(printf '%s\n' "$rows" | awk -F'|' 'NF {
  status = $4; evidence = $5
  gsub(/^ +| +$/, "", status); gsub(/^ +| +$/, "", evidence)
  if (status != "PASS" || evidence == "") print
}')
[ -z "$incomplete" ] || problems="$problems  contract rows not PASS with evidence:
$(printf '%s\n' "$incomplete" | sed 's/^/    /')
"

if [ -n "$problems" ]; then
  printf 'contract: %s is not proven:\n%s' "$key" "$problems" >&2
  exit 1
fi
printf 'contract: %s proven (%s tier)\n' "$key" "$tier"
