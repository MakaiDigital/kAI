# Using Kai

This guide walks a developer through one change, from ticket to release. Kai does the drafting, planning, testing, and checking; you decide what gets built and confirm it works.

Kai is already set up in your repository if it has a `.kai/config`. If not, install the plugin (`claude plugin marketplace add MakaiDigital/kAI`, then `claude plugin install kai@makaidigital`) and run `/kai:setup`. To trial it first, see [pilot.md](pilot.md).

## Before you start

- **Install the plugins.** Open the repository in Claude Code. The first time, accept the prompts to trust the folder and install `kai@makaidigital`, which also installs Superpowers and feature-dev. Run `/plugin` to confirm all three are enabled.
- **Know your level.** Run `grep KAI_LEVEL .kai/config`. The level decides which steps below apply:

| Level | Adds |
|---|---|
| 1 | Build, prove, guardrail hooks |
| 2 | Specs, risk tiers, the two-PR flow |
| 3 | Locked tests, contract check, `/kai:ship`, AI review in CI |
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
- It decides whether the change needs a spec and says why in one line. A bug with a clear reproduction, a typo, docs, and other low-tier changes skip it and go straight to `/kai:build`, with the ticket as the intent. You can overrule it either way.
- Below level 2 there are no specs: go straight to `/kai:build`.

Claude works on a branch named after the ticket (`PAY-123-short-description`), creating or suggesting one. Branch names must contain the key, because CI checks for it.

### 2. Review the spec (level 2, medium and high tier)

If the ticket needs a spec, Claude writes `specs/PAY-123/spec.md`:
- A **Review here** list at the top: the assumptions, chosen numbers, added criteria, and security or data implications a person must judge. Each is marked `⚠ review` where it appears below.
- A short **Context** (problem, outcome, success metric, constraints, out of scope) taken from the ticket, so CI reviewers and `/kai:accept` have the goal without ticket access.
- Criteria numbered C1, C2, … in a fixed form: "When …, the system shall …" or "If …, then the system shall …", including the unhappy paths (signed out, network down, invalid input).
- An end-to-end check you could run by hand, and a contract table mapping each criterion to a test, every row starting as FAIL.
- YAML frontmatter (key, ticket, tier, status, ADR) that agents and gates read.

If the change needs a new service, dependency, data store, external integration, or trust boundary, Claude also drafts `docs/adr/NNNN-title.md` with two or three options for the tech lead to decide. You do not run `/kai:adr` for this.

What you do:
1. Read the **Review here** list first, then check the criteria with product. Each must be testable, and together they must cover the ticket.
2. Merge the spec (and ADR) on their own, as a **Definition PR**: branch `PAY-123-definition`, title `PAY-123: definition`. Claude prepares it for you.
3. Wait for the merge before writing code. CI's `definition` check fails code for a medium- or high-tier ticket until its spec is on the main branch. If Claude skipped the spec and the tier turns out higher, write it then.

### 3. Plan, test first, implement (all levels)

Start a fresh branch for the code, then:

```
/kai:build
```

This runs in three stops:
1. **Plan.** Claude explores the code and presents a plan: files to change, tasks, tests named by behavior (for example `rejects_expired_token`) and mapped to the criteria, and risks. Then it stops and waits for you.
   - **You approve or push back.** Push back if the plan adds files or dependencies you didn't expect, has tests that don't map to a criterion, or has criteria with no test. A wrong plan costs minutes to fix; wrong code costs hours.
2. **Failing tests.** Claude writes the planned tests, confirms they fail for the right reason, and commits them on their own as `PAY-123: failing tests`.
3. **Implementation.** Claude writes the smallest change that makes the tests pass, following `.kai/constraints.md`.

While it works:
- The **Stop hook** runs your test commands (`KAI_VERIFY_CMDS`) whenever Claude tries to finish, and sends it back to work while they fail. It gives up after three attempts and tells you.
- At level 3, a hook blocks Claude from editing the tests it committed in step 2.

### 4. Prove it works (all levels)

```
/kai:prove
```

What happens:
- Claude runs `kai verify --evidence specs/PAY-123/evidence.md` and adds a table matching every planned test to the output line that shows it passing.
- A planned test that never ran is marked **MISSING**, which counts as a failure.
- If there is a spec, Claude updates its contract table. It then commits `PAY-123: evidence`.

What you do: read the result. "Done" means this evidence file, not Claude saying the tests pass.

### 5. Open the pull request

**Level 3 and up:**

```
/kai:ship
```

What happens:
- Claude runs the same checks CI will run.
- It gets an independent, read-only review. `kai:contract-reviewer` confirms every PASS is real and every change traces to a criterion, and `kai:spec-critic` looks for behavior no criterion covers.
- It fixes anything blocking, then pushes and opens the PR. The PR description contains the outcome, contract, evidence, and review.

**Levels 1–2:** push the branch and open the PR yourself, linking the ticket, spec, plan, and evidence.

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

### 6. Accept it in integration (level 4)

After the merge is deployed to your integration environment:

```
/kai:accept PAY-123
```

What happens: Claude runs the spec's end-to-end steps against integration and records every command and its output in `specs/PAY-123/accept.md`. It never marks the change accepted.

What you do:
1. The product owner (or service owner, for APIs and infrastructure) tries the feature against the **ticket's outcome**.
2. They fill in the verdict and their name in `accept.md`.
3. They add the `accepted` label to the merged PR. Releases take only accepted changes.

### 7. Learn from it (level 4)

Once a sprint:

```
/kai:retro
```

What happens:
- Claude reads the period's review findings, acceptance results, and `kai metrics`, plus any success metrics due for a check.
- It proposes where each recurring lesson should live: a hook, a skill, an ADR, or `CLAUDE.md`. It also proposes instructions to delete.
- It writes `docs/retros/<date>.md`.

What you do: the team approves which changes to apply.

## Who decides what

| Decision | Who |
|---|---|
| What the change is for (the ticket and spec) | Product owner |
| Whether the criteria are complete and testable (Definition PR) | Product and engineering |
| Architecture decisions (ADR) | Tech lead or service owner |
| The plan, before any code | The developer running Kai (tech lead for high tier) |
| Changing a committed test | A reviewer, with the `kai:tests-changed` label |
| Merging | A code owner approving the PR (two for high tier) |
| Acceptance | Product owner or service owner (two people for high tier) |

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
| A skill doesn't start | Claude didn't match your request to it | Use the slash command, for example `/kai:build` |

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
