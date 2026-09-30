# shellcheck shell=sh disable=SC2154

kai_require_config
kai_gate_args "$@"

if [ "$KAI_LEVEL" -lt 2 ]; then
  printf 'definition: skipped (level %s)\n' "$KAI_LEVEL"
  exit 0
fi
if [ -n "$exempt" ]; then
  printf 'definition: branch %s is exempt\n' "$exempt"
  exit 0
fi
[ -n "$base" ] || base=$(kai_base_ref)
cd "$KAI_REPO_ROOT" || exit 1

tier=$(kai_change_tier "$base")
if [ "$tier" = low ]; then
  printf 'definition: low tier, no spec required\n'
  exit 0
fi
[ -n "$key" ] || kai_die "definition: no ticket key in branch or title (see the ticket-ref gate)"

missing=
for f in intent.md spec.md; do
  git cat-file -e "$base:specs/$key/$f" 2>/dev/null || missing="$missing $f"
done
if [ -n "$missing" ]; then
  printf 'definition: %s is a %s-tier change, but%s not approved yet.\nMerge specs/%s/ with intent.md and spec.md into %s in a Definition PR first (/kai:spec writes the spec).\n' \
    "$key" "$tier" "$missing" "$key" "$base" >&2
  exit 1
fi
printf 'definition: %s (%s tier) has an approved intent and spec\n' "$key" "$tier"
