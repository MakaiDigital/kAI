# shellcheck shell=sh disable=SC2034

kai_die() {
  printf 'kai: %s\n' "$*" >&2
  exit "${kai_die_status:-1}"
}

kai_load_config() {
  KAI_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -f "$KAI_REPO_ROOT/.kai/config" ] || return 1
  sh -n "$KAI_REPO_ROOT/.kai/config" || kai_die ".kai/config is not valid sh; fix it, then retry"
  . "$KAI_REPO_ROOT/.kai/config"
  : "${KAI_LEVEL:=1}"
  : "${KAI_TICKET_PROVIDER:=jira}"
  : "${KAI_TICKET_PREFIXES:=}"
  : "${KAI_TICKET_EXEMPT:=dependabot/* renovate/* kai-setup* kai-retro*}"
  : "${KAI_VERIFY_CMDS:=}"
  : "${KAI_BASE_BRANCH:=main}"
  : "${KAI_PROD_DEPLOY_PATTERN:=}"
  case $KAI_LEVEL in
    1 | 2 | 3 | 4) ;;
    *) kai_die "KAI_LEVEL in .kai/config must be 1, 2, 3 or 4, not '$KAI_LEVEL'" ;;
  esac
}

kai_require_config() {
  kai_load_config || kai_die "no .kai/config in this repository (run /kai:setup or kai init first)"
}

kai_state_dir() {
  _d="$(git rev-parse --absolute-git-dir)/kai"
  mkdir -p "$_d"
  printf '%s\n' "$_d"
}

kai_branch() {
  git symbolic-ref --short -q HEAD 2>/dev/null || true
}

kai_key_from() {
  case $KAI_TICKET_PROVIDER in
    github)
      _n=$(printf '%s\n' "$1" | grep -oiE '(^|[^A-Za-z0-9])(#|gh-)[0-9]+|(^|/)[0-9]+(-[A-Za-z]|$)|^[0-9]+:' | head -n1 | grep -oE '[0-9]+' || true)
      [ -n "$_n" ] && printf '%s\n' "$_n"
      ;;
    jira | linear)
      _prefix='[[:upper:]][[:upper:][:digit:]]+'
      _case=
      _alt=$(printf '%s' "$KAI_TICKET_PREFIXES" | tr -s ', \t\n' '||||' | sed 's/^|//;s/|$//')
      [ -z "$_alt" ] || { _prefix="($_alt)"; _case=i; }
      _k=$(printf '%s\n' "$1" | grep "-o${_case}E" "(^|[^A-Za-z0-9])$_prefix-[0-9]+" | head -n1 | sed 's/^[^A-Za-z0-9]//' | tr '[:lower:]' '[:upper:]' || true)
      [ -n "$_k" ] && printf '%s\n' "$_k"
      ;;
    *)
      kai_die "unknown KAI_TICKET_PROVIDER '$KAI_TICKET_PROVIDER' (expected jira, linear or github)"
      ;;
  esac
}

kai_fingerprint() {
  _idx=$(mktemp)
  cp "$(git rev-parse --git-path index)" "$_idx" 2>/dev/null || rm -f "$_idx"
  (
    cd "$KAI_REPO_ROOT" || exit 1
    export GIT_INDEX_FILE="$_idx"
    git add -A >/dev/null 2>&1
    git rm -r -q --cached --ignore-unmatch -- specs >/dev/null 2>&1
    git write-tree
  )
  rm -f "$_idx"
}

kai_base_ref() {
  if git rev-parse -q --verify "origin/$KAI_BASE_BRANCH" >/dev/null; then
    printf 'origin/%s\n' "$KAI_BASE_BRANCH"
  elif git rev-parse -q --verify "$KAI_BASE_BRANCH" >/dev/null; then
    printf '%s\n' "$KAI_BASE_BRANCH"
  else
    kai_die "base branch '$KAI_BASE_BRANCH' not found; pass --base or set KAI_BASE_BRANCH"
  fi
}

kai_rank() {
  case $1 in low) _r=1 ;; medium) _r=2 ;; high) _r=3 ;; *) _r=0 ;; esac
}

kai_changed_files() {
  {
    git diff -z --no-renames --name-only "$(git merge-base "$1" HEAD)" HEAD
    git diff -z --no-renames --name-only HEAD
    git ls-files -z -o --exclude-standard
  } | tr '\000' '\n' | sort -u
}

kai_change_tier() {
  git merge-base "$1" HEAD >/dev/null 2>&1 || kai_die "cannot diff against $1; in CI, check out with fetch-depth: 0"
  _rules=$(grep -vE '^[[:space:]]*(#|$)' "$KAI_REPO_ROOT/.kai/tiers" 2>/dev/null || true)
  _max=low
  _max_r=1
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _t=medium
    _t_r=0
    while read -r _pat _pt _rest; do
      # shellcheck disable=SC2254
      case $_f in
        $_pat) kai_rank "$_pt"; [ "$_r" -le "$_t_r" ] || { _t=$_pt; _t_r=$_r; } ;;
      esac
    done <<EOF
$_rules
EOF
    kai_rank "$_t"
    printf '%-6s %s\n' "$_t" "$_f" >&2
    [ "$_r" -le "$_max_r" ] || { _max=$_t; _max_r=$_r; }
  done <<EOF
$(kai_changed_files "$1")
EOF
  printf '%s\n' "$_max"
}

kai_gate_args() {
  base=
  branch=
  title=
  labels=
  while [ $# -gt 0 ]; do
    case $1 in
      --base) base=${2-}; shift 2 ;;
      --branch) branch=${2-}; shift 2 ;;
      --title) title=${2-}; shift 2 ;;
      --labels) labels=${2-}; shift 2 ;;
      *) kai_die "unknown option '$1' (expected --base, --branch, --title, --labels)" ;;
    esac
  done
  [ -n "$branch" ] || branch=$(kai_branch)
  exempt=
  set -f
  for _p in $KAI_TICKET_EXEMPT; do
    # shellcheck disable=SC2254
    case $branch in $_p) exempt=$branch ;; esac
  done
  set +f
  key=$(kai_key_from "$branch" || kai_key_from "$title" || true)
}

kai_lock_commits() {
  git log --reverse --format=%H -E --grep="^($1|test\($1\)): failing tests\$" "${2:-HEAD}" 2>/dev/null
}

kai_lock_files() {
  git show -z --no-renames --name-only --format= --diff-filter=AM "$1" -- ':(top)' ':(exclude,top)specs' | tr '\000' '\n'
}

kai_locked_paths() {
  for _c in $(kai_lock_commits "$1"); do
    kai_lock_files "$_c"
  done | grep . | sort -u
}
