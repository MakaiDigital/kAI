load helpers

setup() {
  make_repo
  MP="$BATS_TEST_TMPDIR/mp"
  mkdir -p "$MP"
}

install_kai() { "$KAI" init --target "$TEST_REPO" --marketplace "$MP" "$@"; }

snapshot() {
  find . -path ./.git -prune -o -type f -print | sort | xargs git hash-object
}

@test "installs into a fresh repository" {
  run install_kai --provider linear --prefixes "ENG" --verify "make check" --level 2
  [ "$status" -eq 0 ]
  grep -q '^KAI_LEVEL=2$' .kai/config
  grep -q '^KAI_TICKET_PROVIDER=linear$' .kai/config
  grep -q '^KAI_TICKET_PREFIXES="ENG"$' .kai/config
  grep -q "^KAI_VERIFY_CMDS='make check'$" .kai/config
  grep -q '^specs/\* low$' .kai/tiers
  [ -f .kai/constraints.md ] && [ -f .github/workflows/kai.yml ]
  grep -q 'kai:begin' CLAUDE.md
  grep -q '^## Things Claude gets wrong' CLAUDE.md
  [ "$(jq -r '.enabledPlugins["kai@makaidigital"]' .claude/settings.json)" = true ]
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.source' .claude/settings.json)" = directory ]
  [ "$(jq -r '.permissions.defaultMode' .claude/settings.json)" = plan ]
}

@test "a GitHub marketplace is pinned to the plugin version tag" {
  install_kai --marketplace acme/kai
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.repo' .claude/settings.json)" = acme/kai ]
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.ref' .claude/settings.json)" = "v$(jq -r .version "$REPO_ROOT/plugins/kai/.claude-plugin/plugin.json")" ]
  grep -q 'uses: acme/kai/actions/kai-gates@v' .github/workflows/kai.yml
}

@test "the config is valid shell and round-trips tricky verify commands" {
  install_kai --verify "npm run lint && echo 'it''s fine' | grep -q fine" --verify "npm test"
  . .kai/config
  [ "$KAI_VERIFY_CMDS" = "npm run lint && echo 'it''s fine' | grep -q fine
npm test" ]
}

@test "detects the test command when none is given" {
  echo '{"scripts":{"test":"jest"}}' >package.json
  install_kai
  grep -q "^KAI_VERIFY_CMDS='npm test'$" .kai/config
}

@test "is idempotent" {
  install_kai
  before=$(snapshot)
  run install_kai
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "preserves existing CLAUDE.md content and settings" {
  printf '# Team notes\n\nUse pnpm.\n' >CLAUDE.md
  mkdir -p .claude
  echo '{"permissions":{"defaultMode":"acceptEdits","allow":["Bash(pnpm test)"]}}' >.claude/settings.json
  install_kai
  head -3 CLAUDE.md | grep -q 'Use pnpm.'
  grep -q 'kai:begin' CLAUDE.md
  [ "$(jq -r '.permissions.defaultMode' .claude/settings.json)" = acceptEdits ]
  [ "$(jq -r '.permissions.allow[0]' .claude/settings.json)" = "Bash(pnpm test)" ]
}

@test "re-running replaces only the CLAUDE.md block" {
  install_kai
  printf '\nMore team notes.\n' >>CLAUDE.md
  sed -i.bak 's/## How we deliver (Kai)/## Old heading/' CLAUDE.md && rm CLAUDE.md.bak
  install_kai
  grep -q 'More team notes.' CLAUDE.md
  grep -q '## How we deliver (Kai)' CLAUDE.md
  ! grep -q 'Old heading' CLAUDE.md
  [ "$(grep -c 'kai:begin' CLAUDE.md)" -eq 1 ]
}

@test "never overwrites a file that differs, and never touches config or tiers" {
  install_kai
  echo "- Local rule." >>.kai/constraints.md
  echo "src/* high" >>.kai/tiers
  run install_kai --level 2
  grep -q 'Local rule' .kai/constraints.md
  cmp -s .kai/constraints.md.kai-new "$REPO_ROOT/plugins/kai/template/.kai/constraints.md"
  grep -q '^KAI_LEVEL=1$' .kai/config
  grep -q '^src/\* high$' .kai/tiers
}

@test "dry run writes nothing" {
  before=$(snapshot)
  run install_kai --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would write .kai/config"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "level 3 adds REVIEW.md and the review workflow" {
  install_kai --marketplace acme/kai --level 3
  grep -q '^KAI_LEVEL=3$' .kai/config
  [ -f REVIEW.md ]
  cmp -s .claude/agents/contract-reviewer.md "$REPO_ROOT/plugins/kai/agents/contract-reviewer.md"
  cmp -s .claude/agents/spec-critic.md "$REPO_ROOT/plugins/kai/agents/spec-critic.md"
}

@test "level 4 adds the weekly metrics workflow" {
  install_kai --marketplace acme/kai --level 4
  grep -q 'uses: acme/kai/actions/kai-gates@v' .github/workflows/kai-metrics.yml
  grep -q 'gates: metrics' .github/workflows/kai-metrics.yml
}

@test "the review workflow accepts either credential and skips without one" {
  install_kai --marketplace acme/kai --level 3
  grep -q 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' .github/workflows/kai-review.yml
  grep -q 'id-token: write' .github/workflows/kai-review.yml
  grep -q 'Kai review skipped' .github/workflows/kai-review.yml
  ! grep -q 'plugin_marketplaces\|KAI_MARKETPLACE_TOKEN' .github/workflows/kai-review.yml
}

@test "levels below 3 skip the review workflow" {
  install_kai --level 2
  [ ! -e REVIEW.md ] && [ ! -e .github/workflows/kai-review.yml ] && [ ! -e .github/workflows/kai-metrics.yml ] && [ ! -e .claude/agents ]
}

@test "defaults to the MakaiDigital/kAI marketplace" {
  "$KAI" init --target "$TEST_REPO"
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.repo' .claude/settings.json)" = MakaiDigital/kAI ]
}

@test "rejects bad input" {
  run install_kai --level 5
  [ "$status" -ne 0 ]
  run "$KAI" init --target "$BATS_TEST_TMPDIR" --marketplace "$MP"
  [[ "$output" == *"not a git repository"* ]]
}
