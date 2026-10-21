load helpers

setup() {
  make_repo
  write_config
}

guard() { run_hook guard-bash "$1"; }

@test "allows ordinary commands" {
  run guard "npm test && git push -u origin PAY-1-work"
  [ "$status" -eq 0 ]
}

@test "blocks skipping git hooks" {
  run guard "git commit --no-verify -m wip"
  [ "$status" -eq 2 ]
  [[ "$output" == *"git hooks"* ]]
  run guard "git -c core.hooksPath=/dev/null commit -m x"
  [ "$status" -eq 2 ]
}

@test "blocks the short flag, abbreviations, any case of hooksPath, and hook managers' skip switches" {
  run guard "git commit -n -m x"
  [ "$status" -eq 2 ]
  run guard "git commit -anm x"
  [ "$status" -eq 2 ]
  run guard "npm test; git push --no-verif origin PAY-1-work"
  [ "$status" -eq 2 ]
  run guard "git -c core.HOOKSPATH=/dev/null commit -m x"
  [ "$status" -eq 2 ]
  run guard "HUSKY=0 git commit -m x"
  [ "$status" -eq 2 ]
  run guard "HUSKY_SKIP_HOOKS=1 git commit -m x"
  [ "$status" -eq 2 ]
  run guard "LEFTHOOK=0 git commit -m x"
  [ "$status" -eq 2 ]
  run guard "SKIP=eslint git commit -m x"
  [ "$status" -eq 2 ]
}

stage_tests() {
  mkdir -p test/helpers && echo t >test/cart.test.js && echo h >test/helpers/make_cart.js && git add test
}

@test "during the workflow, the ticket's failing-tests commit may skip git hooks that run the failing tests" {
  git switch -qc PAY-1-work
  mark_workflow
  stage_tests
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 0 ]
  run guard "git commit -n -m 'test(PAY-1): failing tests'"
  [ "$status" -eq 0 ]
  run guard "git commit -q -m \"PAY-1: failing tests\" --no-verify"
  [ "$status" -eq 0 ]
}

@test "test files in common layouts count as tests" {
  git switch -qc PAY-1-work
  mark_workflow
  mkdir -p pkg/cart/__tests__ spec tests/fixtures
  for f in pkg/cart/__tests__/cart.js pkg/cart/cart_test.go pkg/cart/test_cart.py pkg/cart/CartTest.java \
    pkg/cart/cart.spec.ts spec/cart_spec.rb tests/fixtures/cart.json; do
    echo t >"$f"
  done
  git add pkg spec tests
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 0 ]
}

@test "the failing-tests commit may not move code into a test folder or delete files while skipping git hooks" {
  mkdir -p src test && echo code >src/cart.js && echo t >test/old.test.js && git add src test && git commit -qm code
  git switch -qc PAY-1-work
  mark_workflow
  echo more >>test/old.test.js && git add test
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 0 ]
  git mv src/cart.js test/cart.js
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 2 ]
  git reset -q --hard && git rm -q test/old.test.js
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 2 ]
}

@test "the failing-tests commit may not skip git hooks with code staged, or with nothing staged" {
  git switch -qc PAY-1-work
  mark_workflow
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 2 ]
  stage_tests
  mkdir -p src && echo code >src/cart.js && git add src
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 2 ]
  [[ "$output" == *"only test files staged"* ]]
}

@test "no other commit, command, ticket or session may skip git hooks" {
  git switch -qc PAY-1-work
  stage_tests
  run guard "git commit --no-verify -m \"PAY-1: failing tests\""
  [ "$status" -eq 2 ]
  [[ "$output" == *'git commit --no-verify -m "<KEY>: failing tests"'* ]]
  mark_workflow
  for c in "git commit --no-verify -m \"PAY-1: implement\"" \
    "git commit --no-verify -m \"PAY-2: failing tests\"" \
    "git commit --no-verify -m \"PAY-1: failing tests and the fix\"" \
    "git commit --no-verify -am \"PAY-1: failing tests\"" \
    "git commit --no-verify -m \"PAY-1: failing tests\" src/app.js" \
    "git commit --no-verify -m \"PAY-1: failing tests\" && git push" \
    "git commit --no-verify -m \"PAY-1: failing tests\"; rm -rf test" \
    "git commit --no-verify -m \"PAY-1: failing tests\"
git commit --no-verify -m \"PAY-1: implement\"" \
    "HUSKY=0 git commit -m \"PAY-1: failing tests\"" \
    "git -c core.hooksPath=/dev/null commit -m \"PAY-1: failing tests\"" \
    "sh -c \"git commit --no-verify -m 'PAY-1: failing tests'\"" \
    "git push --no-verify -m \"PAY-1: failing tests\"" \
    "$(printf 'git commit --no-verify -m "PAY-1: failing tests"\r')"; do
    run guard "$c"
    [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
  done
  run run_hook guard-bash "git commit --no-verify -m \"PAY-1: failing tests\"" s2
  [ "$status" -eq 2 ]
}

@test "blocks a hook flag on a continuation line or quoted as a single word" {
  run guard "git commit \\
  --no-verify -m x"
  [ "$status" -eq 2 ]
  run guard "git commit \"--no-verify\" -m x"
  [ "$status" -eq 2 ]
  run guard "git commit -m wip '-n'"
  [ "$status" -eq 2 ]
  run guard "git -c 'core.hooksPath=/dev/null' commit -m x"
  [ "$status" -eq 2 ]
  run guard "HUSKY=\"0\" git commit -m x"
  [ "$status" -eq 2 ]
}

@test "a quote inside the other kind of quote does not hide a hook flag" {
  run guard "git commit -m \"Fix user's cart\" --no-verify && echo 'all done'"
  [ "$status" -eq 2 ]
  run guard "git commit -m \"\$(cat <<'EOF'
Fix the user's cart
EOF
)\" --no-verify && git log --format='%h %s' -1"
  [ "$status" -eq 2 ]
  run guard "git commit -m \"a \\\" b\" --no-verify -m \"c d\""
  [ "$status" -eq 2 ]
}

@test "checks commands wrapped in sh -c, eval, or a git alias" {
  run guard "sh -c 'git commit --no-verify -m wip'"
  [ "$status" -eq 2 ]
  run guard "bash -c \"git commit -n -m 'PAY-1: wip'\""
  [ "$status" -eq 2 ]
  run guard "eval 'git commit --no-verify -m wip'"
  [ "$status" -eq 2 ]
  run guard "git config alias.ci 'commit --no-verify'"
  [ "$status" -eq 2 ]
  run guard "sh -c 'git config core.hooksPath /dev/null'"
  [ "$status" -eq 2 ]
  run guard "bash -c 'npm test && git commit -m \"PAY-1: implement\"'"
  [ "$status" -eq 0 ]
}

@test "allows commands, quoted text and other tools that only mention a hook flag" {
  run guard "git commit --amend --no-edit"
  [ "$status" -eq 0 ]
  run guard "git log -n 5"
  [ "$status" -eq 0 ]
  run guard "git commit -m x 2>&1 | tail -n 5"
  [ "$status" -eq 0 ]
  run guard "gh pr comment 12 --body 'do not use --no-verify'"
  [ "$status" -eq 0 ]
  run guard "grep -rn -- --no-verify docs/"
  [ "$status" -eq 0 ]
  run guard "git add -A && cargo publish --no-verify"
  [ "$status" -eq 0 ]
  run guard "git commit -m \"\$(cat <<'EOF'
PAY-1: failing tests

Explain why git commit --no-verify and -n are blocked.
EOF
)\""
  [ "$status" -eq 0 ]
}

@test "production deploys need a release approval when a pattern is set" {
  echo 'KAI_PROD_DEPLOY_PATTERN="deploy.*--env[= ]prod"' >>.kai/config
  run guard "./deploy.sh --env prod"
  [ "$status" -eq 2 ]
  [[ "$output" == *"release manager"* ]]
  KAI_RELEASE_APPROVAL="Dana" run guard "./deploy.sh --env prod"
  [ "$status" -eq 0 ]
  run guard "./deploy.sh --env staging"
  [ "$status" -eq 0 ]
}

@test "an invalid deploy pattern blocks with its message" {
  echo 'KAI_PROD_DEPLOY_PATTERN="deploy("' >>.kai/config
  run guard "ls"
  [ "$status" -eq 2 ]
  [[ "$output" == *"kai: blocked: KAI_PROD_DEPLOY_PATTERN in .kai/config is not a valid regular expression; fix it."* ]]
}

@test "an invalid .kai/config blocks Bash with its message" {
  echo 'KAI_LEVEL=5' >>.kai/config
  run guard "git commit --no-verify -m x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"KAI_LEVEL in .kai/config must be 1, 2, 3 or 4, not '5'"* ]] || false
  echo 'KAI_TICKET_PREFIXES="PAY' >.kai/config
  run guard "ls"
  [ "$status" -eq 2 ]
  [[ "$output" == *".kai/config is not valid sh"* ]]
}

@test "does nothing in repositories without kai" {
  rm .kai/config
  run guard "git commit --no-verify"
  [ "$status" -eq 0 ]
}

@test "a SKIP variable blocks only a command that runs git" {
  run guard "SKIP=e2e npm test"
  [ "$status" -eq 0 ]
  run guard "SKIP=flake8,mypy git commit -m x"
  [ "$status" -eq 2 ]
}
