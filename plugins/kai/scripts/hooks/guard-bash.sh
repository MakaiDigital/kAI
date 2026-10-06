# shellcheck shell=sh disable=SC2154

block() {
  printf 'kai: blocked: %s\n' "$1" >&2
  exit 2
}

git_cmd='(^|[^[:alnum:]_.-])git[[:space:]]'
cmd=$(printf '%s\n' "$hook_command" | tr '\n' ';' | sed 's/\\;/ /g')
words=$(printf '%s\n' "$cmd" | sed -E -e "s/'([^'\"[:space:]]*)'|\"([^'\"[:space:]]*)\"/\1\2/g" \
  -e "s/'[^']*'|\"([^\"\\\\]|\\\\.)*\"//g")
if printf '%s\n' "$cmd" | grep -qiE '(^|[^[:alnum:]_.-])(eval|(ba|da|k|z)?sh)[[:space:]]|alias\.'; then
  words="$words;$cmd"
fi
lines=$(printf '%s\n' "$words" | tr '&|' ';;' | tr ';' '\n')
if printf '%s\n' "$lines" | grep -qiE -e "$git_cmd.*--no-veri" -e 'core\.hookspath' \
  -e "$git_cmd(.*[[:space:]])?commit[[:space:]](.*[[:space:]])?-[[:alpha:]]*n" ||
  printf '%s\n' "$lines" | grep -qE -e '(^|[^[:alnum:]_])(HUSKY=0|HUSKY_SKIP_HOOKS=|LEFTHOOK=(0|false))' \
    -e "(^|[^[:alnum:]_])SKIP=[^[:space:]]*[[:space:]](.*[[:space:]])?git[[:space:]]"; then
  block "this would skip the repository's git hooks. Fix what the hook reports instead of bypassing it."
fi

if [ -n "$KAI_PROD_DEPLOY_PATTERN" ] && [ -z "${KAI_RELEASE_APPROVAL:-}" ]; then
  rc=0
  printf '%s' "$hook_command" | grep -qE -- "$KAI_PROD_DEPLOY_PATTERN" || rc=$?
  case $rc in
    0) block "production deploys need a named release manager. Ask them to approve, then restart the session with KAI_RELEASE_APPROVAL=<their name>." ;;
    2) block "KAI_PROD_DEPLOY_PATTERN in .kai/config is not a valid regular expression; fix it." ;;
  esac
fi
