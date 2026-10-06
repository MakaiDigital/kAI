bats_require_minimum_version 1.5.0
load helpers

setup() { make_repo; write_config; }

artifacts() {
  mkdir -p specs/PAY-9
  for f in "$@"; do echo x >"specs/PAY-9/$f.md"; done
}

ticket() { printf 'kai: ticket PAY-9. Artifacts are in specs/PAY-9/. Next: %s' "$1"; }

@test "suggests building when the ticket has no artifacts at level 1" {
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$status" -eq 0 ]
  [ "$output" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
}

@test "suggests a spec first at level 2" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:spec PAY-9 (a change that touches only low-tier files can skip it; medium and high tier changes need a merged spec before code).")" ]
}

@test "suggests building once the spec exists at level 2" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-thing
  artifacts spec
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
}

@test "continues with the tests and the proof once the plan exists" {
  git switch -qc PAY-9-thing
  artifacts plan
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "suggests reviewing and opening the PR once evidence exists, at any level" {
  git switch -qc PAY-9-thing
  artifacts plan evidence
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement to review the change, open the PR, and answer its reviews.")" ]
}

@test "a definition branch finishes the spec, whatever the case of its name" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc pay-9-definition
  run run_hook session-start
  [ "$output" = "$(ticket "finish specs/PAY-9/spec.md and open the Definition PR (/kai:spec PAY-9).")" ]
}

@test "a cleanup branch finishes the cleanup PR" {
  git switch -qc PAY-9-cleanup
  artifacts spec plan evidence
  run run_hook session-start
  [ "$output" = "$(ticket "finish the cleanup PR (/kai:accept PAY-9).")" ]
}

@test "a fix branch plans the fix, although the ticket's artifacts exist" {
  git switch -qc PAY-9-fix-1
  artifacts spec plan evidence
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement the fix, starting with its plan.")" ]
}

@test "any branch that contains <KEY>-fix- is a fix branch" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-fix-login
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement the fix, starting with its plan.")" ]
}

@test "a plan and evidence inherited from the base branch belong to the earlier change" {
  artifacts spec plan evidence
  git add specs && git commit -qm "PAY-9: merged earlier"
  git switch -qc PAY-9-offline
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
  echo y >specs/PAY-9/plan.md && git commit -qam "PAY-9: plan"
  run run_hook session-start
  [ "$output" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "prompts for a ticket on a branch without one" {
  run run_hook session-start
  [ "$output" = "kai: no ticket key on branch main; start a ticket with /kai:spec <KEY>, or accept a deployed one with /kai:accept <KEY>." ]
  git switch -q --detach
  run run_hook session-start
  [ "$output" = "kai: no ticket key on branch <detached>; start a ticket with /kai:spec <KEY>, or accept a deployed one with /kai:accept <KEY>." ]
}

@test "says first that the guards are off when jq is missing" {
  git switch -qc PAY-9-thing
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  for c in cat cp dirname find git grep head mkdir mktemp rm sed sh tr; do ln -s "$(command -v "$c")" "$bin/$c"; done
  run --separate-stderr env PATH="$bin" "$KAI" hook session-start </dev/null
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "kai: jq is not installed, so Kai's Bash and Edit guards are off. Ask the person to install jq." ]
  [ "${lines[1]}" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
}

@test "a later SessionStart in the same session (resume, compact) keeps the baseline" {
  run_hook session-start >/dev/null
  start="$(git rev-parse --absolute-git-dir)/kai/session-s1.start"
  before=$(cat "$start")
  echo change >>README.md
  run_hook session-start >/dev/null
  [ "$(cat "$start")" = "$before" ]
}

@test "stays silent in repositories without kai" {
  rm .kai/config
  run run_hook session-start
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
