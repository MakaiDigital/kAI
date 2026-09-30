# shellcheck shell=sh disable=SC2154

[ "$KAI_LEVEL" -ge 3 ] && [ -n "$hook_file" ] || exit 0
key=$(kai_key_from "$(kai_branch)") || exit 0
locked=$(kai_locked_commit "$key")
[ -n "$locked" ] || exit 0

dir=$(dirname -- "$hook_file")
[ ! -d "$dir" ] || hook_file="$(cd "$dir" && pwd -P)/${hook_file##*/}"
case $hook_file in
  "$KAI_REPO_ROOT"/*) rel=${hook_file#"$KAI_REPO_ROOT"/} ;;
  /*) exit 0 ;;
  *) rel=$hook_file ;;
esac
if kai_locked_files "$locked" | grep -qxF -- "$rel"; then
  printf 'kai: blocked: %s was locked by the "%s: failing tests" commit. The tests define the feature, so they change only with a person'"'"'s agreement. If this test is wrong, stop and explain why; a reviewer can approve the change with the kai:tests-changed PR label.\n' "$rel" "$key" >&2
  exit 2
fi
