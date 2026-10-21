bats_require_minimum_version 1.5.0
load helpers

setup() { make_repo; write_config; }

artifacts() {
  mkdir -p docs/specs/PAY-9
  for f in "$@"; do echo x >"docs/specs/PAY-9/$f.md"; done
}

ticket() { printf 'kai: ticket PAY-9. Artifacts are in docs/specs/PAY-9/. Next: %s' "$1"; }

message() { jq -r .systemMessage <<<"$output"; }

@test "suggests building when the ticket has no artifacts at level 1" {
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
  jq -e 'keys == ["systemMessage"]' <<<"$output"
}

@test "suggests a spec first at level 2" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:spec PAY-9 (a change that touches only low-tier files can skip it; medium and high tier changes need a merged spec and plan before code).")" ]
}

@test "a spec without a plan at level 2, such as one product wrote, goes back to /kai:spec for its plan" {
  echo KAI_LEVEL=2 >>.kai/config
  artifacts spec
  git add docs/specs && git commit -qm "PAY-9: spec from product"
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:spec PAY-9 (a change that touches only low-tier files can skip it; medium and high tier changes need a merged spec and plan before code).")" ]
}

@test "a follow-up change at level 2 plans in the session, since the earlier change's plan is merged" {
  echo KAI_LEVEL=2 >>.kai/config
  artifacts spec plan evidence
  git add docs/specs && git commit -qm "PAY-9: merged earlier"
  git switch -qc PAY-9-offline
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
}

@test "continues with the tests and the proof once the plan exists" {
  git switch -qc PAY-9-thing
  artifacts plan
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "suggests reviewing and opening the PR once evidence exists, at any level" {
  git switch -qc PAY-9-thing
  artifacts plan evidence
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement to review the change, open the PR, and answer its reviews.")" ]
}

@test "a definition branch finishes the spec and plan, whatever the case of its name" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc pay-9-definition
  run run_hook session-start
  [ "$(message)" = "$(ticket "finish the spec and plan in docs/specs/PAY-9/ and open the Definition PR (/kai:spec PAY-9).")" ]
}

@test "a cleanup branch finishes the cleanup PR" {
  git switch -qc PAY-9-cleanup
  artifacts spec plan evidence
  run run_hook session-start
  [ "$(message)" = "$(ticket "finish the cleanup PR (/kai:accept PAY-9).")" ]
}

@test "a fix branch plans the fix, although the ticket's artifacts exist" {
  git switch -qc PAY-9-fix-1
  artifacts spec plan evidence
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement the fix, starting with its plan.")" ]
}

@test "any branch that contains <KEY>-fix- is a fix branch" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-fix-login
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement the fix, starting with its plan.")" ]
}

@test "a plan and evidence inherited from the base branch belong to the earlier change" {
  artifacts spec plan evidence
  git add docs/specs && git commit -qm "PAY-9: merged earlier"
  git switch -qc PAY-9-offline
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
  echo y >docs/specs/PAY-9/plan.md && git commit -qam "PAY-9: plan"
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "a plan the Definition PR merged is this change's plan, so the build starts with the tests" {
  echo KAI_LEVEL=2 >>.kai/config
  artifacts spec plan
  git add docs/specs && git commit -qm "PAY-9: definition"
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "a plan a later Definition PR changed after the evidence is the new change's plan" {
  artifacts spec plan evidence
  git add docs/specs && git commit -qm "PAY-9: merged earlier"
  echo redone >docs/specs/PAY-9/plan.md && git commit -qam "PAY-9: plan"
  git switch -qc PAY-9-respec
  run run_hook session-start
  [ "$(message)" = "$(ticket "/kai:implement continues with the failing tests, the code, and /kai:prove.")" ]
}

@test "stays silent on a branch without a ticket key" {
  run run_hook session-start
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  git switch -q --detach
  run run_hook session-start
  [ -z "$output" ]
}

@test "says first that the guards are off when jq is missing" {
  git switch -qc PAY-9-thing
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  for c in cat cp dirname find git grep head mkdir mktemp rm sed sh tr; do ln -s "$(command -v "$c")" "$bin/$c"; done
  run --separate-stderr env PATH="$bin" "$KAI" hook session-start </dev/null
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(message)" = "kai: jq is not installed, so Kai's Bash and Edit guards are off. Install jq to turn them on.
$(ticket "/kai:implement (plan first, then tests, code, review, and the PR).")" ]
}

@test "without jq, a branch without a ticket still gets the jq warning" {
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  for c in cat cp dirname find git grep head mkdir mktemp rm sed sh tr; do ln -s "$(command -v "$c")" "$bin/$c"; done
  run --separate-stderr env PATH="$bin" "$KAI" hook session-start </dev/null
  [ "$status" -eq 0 ]
  [ "$(message)" = "kai: jq is not installed, so Kai's Bash and Edit guards are off. Install jq to turn them on." ]
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
