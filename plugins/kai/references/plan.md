# Plan

Turn the spec (or, when there is none, the ticket) into a plan that someone who never saw this conversation could build from alone. A wrong plan is cheap to fix, and wrong code is not. `/kai:spec` writes the plan into the Definition PR, so a merge approves it with the spec. `/kai:implement` follows this file only when no plan was merged.

- Explore only what the change touches and its direct callers. For anything wider, dispatch `feature-dev:code-explorer` so the main context stays focused. Reuse what earlier exploration found instead of exploring the same code again. When there are genuine design alternatives that no ADR settles, have `feature-dev:code-architect` compare two or three.
- Draft the plan from `templates/plan.md` in this plugin (the folder beside this `references/` folder):
  - **Files touched**: real paths found by exploration. Call out every new file and new dependency; the expected number is zero.
  - **Tasks**, smallest first, each ending green.
  - **Tests** named by behavior (`rejects_expired_token`), each mapped to a spec criterion, or to a ticket outcome when there is no spec. Every criterion or outcome needs a test, and every test needs a criterion or outcome. Start from the spec's Contract rows, and use their test names.
  - Give each test a **Kind**. An `example` test checks the cases you thought of. An `e2e` test drives a real user flow through the running application with the repository's end-to-end harness (a browser driver, an API harness, a simulator). The whole feature works or it does not, so where the repository has a harness, write each step of the spec's End-to-end verification that can run locally as an `e2e` test: `kai verify` and CI then repeat the run on every push. A `property` test states something that must hold for every input (a round trip returns the input, a balance is never negative, doing it twice equals doing it once, the fast path equals the simple one) and lets the repository's property library generate the inputs, so the edge cases do not share the author's blind spots. A `differential` test runs the old code and the new code on the same generated or sampled inputs and compares the results, for a criterion that says behavior stays the same (a refactor, a migration, a rewrite); list each approved difference in Risks. Use `property` or `differential` wherever a criterion allows it. A property library or an end-to-end harness the repository does not have is a new dependency: list it.
  - **Risks**, and how to roll back.
  - **Verification**: `kai verify`, and the end-to-end steps that will be run before the PR, taken from the spec's End-to-end verification.
  - **Existing decisions** (ADRs, conventions) the plan relies on, including the option any new ADR chose.
  - The **Summary** diagram of what changes, drawn last from Files touched and Tasks, by the template's rules.
- Check each path, function, and behavior the plan names against the code. A plan that names code that is not there sends the implementer back to the spec.
- If planning shows that a criterion cannot be built or tested as written, the spec is wrong. Fix it before the plan is approved, not during implementation.
- A plan without named tests is not ready.
