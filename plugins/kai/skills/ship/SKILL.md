---
name: ship
description: Ship a proven Kai change (in a repository with a .kai/config) as a pull request. It runs the same gates CI will run, gets an independent read-only review of the contract and the criteria, then pushes the branch and opens the PR with the contract as its description. Use it when someone says ship it, open the PR, raise a pull request, or send it for review after /kai:prove passed. Run /kai:prove first if there is no passing evidence.
argument-hint: [TICKET-KEY]
---

# Ship

Open the pull request for a proven change, so the human approver sees the intent, the contract, and the evidence in one place and can judge the change against them instead of reading every line.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly.

## 1. Check what CI will check

- Get the key from `$ARGUMENTS` or `kai key`. There must be a passing `specs/<KEY>/evidence.md` from `/kai:prove`. If there is not, run `/kai:prove` first.
- Run the gates locally: `kai gate ticket-ref`, `kai gate definition`, `kai gate tests-locked`, and `kai gate contract`. Each one prints why it fails. Fix the cause, which usually means going back to `/kai:prove` or `/kai:build`, rather than working around a gate: CI runs the same checks and will fail the same way.

## 2. Get an independent review

The agent that wrote the code should not be the one that grades it. Dispatch these read-only agents in parallel, in fresh contexts:

- `kai:contract-reviewer`: evidence, scope, and decisions.
- `kai:spec-critic`: behavior no criterion covers. Only when `specs/<KEY>/spec.md` exists.
- The built-in `/code-review` skill, for a general bug pass, if it is available.

Handle what comes back:
- A contract-reviewer finding marked blocking is a bug to fix before shipping. Fix it, then re-run `/kai:prove`.
- A spec-critic gap is a question for product and engineering, not something to code now. List it in the PR under "Open questions for reviewers".
- A note is the author's call. Mention the ones you leave as they are.

## 3. Open the pull request

- Push the branch (`git push -u origin <branch>`). Pushes go to the ticket branch, never to the base branch.
- Open the PR with `gh pr create`, titled `<KEY>: <short summary>`, with this body:

```markdown
## Intent
<one-paragraph summary> ([intent](specs/<KEY>/intent.md))

## Contract
<the spec's Contract table, or the plan's Tests table when there is no spec, with the evidence column filled>

## Evidence
[evidence.md](specs/<KEY>/evidence.md). `kai verify` result: PASS

## Review
- contract-reviewer: <verdict and blocking findings fixed>
- spec-critic: <number of gaps>

## Open questions for reviewers
<spec-critic gaps and notes left as they are, or "None">
```

- Tell the person the PR link, the tier (`kai tier`), and what the reviewer should focus on. A person approves the merge. The review here and in CI informs that decision but does not replace it.
