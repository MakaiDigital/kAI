load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  commit_config
  git switch -qc PAY-1-work
  mkdir -p test && echo 'test("a")' >test/a.test.js
  git add -A && git commit -qm "PAY-1: failing tests"
  echo 'impl' >app.js && git add -A && git commit -qm "PAY-1: implement"
}

gate() { "$KAI" gate tests-locked --base main "$@"; }

@test "passes when locked tests are unchanged" {
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"unchanged"* ]]
}

@test "fails when a locked test changes after the failing-tests commit" {
  echo 'test("weakened")' >test/a.test.js && git commit -qam "tweak test"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
  [[ "$output" == *"kai:tests-changed"* ]]
}

@test "a reviewer label approves a test change" {
  echo 'test("fixed")' >test/a.test.js && git commit -qam "fix test"
  run gate --labels "bug kai:tests-changed"
  [ "$status" -eq 0 ]
  [[ "$output" == *"approved"* ]]
}

@test "medium tier without a failing-tests commit fails" {
  git switch -q main && git switch -qc PAY-2-work
  echo impl >other.js && git add -A && git commit -qm "PAY-2: implement"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *'"PAY-2: failing tests"'* ]]
}

@test "skipped below level 3 and for low tier" {
  sed -i.bak '/KAI_LEVEL=3/d' .kai/config && rm .kai/config.bak
  run gate
  [[ "$output" == *"skipped"* ]]
  echo KAI_LEVEL=3 >>.kai/config
  git switch -q main && printf '*.md low\n' >.kai/tiers && commit_config
  git switch -qc PAY-3-docs
  echo notes >NOTES.md && git add NOTES.md && git commit -qm docs
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"low tier"* ]]
}
