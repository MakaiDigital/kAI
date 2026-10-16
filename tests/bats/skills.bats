load helpers

SDLC="$REPO_ROOT/plugins/kai"

@test "commands and the skills that need them share one procedure file" {
  for r in implement prove adr retro answer-reviews; do [ -f "$SDLC/references/$r.md" ]; done
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/implement.md' "$SDLC/skills/implement/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/implement.md' "$SDLC/skills/accept/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/prove.md' "$SDLC/skills/prove/SKILL.md"
  grep -qF '`prove.md` in this folder' "$SDLC/references/implement.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/adr.md' "$SDLC/skills/adr/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/adr.md' "$SDLC/skills/spec/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/retro.md' "$SDLC/skills/retro/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/retro.md' "$SDLC/skills/accept/SKILL.md"
  grep -qF '`answer-reviews.md` in this folder' "$SDLC/references/implement.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/answer-reviews.md' "$SDLC/skills/accept/SKILL.md"
}

@test "every skill and review agent writes for people by the same rules" {
  for f in "$REPO_ROOT"/plugins/*/skills/*/SKILL.md; do
    grep -qF '${CLAUDE_PLUGIN_ROOT}/references/writing.md' "$f" || { echo "missing in $f"; false; }
  done
  for f in "$SDLC"/agents/*.md; do
    grep -qF 'KAI_WRITING_STE' "$f" || { echo "missing in $f"; false; }
  done
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

@test "acceptance fixes a failure itself instead of handing the fix to the person" {
  run grep -n 'run `/kai:implement' "$SDLC/skills/accept/SKILL.md" "$REPO_ROOT/README.md" "$REPO_ROOT/docs/using-kai.md"
  [ "$status" -eq 1 ]
}

@test "acceptance is the merged cleanup PR, not a label" {
  run grep -rn 'accepted` label\|label:accepted' "$SDLC/skills" "$SDLC/references" "$SDLC/templates" "$SDLC/template" "$REPO_ROOT/README.md" "$REPO_ROOT/docs"
  [ "$status" -eq 1 ]
}
