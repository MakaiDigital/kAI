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

locked=$(kai_locked_commit "$key")
if [ -z "$locked" ]; then
  printf 'tests-locked: %s is a %s-tier change without a "%s: failing tests" commit.\nCommit the planned tests on their own, before the implementation (/kai:implement does this).\n' "$key" "$tier" "$key" >&2
  exit 1
fi
changed=$(kai_locked_files "$locked" | while IFS= read -r f; do
  git diff --quiet "$locked" HEAD -- "$f" 2>/dev/null || printf '  %s\n' "$f"
done)
if [ -z "$changed" ]; then
  printf 'tests-locked: tests from %s unchanged since %s\n' "$key" "$(git rev-parse --short "$locked")"
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
