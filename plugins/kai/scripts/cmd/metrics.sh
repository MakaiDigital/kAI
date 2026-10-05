# shellcheck shell=sh disable=SC2154,SC2016

kai_require_config
weeks=12
ref=
while [ $# -gt 0 ]; do
  case $1 in
    --weeks) weeks=${2:?--weeks needs a number}; shift 2 ;;
    --base) ref=${2:?--base needs a ref}; shift 2 ;;
    *) kai_die "usage: kai metrics [--weeks N] [--base REF]" ;;
  esac
done
[ -n "$ref" ] || ref=$(kai_base_ref)
cd "$KAI_REPO_ROOT" || exit 1

now=${KAI_NOW:-$(date +%s)}
added() { git log "$ref" --diff-filter=A --format=%ct -- "$1" | tail -n 1; }

tickets=$(git ls-tree -d --name-only "$ref" specs/ 2>/dev/null | while IFS= read -r dir; do
  done_at=$(added "$dir/evidence.md")
  [ -n "$done_at" ] || continue
  plan=$(added "$dir/plan.md")
  start=$(printf '%s\n%s\n' "$(added "$dir/spec.md")" "$plan" | grep . | sort -n | head -n 1)
  spec_after_plan=0
  [ -z "$plan" ] || spec_after_plan=$(git log "$ref" --format=%ct -- "$dir/spec.md" | awk -v p="$plan" '$1 > p' | wc -l)
  after_done=$(git log "$ref" --format=%ct -- "$dir" | awk -v d="$done_at" '$1 > d' | wc -l)
  week=$(((now - done_at) / 604800))
  [ "$week" -lt "$weeks" ] || continue
  reworked=0
  [ $((spec_after_plan + after_done)) -eq 0 ] || reworked=1
  printf '%s %s %s\n' "$week" "$(((done_at - ${start:-$done_at}) / 3600))" "$reworked"
done | sort -k1,1n -k2,2n)

week_of() {
  t=$((now - $1 * 604800))
  date -u -d "@$t" +%F 2>/dev/null || date -u -r "$t" +%F
}

printf '# Kai metrics\n\nLast %s weeks on `%s`, from the `specs/` history. Speed and quality are shown together: neither means much alone.\n\n' "$weeks" "$ref"
printf '| Week ending | Shipped | Median lead time (days) | Reworked |\n|---|---|---|---|\n'
printf '%s\n' "$tickets" | awk -v weeks="$weeks" '
  NF {
    n[$1]++; lead[$1, n[$1]] = $2; rw[$1] += $3
    all[++total] = $2; allrw += $3
  }
  function median(w,   k) { k = n[w]; return (k % 2) ? lead[w, (k + 1) / 2] : (lead[w, k / 2] + lead[w, k / 2 + 1]) / 2 }
  END {
    for (w = 0; w < weeks; w++) if (n[w]) { m[w] = median(w) / 24; sum += m[w]; cnt++ }
    mean = cnt ? sum / cnt : 0
    for (w in m) sq += (m[w] - mean) ^ 2
    sd = cnt > 1 ? sqrt(sq / (cnt - 1)) : 0
    for (w = weeks - 1; w >= 0; w--) {
      if (!n[w]) { printf "| @%d | 0 | - | - |\n", w; continue }
      flag = (cnt >= 4 && sd > 0 && m[w] > mean + 2 * sd) ? " ▲" : ""
      printf "| @%d | %d | %.1f%s | %d of %d |\n", w, n[w], m[w], flag, rw[w], n[w]
    }
    if (total) {
      for (i = 1; i <= total; i++) for (j = i + 1; j <= total; j++) if (all[j] < all[i]) { t = all[i]; all[i] = all[j]; all[j] = t }
      med = (total % 2) ? all[(total + 1) / 2] : (all[total / 2] + all[total / 2 + 1]) / 2
      printf "\n**%d tickets shipped**, median lead time **%.1f days**, **%d%% reworked**.\n", total, med / 24, 100 * allrw / total
    } else {
      printf "\nNo tickets shipped in this period.\n"
    }
  }' | while IFS= read -r line; do
  case $line in
    "| @"*) w=${line#"| @"}; w=${w%% *}; printf '| %s |%s\n' "$(week_of "$w")" "${line#"| @$w |"}" ;;
    *) printf '%s\n' "$line" ;;
  esac
done

printf '\nLead time runs from the first of `spec.md` and `plan.md` to `evidence.md` landing on the base branch. A ticket counts as reworked when its spec changed after the plan, or its specs changed again after the evidence landed. ▲ marks a week whose median lead time is more than two standard deviations above the mean for the period.\n'
