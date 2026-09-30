load helpers

setup() { make_repo; }

@test "jira key from branch is normalized to upper case" {
  write_config jira "PAY OPS"
  run "$KAI" key "pay-123-save-favorites"
  [ "$status" -eq 0 ]
  [ "$output" = "PAY-123" ]
}

@test "jira key must use an allowed prefix" {
  write_config jira "PAY OPS"
  run "$KAI" key "ENG-9-thing"
  [ "$status" -ne 0 ]
}

@test "any KEY-123 is accepted when no prefixes are configured" {
  write_config jira ""
  run "$KAI" key "feature/ENG-9-thing"
  [ "$output" = "ENG-9" ]
}

@test "key reads the current branch by default" {
  write_config linear "ENG"
  git switch -qc ENG-42-login
  run "$KAI" key
  [ "$output" = "ENG-42" ]
}

@test "github keys come from issue branches, #N and GH-N" {
  write_config github ""
  run "$KAI" key "42-fix-login"
  [ "$output" = "42" ]
  run "$KAI" key "Fix login (#7)"
  [ "$output" = "7" ]
  run "$KAI" key "gh-13 tidy"
  [ "$output" = "13" ]
}

@test "commands fail clearly without .kai/config" {
  run "$KAI" key PAY-1
  [ "$status" -ne 0 ]
  [[ "$output" == *"no .kai/config"* ]]
}
