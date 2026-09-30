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

@test "does nothing in repositories without kai" {
  rm .kai/config
  run guard "git commit --no-verify"
  [ "$status" -eq 0 ]
}
