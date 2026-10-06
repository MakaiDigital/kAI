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
  jq -cn --arg f "$1" --arg cwd "$PWD" --arg tool "${2:-Edit}" --arg field "${3:-file_path}" \
    '{session_id: "s1", cwd: $cwd, tool_name: $tool, tool_input: {($field): $f}}' |
    "$KAI" hook protect-tests
}

@test "blocks editing a locked test by absolute or relative path" {
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"test/a.test.js was locked"* ]] || false
  run edit_hook "test/a.test.js"
  [ "$status" -eq 2 ]
}

@test "blocks a locked test whose name git would quote" {
  echo 'test("c")' >'test/c".test.js' && git add test && git commit -qm "PAY-1: failing tests"
  run edit_hook "$PWD/test/c\".test.js"
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

@test "an empty re-lock keeps the lock" {
  git commit -q --allow-empty -m "PAY-1: failing tests"
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 2 ]
}

@test "files under specs/ in a lock commit stay editable" {
  mkdir -p specs/PAY-1 && echo plan >specs/PAY-1/plan.md
  echo 'test("b")' >test/b.test.js
  git add specs test && git commit -qm "PAY-1: failing tests"
  run edit_hook "$PWD/specs/PAY-1/plan.md"
  [ "$status" -eq 0 ]
  run edit_hook "$PWD/test/b.test.js"
  [ "$status" -eq 2 ]
}

@test "a test file the lock commit moved is locked at its new path" {
  printf 'test("%s")\n' one two three four >test/cart.test.js && git add test && git commit -qm "cart test"
  git mv test/cart.test.js test/favorites.test.js && echo 'test("saves")' >>test/favorites.test.js
  git commit -qam "PAY-1: failing tests"
  run edit_hook "$PWD/test/favorites.test.js"
  [ "$status" -eq 2 ]
}

@test "blocks a NotebookEdit of a locked notebook" {
  echo '{"cells": []}' >test/eval.ipynb && git add test && git commit -qm "PAY-1: failing tests"
  run edit_hook "$PWD/test/eval.ipynb" NotebookEdit notebook_path
  [ "$status" -eq 2 ]
}

@test "blocks a locked test in a sibling worktree from the main checkout" {
  git switch -q main
  git worktree add -q "$BATS_TEST_TMPDIR/wt" PAY-1-work
  cp -R .kai "$BATS_TEST_TMPDIR/wt/"
  run edit_hook "$BATS_TEST_TMPDIR/wt/test/a.test.js"
  [ "$status" -eq 2 ]
}

@test "compares paths case-insensitively when git ignores case" {
  git config core.ignorecase true
  run edit_hook "TEST/A.test.js"
  [ "$status" -eq 2 ]
}

@test "a file in another repository is judged by that repository's config alone" {
  other="$BATS_TEST_TMPDIR/other"
  mkdir -p "$other/.kai" "$other/test" && cd "$other"
  git init -q -b PAY-9-x && git config user.email t@e.com && git config user.name t && git config commit.gpgsign false
  echo 'KAI_TICKET_PREFIXES="PAY"' >.kai/config
  echo 'test("z")' >test/z.test.js && git add -A && git commit -qm "PAY-9: failing tests"
  cd "$TEST_REPO"
  run edit_hook "$other/test/z.test.js"
  [ "$status" -eq 0 ]
}

@test "an invalid .kai/config does not block the edit that fixes it" {
  echo 'KAI_LEVEL=5' >>.kai/config
  run edit_hook "$PWD/.kai/config"
  [ "$status" -ne 2 ]
}

@test "blocks a locked test while a rebase of the branch is stopped on a conflict" {
  echo branch >app.js && git add app.js && git commit -qm "PAY-1: implement"
  git switch -q main && echo main >app.js && git add app.js && git commit -qm "OPS-1: app"
  git switch -q PAY-1-work
  run git rebase main
  [ "$status" -ne 0 ]
  run edit_hook "$PWD/test/a.test.js"
  [ "$status" -eq 2 ]
}
