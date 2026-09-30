# shellcheck shell=sh disable=SC2154

kai_require_config
kai_gate_args "$@"
[ -n "$base" ] || base=$(kai_base_ref)
cd "$KAI_REPO_ROOT" || exit 1
kai_change_tier "$base"
