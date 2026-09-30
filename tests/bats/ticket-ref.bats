load helpers

setup() { make_repo; }

@test "passes when the branch has a key" {
  write_config jira "PAY"
  run "$KAI" gate ticket-ref --branch PAY-12-thing --title "whatever"
  [ "$status" -eq 0 ]
  [ "$output" = "ticket-ref: PAY-12" ]
}

@test "passes when only the PR title has a key" {
  write_config jira "PAY"
  run "$KAI" gate ticket-ref --branch fix-thing --title "PAY-12: fix thing"
  [ "$status" -eq 0 ]
}

@test "fails with guidance when neither has a key" {
  write_config jira "PAY"
  run "$KAI" gate ticket-ref --branch fix-thing --title "fix thing"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected: PAY-123"* ]]
}

@test "a Jira-shaped key with another team's prefix does not satisfy a Linear repo" {
  write_config linear "ENG"
  run "$KAI" gate ticket-ref --branch PAY-12-thing --title "PAY-12"
  [ "$status" -eq 1 ]
}

@test "the Kai setup branch is exempt" {
  write_config jira "PAY"
  run "$KAI" gate ticket-ref --branch kai-setup --title "Set up Kai (level 1)"
  [ "$status" -eq 0 ]
}

@test "bot branches are exempt" {
  write_config jira "PAY"
  run "$KAI" gate ticket-ref --branch dependabot/npm_and_yarn/lodash-4.17.21 --title "Bump lodash"
  [ "$status" -eq 0 ]
}
