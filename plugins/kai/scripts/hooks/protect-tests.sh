# shellcheck shell=sh disable=SC2154

[ -n "$hook_file" ] || exit 0
dir=$(dirname -- "$hook_file")
if [ -d "$dir" ]; then
  cd "$dir" || exit 0
  unset KAI_LEVEL KAI_TICKET_PROVIDER KAI_TICKET_PREFIXES KAI_TICKET_EXEMPT KAI_VERIFY_CMDS KAI_BASE_BRANCH KAI_PROD_DEPLOY_PATTERN
  kai_load_config || exit 0
  hook_file="$(pwd -P)/${hook_file##*/}"
fi
[ "$KAI_LEVEL" -ge 3 ] || exit 0
branch=$(kai_branch)
[ -n "$branch" ] || branch=$(sed 's#^refs/heads/##' "$(git rev-parse --git-path rebase-merge/head-name)" \
  "$(git rev-parse --git-path rebase-apply/head-name)" 2>/dev/null) || :
key=$(kai_key_from "$branch") || exit 0
locked=$(kai_locked_paths "$key")
[ -n "$locked" ] || exit 0

case $hook_file in
  "$KAI_REPO_ROOT"/*) rel=${hook_file#"$KAI_REPO_ROOT"/} ;;
  /*) exit 0 ;;
  *) rel=$hook_file ;;
esac
match=-qxF
[ "$(git config --bool core.ignorecase)" != true ] || match=-qixF
if printf '%s\n' "$locked" | grep "$match" -- "$rel"; then
  printf 'kai: blocked: %s was locked by the "%s: failing tests" commit. The tests define the feature, so they change only with a person'"'"'s agreement. If this test is wrong, stop and explain why; a reviewer can approve the change with the kai:tests-changed PR label.\n' "$rel" "$key" >&2
  exit 2
fi
