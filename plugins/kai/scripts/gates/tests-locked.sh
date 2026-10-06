# shellcheck shell=sh disable=SC2154

kai_require_config
kai_gate_args "$@"

if [ "$KAI_LEVEL" -lt 3 ]; then
  printf 'tests-locked: skipped (level %s)\n' "$KAI_LEVEL"
  exit 0
fi
if [ -n "$exempt" ]; then
  printf 'tests-locked: branch %s is exempt\n' "$exempt"
  exit 0
fi
[ -n "$base" ] || base=$(kai_base_ref)
cd "$KAI_REPO_ROOT" || exit 1
tier=$(kai_change_tier "$base")
if [ "$tier" = low ]; then
  printf 'tests-locked: low tier, no locked tests required\n'
  exit 0
fi
[ -n "$key" ] || kai_die "tests-locked: no ticket key in branch or title (see the ticket-ref gate)"

if [ -z "$(for c in $(kai_lock_commits "$key" "$base..HEAD"); do kai_lock_files "$c"; done)" ]; then
  printf 'tests-locked: %s is a %s-tier change without a "%s: failing tests" commit in this PR.\nCommit the planned tests on their own, before the implementation (/kai:implement does this).\n' "$key" "$tier" "$key" >&2
  exit 1
fi
git log -1 --remerge-diff --format= >/dev/null 2>&1 ||
  kai_die "tests-locked: needs git 2.36 or newer to see what a merge commit changed"
changed=$(for c in $(kai_lock_commits "$key"); do
  kai_lock_files "$c" | sed "s/^/$c /"
done | awk '!seen[substr($0, index($0, " ") + 1)]++' | while IFS= read -r line; do
  c=${line%% *} f=${line#* }
  [ -z "$(git log -n1 --no-merges --full-history --format=%H "$c..HEAD" --not "$base" -- ":(literal)$f")" ] &&
    [ -z "$(git log --merges --full-history --remerge-diff --format= "$c..HEAD" --not "$base" -- ":(literal)$f")" ] ||
    printf '  %s\n' "$f"
done)
if [ -z "$changed" ]; then
  printf 'tests-locked: tests locked for %s are unchanged\n' "$key"
  exit 0
fi
case " $labels " in
  *" kai:tests-changed "*)
    printf 'tests-locked: locked tests changed, approved by the kai:tests-changed label:\n%s\n' "$changed"
    exit 0
    ;;
esac
printf 'tests-locked: tests locked by "%s: failing tests" changed afterwards:\n%s\nChanging a test changes what the feature means. If the change is right, a reviewer approves it with the kai:tests-changed label (and updates the spec if a criterion changed).\n' "$key" "$changed" >&2
exit 1
