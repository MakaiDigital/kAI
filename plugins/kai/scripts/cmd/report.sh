# shellcheck shell=sh disable=SC2154

dir=
sha=
run_url=
while [ $# -gt 0 ]; do
  case $1 in
    --dir) dir=${2-}; shift 2 ;;
    --sha) sha=${2-}; shift 2 ;;
    --run-url) run_url=${2-}; shift 2 ;;
    *) kai_die "unknown option '$1' (expected --dir, --sha, --run-url)" ;;
  esac
done
[ -f "$dir/gates" ] || kai_die "report: no gate results in '$dir'"

mode=$(cat "$dir/mode" 2>/dev/null || true)
verdict=PASS
while read -r gate; do
  [ "$(cat "$dir/$gate.status")" = 0 ] || verdict=FAIL
done <"$dir/gates"

printf '<!-- kai-gates -->\n## Kai gates\n\n**VERDICT: %s**\n\n' "$verdict"
if [ "$mode" = report ] && [ "$verdict" = FAIL ]; then
  printf 'KAI_ENFORCE=report: this is a report, so the check stays green.\n\n'
fi
printf '| Gate | Result | Detail |\n|---|---|---|\n'
while read -r gate; do
  if [ "$(cat "$dir/$gate.status")" = 0 ]; then result='✅ pass'; else result='❌ fail'; fi
  detail=$(sed -n '/./{p;q;}' "$dir/$gate.out" | sed 's/|/\\|/g')
  printf '| %s | %s | %s |\n' "$gate" "$result" "$detail"
done <"$dir/gates"
while read -r gate; do
  [ "$(cat "$dir/$gate.status")" != 0 ] || continue
  printf '\n### %s\n\n```text\n' "$gate"
  cat "$dir/$gate.out"
  printf '```\n'
done <"$dir/gates"
printf '\n<sub>Checked commit %s · [View run](%s)</sub>\n' "$sha" "$run_url"
