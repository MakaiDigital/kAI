bats_require_minimum_version 1.5.0
load helpers

setup() {
  make_repo
  write_config
  cat >.kai/tiers <<'T'
# comment
specs/* low
docs/* low
*.md low
src/auth/* high
T
  commit_config
  git switch -qc PAY-1-work
}

@test "no changes is low" {
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = low ]
}

@test "docs and specs only is low" {
  mkdir -p docs specs/PAY-1 && echo d >docs/a.txt && echo s >specs/PAY-1/spec.md
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = low ]
}

@test "unmatched files default to medium" {
  mkdir -p src && echo x >src/app.js
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = medium ]
}

@test "the highest file tier wins, including deep paths and committed changes" {
  mkdir -p src/auth/providers && echo x >src/auth/providers/jwt.js && echo y >NOTES.md
  git add -A && git commit -qm work
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
  [[ "$stderr" == *"high   src/auth/providers/jwt.js"* ]] || false
  [[ "$stderr" == *"low    NOTES.md"* ]]
}

@test "a high file stays high even when it also matches a low pattern" {
  mkdir -p src/auth && echo x >src/auth/README.md
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
}

@test "without a tiers file everything is medium" {
  git rm -q .kai/tiers && git commit -qm "no tiers"
  echo x >README.md
  run --separate-stderr "$KAI" tier --base PAY-1-work~1
  [ "$output" = medium ]
}

@test "a rename out of src/auth/ stays high" {
  mkdir -p src/auth && echo x >src/auth/session.js
  git add -A && git commit -qm "add session"
  git mv src/auth/session.js src/session.js
  run --separate-stderr "$KAI" tier --base PAY-1-work
  [ "$output" = high ]
  git commit -qm "move session"
  run --separate-stderr "$KAI" tier --base PAY-1-work~1
  [ "$output" = high ]
}

@test "a non-ASCII path under src/auth/ is high" {
  mkdir -p src/auth && echo x >"src/auth/sesión.js"
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
  git add -A && git commit -qm "add session"
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
}

@test "a path that git would quote under src/auth/ is high" {
  mkdir -p src/auth && echo x >'src/auth/a"b.js'
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
  git add -A && git commit -qm "add a quoted name"
  run --separate-stderr "$KAI" tier --base main
  [ "$output" = high ]
}

@test "a base with no common history dies with the fetch-depth message" {
  git switch -q --orphan unrelated
  echo y >y.txt && git add y.txt && git commit -qm unrelated
  git switch -q PAY-1-work
  run "$KAI" tier --base unrelated
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot diff against unrelated; in CI, check out with fetch-depth: 0"* ]]
}
