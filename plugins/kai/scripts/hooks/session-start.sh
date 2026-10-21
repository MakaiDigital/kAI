# shellcheck shell=sh disable=SC2154

jq_note=
command -v jq >/dev/null || jq_note="kai: jq is not installed, so Kai's Bash and Edit guards are off. Install jq to turn them on."
state=$(kai_state_dir)
find "$state" -name 'session-*' -mtime +7 -exec rm -f {} + 2>/dev/null || true
if [ -z "$session" ] || [ ! -f "$state/session-$session.start" ]; then
  kai_fingerprint >"$state/session-$session.start"
fi

branch=$(kai_branch)
if ! key=$(kai_key_from "$branch"); then
  kai_system_message "$jq_note"
  exit 0
fi
dir="$KAI_REPO_ROOT/docs/specs/$key"
base=$(kai_base_ref 2>/dev/null) || base=
changed_here() {
  [ -f "$dir/$1" ] || return 1
  [ -n "$base" ] || return 0
  ! git show "$base:docs/specs/$key/$1" 2>/dev/null | cmp -s - "$dir/$1"
}
# A plan on the base branch came from a Definition PR when the ticket has no evidence there, or the plan changed after the
# evidence (a spec redone after acceptance). Otherwise it belongs to an earlier change.
has_plan() {
  changed_here plan.md && return 0
  [ -f "$dir/plan.md" ] || return 1
  evidence_at=$(git log -1 --format=%H "$base" -- "docs/specs/$key/evidence.md" 2>/dev/null)
  [ -n "$evidence_at" ] || return 0
  plan_at=$(git log -1 --format=%H "$base" -- "docs/specs/$key/plan.md" 2>/dev/null)
  [ "$plan_at" != "$evidence_at" ] && git merge-base --is-ancestor "$evidence_at" "$plan_at" 2>/dev/null
}
case $(printf '%s' "$branch" | tr '[:lower:]' '[:upper:]') in
  *"$key"-DEFINITION*) next="finish the spec and plan in docs/specs/$key/ and open the Definition PR (/kai:spec $key)." ;;
  *"$key"-CLEANUP*) next="finish the cleanup PR (/kai:accept $key)." ;;
  *"$key"-FIX-*) next="/kai:implement the fix, starting with its plan." ;;
  *)
    if [ "$KAI_LEVEL" -ge 2 ] && ! has_plan && { [ ! -f "$dir/spec.md" ] || [ ! -f "$dir/plan.md" ]; }; then
      next="/kai:spec $key (a change that touches only low-tier files can skip it; medium and high tier changes need a merged spec and plan before code)."
    elif ! has_plan; then
      next="/kai:implement (plan first, then tests, code, review, and the PR)."
    elif ! changed_here evidence.md; then
      next="/kai:implement continues with the failing tests, the code, and /kai:prove."
    else
      next="/kai:implement to review the change, open the PR, and answer its reviews."
    fi
    ;;
esac
kai_system_message "$jq_note" "kai: ticket $key. Artifacts are in docs/specs/$key/. Next: $next"
