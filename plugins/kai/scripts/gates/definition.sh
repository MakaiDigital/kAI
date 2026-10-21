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

if [ -n "$key" ] && open=$(grep -nF '⚠' "docs/specs/$key/spec.md" 2>/dev/null); then
  printf 'definition: docs/specs/%s/spec.md still has open questions:\n%s\nDecide each one with the person and remove its marker before opening a PR (/kai:spec %s).\n' \
    "$key" "$(printf '%s\n' "$open" | sed 's/^/  /')" "$key" >&2
  exit 1
fi

tier=$(kai_change_tier "$base")
if [ "$tier" = low ]; then
  printf 'definition: low tier, no spec required\n'
  exit 0
fi
[ -n "$key" ] || kai_die "definition: no ticket key in branch or title (see the ticket-ref gate)"

if ! git cat-file -e "$base:docs/specs/$key/spec.md" 2>/dev/null; then
  printf 'definition: %s is a %s-tier change, but its spec is not approved yet.\nMerge docs/specs/%s/spec.md and plan.md into %s in a Definition PR first (/kai:spec writes both).\n' \
    "$key" "$tier" "$key" "$base" >&2
  exit 1
fi
if ! git cat-file -e "$base:docs/specs/$key/plan.md" 2>/dev/null; then
  printf 'definition: %s is a %s-tier change, but its plan is not approved yet.\nMerge docs/specs/%s/plan.md into %s in a Definition PR first (/kai:spec writes it on top of the merged spec).\n' \
    "$key" "$tier" "$key" "$base" >&2
  exit 1
fi
printf 'definition: %s (%s tier) has an approved spec and plan\n' "$key" "$tier"
