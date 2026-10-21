# Using Kai

This guide walks a developer through one change, from ticket to done. Kai does the drafting, planning, testing, and checking; you decide what gets built and confirm it works.

Kai is already set up in your repository if it has a `.kai/config`. If not, install the plugin (`claude plugin marketplace add MakaiDigital/kAI`, then `claude plugin install kai@makaidigital`) and run `/kai:setup`. To trial it first, see [pilot.md](pilot.md).

## Before you start

- **Install the plugins.** Open the repository in Claude Code. The first time, accept the prompts to trust the folder and install `kai@makaidigital`, which also installs Superpowers, feature-dev, and `mattpocock-skills` (the `grilling` skill behind Matt Pocock's grill-me). Run `/plugin` to confirm all four are enabled.
- **Know your level.** Run `grep KAI_LEVEL .kai/config`. The level decides which steps below apply:

| Level | Adds |
|---|---|
| 1 | Implement, prove, guardrail hooks |
| 2 | Specs, risk tiers, the two-PR flow |
| 3 | Locked tests, contract check, local gates, AI review in CI |
| 4 | Verify, QA and cleanup in integration (`/kai:accept`), retros, metrics |

- **Know your risk tiers.** `.kai/tiers` maps paths to `low`, `medium`, or `high`. Files it doesn't list count as medium. A change takes the highest tier of any file it touches, and `kai tier` prints it with the reason for each file.

Type the commands below to use the workflow. Claude doesn't start it on its own: a request in plain words is handled directly, and if you ask for workflow work in words, Claude names the command. CI's gates still check every pull request, however it was made; to make the workflow optional for a team, use level 1 or `KAI_ENFORCE=report`.

## The workflow

You ask Claude for four things, and each ends in a pull request you review:

| Step | Command | You review |
|---|---|---|
| 1. Define | `/kai:spec PAY-123` | The Definition PR: the spec's **Review here** list, the plan, and any ADR (or Claude's one-line reason for skipping) |
| 2. Implement | `/kai:implement` | The finished PR (and a plan first, only when no Definition PR merged one) |
| 3. Merge and deploy | (your process) | The PR, as a code owner |
| 4. Accept | `/kai:accept PAY-123` | The cleanup PR; merging it ends the ticket |


### 1. Start from the ticket (all levels)

Every change starts from a ticket, such as `PAY-123` in Jira or Linear or `#42` on GitHub. Point Kai at it:

```
/kai:spec PAY-123
```

What happens:
- Claude reads the ticket (through the Jira, Linear, or GitHub connector, or you paste it).
- It decides whether the change needs a spec and says why in one line. Only a change that touches nothing but low-tier files (by default anything under `docs/` and any Markdown file), such as a typo or a docs fix, skips it and goes straight to `/kai:implement`, with the ticket as the intent. A bug in code is medium tier by default, so from level 2 it gets a short spec: one or two criteria taken from the reproduction. You can overrule it either way.
- Below level 2 there are no specs: go straight to `/kai:implement`.

Claude works on a branch named after the ticket (`PAY-123-short-description`), creating or suggesting one. Branch names must contain the key, because CI checks for it.

### 2. Define it: spec, plan, and review (level 2, medium and high tier)

If the ticket needs a spec, Claude settles everything the build needs before any code, so that `/kai:implement` never has to come back and change it:

1. **Explore.** `feature-dev:code-explorer` agents map how the code the ticket touches works today, its tests, and anything in it that conflicts with the ticket. Criteria about existing behavior rest on what they find, not on guesses.
2. **Draft the spec.** Claude writes `docs/specs/PAY-123/spec.md` (described below), and marks every assumption with `⚠`.
3. **Grill you.** Claude interviews you with the `grilling` skill from Matt Pocock's grill-me, a round at a time: each round asks every question it can ask yet, numbered, with Claude's recommended answer, so "yes" accepts it. It looks up facts itself and asks you only for decisions. Each answer goes into the spec, and is recorded under **Review here** with who decided. It ends when nothing is left assumed and you agree on the result.
4. **Decide any ADR.** If the change needs a new service, dependency, data store, external integration, or trust boundary, `feature-dev:code-architect` agents propose two or three options, and Claude drafts `docs/adr/NNNN-title.md` comparing them. You choose (you can choose for the tech lead); you do not run `/kai:adr` for this.
5. **Write the plan.** `docs/specs/PAY-123/plan.md`: a diagram of what changes, the files to change, tasks, tests named by behavior (for example `rejects_expired_token`) and mapped to the criteria, and risks. Anything planning shows to be wrong in the spec is fixed now.
6. **Review all of it.** Three read-only `kai:definition-reviewer` agents check the spec, plan and ADR, each with a stance: **friendly** (what must be kept, and what is harder to build than it needs to be), **skeptical** (why the build would have to change the spec), and **neutral** (every item, evenly). Claude weighs the three against the code, fixes what is wrong, asks you about anything that needs a decision, and rejects the rest with a reason. It repeats the review on the changed documents, for up to three rounds, until a round finds nothing new that matters.
7. **Open the Definition PR.** Only then does Claude push branch `PAY-123-definition` and open `PAY-123: definition`, with the **Review here** decisions, a summary of the plan, and what the review changed.

The spec contains:
- A **Review here** list at the top: the assumptions, chosen numbers, added criteria, security or data implications, answers to open questions, and ADR choices the spec rests on, each with who decided. You can answer for someone else, such as the product owner, and the spec records who decided and for whom.
- A short **Context** (problem, outcome, success metric, constraints, out of scope) taken from the ticket, so CI reviewers and `/kai:accept` have the goal while the ticket is open without ticket access.
- An **Overview** diagram of the behavior, with criterion IDs on the steps they govern, when there is a flow to draw. It is Mermaid, which GitHub draws in the PR, and it shows only what the criteria say.
- Criteria numbered C1, C2, … in a fixed form: "When …, the system shall …" or "If …, then the system shall …", including the unhappy paths (signed out, network down, invalid input). Each can be proved before merge, by a test, a local end-to-end run, or CI output.
- An end-to-end check you could run by hand, which `/kai:accept` runs after merge. Checks only the deployed system can show, such as real traffic, go here rather than in a criterion.
- A contract table mapping each criterion to a test, every row starting as FAIL.
- YAML frontmatter (key, ticket, tier, status, ADR) that reviewers read.

What you do:
1. Answer the grilling, then read the Definition PR: the **Review here** decisions first, then the criteria with product, then the plan with engineering. Each criterion must be testable, together they must cover the ticket, and the plan must be how you want it built. No question is left open: the `definition` check fails a spec that still holds a `⚠` marker.
2. Comment on the PR to ask for changes. Claude answers the automated reviews while the session lasts; for comments people leave later, run `/kai:spec PAY-123` again on the branch.
3. Merge it on its own. That merge approves the spec and the plan together, before any code. CI's `definition` check fails code for a medium- or high-tier ticket until its spec and plan are on the main branch. If Claude skipped the spec and the tier turns out higher, write it then.

### 3. Implement (all levels)

Claude starts the code on a fresh branch from the up-to-date base branch, or picks up the ticket's open PR or unmerged branch. It builds from the plan the Definition PR merged. A fix or follow-up branch gets its own plan, even though it inherits the earlier change's. Run:

```
/kai:implement
```

Claude takes the ticket to a reviewed, green pull request:
1. **Plan.** With a plan the Definition PR merged, there is nothing to approve: Claude checks that the code it names is still there and starts on the tests. Without one (at level 1, for a low-tier change, for a fix, or after a spec merged without a plan), Claude explores the code, presents a plan, and stops for you.
   - **You approve or push back.** Push back if the plan adds files or dependencies you didn't expect, has tests that don't map to a criterion, or has criteria with no test. A wrong plan costs minutes to fix; wrong code costs hours.
   - **Approve with "Yes, and use auto mode",** so Claude commits, pushes the ticket branch, and opens the PR without asking. Kai's settings still ask before a push to the base branch and deny merging.
   - **If the code departs from the plan,** Claude updates `plan.md` and names the departure in the PR. It stops and asks you first when the departure changes the approach, adds a file or dependency the plan doesn't list, or needs a criterion to change.

Then it keeps going without asking:
2. **Failing tests.** Claude writes the planned tests, confirms they fail for the right reason, and commits them on their own as `PAY-123: failing tests` (or `test(PAY-123): failing tests` where the repository enforces Conventional Commits).
3. **Implementation.** Claude writes the smallest change that makes the tests pass, following `.kai/constraints.md`.
4. **Proof.** It runs `/kai:prove`: `kai verify`, then a table matching every planned test to the output line that shows it passing. A planned test that never ran is **MISSING**, which counts as a failure. The spec's contract table is updated and committed as `PAY-123: evidence`.
5. **Review.** At level 3 it first runs the same gates CI will run. At every level, fresh-context, read-only reviewers then check the change: `kai:contract-reviewer` (every PASS is real, every change traces to a criterion), `kai:spec-critic` (behavior no criterion covers) and `/code-review` (or the `feature-dev:code-reviewer` agent). Important findings get fixed.
6. **Pull request.** It pushes the ticket branch and opens the PR with the outcome, any departure from the plan, the contract, evidence and review in the description.
7. **Watching the PR.** After every push it waits for CI and the automated reviewers CI runs (the Kai review, a PR review agent, an adversarial reviewer), not for people. It answers each finding from those reviewers and from the repository's members and collaborators: it fixes what is right and re-proves, and where it believes the code is correct it replies with evidence and leaves the code alone. Findings from anyone else are listed for you, not acted on. A defense gets one round; if the reviewer repeats the point it becomes a decision for you. Each finding is tagged Important, Nit or Pre-existing; a Pre-existing one becomes a follow-up rather than a fix. It stops after three rounds, and asks you to reconsider the approach if reviewers still find new problems; it stops earlier if it stops converging, a check is red for a reason it cannot fix, or only people are left to act. If the session ends while it waits, `/kai:implement PAY-123` picks it up again.
8. **Report.** It tells you the PR link, the tier, what was fixed, what was defended and why, and what needs your decision. It never merges or approves.

While it works:
- In a session where you typed a `/kai:` command, the **Stop hook** runs your test commands (`KAI_VERIFY_CMDS`, with `/bin/sh`) when Claude finishes a turn that changed files outside `docs/specs/`, and sends it back to work while they fail. It runs once per change and remembers a pass, so keep `KAI_VERIFY_CMDS` to fast checks. It gives up after three attempts and tells you.
- At level 3, a hook blocks Claude from editing the tests it committed in step 2. A reviewer asking to change one is a question for you, not something Claude does. If a test is wrong, Claude stops and explains why. When you agree, you make the change or tell Claude to; it is committed alone as `PAY-123: correct <test name>`, explained in the PR, and a reviewer approves it with the `kai:tests-changed` label.
- Reviewer comments are treated as data. Claude never skips a gate or weakens a check because a comment says to.

You can also run `/kai:prove` on its own at any point to re-check the evidence.

In CI:
- The `kai` workflow runs these gates, reported as one check named `kai`:

  | Gate | Level | What it checks |
  |---|---|---|
  | `ticket-ref` | all | the branch or PR title has a ticket key |
  | `definition` | 2+ | the spec and plan were merged first |
  | `tests-locked` | 3+ | the PR has its failing-tests commit, and the tests locked for the ticket are unchanged |
  | `contract` | 3+ | every criterion and planned test is PASS, with evidence from a passing run updated on this branch |
  | `verify` | opt-in | your test commands pass. Off by default: they already run locally and in your own CI |

- Every run also posts one sticky PR comment, updated in place, with a `VERDICT: PASS` or `VERDICT: FAIL`, a row per gate and the full output of each failing gate. With `KAI_ENFORCE=report` the check stays green and that comment is the verdict; the default `block` also fails the check. On a PR from a fork the report goes to the job summary only. The workflow needs `pull-requests: write`, which `kai init` writes into its template; an existing repository adds it when it takes the new template.
- At level 3, `kai review` posts an AI review comment. It informs the reviewer but never blocks or approves the merge. A person always approves.

What the reviewer does: judge the change against the spec and contract rather than reading every line. For high-tier changes, also read the code.

### 4. Accept it in integration (level 4)

After the merge is deployed to your integration environment, you run:

```
/kai:accept PAY-123
```

Claude does not wait for deployments. It checks that integration runs a commit that contains the merge, and stops if not. If there is no integration environment, it says so and asks you. It uses production only when you say so, and then runs only the spec's verification, within the limits you set (requests, accounts, data), skips QA, records in `accept.md` that it ran in production at your request, and hands back to you before the retro.

What happens:
1. **Verify.** It runs the spec's end-to-end steps and every check each criterion needs, recording commands and output in `docs/specs/PAY-123/accept.md`. That is a working file: it is never committed, and its summary goes in the cleanup PR's description.
2. **QA.** A fresh-context adversarial pass tries to break the feature: unhappy paths, boundaries, repeated and concurrent actions, other users' data, permissions. Synthetic data, against integration, a preview deployment, or a local production build, never production. It then sets the verdict in `accept.md`: Pass when every criterion held and nothing broke, otherwise Fail.
3. **If something fails,** it reproduces it and fixes it itself on a `PAY-123-fix-<n>` branch, following the same steps as `/kai:implement` with the reproduction as the ticket text: you approve the fix's plan as usual, and it opens the fix PR and answers its reviews. After you merge and deploy the fix, tell Claude, and it re-runs what failed plus the full verification (if the session ended, run `/kai:accept PAY-123` again). After 3 cycles, or when a failure needs a decision, it hands back to you.
4. **If it passes,** it starts a `PAY-123-cleanup` branch from the up-to-date base branch, runs `/kai:retro PAY-123` there, and opens one cleanup PR that deletes `docs/specs/PAY-123/` (ADRs under `docs/adr/` stay) and applies the retro's instruction changes, each in its own commit. The PR changes only Markdown, so it is low tier and passes every gate; if your `.kai/tiers` ranks `CLAUDE.md` or `.claude/` higher, the retro's changes to them go in their own `kai-retro-<date>` PR. A lesson that needs a hook, script, setting, or workflow is listed for you to ticket instead. The PR description keeps the outcome, the verification and QA summary, and the lessons. It answers that PR's reviews like `/kai:implement` does.

What you do: approve the plan of any fix and merge its PR, then review the cleanup PR and merge it when you are satisfied. That merge is your sign-off: it ends the ticket, and releases read acceptance from it. Claude never moves or comments on the ticket in Jira, Linear, or GitHub.

### 5. Learn from it (level 4)

`/kai:accept` runs the retro for each ticket. To look across a sprint instead:

```
/kai:retro 2w
```

Claude works on a `kai-retro-<date>` branch, which needs no ticket key. It reads merged PRs and their reviews, `kai metrics`, and success metrics that are due, finds the lessons worth keeping, and applies the instruction changes as separate commits (a skill, an ADR, a `CLAUDE.md` line, or a deletion of instructions nothing needed). It keeps rules that prevent harm even when nothing triggered them. A lesson that needs a hook, script, setting, or workflow becomes a ticket for `/kai:implement`. The report goes in the PR description; no retro file is kept. Review the PR to approve the changes.

## Who decides what

| Decision | Who |
|---|---|
| What the change is for (the ticket and spec) | Product owner |
| Whether the criteria are complete and testable (Definition PR) | Product and engineering |
| Architecture decisions (ADR) | Tech lead or service owner |
| The plan, before any code | Engineering, in the Definition PR (or the developer running Kai, in the session, when none was merged; tech lead for high tier) |
| Changing a committed test | A reviewer, with the `kai:tests-changed` label |
| Merging | A code owner approving the PR (two for high tier) |
| Accepting the change (the cleanup PR) | Product owner or service owner (two people for high tier) |

## When something blocks you

| You see | What it means | What to do |
|---|---|---|
| `kai: verification failed (attempt 1 of 3)` | The Stop hook ran your tests and they fail | Let Claude fix them. If a failure is unrelated to your change, Claude should say so with evidence |
| `kai: blocked: … skip the repository's git hooks` | Claude tried `--no-verify`, `git commit -n`, a switch such as `HUSKY=0` or `LEFTHOOK=0`, pre-commit's `SKIP=` on a git command, or changed `core.hooksPath` | Fix what the git hook reports instead |
| `kai: blocked: … was locked by the "PAY-123: failing tests" commit` | Claude tried to edit a locked test | If the test really is wrong, you make the change or tell Claude to, commit it alone as `PAY-123: correct <test name>`, and have a reviewer add `kai:tests-changed` |
| `kai: blocked: production deploys need a named release manager` | A command matched `KAI_PROD_DEPLOY_PATTERN` | Get release approval, then restart the session with `KAI_RELEASE_APPROVAL=<name>` |
| `kai: blocked: KAI_PROD_DEPLOY_PATTERN in .kai/config is not a valid regular expression` | The pattern doesn't parse, so every Bash command is blocked | Fix the pattern |
| Claude Code asks you to allow a `git push` to the base branch | Kai's settings ask before a `git push` that names the base branch (a bare `git push` doesn't name it, so only GitHub's branch protection stops that one) | Decline it: changes reach the base branch through a pull request |
| `kai: .kai/config is not valid sh`, or `KAI_LEVEL in .kai/config must be 1, 2, 3 or 4` | `.kai/config` has a shell syntax error (the message above it names the line) or a bad level. Until it's fixed, Bash commands are blocked and the other guards are off | Fix the line, then retry |
| `kai: commit your changes first: evidence must describe a commit` | `/kai:prove` ran `kai verify --evidence` with uncommitted changes outside `docs/specs/` | Commit the work first. A file your test commands create belongs in `.gitignore`, in a commit of its own |
| `kai: cannot diff against origin/main; in CI, check out with fetch-depth: 0` | The base branch's history isn't there, as in a shallow CI checkout | In CI, set `fetch-depth: 0` on `actions/checkout`; locally, run `git fetch origin` |
| `kai: tests-locked: needs git 2.36 or newer` | Your git can't show what a merge commit changed, which the gate checks | Upgrade git |
| CI `ticket-ref` fails | No ticket key in the branch name or PR title | Rename the branch or add the key to the PR title |
| CI `definition` fails | Code for a medium or high tier ticket before its spec merged | Merge the Definition PR first. If the paths really are low risk, change `.kai/tiers` in its own PR first, from a `kai-setup` branch as `/kai:setup` does: CI judges a PR by the base branch's `.kai/config` and `.kai/tiers` |
| CI `tests-locked` fails | A test locked for the ticket changed, also in a merge commit, or this PR has no failing-tests commit of its own that commits tests | Restore the tests, or have a reviewer approve with `kai:tests-changed`. A follow-up or fix PR commits its own failing tests |
| CI `contract` fails | A criterion (from the base branch's spec or this branch's) or a planned test is not PASS with its output line | Run `/kai:prove` again and fix what it reports |
| CI `contract`: `evidence.md does not record a passing kai verify run` | The last `kai verify` run in the evidence failed | Fix the failures, then run `/kai:prove` again |
| CI `contract`: `evidence.md has no planned tests table`, or `tests in plan.md missing from evidence.md` | The evidence doesn't map every test in the plan to its result | Run `/kai:prove` again |
| CI `contract`: `evidence.md was not updated on this branch` | The evidence is from an earlier PR (for example the original change on a fix branch), or no `kai verify` run on this branch wrote it | Run `/kai:prove` on this branch |
| The workflow doesn't start | It runs only from its commands | Type the command, for example `/kai:implement PAY-123` |
| Every session starts in plan mode | Kai before 0.10.0 set `permissions.defaultMode` to `plan` in `.claude/settings.json` | Run `/kai:setup` to upgrade, and accept its offer to remove it |

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
| `KAI_VERIFY_CMDS` | The commands that must pass, one per line, run from the repository root with `/bin/sh` |
| `KAI_BASE_BRANCH` | Optional; `main` by default. Setup writes it when the repository's default branch isn't `main` |
| `KAI_TICKET_EXEMPT` | Optional; branches that need no key and skip every gate: `dependabot/*`, `renovate/*`, `kai-setup*`, and `kai-retro*` by default |
| `KAI_ENFORCE` | Optional; `block` by default. `block` fails the PR check when a gate fails. `report` keeps the check green and leaves the verdict to the PR comment |
| `KAI_PROD_DEPLOY_PATTERN` | Optional; a regex for production deploy commands |
| `KAI_WRITING_STE` | Optional; `100` by default. How close the specs, plans, ADRs, evidence, PR descriptions, and review findings Kai writes get to ASD-STE100, the Simplified Technical English of aerospace manuals: short sentences, active voice, one term for one thing. `0` turns the rules off; `100` applies the full standard |

- `.kai/tiers` sets the risk tiers.
- `.kai/constraints.md` is the minimal-code standard Claude follows.
- `REVIEW.md` (level 3) tells the reviewer what to check.

## Product managers

Product managers can write the spec and acceptance criteria in claude.ai or Cowork with the `kai-product` plugin, with no git or terminal needed. It produces the same `spec.md`, with the what and the why, and opens (or hands over) its own Definition PR. Once that merges, a developer runs `/kai:spec <KEY>`, which builds the how on it: it explores the code, grills them, writes the plan, and opens a second Definition PR (step 2). Code starts from step 3 once both are merged.
