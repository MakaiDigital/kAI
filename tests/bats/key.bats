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

@test "commands fail clearly when .kai/config is not valid sh" {
  write_config
  echo 'if true; then' >>.kai/config
  run "$KAI" key PAY-1
  [ "$status" -eq 1 ]
  [[ "$output" == *".kai/config is not valid sh; fix it, then retry"* ]]
}

@test "KAI_LEVEL must be 1, 2, 3 or 4" {
  write_config
  echo 'KAI_LEVEL=5' >>.kai/config
  run "$KAI" key PAY-1
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAI_LEVEL in .kai/config must be 1, 2, 3 or 4, not '5'"* ]]
}

@test "prefixes may be padded or separated by commas" {
  write_config jira " PAY,  OPS "
  run "$KAI" key "ops-7-tidy"
  [ "$status" -eq 0 ]
  [ "$output" = "OPS-7" ]
  run "$KAI" key "PAY-12"
  [ "$output" = "PAY-12" ]
}

@test "lowercase words are not keys when no prefixes are configured" {
  write_config jira ""
  run "$KAI" key "update-2024-deps"
  [ "$status" -ne 0 ]
}

@test "dates in github branches are not keys" {
  write_config github ""
  run "$KAI" key "retro/2026-10-04"
  [ "$status" -ne 0 ]
  run "$KAI" key "release/2026-10"
  [ "$status" -ne 0 ]
  run "$KAI" key "hotfix/2026-10-05-login"
  [ "$status" -ne 0 ]
}

@test "github keys come from cleanup branches, bare numbers and N: titles" {
  write_config github ""
  run "$KAI" key "178-cleanup"
  [ "$output" = "178" ]
  run "$KAI" key "42"
  [ "$output" = "42" ]
  run "$KAI" key "42: definition"
  [ "$output" = "42" ]
}
