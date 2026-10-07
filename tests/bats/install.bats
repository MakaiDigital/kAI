bats_require_minimum_version 1.5.0
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

kai_version() { jq -r .version "$REPO_ROOT/plugins/kai/.claude-plugin/plugin.json"; }

publish_tag() {
  git init -q --bare "$BATS_TEST_TMPDIR/github/acme/kai"
  git push -q "$BATS_TEST_TMPDIR/github/acme/kai" "$1:refs/tags/v$(kai_version)"
}

@test "installs into a fresh repository" {
  run install_kai --provider linear --prefixes "ENG" --verify "make check" --level 2
  [ "$status" -eq 0 ]
  grep -q '^KAI_LEVEL=2$' .kai/config
  grep -q '^KAI_TICKET_PROVIDER=linear$' .kai/config
  grep -q '^KAI_TICKET_PREFIXES="ENG"$' .kai/config
  grep -q "^KAI_VERIFY_CMDS='make check'$" .kai/config
  grep -q '^# KAI_BASE_BRANCH=main$' .kai/config
  grep -q '^specs/\* low$' .kai/tiers
  [ -f .kai/constraints.md ]
  grep -q 'uses: MakaiDigital/kAI/actions/kai-gates@v' .github/workflows/kai.yml
  [[ "$output" == *"CI uses MakaiDigital/kAI's kai-gates action; change it if you host Kai elsewhere."* ]]
  grep -q 'kai:begin' CLAUDE.md
  grep -q '^## Things Claude gets wrong' CLAUDE.md
  [ "$(jq -r '.enabledPlugins["kai@makaidigital"]' .claude/settings.json)" = true ]
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.source' .claude/settings.json)" = directory ]
  [ "$(jq -r '.permissions.defaultMode' .claude/settings.json)" = plan ]
}

@test "the config's comments show the real defaults" {
  install_kai
  . "$REPO_ROOT/plugins/kai/scripts/lib/common.sh"
  kai_load_config
  grep -qxF '# Commands that must pass before work is done, one per line, run from the repository root with /bin/sh' .kai/config
  grep -qxF "# KAI_BASE_BRANCH=$KAI_BASE_BRANCH" .kai/config
  grep -qxF "# KAI_TICKET_EXEMPT=\"$KAI_TICKET_EXEMPT\"   # branches that need no ticket key; they skip every gate" .kai/config
}

@test "a GitHub marketplace is pinned to the plugin version tag" {
  install_kai --marketplace acme/kai
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.repo' .claude/settings.json)" = acme/kai ]
  [ "$(jq -r '.extraKnownMarketplaces.makaidigital.source.ref' .claude/settings.json)" = "v$(kai_version)" ]
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

@test "ignores npm's placeholder test script" {
  echo '{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}' >package.json
  run install_kai
  grep -q "^KAI_VERIFY_CMDS=''$" .kai/config
  [[ "$output" == *"no test command detected"* ]]
}

@test "is idempotent" {
  install_kai
  before=$(snapshot)
  run install_kai
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "installs at the top level when run from a subdirectory" {
  mkdir src
  cd src
  "$KAI" init --marketplace "$MP"
  cd "$TEST_REPO"
  [ -f .kai/config ]
  [ -f .claude/settings.json ]
  [ "$(head -n 1 CLAUDE.md)" = "# repo" ]
  [ ! -e src/.kai ]
  [ ! -e src/CLAUDE.md ]
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

@test "adds Kai's permission rules once, after the person's own" {
  mkdir -p .claude
  echo '{"permissions":{"deny":["Bash(rm -rf *)","Bash(gh pr merge *)"],"ask":["Bash(npm publish *)"]}}' >.claude/settings.json
  install_kai
  [ "$(jq -c .permissions.deny .claude/settings.json)" = '["Bash(rm -rf *)","Bash(gh pr merge *)","Bash(gh api *pulls/*/merge*)","Bash(gh pr edit *kai:tests-changed*)","Bash(gh issue edit *kai:tests-changed*)"]' ]
  [ "$(jq -c .permissions.ask .claude/settings.json)" = '["Bash(npm publish *)","Bash(git push * main)","Bash(git push * main *)","Bash(git push *:main)","Bash(git push *:refs/heads/main)"]' ]
  before=$(snapshot)
  run install_kai
  [[ "$output" == *"already up to date"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "uses the default branch that origin/HEAD names" {
  git update-ref refs/remotes/origin/trunk HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
  install_kai
  jq -e '.permissions.ask | index("Bash(git push * trunk)") and index("Bash(git push *:refs/heads/trunk)")' .claude/settings.json
  run ! grep -q 'git push \* main' .claude/settings.json
  . .kai/config
  [ "$KAI_BASE_BRANCH" = trunk ]
}

@test "a local branch named origin/main does not change the detected base" {
  git branch origin/main
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  install_kai
  jq -e '.permissions.ask | index("Bash(git push * main)")' .claude/settings.json
  grep -q '^# KAI_BASE_BRANCH=main$' .kai/config
}

@test "an upgrade guards the base branch its config names" {
  mkdir -p .kai && echo 'KAI_BASE_BRANCH=develop' >.kai/config
  install_kai
  jq -e '.permissions.ask | index("Bash(git push * develop)")' .claude/settings.json
  run ! grep -q 'git push \* main' .claude/settings.json
}

@test "an invalid settings.json stops the install before anything is written" {
  mkdir -p .claude
  echo '{"permissions":' >.claude/settings.json
  before=$(snapshot)
  run install_kai
  [ "$status" -ne 0 ]
  [[ "$output" == *".claude/settings.json"* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "re-running replaces only the CLAUDE.md block" {
  install_kai
  printf '\nMore team notes.\n' >>CLAUDE.md
  sed -i.bak 's/## How we deliver (Kai)/## Old heading/' CLAUDE.md && rm CLAUDE.md.bak
  install_kai
  grep -q 'More team notes.' CLAUDE.md
  grep -q '## How we deliver (Kai)' CLAUDE.md
  run ! grep -q 'Old heading' CLAUDE.md
  [ "$(grep -c 'kai:begin' CLAUDE.md)" -eq 1 ]
}

@test "replaces the block in a CRLF CLAUDE.md, keeping its other lines" {
  printf '# Notes\r\n\r\n<!-- kai:begin (managed by the kai installer; edit outside this block) -->\r\nold block\r\n<!-- kai:end -->\r\n\r\nMy notes.\r\n' >CLAUDE.md
  install_kai
  [ "$(grep -c 'kai:begin' CLAUDE.md)" -eq 1 ]
  [ "$(grep -c 'kai:end' CLAUDE.md)" -eq 1 ]
  grep -q '## How we deliver (Kai)' CLAUDE.md
  grep -q $'^My notes.\r$' CLAUDE.md
  run ! grep -q 'old block' CLAUDE.md
}

@test "leaves a CLAUDE.md block without its end marker alone and writes CLAUDE.md.kai-new" {
  printf '# Notes\n\n<!-- kai:begin (managed by the kai installer; edit outside this block) -->\nold block\n\nMy notes.\n' >CLAUDE.md
  cp CLAUDE.md "$BATS_TEST_TMPDIR/CLAUDE.md"
  run install_kai
  [ "$status" -eq 0 ]
  [[ "$output" == *"  CLAUDE.md has a kai block without its end marker; review CLAUDE.md.kai-new and merge by hand"* ]]
  cmp CLAUDE.md "$BATS_TEST_TMPDIR/CLAUDE.md"
  grep -q '## How we deliver (Kai)' CLAUDE.md.kai-new
}

@test "keeps the CLAUDE.md block markers, or existing repositories get a second block" {
  install_kai
  grep -qxF '<!-- kai:begin (managed by the kai installer; edit outside this block) -->' CLAUDE.md
  grep -qxF '<!-- kai:end -->' CLAUDE.md
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

@test "updates a Kai workflow in place when only its kai-gates ref differs" {
  install_kai --marketplace acme/kai --level 4 --ref v0.0.1
  grep -q 'kai-gates@v0.0.1' .github/workflows/kai.yml
  publish_tag HEAD
  run install_kai --marketplace acme/kai --level 4
  [ "$status" -eq 0 ]
  grep -qxF "      - uses: acme/kai/actions/kai-gates@$(git rev-parse HEAD) # v$(kai_version)" .github/workflows/kai.yml
  grep -qxF "      - uses: acme/kai/actions/kai-gates@$(git rev-parse HEAD) # v$(kai_version)" .github/workflows/kai-metrics.yml
  [ ! -e .github/workflows/kai.yml.kai-new ]
  [ ! -e .github/workflows/kai-metrics.yml.kai-new ]
}

@test "pins kai-gates to the commit an annotated version tag points at" {
  git -c tag.gpgsign=false tag -a -m release annotated
  publish_tag annotated
  run install_kai --marketplace acme/kai
  [ "$status" -eq 0 ]
  grep -qxF "      - uses: acme/kai/actions/kai-gates@$(git rev-parse HEAD) # v$(kai_version)" .github/workflows/kai.yml
}

@test "keeps the ref and says so when it is not a tag of the action repository" {
  run install_kai --marketplace acme/kai --ref main
  [ "$status" -eq 0 ]
  grep -qxF '      - uses: acme/kai/actions/kai-gates@main' .github/workflows/kai.yml
  [[ "$output" == *"could not find tag main in acme/kai, so CI uses kai-gates@main"* ]]
}

@test "updates the review workflow in place when only its claude-code-action ref differs" {
  install_kai --marketplace acme/kai --level 3
  sed -i.bak 's/claude-code-action@.*/claude-code-action@v1.0.0/' .github/workflows/kai-review.yml
  run install_kai --marketplace acme/kai --level 3
  [ "$status" -eq 0 ]
  cmp -s .github/workflows/kai-review.yml "$REPO_ROOT/plugins/kai/template/.github/workflows/kai-review.yml"
  [ ! -e .github/workflows/kai-review.yml.kai-new ]
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

@test "the gates job is the required kai check" {
  install_kai
  grep -qE '^[[:space:]]+name: kai$' .github/workflows/kai.yml
}

@test "the review workflow accepts either credential and skips without one" {
  install_kai --marketplace acme/kai --level 3
  grep -q 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' .github/workflows/kai-review.yml
  grep -q 'id-token: write' .github/workflows/kai-review.yml
  run ! grep -q 'use_sticky_comment\|track_progress' .github/workflows/kai-review.yml
  grep -q '<!-- kai-review -->' .github/workflows/kai-review.yml
  grep -q 'disallowedTools Agent' .github/workflows/kai-review.yml
  grep -q 'Kai review skipped' .github/workflows/kai-review.yml
  run ! grep -q 'plugin_marketplaces\|KAI_MARKETPLACE_TOKEN' .github/workflows/kai-review.yml
}

@test "the review workflow cancels superseded runs, needs no GitHub App, and edits only its own comment" {
  install_kai --marketplace acme/kai --level 3
  grep -q '^concurrency:' .github/workflows/kai-review.yml
  grep -q 'cancel-in-progress: true' .github/workflows/kai-review.yml
  grep -qF 'github_token: ${{ github.token }}' .github/workflows/kai-review.yml
  grep -qF '.user.login == "github-actions[bot]"' .github/workflows/kai-review.yml
  grep -q 'Reviewed commit' .github/workflows/kai-review.yml
}

@test "the review follows the base branch's instructions, not the PR's" {
  install_kai --marketplace acme/kai --level 3
  grep -qF 'for f in REVIEW.md CLAUDE.md .claude/agents/contract-reviewer.md .claude/agents/spec-critic.md; do' .github/workflows/kai-review.yml
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
