# shellcheck shell=sh disable=SC2154

workflow=
case $hook_command_name in kai:* | /kai:*) workflow=1 ;; esac
case $hook_command in /kai:*) workflow=1 ;; esac
[ -z "$workflow" ] || : >"$(kai_state_dir)/session-$session.workflow"
