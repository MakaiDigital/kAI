load helpers

SDLC="$REPO_ROOT/plugins/kai"

@test "commands and the skills that need them share one procedure file" {
  for r in prove adr retro answer-reviews; do [ -f "$SDLC/references/$r.md" ]; done
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/prove.md' "$SDLC/skills/prove/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/prove.md' "$SDLC/skills/implement/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/adr.md' "$SDLC/skills/adr/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/adr.md' "$SDLC/skills/spec/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/retro.md' "$SDLC/skills/retro/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/retro.md' "$SDLC/skills/accept/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/answer-reviews.md' "$SDLC/skills/implement/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/answer-reviews.md' "$SDLC/skills/accept/SKILL.md"
}

@test "procedure files are read as plain files, so they use no skill substitutions" {
  run grep -n 'CLAUDE_PLUGIN_ROOT\|\$ARGUMENTS' "$SDLC"/references/*.md
  [ "$status" -eq 1 ]
}

@test "every kai skill runs only from its command" {
  for f in "$SDLC"/skills/*/SKILL.md; do
    awk '/^---$/ && ++n == 2 { exit } n == 1' "$f" | grep -qx 'disable-model-invocation: true' || { echo "missing in $f"; false; }
  done
}

@test "skills hand other kai commands to the person instead of running them" {
  run sh -c "grep -nE '(^|[^[:alnum:]])([Rr]un|[Ff]ollow|through|[Gg]o(ing)? to) (step [0-9]+ of )?.?/kai:' \"\$1\"/skills/*/SKILL.md \"\$1\"/references/*.md | grep -v 'the person'" -- "$SDLC"
  [ -z "$output" ]
}

@test "the user docs say acceptance hands a fix to the person" {
  run grep -n 'through `/kai:implement`' "$REPO_ROOT/README.md" "$REPO_ROOT/docs/using-kai.md"
  [ "$status" -eq 1 ]
}
