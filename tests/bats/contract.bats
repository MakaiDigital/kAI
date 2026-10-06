load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  commit_config
  git switch -qc PAY-1-work
  echo impl >app.js && git add app.js && git commit -qm "PAY-1: implement"
  mkdir -p specs/PAY-1
}

CRITERIA='- **C1** When a shopper taps, the system shall save.
- **C2** If signed out, then the system shall refuse.'

evidence() {
  printf '# Evidence\n\nkai verify on commit %s at 2026-10-05T00:00:00Z.\n\n%s\n\n## Planned tests\n\n| Criterion | Test | Result | Output line |\n|---|---|---|---|\n%s\n' \
    "$(git rev-parse HEAD)" "${2:-Result: **PASS**}" "$1" >specs/PAY-1/evidence.md
}

spec() {
  printf '# Spec\n\n## Criteria\n\n%s\n\n## Contract\n\n| Criterion | Test | Status | Evidence |\n|---|---|---|---|\n%s\n' "${2:-$CRITERIA}" "$1" >specs/PAY-1/spec.md
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

@test "fails when the recorded kai verify run failed" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |' 'Result: **FAIL** (1 failed)'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not record a passing kai verify run"* ]]
}

@test "a failed kai verify run with a PASS line added still fails" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |' 'Result: **FAIL** (1 failed)

Result: **PASS**'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not record a passing kai verify run"* ]]
}

@test "a PASS row without its output line fails" {
  evidence '| C1 | `saves` | PASS | |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"planned tests not passing"* ]]
}

@test "a test the plan lists but the evidence leaves out fails" {
  printf '# Plan\n\n## Tests\n\n| Criterion | Test | File |\n|---|---|---|\n| C1 | `saves` | `test/a.test.js` |\n| C2 | `refuses` | `test/a.test.js` |\n\n## Risks\n\n| a | b |\n' >specs/PAY-1/plan.md
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing from specs/PAY-1/evidence.md:"*"refuses"* ]] || false
  evidence '| C1 | `saves` | PASS | `✔ saves` |
| C2 | `refuses` | PASS | `✔ refuses` |'
  run gate
  [ "$status" -eq 0 ]
}

@test "the plan's tests match whatever its table header says, with or without backticks" {
  printf '# Plan\n\n## Tests\n\n| Ticket outcome | Test name | File |\n|---|---|---|\n| saves | `saves` | `test/a.test.js` |\n' >specs/PAY-1/plan.md
  evidence '| Outcome: saves | saves | PASS | `✔ saves` |'
  run gate
  [ "$status" -eq 0 ]
}

@test "evidence that names a commit already on the base branch fails" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  git add specs && git commit -qm "PAY-1: evidence"
  git switch -q main && git merge -q --no-ff --no-edit PAY-1-work
  git switch -qc PAY-1-follow-up
  echo more >>app.js && git commit -qam "PAY-1: follow-up"
  sed -i.bak 's/^\(kai verify on commit .*\) at /\1 at  /' specs/PAY-1/evidence.md && rm specs/PAY-1/evidence.md.bak
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"evidence.md was not updated on this branch"* ]]
}

@test "a passing test whose name mentions FAILED passes" {
  evidence '| C1 | `rejects FAILED payments` | PASS | `✔ rejects FAILED payments` |'
  run gate
  [ "$status" -eq 0 ]
}

@test "a planned test passes only with exactly PASS" {
  evidence '| C1 | `saves` | Pass | `✔ saves` |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"planned tests not passing"* ]]
}

@test "fails without a planned tests table" {
  printf '# Evidence\n\nResult: **PASS**\n' >specs/PAY-1/evidence.md
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no planned tests table"* ]]
}

@test "fails when the evidence is the base branch's" {
  git switch -q main
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  git add specs && git commit -qm "PAY-1: evidence"
  git switch -q PAY-1-work && git merge -q --no-edit main
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"evidence.md was not updated on this branch"* ]]
}

@test "passes with passing evidence and no spec" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"proven"* ]]
}

@test "passes with the evidence kai verify writes on this branch" {
  "$KAI" verify --evidence specs/PAY-1/evidence.md
  printf '\n## Planned tests\n\n| Criterion | Test | Result | Output line |\n|---|---|---|---|\n| C1 | `saves` | PASS | `✔ saves` |\n' >>specs/PAY-1/evidence.md
  run gate
  [ "$status" -eq 0 ]
}

@test "every criterion needs a PASS row with evidence" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  spec '| C1 | `saves` | PASS | evidence.md |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C2 has no contract row"* ]] || false
  spec '| C1 | `saves` | PASS | evidence.md |
| C2 | `refuses` | FAIL | |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"not PASS with evidence"* ]] || false
  spec '| C1 | `saves` | PASS | evidence.md |
| C2 | `refuses` | PASS | evidence.md |'
  run gate
  [ "$status" -eq 0 ]
}

@test "criteria come from the base branch's spec, so deleting one on the branch fails" {
  git switch -q main
  spec '| C1 | `saves` | PASS | evidence.md |
| C2 | `refuses` | PASS | evidence.md |'
  git add specs && git commit -qm "PAY-1: definition"
  git switch -q PAY-1-work && git merge -q --no-edit main
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  spec '| C1 | `saves` | PASS | evidence.md |' '- **C1** When a shopper taps, the system shall save.'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C2 has no contract row"* ]] || false
  rm specs/PAY-1/spec.md
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C1 has no contract row"* ]]
}

@test "a criterion added on the branch needs a contract row too" {
  git switch -q main
  spec '| C1 | `saves` | PASS | evidence.md |' '- **C1** When a shopper taps, the system shall save.'
  git add specs && git commit -qm "PAY-1: definition"
  git switch -q PAY-1-work && git merge -q --no-edit main
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  spec '| C1 | `saves` | PASS | evidence.md |'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C2 has no contract row"* ]]
}

@test "criterion ids written as **C1:** or **C1.** are detected" {
  evidence '| C1 | `saves` | PASS | `✔ saves` |'
  spec '' '- **C1:** When a shopper taps, the system shall save.
- **C2.** If signed out, then the system shall refuse.'
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"C1 has no contract row"* ]] || false
  [[ "$output" == *"C2 has no contract row"* ]]
}
