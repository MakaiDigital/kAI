---
name: build
description: Implement a ticketed change in a Kai repository (one with a .kai/config) in four steps. Plan and stop for approval, commit failing tests, write the smallest code that makes them pass, then hand off to /kai:prove. Produces specs/<KEY>/plan.md, a tests-only commit, and the implementation. Use it whenever someone asks to build, implement, code, or fix a ticket or its intent, for example "build PAY-123", "implement the spec", or "let's code this", once specs/<KEY>/intent.md exists.
argument-hint: [TICKET-KEY]
---

# Build

Turn an agreed intent (and spec, if there is one) into working code in four steps: **plan, approval, failing tests, implementation**. Each step ends in its own commit. A reviewer can then check the plan, then the tests, then the code, and compare them without reading every line.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly.

## 0. Check the ground

- Get the key from `$ARGUMENTS` or `kai key`, and read `specs/<KEY>/intent.md` and `spec.md` if it exists.
- No intent? Run `/kai:intent` first. The only exception is a trivial change (typo, docs, config with no behavior change), where the ticket text is enough.
- At `KAI_LEVEL` 2 or higher, a medium or high tier change needs its intent and spec merged to the base branch before any code. The `definition` CI gate enforces this, so building without it only produces a PR that cannot merge. If they are missing, run `/kai:spec` and get the Definition PR merged first. Low tier changes (see `.kai/tiers`) go ahead with the intent alone.
- Work on a branch whose name contains the key, never a protected branch: `git switch -c <KEY>-<short-description>`.

## 1. Plan, then stop

Read and explore, but do not edit files until the person approves the plan. A wrong plan is cheap to fix, and wrong code is not.

- Explore only what the change touches and its direct callers. For anything wider, dispatch `feature-dev:code-explorer` so the main context stays focused. When there are genuine design alternatives, have `feature-dev:code-architect` compare two or three.
- Draft the plan from `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:
  - **Files touched**: real paths found by exploration. Call out every new file and new dependency; the expected number is zero.
  - **Tasks**, smallest first, each ending green.
  - **Tests** named by behavior (`rejects_expired_token`), each mapped to a spec criterion, or to an intent outcome when there is no spec. Every criterion or outcome needs a test, and every test needs a criterion or outcome. Start from the spec's Contract rows.
  - **Risks**, and how to roll back.
  - **Existing decisions** (ADRs, conventions) the plan relies on.
- The bar: someone who never saw this conversation could implement from the plan alone.
- Present the plan and wait for approval. A plan without named tests is not ready to present.

Once it is approved, save it to `specs/<KEY>/plan.md` with Status: Approved and the approver's name, and commit it alone as `<KEY>: plan`.

## 2. Failing tests first

Follow `superpowers:test-driven-development`.

- Write the planned tests and run them. Each should fail because the behavior is missing, not because of a typo or an import error; a test that fails for the wrong reason proves nothing.
- Commit them alone as `<KEY>: failing tests`.
- From here on, the tests define the feature. Do not change or delete them to get green. If one is genuinely wrong, stop and explain why to the person, because changing it changes what "done" means. At `KAI_LEVEL` 3 a hook blocks edits to these files and the `tests-locked` CI gate fails if they change, unless a reviewer approves with the `kai:tests-changed` label.

## 3. Implement the minimum

- Write only what the tests and the intent require. The minimal-code standard in `.kai/constraints.md` applies.
- With three or more independent tasks, use `superpowers:subagent-driven-development` with `specs/<KEY>/plan.md` as the plan. Otherwise work through the tasks in order.
- When something fails unexpectedly, use `superpowers:systematic-debugging` instead of guessing.
- Run `kai verify` after each task. The Stop hook runs it too and keeps you working while it fails.
- If reality departs from the plan (a new file, a different approach, a dropped task), update `plan.md` in the same commit and say so. A plan that silently disagrees with the code misleads every reviewer.

## 4. Hand off

Run `/kai:prove`. Until it has produced evidence, describe the work as implemented, not as done or passing.
