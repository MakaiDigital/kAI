load helpers

setup() {
  make_repo
  write_config
  echo KAI_LEVEL=3 >>.kai/config
  git switch -qc PAY-1-work
  mkdir -p test && echo 'test("a")' >test/a.test.js
  git add test && git commit -qm "PAY-1: failing tests"
}

edit_hook() {
  jq -cn --arg f "$1" --arg cwd "$PWD" '{session_id: "s1", cwd: $cwd, tool_name: "Edit", tool_input: {file_path: $f}}' |
    "$KAI" hook protect-tests
}

@test "blocks editing a locked test by absolute or relative path" {
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"test/a.test.js was locked"* ]]
  run edit_hook "test/a.test.js"
  [ "$status" -eq 2 ]
}

@test "allows other files and new tests" {
  run edit_hook "$PWD/src/app.js"
  [ "$status" -eq 0 ]
  run edit_hook "$PWD/test/b.test.js"
  [ "$status" -eq 0 ]
}

@test "does nothing below level 3 or before tests are locked" {
  sed -i.bak '/KAI_LEVEL=3/d' .kai/config && rm .kai/config.bak
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 0 ]
  echo KAI_LEVEL=3 >>.kai/config
  git switch -qc PAY-2-work main
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 0 ]
}
