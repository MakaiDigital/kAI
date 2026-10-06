load helpers

setup() {
  make_repo
  write_config
  echo "KAI_LEVEL=2" >>.kai/config
  printf 'specs/* low\n*.md low\n' >.kai/tiers
  commit_config
}

write_definition() {
  mkdir -p specs/PAY-1 && echo s >specs/PAY-1/spec.md
}

definition() { "$KAI" gate definition --base main "$@"; }

@test "skipped below level 2" {
  sed -i.bak '/KAI_LEVEL=2/d' .kai/config && rm .kai/config.bak
  git switch -qc PAY-1-work
  echo x >app.js
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

@test "a low tier change needs no spec" {
  git switch -qc PAY-1-docs
  echo x >>README.md
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"low tier"* ]]
}

@test "the Definition PR itself passes" {
  git switch -qc PAY-1-definition
  write_definition
  run definition
  [ "$status" -eq 0 ]
}

@test "code for a medium change fails until the spec is merged to base" {
  git switch -qc PAY-1-work
  write_definition
  echo x >app.js
  git add -A && git commit -qm "spec and code together"
  run definition
  [ "$status" -eq 1 ]
  [[ "$output" == *"PAY-1 is a medium-tier change"* ]] || false
  [[ "$output" == *"its spec is not approved yet"* ]]
}

@test "code passes once the spec is on the base branch" {
  write_definition
  git add -A && git commit -qm "PAY-1: definition"
  git switch -qc PAY-1-work
  echo x >app.js
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"has an approved spec"* ]]
}

@test "uses the PR title when the branch has no key" {
  write_definition
  git add -A && git commit -qm "PAY-1: definition"
  git switch -qc fix-thing
  echo x >app.js
  run definition --branch fix-thing --title "PAY-1: fix thing"
  [ "$status" -eq 0 ]
}

@test "bot branches are exempt" {
  git switch -qc dependabot/npm/lodash
  echo x >app.js
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"exempt"* ]]
}

@test "a cleanup branch that deletes the spec and adds only Markdown passes as low tier" {
  write_definition
  echo e >specs/PAY-1/evidence.md
  git add -A && git commit -qm "PAY-1: done"
  git switch -qc PAY-1-cleanup
  git rm -rq specs/PAY-1 && git commit -qm "PAY-1: cleanup"
  echo "- A lesson." >>README.md && git commit -qam "PAY-1: retro"
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"low tier"* ]]
}

@test "a cleanup-named branch is not exempt" {
  write_definition
  git add -A && git commit -qm "PAY-1: definition"
  git switch -qc PAY-1-cleanup
  git rm -rq specs/PAY-1
  echo x >app.js
  git add -A && git commit -qm "PAY-1: cleanup"
  run definition
  [ "$status" -eq 0 ]
  [[ "$output" == *"PAY-1 (medium tier) has an approved spec"* ]]
}
