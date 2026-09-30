REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
KAI="$REPO_ROOT/plugins/kai/bin/kai"

make_repo() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  echo "# app" >README.md
  git add README.md
  git commit -qm init
}

write_config() {
  mkdir -p .kai
  cat >.kai/config <<CFG
KAI_TICKET_PROVIDER=${1:-jira}
KAI_TICKET_PREFIXES="${2-PAY OPS}"
KAI_VERIFY_CMDS='${3:-true}'
CFG
}

run_hook() {
  hook_input "${2-}" "${3:-s1}" | "$KAI" hook "$1"
}

commit_config() {
  git add -A && git commit -qm config
}

hook_input() {
  jq -cn --arg cmd "${1-}" --arg cwd "$PWD" --arg sid "${2:-s1}" \
    '{session_id: $sid, cwd: $cwd, tool_name: "Bash", tool_input: {command: $cmd}}'
}
