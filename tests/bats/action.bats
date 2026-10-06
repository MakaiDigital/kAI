load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  printf 'specs/* low\n*.md low\n' >.kai/tiers
  mkdir -p specs/PAY-1
  printf '# Spec\n\n## Criteria\n\n- **C1** When a shopper taps, the system shall save.\n\n## Contract\n\n| Criterion | Test | Status | Evidence |\n|---|---|---|---|\n| C1 | `saves` | | |\n' >specs/PAY-1/spec.md
  git add -A && git commit -qm "PAY-1: definition"
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git remote add origin "$ORIGIN"
  git push -q origin main
  awk 'on && (/^        / || !NF) { print substr($0, 9); next } on { exit } /^      run: \|$/ { on = 1 }' \
    "$REPO_ROOT/actions/kai-gates/action.yml" >"$BATS_TEST_TMPDIR/run.sh"
}

change_pr() {
  git switch -qc PAY-1-work
  echo plan >specs/PAY-1/plan.md && git add -A && git commit -qm "PAY-1: plan"
  mkdir -p test && echo 'test("saves")' >test/save.test.js && git add -A && git commit -qm "PAY-1: failing tests"
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement"
  printf '# Evidence\n\nkai verify on commit %s at 2026-10-05T00:00:00Z.\n\nResult: **PASS**\n\n## Planned tests\n\n| Criterion | Test | Result | Output line |\n|---|---|---|---|\n| C1 | `saves` | PASS | `✔ saves` |\n' \
    "$(git rev-parse HEAD)" >specs/PAY-1/evidence.md
  sed -i.bak 's/^| C1 | `saves` | | |$/| C1 | `saves` | PASS | evidence.md |/' specs/PAY-1/spec.md && rm specs/PAY-1/spec.md.bak
  git add -A && git commit -qm "PAY-1: evidence"
  git push -q origin PAY-1-work
}

ci() {
  rm -rf "$BATS_TEST_TMPDIR/ci"
  git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/ci"
  cd "$BATS_TEST_TMPDIR/ci"
  git config user.email ci@example.com && git config user.name ci && git config commit.gpgsign false
  git checkout -q --detach origin/main
  [ -z "${2-}" ] || git merge -q --no-ff --no-edit "origin/$2"
  [ -z "${3-}" ] || eval "$3"
  KAI_GATES=$1 KAI_BIN=$KAI HEAD_REF=${2-} BASE_REF=main PR_TITLE="PAY-1: save favorites" PR_LABELS= \
    GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" sh -e "$BATS_TEST_TMPDIR/run.sh"
}

@test "a proper change PR passes" {
  change_pr
  run ci "ticket-ref definition tests-locked contract verify" PAY-1-work
  [ "$status" -eq 0 ]
  [[ "$output" == *"contract: PAY-1 proven"* ]]
}

@test "a PR that lowers KAI_LEVEL is still judged at the base branch's level" {
  git switch -qc PAY-1-work
  sed -i.bak 's/^KAI_LEVEL=3$/KAI_LEVEL=1/' .kai/config && rm .kai/config.bak
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement"
  git push -q origin PAY-1-work
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  [ "$status" -eq 1 ]
  [[ "$output" == *'without a "PAY-1: failing tests" commit'* ]]
}

@test "without the base branch's history the step fails instead of judging the PR by its own config" {
  git switch -qc PAY-1-work
  sed -i.bak 's/^KAI_LEVEL=3$/KAI_LEVEL=1/' .kai/config && rm .kai/config.bak
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement"
  git push -q origin PAY-1-work
  run ci "ticket-ref definition tests-locked contract" PAY-1-work "git update-ref -d refs/remotes/origin/main"
  [ "$status" -eq 1 ]
  [[ "$output" == *"origin/main not found"* ]]
}

@test "a tiers file the PR adds is ignored when the base branch has none" {
  git rm -q .kai/tiers && git commit -qm "no tiers" && git push -q origin main
  git switch -qc PAY-1-work
  printf '* low\n' >.kai/tiers && echo impl >app.js && git add -A && git commit -qm "PAY-1: implement"
  git push -q origin PAY-1-work
  run ci "tests-locked" PAY-1-work
  [ "$status" -eq 1 ]
  [[ "$output" == *'medium-tier change without a "PAY-1: failing tests" commit'* ]]
}

@test "metrics writes the step summary, and a missing base branch fails the step" {
  run ci metrics
  [ "$status" -eq 0 ]
  grep -q '^# Kai metrics' "$BATS_TEST_TMPDIR/summary.md"
  echo KAI_BASE_BRANCH=trunk >>.kai/config && git commit -qam "base is trunk" && git push -q origin main
  run ci metrics
  [ "$status" -eq 1 ]
  [[ "$output" == *"base branch 'trunk' not found"* ]]
}

@test "verify runs on every event and fails the step when a command fails" {
  write_config jira PAY 'exit 3'
  git commit -qam "verify fails" && git push -q origin main
  EVENT_ACTION=edited run ci verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  exit 3"* ]]
}
