load helpers

setup() { make_repo; }

@test "passes when every command passes and records the fingerprint" {
  write_config jira PAY "true
echo hello"
  run "$KAI" verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS  true"* ]]
  [ -s "$(git rev-parse --absolute-git-dir)/kai/verified" ]
}

@test "runs every command and fails if any fails" {
  write_config jira PAY "echo broken; exit 3
touch ran-second"
  run "$KAI" verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  echo broken; exit 3 (exit 3)"* ]]
  [[ "$output" == *"broken"* ]]
  [ -f ran-second ]
  [ ! -e "$(git rev-parse --absolute-git-dir)/kai/verified" ]
}

@test "writes a Markdown evidence file" {
  write_config jira PAY "echo all good"
  commit_config
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 0 ]
  grep -q 'Result: \*\*PASS\*\*' specs/PAY-1/evidence.md
  grep -q "^kai verify on commit $(git rev-parse HEAD) at " specs/PAY-1/evidence.md
  grep -q '^## PASS: echo all good (exit 0)$' specs/PAY-1/evidence.md
  grep -q '^all good$' specs/PAY-1/evidence.md
}

@test "evidence describes a commit, so it refuses uncommitted changes outside specs/" {
  write_config jira PAY "echo all good"
  commit_config
  echo change >>README.md
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"commit your changes first: evidence must describe a commit, and these files differ from it:"* ]]
  [[ "$output" == *" M README.md"* ]]
  [ ! -e specs/PAY-1/evidence.md ]
  git checkout -q README.md
  echo 'test("new")' >new.test.js
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"?? new.test.js"* ]]
  rm new.test.js
  mkdir -p specs/PAY-1 && echo plan >specs/PAY-1/plan.md
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 0 ]
}

@test "the evidence keeps a command's full output, the terminal its last 40 lines" {
  write_config jira PAY "seq 1 250; exit 1"
  commit_config
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 1 ]
  grep -qx 1 specs/PAY-1/evidence.md
  grep -qx 250 specs/PAY-1/evidence.md
  [ "$(printf '%s\n' "$output" | grep -c '^      [0-9]*$')" -eq 40 ]
}

@test "a relative evidence path is relative to the repository root" {
  write_config jira PAY "echo all good"
  mkdir src && echo x >src/app.js
  commit_config
  cd src
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 0 ]
  grep -q '^all good$' "$TEST_REPO/specs/PAY-1/evidence.md"
  [ ! -e "$TEST_REPO/src/specs" ]
}

@test "warns and succeeds when nothing is configured" {
  write_config
  echo "KAI_VERIFY_CMDS=''" >>.kai/config
  run "$KAI" verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to verify"* ]]
}

@test "the fingerprint ignores changes under specs/" {
  write_config jira PAY true
  "$KAI" verify
  before=$(cat "$(git rev-parse --absolute-git-dir)/kai/verified")
  mkdir -p specs/PAY-1 && echo x >specs/PAY-1/spec.md
  . "$REPO_ROOT/plugins/kai/scripts/lib/common.sh"
  kai_load_config
  [ "$(kai_fingerprint)" = "$before" ]
  echo change >>README.md
  [ "$(kai_fingerprint)" != "$before" ]
}
