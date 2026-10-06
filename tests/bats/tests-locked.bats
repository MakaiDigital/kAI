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

merge_to_main() { git switch -q main && git merge -q --no-ff --no-edit PAY-1-work; }

@test "passes when locked tests are unchanged" {
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"tests locked for PAY-1 are unchanged"* ]]
}

@test "fails when a locked test changes after the failing-tests commit" {
  echo 'test("weakened")' >test/a.test.js && git commit -qam "tweak test"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]] || false
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
  [[ "$output" == *"skipped"* ]] || false
  echo KAI_LEVEL=3 >>.kai/config
  git switch -q main && printf '*.md low\n' >.kai/tiers && commit_config
  git switch -qc PAY-3-docs
  echo notes >NOTES.md && git add NOTES.md && git commit -qm docs
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"low tier"* ]]
}

@test "an empty re-lock after weakening a test still fails" {
  echo 'test("weakened")' >test/a.test.js && git commit -qam "tweak test"
  git commit -q --allow-empty -m "PAY-1: failing tests"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "a second lock commit cannot rewrite a test the first one locked" {
  echo 'test("weakened")' >test/a.test.js && git commit -qam "PAY-1: failing tests"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "a second lock that only adds a new file still protects the first lock's file" {
  echo 'test("b")' >test/b.test.js && git add test && git commit -qm "PAY-1: failing tests"
  echo 'test("weakened")' >test/a.test.js && git commit -qam "tweak test"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "files under specs/ in a lock commit are not locked" {
  mkdir -p specs/PAY-1 && echo plan >specs/PAY-1/plan.md
  echo 'test("b")' >test/b.test.js
  git add -A && git commit -qm "PAY-1: failing tests"
  echo 'plan, revised' >specs/PAY-1/plan.md && git commit -qam "PAY-1: plan"
  run gate
  [ "$status" -eq 0 ]
}

@test "main's later change to a shared locked test does not count against the PR" {
  git switch -q main
  mkdir -p test && printf 'one\ntwo\nthree\n' >test/shared.test.js && git add test && git commit -qm "shared test"
  git switch -qc PAY-2-work
  printf 'one\ntwo\nthree\npay-2\n' >test/shared.test.js && git commit -qam "PAY-2: failing tests"
  echo impl >pay2.js && git add pay2.js && git commit -qm "PAY-2: implement"
  git switch -q main
  printf 'zero\ntwo\nthree\n' >test/shared.test.js && git commit -qam "OPS-1: rename a case"
  git switch -q PAY-2-work && git merge -q --no-edit main
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"tests locked for PAY-2 are unchanged"* ]]
}

@test "a follow-up branch for a merged key needs its own failing-tests commit" {
  merge_to_main
  git switch -qc PAY-1-follow-up
  echo more >>app.js && git commit -qam "PAY-1: follow-up"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *'without a "PAY-1: failing tests" commit in this PR'* ]]
}

@test "a fix branch that weakens the original ticket's locked test fails" {
  merge_to_main
  git switch -qc PAY-1-fix-1
  echo 'test("repro")' >test/repro.test.js && git add test && git commit -qm "PAY-1: failing tests"
  echo 'test("weakened")' >test/a.test.js && git commit -qam "PAY-1: fix"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "deleting a locked test fails, also in CI's merge commit" {
  git rm -q test/a.test.js && git commit -qm "drop test"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]] || false
  git checkout -q --detach main && git merge -q --no-ff --no-edit PAY-1-work
  run gate --branch PAY-1-work
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "a merge that changes a locked test fails, also in CI's merge commit" {
  git switch -q main && echo other >other.js && git add other.js && git commit -qm "OPS-1: other"
  git switch -q PAY-1-work && git merge -q --no-ff --no-commit main
  echo 'test("weakened")' >test/a.test.js && git add test && git commit -qm "Merge main"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]] || false
  git checkout -q --detach main && git merge -q --no-ff --no-edit PAY-1-work
  run gate --branch PAY-1-work
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/a.test.js"* ]]
}

@test "resolving a conflict in a shared locked test by taking main's side fails" {
  git switch -q main
  mkdir -p test && printf 'one\ntwo\n' >test/shared.test.js && git add test && git commit -qm "shared test"
  git switch -qc PAY-2-work
  printf 'one\ntwo\npay-2\n' >test/shared.test.js && git commit -qam "PAY-2: failing tests"
  echo impl >pay2.js && git add pay2.js && git commit -qm "PAY-2: implement"
  git switch -q main && printf 'one\ntwo\nops-1\n' >test/shared.test.js && git commit -qam "OPS-1: change the test"
  git switch -q PAY-2-work
  git merge -q --no-edit main >/dev/null 2>&1 || true
  git checkout -q --theirs test/shared.test.js && git add test && git commit -qm "Merge main"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/shared.test.js"* ]]
}

@test "a lock commit that moves a test file locks it at its new path" {
  git switch -q main
  mkdir -p test && printf 'test("%s")\n' one two three four >test/cart.test.js && git add test && git commit -qm "cart test"
  git switch -qc PAY-2-work
  git mv test/cart.test.js test/favorites.test.js && echo 'test("saves")' >>test/favorites.test.js
  git commit -qam "PAY-2: failing tests"
  echo 'test("weakened")' >test/favorites.test.js && git commit -qam "PAY-2: tidy"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/favorites.test.js"* ]]
}

@test "an empty failing-tests commit does not count as this PR's lock" {
  merge_to_main
  git switch -qc PAY-1-follow-up
  git commit -q --allow-empty -m "PAY-1: failing tests"
  echo more >>app.js && git commit -qam "PAY-1: follow-up"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *'without a "PAY-1: failing tests" commit in this PR'* ]]
}

@test "locked files whose names end in a space or contain a quote are checked" {
  printf 'test("b")\n' >'test/b.test.js ' && printf 'test("c")\n' >'test/c".test.js'
  git add test && git commit -qm "PAY-1: failing tests"
  echo 'test("weakened")' >'test/b.test.js ' && echo 'test("weakened")' >'test/c".test.js'
  git commit -qam "tweak tests"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *'test/b.test.js '* ]] || false
  [[ "$output" == *'test/c".test.js'* ]]
}

@test "a Conventional Commits subject locks tests too" {
  git switch -q main && git switch -qc PAY-1-conventional
  mkdir -p test && echo 'test("d")' >test/d.test.js && git add test && git commit -qm "test(PAY-1): failing tests"
  echo impl >d.js && git add d.js && git commit -qm "feat(PAY-1): implement"
  run gate
  [ "$status" -eq 0 ]
  echo 'test("weakened")' >test/d.test.js && git commit -qam "test(PAY-1): tweak"
  run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"test/d.test.js"* ]]
}

@test "fails closed when git cannot show what a merge changed" {
  shim="$BATS_TEST_TMPDIR/oldgit"
  mkdir -p "$shim"
  real=$(command -v git)
  printf '#!/bin/sh\nfor a; do [ "$a" != --remerge-diff ] || { echo "fatal: unrecognized argument: --remerge-diff" >&2; exit 128; }; done\nexec %s "$@"\n' "$real" >"$shim/git"
  chmod +x "$shim/git"
  PATH="$shim:$PATH" run gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"git 2.36"* ]]
}
