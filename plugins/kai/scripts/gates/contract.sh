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
  bad=$(awk '/^## /{on = ($0 ~ /^## Planned tests/)} on && /^\|/ && /(MISSING|FAIL)/' "$dir/evidence.md")
  [ -z "$bad" ] || problems="$problems  planned tests not passing in $dir/evidence.md:
$(printf '%s\n' "$bad" | sed 's/^/    /')
"
fi

if [ -f "$dir/spec.md" ]; then
  rows=$(awk '/^## /{on = ($0 ~ /^## Contract/)} on && /^\| *C[0-9]+ *\|/' "$dir/spec.md")
  for id in $(grep -oE '\*\*C[0-9]+\*\*' "$dir/spec.md" | tr -d '*' | sort -u); do
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
fi

if [ -n "$problems" ]; then
  printf 'contract: %s is not proven:\n%s' "$key" "$problems" >&2
  exit 1
fi
printf 'contract: %s proven (%s tier)\n' "$key" "$tier"
