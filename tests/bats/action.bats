load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  printf 'docs/* low\n*.md low\n' >.kai/tiers
  mkdir -p docs/specs/PAY-1
  printf '# Spec\n\n## Criteria\n\n- **C1** When a shopper taps, the system shall save.\n\n## Contract\n\n| Criterion | Test | Status | Evidence |\n|---|---|---|---|\n| C1 | `saves` | | |\n' >docs/specs/PAY-1/spec.md
  git add -A && git commit -qm "PAY-1: definition"
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git remote add origin "$ORIGIN"
  git push -q origin main
  extract_step 1 >"$BATS_TEST_TMPDIR/run.sh"
  extract_step 2 >"$BATS_TEST_TMPDIR/report.sh"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/bin/sh
printf '%s\n' "$*" >>"$GH_LOG"
case $* in
  "api repos/"*"/issues/comments/"*) cat "$GH_EXISTING_BODY" ;;
  "api repos/"*"/issues/"*"/comments"*) [ -z "${GH_EXISTING_ID-}" ] || echo "$GH_EXISTING_ID" ;;
esac
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : >"$GH_LOG"
}

extract_step() {
  awk -v n="$1" 'on && (/^        / || !NF) { print substr($0, 9); next } on { on = 0 } /^      run: \|$/ { if (++seen == n) on = 1 }' \
    "$REPO_ROOT/actions/kai-gates/action.yml"
}

report_step() {
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" KAI_BIN=$KAI RUNNER_TEMP="$BATS_TEST_TMPDIR/runner" GH_LOG=$GH_LOG \
    GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_REPOSITORY=acme/app PR=7 HEAD_SHA=abc123 \
    RUN_URL=https://example.com/run/1 CAN_COMMENT=${CAN_COMMENT-true} sh -e "$BATS_TEST_TMPDIR/report.sh"
}

change_pr() {
  git switch -qc PAY-1-work
  echo plan >docs/specs/PAY-1/plan.md && git add -A && git commit -qm "PAY-1: plan"
  mkdir -p test && echo 'test("saves")' >test/save.test.js && git add -A && git commit -qm "PAY-1: failing tests"
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement"
  printf '# Evidence\n\nkai verify on commit %s at 2026-10-05T00:00:00Z.\n\nResult: **PASS**\n\n## Planned tests\n\n| Criterion | Test | Result | Output line |\n|---|---|---|---|\n| C1 | `saves` | PASS | `✔ saves` |\n' \
    "$(git rev-parse HEAD)" >docs/specs/PAY-1/evidence.md
  sed -i.bak 's/^| C1 | `saves` | | |$/| C1 | `saves` | PASS | evidence.md |/' docs/specs/PAY-1/spec.md && rm docs/specs/PAY-1/spec.md.bak
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
  RUNNER_TEMP="$BATS_TEST_TMPDIR/runner" KAI_GATES=$1 KAI_BIN=$KAI HEAD_REF=${2-} BASE_REF=main PR_TITLE="PAY-1: save favorites" PR_LABELS= \
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

@test "the action runs the CLI at the path the runner gives it" {
  bins=$(sed -n 's/^ *KAI_BIN: \${{ github.action_path }}//p' "$REPO_ROOT/actions/kai-gates/action.yml")
  [ "$(printf '%s\n' "$bins" | wc -l)" -eq 2 ]
  for bin in $bins; do
    run "$REPO_ROOT/actions/kai-gates$bin" help
    [ "$status" -eq 0 ]
    [[ "$output" == "usage: kai <command> [args]"* ]]
  done
}

@test "report mode: a failing gate is reported and the step stays green" {
  echo KAI_ENFORCE=report >>.kai/config && git commit -qam "report mode" && git push -q origin main
  git switch -qc PAY-1-work
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement" && git push -q origin PAY-1-work
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  [ "$status" -eq 0 ]
  [[ "$output" == *'without a "PAY-1: failing tests" commit'* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/runner/kai-gates/tests-locked.status")" = 1 ]
  [ "$(cat "$BATS_TEST_TMPDIR/runner/kai-gates/mode")" = report ]
}

@test "block mode: a failing gate is recorded and the step fails" {
  git switch -qc PAY-1-work
  echo impl >app.js && git add -A && git commit -qm "PAY-1: implement" && git push -q origin PAY-1-work
  run ci "ticket-ref tests-locked" PAY-1-work
  [ "$status" -eq 1 ]
  [ "$(cat "$BATS_TEST_TMPDIR/runner/kai-gates/ticket-ref.status")" = 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/runner/kai-gates/tests-locked.status")" = 1 ]
  [ "$(cat "$BATS_TEST_TMPDIR/runner/kai-gates/mode")" = block ]
}

@test "report mode still fails the step when metrics fails" {
  echo KAI_ENFORCE=report >>.kai/config
  echo KAI_BASE_BRANCH=trunk >>.kai/config && git commit -qam "base is trunk" && git push -q origin main
  run ci metrics
  [ "$status" -eq 1 ]
}

@test "the report step creates the sticky comment, once, when there is none" {
  change_pr
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  [ "$status" -eq 0 ]
  run report_step
  [ "$status" -eq 0 ]
  grep -q '^<!-- kai-gates -->' "$BATS_TEST_TMPDIR/summary.md"
  grep -q '^pr comment 7 --body-file ' "$GH_LOG"
  ! grep -q -- '-X PATCH' "$GH_LOG"
}

@test "the report step updates the existing comment in place" {
  change_pr
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  printf 'old body\n' >"$BATS_TEST_TMPDIR/old.md"
  GH_EXISTING_ID=99 GH_EXISTING_BODY="$BATS_TEST_TMPDIR/old.md" run report_step
  [ "$status" -eq 0 ]
  grep -q -- '-X PATCH repos/acme/app/issues/comments/99' "$GH_LOG"
  ! grep -q '^pr comment' "$GH_LOG"
}

@test "the report step leaves an unchanged comment alone" {
  change_pr
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  "$KAI" report --dir "$BATS_TEST_TMPDIR/runner/kai-gates" --sha abc123 --run-url https://example.com/run/1 >"$BATS_TEST_TMPDIR/old.md"
  GH_EXISTING_ID=99 GH_EXISTING_BODY="$BATS_TEST_TMPDIR/old.md" run report_step
  [ "$status" -eq 0 ]
  ! grep -q -- '-X PATCH' "$GH_LOG"
  ! grep -q '^pr comment' "$GH_LOG"
}

@test "on a fork's PR the report goes to the step summary and nothing is posted" {
  change_pr
  run ci "ticket-ref definition tests-locked contract" PAY-1-work
  CAN_COMMENT=false run report_step
  [ "$status" -eq 0 ]
  grep -q '^<!-- kai-gates -->' "$BATS_TEST_TMPDIR/summary.md"
  [ ! -s "$GH_LOG" ]
}

@test "the report step does nothing when no gate ran" {
  run report_step
  [ "$status" -eq 0 ]
  [ ! -s "$GH_LOG" ]
}
