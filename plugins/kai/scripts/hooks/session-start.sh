# shellcheck shell=sh disable=SC2154

state=$(kai_state_dir)
find "$state" -name 'session-*' -mtime +7 -exec rm -f {} + 2>/dev/null || true
kai_fingerprint >"$state/session-$session.start"

branch=$(kai_branch)
if ! key=$(kai_key_from "$branch"); then
  printf 'kai: no ticket key on branch %s; start work with /kai:spec <KEY>.\n' "${branch:-<detached>}"
  exit 0
fi
dir="$KAI_REPO_ROOT/specs/$key"
if [ "$KAI_LEVEL" -ge 2 ] && [ ! -f "$dir/spec.md" ] && [ ! -f "$dir/plan.md" ]; then
  next="/kai:spec $key (it skips itself for simple tickets and bugs; medium and high tier changes need a merged spec before code)"
elif [ ! -f "$dir/plan.md" ]; then
  next="/kai:build (plan first, then tests, then code)"
elif [ "$KAI_LEVEL" -ge 3 ] && [ -f "$dir/evidence.md" ]; then
  next="/kai:ship once /kai:prove passes"
else
  next="/kai:prove before calling the work done"
fi
printf 'kai: ticket %s. Artifacts are in specs/%s/. Next: %s\n' "$key" "$key" "$next"
