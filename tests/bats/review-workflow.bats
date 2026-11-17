load helpers

WORKFLOW="$REPO_ROOT/plugins/kai/template/.github/workflows/kai-review.yml"

setup() {
  make_repo
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git remote add origin "$ORIGIN"
  git push -q origin main
  extract_step 1 >"$BATS_TEST_TMPDIR/gates.sh"
  extract_step 2 >"$BATS_TEST_TMPDIR/prep.sh"
  extract_step 3 >"$BATS_TEST_TMPDIR/post.sh"
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/runner"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/bin/sh
printf '%s\n' "$*" >>"$GH_LOG"
case $* in
  *check-runs*) printf '%s\n' "${GH_CONCLUSION-}" ;;
  *"--jq .[] | select"*".body"*) [ ! -f "${GH_PREVIOUS_BODY-}" ] || cat "$GH_PREVIOUS_BODY" ;;
esac
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : >"$GH_LOG"
}

extract_step() {
  awk -v n="$1" 'on && (/^          / || !NF) { print substr($0, 11); next } on { on = 0 } /^        run: \|$/ { if (++seen == n) on = 1 }' "$WORKFLOW"
}

prep_step() {
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" GH_LOG=$GH_LOG GH_PREVIOUS_BODY=${GH_PREVIOUS_BODY-} GITHUB_REPOSITORY=acme/app PR=7 \
    BASE_REF=main HEAD_REF=PAY-1-work TITLE="PAY-1: save favorites" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output" \
    RUNNER_TEMP="$BATS_TEST_TMPDIR/runner" sh -e "$BATS_TEST_TMPDIR/prep.sh"
}

gates_step() {
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" GH_LOG=$GH_LOG GH_CONCLUSION=${1-} GITHUB_REPOSITORY=acme/app HEAD_SHA=abc123 \
    KAI_REVIEW_WAIT_TRIES=2 KAI_REVIEW_WAIT_SECONDS=0 GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output" sh -e "$BATS_TEST_TMPDIR/gates.sh"
}

previous() { printf '<!-- kai-review -->\n## Kai review\n\n1 Important, 0 Nit, 0 Pre-existing\n\n%s\n' "$1" >"$BATS_TEST_TMPDIR/previous.md"; GH_PREVIOUS_BODY="$BATS_TEST_TMPDIR/previous.md"; }

@test "the first review is review 1 and gets no earlier review" {
  run prep_step
  [ "$status" -eq 0 ]
  [ "$(jq -r .review_round .git/kai-pull-request.json)" = 1 ]
  [ "$(jq -r .previous_review_commit .git/kai-pull-request.json)" = "" ]
  [ ! -e .git/kai-previous-review.md ]
  grep -qx 'round=1' "$BATS_TEST_TMPDIR/output"
}

@test "a later review gets the earlier review, its commit, and the next number" {
  previous '<sub>Reviewed commit 0a1b2c3d · review 2 · [View run](https://example.com/run/1)</sub>'
  run prep_step
  [ "$status" -eq 0 ]
  [ "$(jq -r .review_round .git/kai-pull-request.json)" = 3 ]
  [ "$(jq -r .previous_review_commit .git/kai-pull-request.json)" = 0a1b2c3d ]
  grep -q '1 Important, 0 Nit, 0 Pre-existing' .git/kai-previous-review.md
  grep -qx 'round=3' "$BATS_TEST_TMPDIR/output"
}

@test "a review from an older workflow, without a number, counts as review 1" {
  previous '<sub>Reviewed commit 0a1b2c3d · [View run](https://example.com/run/1)</sub>'
  prep_step
  [ "$(jq -r .review_round .git/kai-pull-request.json)" = 2 ]
}

@test "the posted review names the commit it reviewed and its number" {
  printf '[{"type":"result","result":"Nothing to fix.\\n\\nVERDICT: PASS"}]\n' >"$BATS_TEST_TMPDIR/execution.json"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" GH_LOG=$GH_LOG GITHUB_REPOSITORY=acme/app PR=7 HEAD_SHA=abc123 ROUND=3 \
    EXECUTION_FILE="$BATS_TEST_TMPDIR/execution.json" RUN_URL=https://example.com/run/2 RUNNER_TEMP="$BATS_TEST_TMPDIR/runner" \
    sh -e "$BATS_TEST_TMPDIR/post.sh"
  grep -qF '<sub>Reviewed commit abc123 · review 3 · [View run](https://example.com/run/2)</sub>' "$BATS_TEST_TMPDIR/runner/kai-review.md"
  grep -q '^pr comment 7 --body-file ' "$GH_LOG"
}

@test "the review is skipped when the kai check failed on the commit" {
  run gates_step failure
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kai review skipped: the kai check failed"* ]]
  grep -qx 'skip=true' "$BATS_TEST_TMPDIR/output"
  grep -q 'commits/abc123/check-runs?check_name=kai' "$GH_LOG"
}

@test "the review runs when the kai check passed, and when it never reports" {
  run gates_step success
  [ "$status" -eq 0 ]
  [ ! -s "$BATS_TEST_TMPDIR/output" ]
  [ "$(grep -c check-runs "$GH_LOG")" -eq 1 ]
  : >"$GH_LOG"
  run gates_step ""
  [ "$status" -eq 0 ]
  [ ! -s "$BATS_TEST_TMPDIR/output" ]
  [ "$(grep -c check-runs "$GH_LOG")" -eq 2 ]
}

@test "the review steps run only when the gates step did not skip" {
  [ "$(grep -c "steps.gates.outputs.skip != 'true'" "$WORKFLOW")" -eq 2 ]
}
