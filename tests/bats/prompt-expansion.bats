load helpers

setup() {
  make_repo
  write_config
  commit_config
}

marker() { printf '%s/kai/session-%s.workflow\n' "$(git rev-parse --absolute-git-dir)" "${1:-s1}"; }

typed() { expansion_input "$@" | "$KAI" hook prompt-expansion; }

@test "a kai command marks the session" {
  run typed kai:implement "/kai:implement PAY-1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$(marker)" ]
}

@test "the typed command is enough when the command name has no plugin prefix" {
  typed implement "/kai:implement PAY-1"
  [ -f "$(marker)" ]
}

@test "another command does not mark the session, even when its text names a kai command" {
  typed code-review "/code-review /kai:implement"
  typed "" ""
  [ ! -e "$(marker)" ]
}

@test "each session is marked on its own" {
  typed kai:spec "/kai:spec PAY-1" s1
  [ -f "$(marker s1)" ]
  [ ! -e "$(marker s2)" ]
}

@test "does nothing in repositories without kai" {
  git rm -q .kai/config
  run typed kai:implement "/kai:implement PAY-1"
  [ "$status" -eq 0 ]
  [ ! -e "$(git rev-parse --absolute-git-dir)/kai" ]
}
