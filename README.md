# kAI

Makai's AI-native SDLC for Claude Code. Every change moves through a chain of committed artifacts (spec, plan, failing tests, code, evidence), and the rules that must always hold are enforced by hooks and CI rather than left to the model.

Kai is deliberately thin. It supplies the workflow, templates, and guardrails, and builds on pinned upstream plugins for the heavy lifting: [Superpowers](https://github.com/obra/superpowers) for test-driven development and verification discipline, and Anthropic's `feature-dev` agents for codebase exploration.

- **Developers:** [Using Kai](docs/using-kai.md) walks through a change step by step, from ticket to done.
- **Trying it in a repository:** [Piloting Kai](docs/pilot.md) covers installing, measuring a baseline, and sending feedback.

## The flow

```
ticket ──▶ /kai:spec ──▶ /kai:implement ──▶ merge + deploy ──▶ /kai:accept ──▶ done
          (spec + ADR,    (plan ▸ tests ▸     (a person        (verify ▸ QA ▸
           or skipped      code ▸ prove ▸      approves)        fix loop ▸ retro ▸
           for low-tier    review ▸ PR ▸                        cleanup PR)
           changes)        answer reviews)
```

The ticket is the intent; there is no separate intent document. `/kai:spec` reads it and either writes a spec (and an ADR when the change needs a decision) for a Definition PR, or, when the change touches only low-tier files, says why it can skip one. `/kai:implement` asks for approval once, at the plan (approve it with "Yes, and use auto mode"), then carries the work to a reviewed, green PR. After a person merges it and it is deployed, `/kai:accept` verifies it in integration, tries to break it, and finishes with a cleanup PR that removes the ticket's working documents. At level 4, only ADRs remain as documentation; the rest is read from the code.

## Commands

| Command | What it does | Output |
|---|---|---|
| `/kai:spec <KEY>` | Reads the ticket, decides whether it needs a spec (only a change that touches nothing but low-tier files skips it), then writes numbered EARS criteria, a contract mapping each to a test, and a short "Review here" list of what a person must judge. Drafts an ADR when the change needs one (level 2) | `specs/<KEY>/spec.md`, `docs/adr/NNNN-*.md` |
| `/kai:adr` | Records an architecture decision with options and trade-offs. `/kai:spec` runs it when needed; call it directly for a decision outside a spec (level 2) | `docs/adr/NNNN-*.md` |
| `/kai:implement` | Plans (stops for approval), commits failing tests, implements the minimum, proves it, gets an independent review and fixes it, opens the PR, then answers its trusted reviewers (fixing what is right, defending with evidence what is not) until reviews are satisfied and checks are green, for up to five rounds | `plan.md`, tests, code, `evidence.md`, pull request |
| `/kai:prove` | Runs the team's checks and maps each planned test (and spec criterion) to its result. `/kai:implement` calls it; run it alone to re-check | `evidence.md` |
| `/kai:accept <KEY>` | After the change is deployed to integration, verifies it, tries to break it, fixes failures through `/kai:implement`, then runs the retro and opens a cleanup PR that deletes the ticket's specs (keeping ADRs) and applies the retro's instruction changes (level 4) | cleanup pull request |
| `/kai:retro` | Finds the lessons worth keeping in a ticket or a period and applies the instruction changes as separate commits; a lesson that needs a hook or script becomes a ticket. `/kai:accept` runs it; run it alone for a sprint view (level 4) | skill, ADR, or CLAUDE.md changes |

Two read-only review agents back `/kai:implement` and the CI review: `kai:contract-reviewer` (every PASS has evidence, every change traces to a criterion) and `kai:spec-critic` (behavior no criterion covers, proposed as EARS criteria).

The skills also trigger from plain requests such as "start PAY-123" or "let's implement this".

Guardrail hooks run in every session:

- **Stop** runs `kai verify` and keeps Claude working until the configured checks pass (it gives up with a warning after a few attempts).
- **PreToolUse (Bash)** blocks skipping git hooks (`--no-verify`, `git commit -n`, `core.hooksPath`, the `HUSKY=0` and `LEFTHOOK=0` switches, and pre-commit's `SKIP=` on a git command, also inside `sh -c`, `eval` or a git alias) and production deploys without a named release approval.
- **PreToolUse (Edit, Write, NotebookEdit)** at level 3 blocks edits to tests locked by the ticket's `<KEY>: failing tests` commits.
- **SessionStart** tells Claude which ticket the branch is for and what the next step is.

The settings `kai init` writes also deny `gh pr merge` and adding the `kai:tests-changed` label with `gh pr edit` or `gh issue edit`, and ask before a `git push` that names the base branch. These rules match command shapes, so other forms slip past them; what stops the push is GitHub branch protection, which needs a paid plan for private repositories.

## Kai for Product (claude.ai and Cowork)

`kai-product` lets product managers and other non-engineers write the spec and acceptance criteria in claude.ai or Cowork, without git or a terminal. Its `spec` skill produces the same `specs/<KEY>/spec.md` file engineering's Kai reads, and delivers it as the Definition PR:

- With a GitHub connector that can write to the repository (claude.ai's built-in GitHub integration is read-only), it opens the PR after the person approves its title and body.
- Without one, it hands over the file and a note for the engineering lead.

It bundles no connectors: it uses whichever Jira, Linear, or GitHub connectors your organization has approved and enabled. An organization admin adds `kai-product` from the `makaidigital` marketplace in claude.ai's organization settings. It has no `bin/`, which would stop claude.ai and Cowork from installing it. Anthropic's product-management plugin can be installed alongside it for roadmaps and stakeholder updates. In Claude Code, don't enable `kai-product` or `superpowers@claude-plugins-official` next to `kai`: `kai-product` also has a skill named `spec`, and the official Superpowers' session hook and entry skills compete with Kai's.

## Install into a repository

Requirements: Claude Code, `git` 2.36 or newer, `jq`, and an authenticated `gh` (`gh auth login`, then `gh auth setup-git` so the private marketplace clones without a prompt). Nothing to clone.

1. Install the plugin, once per machine:

   ```sh
   claude plugin marketplace add MakaiDigital/kAI
   claude plugin install kai@makaidigital
   ```

2. Open the repository in Claude Code and run `/kai:setup`. Claude works out the ticket system, prefixes, and test commands, previews the changes, writes them with `kai init`, and proposes high-risk paths for `.kai/tiers`.

To script it instead, Claude can run `kai init` directly, for example `kai init --provider jira --prefixes "PAY OPS" --level 1`. `kai init --help` lists every option.

Setup adds:

| Path | Purpose | Ownership |
|---|---|---|
| `.kai/config` | Level, ticket provider, allowed prefixes, verify commands | Yours; never overwritten |
| `.kai/tiers` | Path patterns that make a change low, medium, or high risk | Yours; never overwritten |
| `.kai/constraints.md` | The minimal-code standard | Kai's; if yours differs, the new version lands in `*.kai-new` |
| `CLAUDE.md` | A short kai block between markers | Only the block is managed |
| `.claude/settings.json` | Registers the `makaidigital` marketplace, enables `kai`, defaults to plan mode, and adds permission rules (deny `gh pr merge` and adding `kai:tests-changed`; ask before a push to the base branch) | Merged; your keys and rules are kept |
| `.github/workflows/kai.yml` | Runs the gates on pull requests as the `kai` check | Kai's; updated in place when only the action versions Kai pins differ, otherwise the same `*.kai-new` rule |
| `REVIEW.md` (level 3) | What the reviewer checks and how it rates findings; owned by the tech lead | Yours; never overwritten |
| `.claude/agents/contract-reviewer.md`, `spec-critic.md` (level 3) | The read-only review agents the CI review runs | Kai's; same `*.kai-new` rule |
| `.github/workflows/kai-review.yml` (level 3) | AI review comment on trusted PRs through `claude-code-action` | Kai's; same rule as `kai.yml` |
| `.github/workflows/kai-metrics.yml` (level 4) | Weekly `kai metrics` report in the job summary | Kai's; same rule as `kai.yml` |

Run `/kai:setup` again to upgrade; `kai init --dry-run` shows what would change. It never overwrites your changes: when one of Kai's files differs from the new version, it writes `<file>.kai-new` next to it for you to merge (a workflow that differs only in the action versions Kai pins is updated in place).

To uninstall, delete:

- `.kai/`, `REVIEW.md`, `.github/workflows/kai*.yml`, `.claude/agents/contract-reviewer.md`, and `.claude/agents/spec-critic.md`
- the kai block in `CLAUDE.md`
- in `.claude/settings.json`: the `makaidigital` and `kai@makaidigital` entries, the rules Kai added to `permissions.deny` and `permissions.ask` (merging, `kai:tests-changed`, and pushes to the base branch), `env.SUPERPOWERS_DISABLE_TELEMETRY`, and `permissions.defaultMode` if Kai set it
- any `*.kai-new` files

Teammates who open the repository in Claude Code are prompted to install `kai` from the `makaidigital` marketplace, which also installs the pinned dependencies.

## The `kai` CLI

The plugin puts `kai` on Claude's PATH. The same script backs the hooks and the CI action.

```
kai key [TEXT]              ticket key from TEXT or the current branch
kai verify [--evidence F]   run KAI_VERIFY_CMDS; optionally write the evidence to F
kai tier [--base REF]       risk tier of the change, from .kai/tiers
kai metrics [--weeks N]     weekly speed and quality report from the specs/ history
kai gate ticket-ref         CI gate: branch or PR title must reference a ticket
kai gate definition         CI gate (level 2): medium/high-tier code needs a merged spec
kai gate tests-locked       CI gate (level 3): tests from the ticket's failing-tests commits are unchanged
kai gate contract           CI gate (level 3): every criterion and planned test is PASS with evidence
```

## Levels

Set `KAI_LEVEL` in `.kai/config` (or `--level` when installing). CI judges each PR by the base branch's `.kai/config` and `.kai/tiers`, so a change to either takes effect once it is merged.

1. **Implement, prove.** Guardrail hooks, `kai verify` in the Stop hook and `/kai:prove`, and the `ticket-ref` gate in CI.
2. **Specs and tiers.** `/kai:spec` and `/kai:adr`. Medium and high tier changes take two PRs: a Definition PR with `spec.md` (and any ADR), then the Change PR with the code. The `definition` gate enforces the order.

Kai adds only one gate at level 2. The rest comes from GitHub settings you configure once per repository (at any level):

- **Branch protection on `main`:** require a pull request, at least one approval, and the `kai` check. This is what stops direct pushes, for people and agents alike. Private repositories need a paid GitHub plan for branch protection or rulesets; until then, only Kai's permission rules stand in the way of a push to the base branch.
- **CODEOWNERS**, for example `specs/**/spec.md @your-org/product` and `specs/ @your-org/product @your-org/eng-leads`, so product and engineering both sign off on the Definition PR. Add `.github/workflows/ @your-org/eng-leads` too: a PR runs the workflow files it changes, so an edit to `kai.yml` changes its own checks. Branches in `KAI_TICKET_EXEMPT` (`kai-setup*`, `kai-retro*`, and bot branches by default) skip every gate, so for those PRs the approval is the only check.
- **High-risk paths:** list them in CODEOWNERS with the tech leads and require two approvals, so a human reads that code.

3. **Independent verification.** Tests in a ticket's failing-tests commits are locked for that ticket's PRs: a hook blocks Claude from editing them, and the `tests-locked` gate fails if they change, unless a reviewer adds the `kai:tests-changed` label. The `contract` gate requires every criterion and planned test to be PASS with evidence. `/kai:implement` also runs the gates locally before it opens the PR (its read-only review runs at every level), and `kai-review.yml` posts the same review on trusted PRs (not forks or bots). The review informs the human approver; it never blocks or approves the merge by itself.

The CI review needs a Claude credential as a repository secret (`ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`, or switch the action to Bedrock or Vertex), pointed at an endpoint your security team has approved. It skips with a notice when neither is set. It passes the workflow's own token to the action, so no GitHub App is needed. The review uses the `contract-reviewer` and `spec-critic` agents that setup copies into `.claude/agents/`, so it installs nothing and works whether or not the Kai repository is public.

4. **Close the loop.** Once the change is deployed to integration, the engineer runs `/kai:accept`: Claude verifies it, tries to break it, fixes failures through the same PR flow, and when it passes opens a cleanup PR that deletes the ticket's specs (only ADRs stay as documentation) and applies the retro's instruction changes. A person merges it, and that is the end of the ticket. `kai metrics` reports speed next to quality every week, reading ticket history from git, which survives the deletion.

Kai doesn't gate releases. Acceptance happens after merge, so `main` can hold merged changes that aren't accepted yet. The person who merges a ticket's cleanup PR adds the `accepted` label to its change PR (and any fix PRs). A release that should take only accepted changes is cut from a commit older than the oldest change PR without the label. This lists them, oldest first:

```sh
gh pr list --state merged --base main --limit 500 \
  --search "merged:>=<last release date> -label:accepted" --json number,title,mergedAt,headRefName \
  --jq 'sort_by(.mergedAt) | .[] | select(.title | ascii_downcase | test(": (definition|cleanup)$") | not)
    | select(.headRefName | test("^(kai-setup|kai-retro|dependabot/|renovate/)") | not) | "\(.mergedAt) #\(.number) \(.title)"'
```

Measure a baseline before turning on levels 3 and 4, and keep reading speed and quality together: `kai metrics` shows lead time next to rework on purpose.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the repository layout, the checks, skill evals, and how to send a pull request.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
