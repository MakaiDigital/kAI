# shellcheck shell=sh disable=SC2154

kai_require_config
kai_gate_args "$@"

if [ -n "$exempt" ]; then
  printf 'ticket-ref: branch %s is exempt\n' "$exempt"
elif [ -n "$key" ]; then
  printf 'ticket-ref: %s\n' "$key"
else
  case $KAI_TICKET_PROVIDER in
    github) example='a 42-short-description branch, or "#42" in the PR title' ;;
    *) example="$(printf '%s' "${KAI_TICKET_PREFIXES:-PROJ}" | tr ',\n' '  ' | awk '{print $1}')-123 in the branch name or PR title" ;;
  esac
  printf 'ticket-ref: no %s ticket key in branch "%s" or title "%s".\nExpected: %s.\n' \
    "$KAI_TICKET_PROVIDER" "$branch" "$title" "$example" >&2
  exit 1
fi
