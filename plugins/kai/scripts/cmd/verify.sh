# shellcheck shell=sh

kai_require_config
report=/dev/null
case ${1-} in
  --evidence) report=${2:?--evidence needs a file} ;;
  '') ;;
  *) kai_die "usage: kai verify [--evidence FILE]" ;;
esac

if [ -z "$KAI_VERIFY_CMDS" ]; then
  printf 'kai: KAI_VERIFY_CMDS is empty in .kai/config; nothing to verify\n' >&2
  exit 0
fi

state=$(kai_state_dir)
fingerprint=${KAI_FINGERPRINT:-$(kai_fingerprint)}
cd "$KAI_REPO_ROOT" || exit 1
if [ "$report" != /dev/null ]; then
  [ -z "$(git status --porcelain -- ':(top)' ':(exclude,top)specs')" ] ||
    kai_die "commit your changes first: evidence must describe a commit, and these files differ from it:
$(git status --short -- ':(top)' ':(exclude,top)specs')"
  mkdir -p "$(dirname -- "$report")"
fi

printf '# Evidence\n\nkai verify on commit %s at %s.\n' \
  "$(git rev-parse HEAD 2>/dev/null || echo none)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$report"
failed=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  if out=$(sh -c "$c" </dev/null 2>&1); then
    rc=0 result=PASS
    printf 'PASS  %s\n' "$c"
  else
    rc=$? result=FAIL failed=$((failed + 1))
    printf 'FAIL  %s (exit %s)\n' "$c" "$rc"
    printf '%s\n' "$out" | tail -n 40 | sed 's/^/      /'
  fi
  printf '\n## %s: %s (exit %s)\n\n~~~text\n%s\n~~~\n' "$result" "$c" "$rc" "$out" >>"$report"
done <<EOF
$KAI_VERIFY_CMDS
EOF

if [ "$failed" -eq 0 ]; then
  printf '\nResult: **PASS**\n' >>"$report"
  printf '%s\n' "$fingerprint" >"$state/verified"
else
  printf '\nResult: **FAIL** (%s failed)\n' "$failed" >>"$report"
  rm -f "$state/verified"
fi
[ "$report" = /dev/null ] || printf 'evidence written to %s\n' "$report"
[ "$failed" -eq 0 ]
