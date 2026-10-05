load helpers

PRODUCT="$REPO_ROOT/plugins/kai-product"

@test "kai-product templates match kai's, so both produce the same artifacts" {
  for t in spec.md; do
    cmp "$REPO_ROOT/plugins/kai/templates/$t" "$PRODUCT/templates/$t"
  done
}

@test "kai-product installs in claude.ai and Cowork: no bin/, hooks, or local commands" {
  [ ! -e "$PRODUCT/bin" ] && [ ! -e "$PRODUCT/hooks" ]
  ! grep -rn 'kai key\|kai verify\|kai gate' "$PRODUCT/skills" "$PRODUCT/references"
}

@test "review agents are self-contained, since kai init copies them into repositories" {
  ! grep -n 'kai key\|kai gate\|CLAUDE_PLUGIN_ROOT' "$REPO_ROOT"/plugins/kai/agents/*.md
}
