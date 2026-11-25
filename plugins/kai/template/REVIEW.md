# Review guidelines

Read by the `contract-reviewer` agent locally (`/kai:implement`) and in CI, and by Claude Code Review when the repository uses it. CI reads this file, `CLAUDE.md` and the review agents from the base branch, so a PR's changes to them apply from the next PR (Claude Code Review does so only when the default branch is protected). Owned by the tech lead. Keep it short, and tune it when reviews get noisy or miss things: when the same comment keeps coming back, add it here or fix it at the source (a lint rule, a skill, or a `CLAUDE.md` line).

## What failure looks like here

<Name the failures that matter most in this repository, a few words each. For example: "it charges twice" for payments, "it lies" for docs, "it misroutes" for configuration, "it shows another user's data" for an API.>

## Checks

Each row is a mistake this repository has made, or one its owners expect. The reviewer runs a row only when the diff matches its trigger, and says which rows it ran, so nobody has to remember past failures. The people who own the code write their rows and change them until the reviewer flags what they would flag. `/kai:retro` adds a row when a review misses something a diff could show, and removes a row that no longer finds anything.

| Check | When the diff… | Ask | From |
|---|---|---|---|
| <old-records-load> | <changes a stored record or a message type> | <Does a record written before this change still load?> | <the incident or PR behind it> |

## What to review

1. Evidence: every PASS in the contract matches a passing test in `kai verify` output.
2. Scope: every changed file, function, and dependency traces to a criterion or planned task.
3. Decisions: ADRs and existing patterns are followed; existing helpers are reused.
4. Correctness: logic errors, unhandled error paths the criteria name, empty or null input, off-by-one errors, races.
5. Security: injection (SQL, command, template), cross-site scripting, broken authentication or authorization, secrets in code, server-side request forgery, path traversal, insecure deserialization, sensitive data in logs.
6. Performance: N+1 queries, unbounded queries or loops, missing indexes on new queries, resource leaks, quadratic work on hot paths.
7. Observed: the evidence shows the change running end to end, not only its tests passing.

For a ticket's change, also follow `.claude/agents/contract-reviewer.md` for the kind of PR it is and the contract, and `.claude/agents/spec-critic.md` when `docs/specs/<KEY>/spec.md` exists. Report the spec-critic's gaps as questions for product and engineering, not as code fixes.

## Severities

- **Important**: the contract is not actually met, the change is wrong, or it adds unplanned scope. It blocks the review's verdict.
- **Nit**: worth knowing; the author decides. At most three in one review.
- **Pre-existing**: a problem the change did not introduce, in code the diff does not touch or with the same behavior on the base branch. Never blocks; listed as a follow-up.

## Evidence

Every finding names a file and line, and says what goes wrong and when.

## Report

Start with a count, for example `1 Important, 2 Nit, 0 Pre-existing`. When there is nothing to fix, say `Nothing to fix.` and stop.

## Skip

- Formatting and naming (linters own these).
- Generated files and lockfiles.
- <Paths this repository never needs reviewed, such as vendored code.>
