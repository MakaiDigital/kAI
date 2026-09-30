load helpers

setup() {
  make_repo
  git switch -qc PAY-1-work
}

start_session() {
  write_config jira PAY "$1"
  commit_config
  run_hook session-start >/dev/null
}

runs() { wc -l <"$(git rev-parse --absolute-git-dir)/runs" | tr -d ' '; }
COUNTING_VERIFY='echo run >>"$(git rev-parse --absolute-git-dir)/runs"'

@test "nothing changed since the session started: no verify" {
  start_session "exit 1"
  run run_hook stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a session that started before kai records a baseline and lets Claude stop" {
  write_config jira PAY "exit 1"
  run run_hook stop
  [ "$status" -eq 0 ]
  [ -f "$(git rev-parse --absolute-git-dir)/kai/session-s1.start" ]
}

@test "blocks finishing while verification fails, then gives up with a warning" {
  start_session 'echo "expected 2 got 3"; exit 1'
  echo change >>README.md
  run run_hook stop
  [ "$status" -eq 2 ]
  [[ "$output" == *"attempt 1 of 3"* ]]
  [[ "$output" == *"expected 2 got 3"* ]]
  run run_hook stop
  [ "$status" -eq 2 ]
  run run_hook stop
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"still failing after 3 attempts"* ]]
  run run_hook stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lets Claude finish when verification passes, and caches the result" {
  start_session "$COUNTING_VERIFY"
  echo change >>README.md
  run run_hook stop
  [ "$status" -eq 0 ]
  run run_hook stop
  [ "$(runs)" -eq 1 ]
}

@test "committing only spec artifacts does not trigger another run" {
  start_session "$COUNTING_VERIFY"
  echo change >>README.md
  run_hook stop
  mkdir -p specs/PAY-1 && echo e >specs/PAY-1/evidence.md
  git add -A && git commit -qm evidence
  run run_hook stop
  [ "$status" -eq 0 ]
  [ "$(runs)" -eq 1 ]
}
