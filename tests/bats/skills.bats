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
  grep -qF 'through its step 8' "$SDLC/skills/accept/SKILL.md"
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

@test "Steward stops on an issue after three pushes, and on the approach after three rounds" {
  grep -q 'After three pushes for the same finding' "$SDLC/template/.claude/skills/steward/SKILL.md"
  grep -q 'after three rounds' "$SDLC/template/.claude/skills/steward/SKILL.md"
  grep -q 'still fails after three fixes' "$SDLC/references/prove.md"
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

@test "prove runs the change end to end and records it where the reviewer looks" {
  grep -qx '## Observed' "$SDLC/references/prove.md"
  grep -qF "Prove on the ticket's own branch" "$SDLC/references/prove.md"
  grep -qF '`## Observed` table' "$SDLC/agents/contract-reviewer.md"
  grep -qF "\`git log --grep '^Verified: checks\$'\`" "$SDLC/references/prove.md"
  grep -qF "\`git log --grep '^Verified: checks\$'\`" "$SDLC/references/retro.md"
  grep -qF '.claude/skills/verify/SKILL.md' "$SDLC/skills/setup/SKILL.md"
}

@test "the reviewer runs the REVIEW.md checks the diff triggers and says what needs a person" {
  grep -qx '## Checks' "$SDLC/template/REVIEW.md"
  grep -qF 'Checks table' "$SDLC/agents/contract-reviewer.md"
  grep -qF '`Checks run:' "$SDLC/agents/contract-reviewer.md"
  grep -qF '`Needs a person:' "$SDLC/agents/contract-reviewer.md"
  grep -qx '## Needs a person' "$SDLC/references/implement.md"
  grep -qF '`Needs a person:` line' "$SDLC/references/implement.md"
}

@test "the plan gives every test a kind, and its table keeps the test in the second column for the contract gate" {
  grep -qxF '| Criterion | Test | File | Kind |' "$SDLC/templates/plan.md"
  for kind in example e2e property differential; do grep -q "\`$kind\`" "$SDLC/references/plan.md"; grep -q "\`$kind\`" "$SDLC/templates/plan.md"; done
}

@test "a flaky test is not rerun until it passes, and the retro replays the reviewer on what it missed" {
  grep -qF 'is flaky, not fixed' "$SDLC/references/prove.md"
  grep -qx '### Review the reviewers' "$SDLC/references/retro.md"
  grep -qF '.kai/escapes.md' "$SDLC/references/retro.md"
}

@test "a change PR is handed to Steward: PR Steward with Claude Ship, or the person's /steward watch otherwise" {
  f="$SDLC/references/answer-reviews.md"
  grep -qF '@claude steward' "$f"
  grep -qF 'claude-pr-steward-watching' "$f"
  grep -qF 'KAI_SHIP' "$f"
  grep -qF 'type `/steward +github-actions`' "$f"
  grep -qF 'user.login == "github-actions[bot]"' "$SDLC/template/.github/workflows/kai-review.yml"
  grep -qF 'trust everyone who can merge to the base branch' "$f"
  grep -qF 'PR Steward has not started yet' "$f"
  grep -qF 'which can be after this check' "$f"
  grep -qF 'headed **Claude PR Steward**' "$f"
  grep -qF 'Steward never proves a change' "$SDLC/references/implement.md"
  run grep -n 'until it is green' "$SDLC/references/implement.md"
  [ "$status" -eq 1 ]
  grep -qF 'second clone' "$f"
  grep -qF 'second clone' "$REPO_ROOT/docs/using-kai.md"
  run grep -n 'claude --worktree' "$f" "$SDLC/skills/setup/SKILL.md" "$REPO_ROOT/docs/using-kai.md"
  [ "$status" -eq 1 ]
  run grep -n 'Monitor\|graphql' "$f"
  [ "$status" -eq 1 ]
}

@test "the Definition PR and the cleanup PR are answered with the person, not handed to Steward" {
  run grep -n 'answer-reviews.md' "$SDLC/skills/spec/SKILL.md" "$SDLC/skills/accept/SKILL.md"
  [ "$status" -eq 1 ]
  grep -qF '<!-- claude-pr-steward-disable -->' "$SDLC/skills/spec/SKILL.md"
  grep -qF '<!-- claude-pr-steward-disable -->' "$SDLC/skills/accept/SKILL.md"
  grep -qF '`<KEY>: address review`' "$SDLC/skills/spec/SKILL.md"
  grep -qF 'Never record a decision' "$SDLC/template/.claude/skills/steward/SKILL.md"
}

@test "the review template states its own checks, since Code Review cannot include the agents" {
  run grep -n '\.claude/agents' "$SDLC/template/REVIEW.md"
  [ "$status" -eq 1 ]
}

@test "lessons go where their readers are, and never into a hook that stops a watch" {
  f="$SDLC/references/retro.md"
  grep -qF '.claude/skills/steward/SKILL.md' "$f"
  grep -qF '.claude/skills/verify/SKILL.md' "$f"
  grep -qF 'no `/ship` or `/steward` watch starts with one' "$f"
  run grep -n 'hookify' "$f"
  [ "$status" -eq 1 ]
}

@test "setup hands the approvals policy to the bundled skill and names what a watch needs" {
  f="$SDLC/skills/setup/SKILL.md"
  grep -qF '`claude-approvals` skill' "$f"
  grep -qF 'permissions.ask' "$f"
  grep -qF 'Dismiss stale pull request approvals when new commits are pushed' "$f"
  grep -qF 'kai-setup-approvals' "$f"
  grep -qF 'no longer blocks a command that skips them' "$f"
  grep -qF 'second clone' "$f"
  [ ! -e "$SDLC/template/.claude/approvals.yml" ]
}

@test "the steward rules run where the plugin is not installed" {
  run grep -n 'CLAUDE_PLUGIN_ROOT\|/kai:\|references/\|kai verify\|kai gate' "$SDLC/template/.claude/skills/steward/SKILL.md"
  [ "$status" -eq 1 ]
  grep -qF 'KAI_WRITING_STE' "$SDLC/template/.claude/skills/steward/SKILL.md"
}

@test "the steward rules keep Kai's safety rules" {
  f="$SDLC/template/.claude/skills/steward/SKILL.md"
  grep -qF '`<KEY>: failing tests`' "$f"
  grep -qF 'kai:tests-changed' "$f"
  grep -qi 'never approve or merge' "$f"
  grep -qF 'Pre-existing' "$f"
  grep -qF 'Do not re-run a check until it passes' "$f"
  grep -qF '`<KEY>: address review`' "$f"
  grep -qF "That proof is the author's" "$f"
  grep -qF 'core.hooksPath=/dev/null' "$f"
  grep -qF 'describes an earlier commit' "$f"
  grep -qF 'describes an earlier commit' "$SDLC/scripts/gates/contract.sh"
  grep -qF 'never write PASS for a test or a step you did not run' "$f"
  run grep -rn 'proves it again' "$REPO_ROOT/docs" "$REPO_ROOT/README.md"
  [ "$status" -eq 1 ]
  grep -qx '## This repository' "$f"
}
