load helpers

setup() { make_repo; write_config; }

@test "suggests capturing intent when the ticket has no artifacts" {
  git switch -qc PAY-9-thing
  run run_hook session-start
  [ "$status" -eq 0 ]
  [[ "$output" == *"ticket PAY-9"* ]]
  [[ "$output" == *"Next: /kai:intent PAY-9"* ]]
}

@test "suggests building once intent exists" {
  git switch -qc PAY-9-thing
  mkdir -p specs/PAY-9 && echo i >specs/PAY-9/intent.md
  run run_hook session-start
  [[ "$output" == *"Next: /kai:build"* ]]
}

@test "suggests a spec first at level 2" {
  echo KAI_LEVEL=2 >>.kai/config
  git switch -qc PAY-9-thing
  mkdir -p specs/PAY-9 && echo i >specs/PAY-9/intent.md
  run run_hook session-start
  [[ "$output" == *"Next: /kai:spec"* ]]
}

@test "suggests shipping at level 3 once evidence exists" {
  echo KAI_LEVEL=3 >>.kai/config
  git switch -qc PAY-9-thing
  mkdir -p specs/PAY-9
  for f in intent spec plan evidence; do echo x >specs/PAY-9/$f.md; done
  run run_hook session-start
  [[ "$output" == *"Next: /kai:ship"* ]]
}

@test "prompts for a ticket on a branch without one" {
  run run_hook session-start
  [[ "$output" == *"no ticket key on branch main"* ]]
}

@test "stays silent in repositories without kai" {
  rm .kai/config
  run run_hook session-start
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
