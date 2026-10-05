# shellcheck shell=sh disable=SC2034

kai_die() {
  printf 'kai: %s\n' "$*" >&2
  exit 1
}

kai_load_config() {
  KAI_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -f "$KAI_REPO_ROOT/.kai/config" ] || return 1
  . "$KAI_REPO_ROOT/.kai/config"
  : "${KAI_LEVEL:=1}"
  : "${KAI_TICKET_PROVIDER:=jira}"
  : "${KAI_TICKET_PREFIXES:=}"
  : "${KAI_TICKET_EXEMPT:=dependabot/* renovate/* kai-setup*}"
  : "${KAI_VERIFY_CMDS:=}"
  : "${KAI_BASE_BRANCH:=main}"
  : "${KAI_PROD_DEPLOY_PATTERN:=}"
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
      _n=$(printf '%s\n' "$1" | grep -oiE '(^|[^A-Za-z0-9])(#|gh-)[0-9]+|(^|/)[0-9]+(-|$)' | head -n1 | grep -oE '[0-9]+' || true)
      [ -n "$_n" ] && printf '%s\n' "$_n"
      ;;
    jira | linear)
      _prefix='[A-Z][A-Z0-9]+'
      [ -z "$KAI_TICKET_PREFIXES" ] || _prefix="($(printf '%s' "$KAI_TICKET_PREFIXES" | tr -s ' ' '|'))"
      _k=$(printf '%s\n' "$1" | grep -oiE "(^|[^A-Za-z0-9])$_prefix-[0-9]+" | head -n1 | sed 's/^[^A-Za-z0-9]//' | tr '[:lower:]' '[:upper:]' || true)
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
    git diff --name-only "$(git merge-base "$1" HEAD)" HEAD
    git diff --name-only HEAD
    git ls-files -o --exclude-standard
  } | sort -u
}

kai_change_tier() {
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
  for _p in $KAI_TICKET_EXEMPT; do
    # shellcheck disable=SC2254
    case $branch in $_p) exempt=$branch ;; esac
  done
  key=$(kai_key_from "$branch" || kai_key_from "$title" || true)
  if [ -z "$exempt" ] && [ -n "$key" ]; then
    case $branch in
      "$key"-cleanup*)
        if git diff --diff-filter=D --name-only "${base:-$(kai_base_ref)}...HEAD" -- ":(top)specs/$key/spec.md" ":(top)specs/$key/evidence.md" 2>/dev/null | grep -q .; then
          exempt=$branch
        fi
        ;;
    esac
  fi
}

kai_locked_commit() {
  git log --format=%H -n1 --grep="^$1: failing tests\$" 2>/dev/null
}

kai_locked_files() {
  git show --name-only --format= --diff-filter=AM "$1"
}
