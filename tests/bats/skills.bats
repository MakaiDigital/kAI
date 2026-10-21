load helpers

SDLC="$REPO_ROOT/plugins/kai"

@test "commands and the skills that need them share one procedure file" {
  for r in implement plan prove adr retro answer-reviews; do [ -f "$SDLC/references/$r.md" ]; done
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/implement.md' "$SDLC/skills/implement/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/implement.md' "$SDLC/skills/accept/SKILL.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/prove.md' "$SDLC/skills/prove/SKILL.md"
  grep -qF '`prove.md` in this folder' "$SDLC/references/implement.md"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/references/plan.md' "$SDLC/skills/spec/SKILL.md"
  grep -qF '`plan.md` in this folder' "$SDLC/references/implement.md"
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

@test "the reviewer and the REVIEW.md template tag findings Important, Nit or Pre-existing" {
  for f in "$SDLC/agents/contract-reviewer.md" "$SDLC/template/REVIEW.md"; do
    for tag in Important Nit Pre-existing; do grep -q "\*\*$tag\*\*" "$f" || { echo "$tag missing in $f"; false; }; done
  done
}

@test "a Pre-existing finding never blocks, and the verdict turns on Important findings" {
  grep -q '\*\*Pre-existing\*\*.*never blocks' "$SDLC/agents/contract-reviewer.md"
  grep -q '\*\*Pre-existing\*\*.*Never blocks' "$SDLC/template/REVIEW.md"
  grep -qF '`VERDICT: PASS` if there are no Important findings' "$SDLC/agents/contract-reviewer.md"
}

@test "a review starts with its count, and says so when there is nothing to fix" {
  grep -qF 'Nothing to fix.' "$SDLC/agents/contract-reviewer.md"
  grep -qF 'Nothing to fix.' "$SDLC/template/REVIEW.md"
}

@test "answering reviews stops after three rounds" {
  grep -q 'for up to three rounds' "$SDLC/references/answer-reviews.md"
  run grep -rn 'five rounds\|fifth round' "$SDLC/skills" "$SDLC/references" "$REPO_ROOT/README.md" "$REPO_ROOT/docs"
  [ "$status" -eq 1 ]
}

@test "every upstream skill Kai names is pinned in the marketplace and installed with kai" {
  m="$REPO_ROOT/.claude-plugin/marketplace.json"
  refs=$(grep -rhoE '`(superpowers|mattpocock-skills):[a-z-]+`' "$SDLC/skills" "$SDLC/references" | tr -d '`' | sort -u)
  printf '%s\n' "$refs" | grep -qx 'mattpocock-skills:grilling'
  for ref in $refs; do
    plugin=${ref%%:*} skill=${ref#*:}
    jq -e --arg p "$plugin" --arg s "./$skill" '.plugins[] | select(.name == $p) | .skills | index($s)' "$m" >/dev/null || { echo "$ref is not pinned"; false; }
    jq -e --arg p "$plugin" '.plugins[] | select(.name == "kai") | .dependencies | index($p)' "$m" >/dev/null || { echo "$plugin is not a kai dependency"; false; }
  done
}

@test "the spec grills the developer, and a friendly, a skeptical and a neutral reviewer check the definition before its PR" {
  grep -qF '`mattpocock-skills:grilling`' "$SDLC/skills/spec/SKILL.md"
  for stance in friendly skeptical neutral; do
    grep -q "^- \*\*$stance\*\*:" "$SDLC/skills/spec/SKILL.md" || { echo "$stance missing in the spec skill"; false; }
    grep -q "^- \*\*$stance\*\*:" "$SDLC/agents/definition-reviewer.md" || { echo "$stance missing in the agent"; false; }
  done
  grep -qF '`kai:definition-reviewer`' "$SDLC/skills/spec/SKILL.md"
  grep -qF '`VERDICT: PASS` if there are no Important findings' "$SDLC/agents/definition-reviewer.md"
}

@test "implement builds from a plan the Definition PR merged, without planning again" {
  grep -qF 'With a plan the Definition PR merged' "$SDLC/references/implement.md"
  grep -qF 'Do not plan again' "$SDLC/references/implement.md"
  grep -qx '## Plan' "$SDLC/references/implement.md"
}

@test "the PR description says how risky the change is and how to revert it" {
  grep -qx '## Risk' "$SDLC/references/implement.md"
  grep -qx '## How to revert' "$SDLC/references/implement.md"
}
