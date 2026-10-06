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
