load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  commit_config
  git switch -qc PAY-1-work
  echo impl >app.js
  mkdir -p specs/PAY-1
}

evidence() {
  printf '# Evidence\n\nResult: **PASS**\n\n## Planned tests\n\n| Criterion | Test | Result | Output line |\n|---|---|---|---|\n%s\n' "$1" >specs/PAY-1/evidence.md
}

spec() {
  printf '# Spec\n\n## Criteria\n\n- **C1** When a shopper taps, the system shall save.\n- **C2** If signed out, then the system shall refuse.\n\n## Contract\n\n| Criterion | Test | Status | Evidence |\n|---|---|---|---|\n%s\n' "$1" >specs/PAY-1/spec.md
}

gate() { "$KAI" gate contract --base main "$@"; }

@test "fails without evidence" {
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"evidence.md is missing"* ]]
}

@test "fails when a planned test is MISSING" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |
| C2 | `refuses` | MISSING | not found |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"refuses"* ]]
}

@test "passes with passing evidence and no spec" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"proven"* ]]
}

@test "every criterion needs a PASS row with evidence" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  spec '| C1 | `saves` | PASS | evidence.md |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C2 has no contract row"* ]]
  spec '| C1 | `saves` | PASS | evidence.md |
| C2 | `refuses` | FAIL | |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"not PASS with evidence"* ]]
  spec '| C1 | `saves` | PASS | evidence.md |
| C2 | `refuses` | PASS | evidence.md |'
  run gate
  [ "$status" -eq 0 ]
}
