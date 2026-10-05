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
  run "$KAI" verify --evidence specs/PAY-1/evidence.md
  [ "$status" -eq 0 ]
  grep -q 'Result: \*\*PASS\*\*' specs/PAY-1/evidence.md
  grep -q '^## PASS: echo all good (exit 0)$' specs/PAY-1/evidence.md
  grep -q '^all good$' specs/PAY-1/evidence.md
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
