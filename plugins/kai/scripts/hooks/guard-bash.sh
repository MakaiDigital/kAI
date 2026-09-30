# shellcheck shell=sh disable=SC2154

block() {
  printf 'kai: blocked: %s\n' "$1" >&2
  exit 2
}

case $hook_command in
  *--no-verify* | *core.hooks[Pp]ath*)
    block "this would skip the repository's git hooks. Fix what the hook reports instead of bypassing it."
    ;;
esac

if [ -n "$KAI_PROD_DEPLOY_PATTERN" ] && [ -z "${KAI_RELEASE_APPROVAL:-}" ] &&
  printf '%s' "$hook_command" | grep -qE -- "$KAI_PROD_DEPLOY_PATTERN"; then
  block "production deploys need a named release manager. Ask them to approve, then restart the session with KAI_RELEASE_APPROVAL=<their name>."
fi
