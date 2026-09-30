# shellcheck shell=sh

TEMPLATE="$KAI_ROOT/template"
VERSION=$(jq -r .version "$KAI_ROOT/.claude-plugin/plugin.json")
BEGIN_MARK='<!-- kai:begin (managed by the kai installer; edit outside this block) -->'
END_MARK='<!-- kai:end -->'

init_usage() {
  cat <<'EOF'
usage: kai init [options]

  --target DIR          repository to install into (default: current directory)
  --level N             1 (intent, build, prove), 2 (adds specs and tiers), 3 (adds locked
                        tests, contract gate, /kai:ship, and CI review), or 4 (adds
                        /kai:accept, /kai:retro, and weekly metrics); default 1
  --provider NAME       jira | linear | github (default: jira)
  --prefixes "A B"      Jira/Linear project keys allowed in branch names
  --verify CMD          a command that must pass before work is done (repeatable;
                        default: detected from the repository)
  --marketplace SRC     OWNER/REPO hosting the makaidigital marketplace, or a local directory
                        (default: MakaiDigital/kAI)
  --ref REF             marketplace and action ref (default: v<plugin version>)
  --no-ci               skip .github/workflows/kai.yml
  --dry-run             show what would change without writing
EOF
}

die() { printf 'kai init: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

target=.
level=1
provider=jira
prefixes=
verify=
marketplace=${KAI_MARKETPLACE:-MakaiDigital/kAI}
ref="v$VERSION"
ci=1
dry=0
changed=0

while [ $# -gt 0 ]; do
  case $1 in
    --target) target=${2:?}; shift 2 ;;
    --level) level=${2:?}; shift 2 ;;
    --provider) provider=${2:?}; shift 2 ;;
    --prefixes) prefixes=${2-}; shift 2 ;;
    --verify) verify="${verify:+$verify
}${2:?}"; shift 2 ;;
    --marketplace) marketplace=${2:?}; shift 2 ;;
    --ref) ref=${2:?}; shift 2 ;;
    --no-ci) ci=0; shift ;;
    --dry-run) dry=1; shift ;;
    -h | --help) init_usage; exit 0 ;;
    *) init_usage >&2; exit 64 ;;
  esac
done

command -v jq >/dev/null || die "jq is required"
case $provider in jira | linear | github) ;; *) die "--provider must be jira, linear or github" ;; esac
case $level in 1 | 2 | 3 | 4) ;; *) die "--level must be 1, 2, 3 or 4" ;; esac
target=$(CDPATH='' cd -- "$target" && pwd) || die "no such directory: $target"
git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "$target is not a git repository"

if [ -d "$marketplace" ]; then
  source_json=$(jq -cn --arg p "$(CDPATH='' cd -- "$marketplace" && pwd)" '{source: "directory", path: $p}')
  action_repo=OWNER/REPO
else
  source_json=$(jq -cn --arg r "$marketplace" --arg ref "$ref" '{source: "github", repo: $r, ref: $ref}')
  action_repo=$marketplace
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

write() {
  if [ "$dry" -eq 1 ]; then
    say "would write $1"
  else
    mkdir -p "$(dirname -- "$target/$1")"
    cp "$2" "$target/$1"
    say "wrote $1"
  fi
  changed=1
}

create() {
  [ -e "$target/$1" ] || write "$1" "$2"
}

place() {
  if [ ! -e "$target/$1" ]; then
    write "$1" "$2"
  elif ! cmp -s "$2" "$target/$1" && ! cmp -s "$2" "$target/$1.kai-new" 2>/dev/null; then
    write "$1.kai-new" "$2"
    say "  $1 differs from this version; review $1.kai-new and merge by hand"
  fi
}

if [ -n "$verify" ]; then
  :
elif [ -f "$target/package.json" ] && jq -e '.scripts.test' "$target/package.json" >/dev/null 2>&1; then
  verify="npm test"
elif [ -f "$target/Makefile" ] && grep -q '^test:' "$target/Makefile"; then
  verify="make test"
elif [ -f "$target/go.mod" ]; then
  verify="go test ./..."
elif [ -f "$target/Cargo.toml" ]; then
  verify="cargo test"
elif [ -f "$target/pyproject.toml" ]; then
  verify="pytest"
fi
[ -f "$target/.kai/config" ] || [ -n "$verify" ] || say "  no test command detected; set KAI_VERIFY_CMDS in .kai/config"

cat >"$work/config" <<EOF
# Kai configuration, sourced by POSIX sh. Quote values that contain spaces.

# 1 = intent, build, prove. 2 = adds specs, tiers and the definition gate. 3 = adds locked tests, the contract gate and review. 4 = adds acceptance, retros and metrics.
KAI_LEVEL=$level

# Ticket system: jira | linear | github
KAI_TICKET_PROVIDER=$provider
# Jira/Linear project keys allowed in branch names and PR titles, space-separated (empty = any KEY-123)
KAI_TICKET_PREFIXES="$prefixes"

# Commands that must pass before work is done, one per line, run from the repository root
KAI_VERIFY_CMDS='$(printf '%s' "$verify" | sed "s/'/'\\\\''/g")'

# Optional, shown with their defaults:
# KAI_BASE_BRANCH=main
# KAI_TICKET_EXEMPT="dependabot/* renovate/* kai-setup*"   # branches that need no ticket key
# KAI_PROD_DEPLOY_PATTERN=""                    # regex for production deploys; they then need KAI_RELEASE_APPROVAL
EOF
create .kai/config "$work/config"
create .kai/tiers "$TEMPLATE/.kai/tiers"
place .kai/constraints.md "$TEMPLATE/.kai/constraints.md"

if [ "$ci" -eq 1 ]; then
  sed -e "s#__ACTION_REPO__#$action_repo#g" -e "s#__ACTION_REF__#$ref#g" \
    "$TEMPLATE/.github/workflows/kai.yml" >"$work/kai.yml"
  place .github/workflows/kai.yml "$work/kai.yml"
  if [ "$level" -ge 3 ]; then
    sed -e "s#__ACTION_REPO__#$action_repo#g" "$TEMPLATE/.github/workflows/kai-review.yml" >"$work/kai-review.yml"
    place .github/workflows/kai-review.yml "$work/kai-review.yml"
  fi
  if [ "$level" -ge 4 ]; then
    sed -e "s#__ACTION_REPO__#$action_repo#g" -e "s#__ACTION_REF__#$ref#g" \
      "$TEMPLATE/.github/workflows/kai-metrics.yml" >"$work/kai-metrics.yml"
    place .github/workflows/kai-metrics.yml "$work/kai-metrics.yml"
  fi
fi
[ "$level" -lt 3 ] || create REVIEW.md "$TEMPLATE/REVIEW.md"

{ printf '%s\n' "$BEGIN_MARK"; cat "$TEMPLATE/claude-block.md"; printf '%s\n' "$END_MARK"; } >"$work/block"
if [ ! -f "$target/CLAUDE.md" ]; then
  { printf '# %s\n\n## Commands\n\n## Conventions\n\n## Architecture\n\n## Things Claude gets wrong\n\n' "$(basename -- "$target")"
    cat "$work/block"; } >"$work/CLAUDE.md"
elif grep -qF "$BEGIN_MARK" "$target/CLAUDE.md"; then
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v f="$work/block" '
    $0 == b { while ((getline l < f) > 0) print l; skip = 1; next }
    $0 == e { skip = 0; next }
    !skip' "$target/CLAUDE.md" >"$work/CLAUDE.md"
else
  { cat "$target/CLAUDE.md"; printf '\n'; cat "$work/block"; } >"$work/CLAUDE.md"
fi
cmp -s "$work/CLAUDE.md" "$target/CLAUDE.md" 2>/dev/null || write CLAUDE.md "$work/CLAUDE.md"

settings="$target/.claude/settings.json"
current='{}'
[ ! -f "$settings" ] || current=$(cat "$settings")
printf '%s' "$current" | jq -e 'type == "object"' >/dev/null 2>&1 || die ".claude/settings.json is not a JSON object"
printf '%s' "$current" | jq --argjson src "$source_json" '
  .extraKnownMarketplaces.makaidigital = {source: $src}
  | .enabledPlugins["kai@makaidigital"] = true
  | .permissions.defaultMode //= "plan"
  | .env.SUPERPOWERS_DISABLE_TELEMETRY //= "1"' >"$work/settings.json"
[ "$(printf '%s' "$current" | jq -S .)" = "$(jq -S . "$work/settings.json")" ] ||
  write .claude/settings.json "$work/settings.json"

if [ "$changed" -eq 0 ]; then
  say "kai $VERSION: already up to date"
elif [ "$dry" -eq 0 ]; then
  say ""
  say "Next: review .kai/config and .kai/tiers, then commit."
  say "Teammates are prompted to install the kai plugin from the makaidigital marketplace."
fi
