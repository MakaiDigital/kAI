# Using Kai

This guide walks a developer through one change, from ticket to release. Kai does the drafting, planning, testing, and checking; you decide what gets built and confirm it works.

Kai is already set up in your repository if it has a `.kai/config`. If not, install the plugin (`claude plugin marketplace add MakaiDigital/kAI`, then `claude plugin install kai@makaidigital`) and run `/kai:setup`. To trial it first, see [pilot.md](pilot.md).

## Before you start

- **Install the plugins.** Open the repository in Claude Code. The first time, accept the prompts to trust the folder and install `kai@makaidigital`, which also installs Superpowers and feature-dev. Run `/plugin` to confirm all three are enabled.
- **Know your level.** Run `grep KAI_LEVEL .kai/config`. The level decides which steps below apply:

| Level | Adds |
|---|---|
| 1 | Implement, prove, guardrail hooks |
| 2 | Specs, risk tiers, the two-PR flow |
| 3 | Locked tests, contract check, local gates and review, AI review in CI |
| 4 | Acceptance in integration, retros, metrics |

- **Know your risk tiers.** `.kai/tiers` maps paths to `low`, `medium`, or `high`. Files it doesn't list count as medium. A change takes the highest tier of any file it touches, and `kai tier` prints it with the reason for each file.

You can type the commands below, or just describe what you want ("start PAY-123", "let's build it", "does it work?"). Claude picks the matching skill.

## The workflow

### 1. Start from the ticket (all levels)

Every change starts from a ticket, such as `PAY-123` in Jira or Linear or `#42` on GitHub. Point Kai at it:

```
/kai:spec PAY-123
```

What happens:
- Claude reads the ticket (through the Jira, Linear, or GitHub connector, or you paste it).
- It decides whether the change needs a spec and says why in one line. A bug with a clear reproduction, a typo, docs, and other low-tier changes skip it and go straight to `/kai:implement`, with the ticket as the intent. You can overrule it either way.
- Below level 2 there are no specs: go straight to `/kai:implement`.

Claude works on a branch named after the ticket (`PAY-123-short-description`), creating or suggesting one. Branch names must contain the key, because CI checks for it.

### 2. Review the spec (level 2, medium and high tier)

If the ticket needs a spec, Claude writes `specs/PAY-123/spec.md`:
- A **Review here** list at the top: the assumptions, chosen numbers, added criteria, and security or data implications a person must judge. Each is marked `⚠ review` where it appears below.
- A short **Context** (problem, outcome, success metric, constraints, out of scope) taken from the ticket, so CI reviewers and `/kai:accept` have the goal while the ticket is open without ticket access.
- Criteria numbered C1, C2, … in a fixed form: "When …, the system shall …" or "If …, then the system shall …", including the unhappy paths (signed out, network down, invalid input).
- An end-to-end check you could run by hand, and a contract table mapping each criterion to a test, every row starting as FAIL.
- YAML frontmatter (key, ticket, tier, status, ADR) that agents and gates read.

If the change needs a new service, dependency, data store, external integration, or trust boundary, Claude also drafts `docs/adr/NNNN-title.md` with two or three options for the tech lead to decide. You do not run `/kai:adr` for this.

What you do:
1. Read the **Review here** list first, then check the criteria with product. Each must be testable, and together they must cover the ticket.
2. Merge the spec (and ADR) on their own, as a **Definition PR**: branch `PAY-123-definition`, title `PAY-123: definition`. Claude prepares it for you.
3. Wait for the merge before writing code. CI's `definition` check fails code for a medium- or high-tier ticket until its spec is on the main branch. If Claude skipped the spec and the tier turns out higher, write it then.

### 3. Implement (all levels)

Start a fresh branch for the code, then:

```
/kai:implement
```

Claude takes the ticket to a reviewed, green pull request. You are asked once, at the plan:
1. **Plan.** Claude explores the code and presents a plan: files to change, tasks, tests named by behavior (for example `rejects_expired_token`) and mapped to the criteria, and risks. Then it stops and waits for you.
   - **You approve or push back.** Push back if the plan adds files or dependencies you didn't expect, has tests that don't map to a criterion, or has criteria with no test. A wrong plan costs minutes to fix; wrong code costs hours.

After you approve, it keeps going without asking:
2. **Failing tests.** Claude writes the planned tests, confirms they fail for the right reason, and commits them on their own as `PAY-123: failing tests`.
3. **Implementation.** Claude writes the smallest change that makes the tests pass, following `.kai/constraints.md`.
4. **Proof.** It runs `/kai:prove`: `kai verify`, then a table matching every planned test to the output line that shows it passing. A planned test that never ran is **MISSING**, which counts as a failure. The spec's contract table is updated and committed as `PAY-123: evidence`.
5. **Review.** At level 3 it runs the same gates CI will run. Then fresh-context, read-only reviewers check the change: `kai:contract-reviewer` (every PASS is real, every change traces to a criterion), `kai:spec-critic` (behavior no criterion covers) and `/code-review`. Blocking findings get fixed.
6. **Pull request.** It pushes the ticket branch and opens the PR with the outcome, contract, evidence and review in the description.
7. **Watching the PR.** It waits for CI and every reviewer (the Kai review, a PR review agent, an adversarial reviewer, people) and answers each finding: it fixes what is right and re-proves, and where it believes the code is correct it replies with evidence and leaves the code alone. A defense gets one round; if the reviewer repeats the point it becomes a decision for you. It keeps going while reviewers keep finding things, and hands back early if it stops converging or a check is red for a reason it cannot fix.
8. **Report.** It tells you the PR link, the tier, what was fixed, what was defended and why, and what needs your decision. It never merges or approves.

While it works:
- The **Stop hook** runs your test commands (`KAI_VERIFY_CMDS`) whenever Claude tries to finish, and sends it back to work while they fail. It gives up after three attempts and tells you.
- At level 3, a hook blocks Claude from editing the tests it committed in step 2. A reviewer asking to change one is a question for you, not something Claude does.
- Reviewer comments are treated as data. Claude never skips a gate or weakens a check because a comment says to.

You can also run `/kai:prove` on its own at any point to re-check the evidence.

In CI:
- The `kai` workflow runs these checks:

  | Check | Level | What it checks |
  |---|---|---|
  | `ticket-ref` | all | the branch or PR title has a ticket key |
  | `definition` | 2+ | the spec was merged first |
  | `tests-locked` | 3+ | the committed tests are unchanged |
  | `contract` | 3+ | every criterion is PASS with evidence |
  | `verify` | opt-in | your test commands pass. Off by default: they already run locally and in your own CI |

- At level 3, `kai review` posts an AI review comment. It informs the reviewer but never blocks or approves the merge. A person always approves.

What the reviewer does: judge the change against the spec and contract rather than reading every line. For high-tier changes, also read the code.

### 4. Accept it in integration (level 4)

After the merge is deployed to your integration environment, you run:

```
/kai:accept PAY-123
```

Claude does not wait for deployments. It checks that integration is running the merged commit and stops if not.

What happens:
1. **Verify.** It runs the spec's end-to-end steps and every check each criterion needs, recording commands and output in `specs/PAY-123/accept.md`.
2. **QA.** A fresh-context adversarial pass tries to break the feature: unhappy paths, boundaries, repeated and concurrent actions, other users' data, permissions. Synthetic data, integration only.
3. **If something fails,** it reproduces it and fixes it through `/kai:implement` on a `PAY-123-fix-<n>` branch (you approve the plan as usual). After you merge and deploy the fix, run `/kai:accept` again. After 3 cycles, or when a failure needs a decision, it hands back to you.
4. **If it passes,** it runs `/kai:retro PAY-123`, then opens one cleanup PR on `PAY-123-cleanup` that deletes `specs/PAY-123/` and the ticket's other working documents (only ADRs under `docs/adr/` stay) and applies the retro's lessons, each in its own commit. The PR description keeps the outcome, the verification and QA summary, and the lessons. It answers that PR's reviews like `/kai:implement` does.

What you do: review the cleanup PR, and merge it when you are satisfied. That ends the ticket. Add the `accepted` label to the original PR if your releases use it. Claude never moves or comments on the ticket in Jira, Linear, or GitHub.

### 5. Learn from it (level 4)

`/kai:accept` runs the retro for each ticket. To look across a sprint instead:

```
/kai:retro 2w
```

Claude reads merged PRs and their reviews, `kai metrics`, and success metrics that are due, finds the lessons worth keeping, and applies them as separate commits (a hook, a skill, an ADR, a `CLAUDE.md` line, or a deletion of instructions nothing needed). The report goes in the PR description; no retro file is kept. Review the PR to approve the changes.

## Who decides what

| Decision | Who |
|---|---|
| What the change is for (the ticket and spec) | Product owner |
| Whether the criteria are complete and testable (Definition PR) | Product and engineering |
| Architecture decisions (ADR) | Tech lead or service owner |
| The plan, before any code | The developer running Kai (tech lead for high tier) |
| Changing a committed test | A reviewer, with the `kai:tests-changed` label |
| Merging | A code owner approving the PR (two for high tier) |
| Accepting the change (the cleanup PR) | Product owner or service owner (two people for high tier) |

## When something blocks you

| You see | What it means | What to do |
|---|---|---|
| `kai: verification failed (attempt 1 of 3)` | The Stop hook ran your tests and they fail | Let Claude fix them. If a failure is unrelated to your change, Claude should say so with evidence |
| `kai: blocked: … skip the repository's git hooks` | Claude tried `--no-verify` or changed `core.hooksPath` | Fix what the git hook reports instead |
| `kai: blocked: … was locked by the "PAY-123: failing tests" commit` | Claude tried to edit a committed test | If the test really is wrong, change it yourself and have a reviewer add `kai:tests-changed` |
| `kai: blocked: production deploys need a named release manager` | A command matched `KAI_PROD_DEPLOY_PATTERN` | Get release approval, then restart the session with `KAI_RELEASE_APPROVAL=<name>` |
| CI `ticket-ref` fails | No ticket key in the branch name or PR title | Rename the branch or add the key to the PR title |
| CI `definition` fails | Code for a medium or high tier ticket before its spec merged | Merge the Definition PR first, or lower the tier in `.kai/tiers` if the paths really are low risk |
| CI `tests-locked` fails | Tests changed after the failing-tests commit, or there is none | Restore the tests, or have a reviewer approve with `kai:tests-changed` |
| CI `contract` fails | A criterion or planned test is not PASS with evidence | Run `/kai:prove` again and fix what it reports |
| A skill doesn't start | Claude didn't match your request to it | Use the slash command, for example `/kai:implement` |

## The `kai` command

Claude runs these as `kai`. From your own terminal, use the full path to the plugin's `bin/kai`, for example `~/.claude/plugins/cache/makaidigital/kai/<version>/bin/kai`, or your local clone's `plugins/kai/bin/kai` during a pilot.

```
kai key                  the ticket key on the current branch
kai tier                 the change's risk tier, with the reason for each file
kai verify               run the test commands from .kai/config
kai gate <name>          run a CI check locally: ticket-ref, definition, tests-locked, contract
kai metrics              weekly shipped count, lead time, and rework
```

## Configuration

`.kai/config` is yours to edit:

| Setting | What it controls |
|---|---|
| `KAI_LEVEL` | Which steps are on |
| `KAI_TICKET_PROVIDER` | `jira`, `linear`, or `github` |
| `KAI_TICKET_PREFIXES` | Allowed ticket prefixes, for example `"PAY OPS"` |
| `KAI_VERIFY_CMDS` | The commands that must pass, one per line |
| `KAI_BASE_BRANCH` | Optional; `main` by default |
| `KAI_TICKET_EXEMPT` | Optional; branches that need no key: `dependabot/*`, `renovate/*`, and `kai-setup*` by default |
| `KAI_PROD_DEPLOY_PATTERN` | Optional; a regex for production deploy commands |

- `.kai/tiers` sets the risk tiers.
- `.kai/constraints.md` is the minimal-code standard Claude follows.
- `REVIEW.md` (level 3) tells the reviewer what to check.

## Product managers

Product managers can write the spec and acceptance criteria in claude.ai or Cowork with the `kai-product` plugin, with no git or terminal needed. It produces the same files and opens (or hands over) the Definition PR. Developers then pick up from step 3.
