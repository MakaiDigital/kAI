# shellcheck shell=sh disable=SC2154

[ -n "$KAI_VERIFY_CMDS" ] || exit 0

max=3
state=$(kai_state_dir)
start_file="$state/session-$session.start"
blocks_file="$state/session-$session.blocks"
fingerprint=$(kai_fingerprint)

if [ ! -f "$start_file" ]; then
  printf '%s\n' "$fingerprint" >"$start_file"
  exit 0
fi
[ "$fingerprint" != "$(cat "$start_file")" ] || exit 0
[ "$fingerprint" != "$(cat "$state/verified" 2>/dev/null)" ] || exit 0
blocks=$(cat "$blocks_file" 2>/dev/null || echo 0)
[ "$blocks" -lt "$max" ] || exit 0

if output=$(KAI_FINGERPRINT=$fingerprint "$KAI_ROOT/bin/kai" verify 2>&1); then
  rm -f "$blocks_file"
  exit 0
fi

blocks=$((blocks + 1))
printf '%s\n' "$blocks" >"$blocks_file"
if [ "$blocks" -ge "$max" ]; then
  jq -n --arg m "kai: verification still failing after $blocks attempts; stopping anyway. Run 'kai verify' and fix the failures before shipping." '{systemMessage: $m}'
  exit 0
fi
printf 'kai: verification failed (attempt %s of %s). Fix the failures before finishing; do not weaken or edit tests to make them pass. If a failure is unrelated to this change, say so explicitly with the evidence.\n\n%s\n' \
  "$blocks" "$max" "$output" >&2
exit 2
