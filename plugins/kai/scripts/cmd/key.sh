# shellcheck shell=sh disable=SC2154

kai_require_config
text=${1:-$(kai_branch)}
kai_key_from "$text" || kai_die "no ${KAI_TICKET_PROVIDER} ticket key found in '$text'"
