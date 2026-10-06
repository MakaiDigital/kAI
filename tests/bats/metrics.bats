load helpers

DAY=86400

setup() {
  make_repo
  write_config
  commit_config
  NOW=$(date +%s)
  export KAI_NOW=$NOW
}

at() {
  mkdir -p "specs/$1"
  echo x >>"specs/$1/$2"
  git add -A
  GIT_COMMITTER_DATE="@$3" GIT_AUTHOR_DATE="@$3" git commit -qm "$1 $2"
}

merge() {
  git switch -q main
  GIT_COMMITTER_DATE="@$2" GIT_AUTHOR_DATE="@$2" git merge -q --no-ff -m "Merge $1" "$1"
}

@test "reports shipped tickets, lead time, and rework side by side" {
  at PAY-1 spec.md $((NOW - 20 * DAY))
  at PAY-1 plan.md $((NOW - 19 * DAY))
  at PAY-1 evidence.md $((NOW - 18 * DAY))
  at PAY-2 spec.md $((NOW - 10 * DAY))
  at PAY-2 plan.md $((NOW - 9 * DAY))
  at PAY-2 spec.md $((NOW - 8 * DAY))
  at PAY-2 evidence.md $((NOW - 6 * DAY))
  at PAY-3 spec.md $((NOW - 3 * DAY))
  at PAY-3 evidence.md $((NOW - 2 * DAY))
  at PAY-3 evidence.md $((NOW - 1 * DAY))
  run "$KAI" metrics --weeks 4 --base main
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 1 | 2.0 | 0 of 1 |"* ]]
  [[ "$output" == *"| 2 | 2.5 | 2 of 2 |"* ]]
  [[ "$output" == *"**3 tickets shipped**, median lead time **2.0 days**, **66% reworked**"* ]]
}

@test "ignores tickets without evidence and those outside the window" {
  at PAY-1 spec.md $((NOW - 2 * DAY))
  at PAY-2 spec.md $((NOW - 70 * DAY))
  at PAY-2 evidence.md $((NOW - 60 * DAY))
  run "$KAI" metrics --weeks 4 --base main
  [[ "$output" == *"No tickets shipped in this period."* ]]
}

@test "flags a week whose lead time is far above the rest" {
  for w in 1 2 3 4 5 6; do
    at "PAY-$w" spec.md $((NOW - (w * 7 + 2) * DAY))
    at "PAY-$w" evidence.md $((NOW - (w * 7 + 1) * DAY))
  done
  at PAY-9 spec.md $((NOW - 40 * DAY))
  at PAY-9 evidence.md $((NOW - 1 * DAY))
  run "$KAI" metrics --weeks 8 --base main
  [[ "$output" == *"39.0 ▲"* ]]
}

@test "tickets whose specs were deleted at acceptance still count, without counting as reworked" {
  at PAY-1 spec.md $((NOW - 6 * DAY))
  at PAY-1 plan.md $((NOW - 5 * DAY))
  at PAY-1 evidence.md $((NOW - 4 * DAY))
  git rm -rq specs/PAY-1
  GIT_COMMITTER_DATE="@$((NOW - 1 * DAY))" GIT_AUTHOR_DATE="@$((NOW - 1 * DAY))" git commit -qm "PAY-1: cleanup"
  run "$KAI" metrics --weeks 4 --base main
  [ "$status" -eq 0 ]
  [[ "$output" == *"**1 tickets shipped**"* ]]
  [[ "$output" == *"**0% reworked**"* ]]
}

@test "times are when files land on the base branch, so merged PRs whose evidence commit updates the spec are not rework" {
  git switch -qc PAY-1-definition
  at PAY-1 spec.md $((NOW - 12 * DAY))
  merge PAY-1-definition $((NOW - 11 * DAY))
  git switch -qc PAY-1-favorites
  at PAY-1 plan.md $((NOW - 9 * DAY))
  echo contract >>specs/PAY-1/spec.md
  at PAY-1 evidence.md $((NOW - 7 * DAY))
  merge PAY-1-favorites $((NOW - 4 * DAY))
  run "$KAI" metrics --weeks 4 --base main
  [ "$status" -eq 0 ]
  [[ "$output" == *"**1 tickets shipped**, median lead time **7.0 days**, **0% reworked**"* ]]
}

@test "rejects a --weeks that is not a whole number, and an unknown ref" {
  run "$KAI" metrics --weeks abc
  [ "$status" -eq 1 ]
  [[ "$output" == *"--weeks needs a whole number, for example --weeks 4"* ]]
  run "$KAI" metrics --base nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown ref 'nope'"* ]]
}
