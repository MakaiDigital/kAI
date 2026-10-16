load helpers

setup() {
  DIR="$BATS_TEST_TMPDIR/results"
  mkdir -p "$DIR"
}

record() {
  printf '%s\n' "$1" >>"$DIR/gates"
  printf '%s\n' "$2" >"$DIR/$1.status"
  printf '%s\n' "$3" >"$DIR/$1.out"
}

@test "report is a command and starts with the sticky comment's marker" {
  record ticket-ref 0 "ticket-ref: PAY-1"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url https://example.com/run/1
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "<!-- kai-gates -->" ]
  [ "${lines[1]}" = "## Kai gates" ]
}

@test "all gates passing gives VERDICT: PASS, one row per gate and the commit" {
  record ticket-ref 0 "ticket-ref: PAY-1"
  record definition 0 "definition: low tier, no spec required"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url https://example.com/run/1
  [[ "$output" == *"VERDICT: PASS"* ]]
  [[ "$output" != *"VERDICT: FAIL"* ]]
  [[ "$output" == *"| ticket-ref | ✅ pass | ticket-ref: PAY-1 |"* ]]
  [[ "$output" == *"| definition | ✅ pass | definition: low tier, no spec required |"* ]]
  [[ "$output" == *"Checked commit abc123"* ]]
  [[ "$output" == *"[View run](https://example.com/run/1)"* ]]
}

@test "a failing gate gives VERDICT: FAIL and its full output" {
  record ticket-ref 0 "ticket-ref: PAY-1"
  record contract 1 "contract: PAY-1 is not proven:
  specs/PAY-1/evidence.md is missing (run /kai:prove)"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [[ "$output" == *"VERDICT: FAIL"* ]]
  [[ "$output" == *"| contract | ❌ fail | contract: PAY-1 is not proven: |"* ]]
  [[ "$output" == *"### contract"* ]]
  [[ "$output" == *"specs/PAY-1/evidence.md is missing (run /kai:prove)"* ]]
}

@test "passing gates do not get a section of their own" {
  record ticket-ref 0 "ticket-ref: PAY-1"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [[ "$output" != *"### ticket-ref"* ]]
}

@test "a pipe in a gate's output does not break the table" {
  record verify 1 "FAIL  a | b"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [[ "$output" == *"| verify | ❌ fail | FAIL  a \| b |"* ]]
}

@test "report mode says the job stays green" {
  record contract 1 "contract: PAY-1 is not proven:"
  echo report >"$DIR/mode"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [[ "$output" == *"VERDICT: FAIL"* ]]
  [[ "$output" == *"KAI_ENFORCE=report"* ]]
}

@test "block mode does not mention report mode" {
  record contract 1 "contract: PAY-1 is not proven:"
  echo block >"$DIR/mode"
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [[ "$output" != *"KAI_ENFORCE"* ]]
}

@test "no results is an error" {
  run "$KAI" report --dir "$DIR" --sha abc123 --run-url u
  [ "$status" -eq 1 ]
  [[ "$output" == *"no gate results"* ]]
}

@test "KAI_ENFORCE accepts report and block and rejects anything else" {
  make_repo
  write_config
  for v in report block; do
    echo "KAI_ENFORCE=$v" >>.kai/config
    run "$KAI" gate ticket-ref --branch PAY-1-x
    [ "$status" -eq 0 ]
  done
  echo "KAI_ENFORCE=warn" >>.kai/config
  run "$KAI" gate ticket-ref --branch PAY-1-x
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAI_ENFORCE in .kai/config must be report or block, not 'warn'"* ]]
}
