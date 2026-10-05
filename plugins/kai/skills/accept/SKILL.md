---
name: accept
description: Accept a merged Kai change in the integration environment. It verifies the deployed change against the spec and ticket, tries to break it with adversarial QA, and if something fails opens a fix PR through the /kai:implement flow and verifies again. When verification and QA pass it runs the retro for the ticket, then opens one cleanup PR that deletes the ticket's specs and other working documents (keeping only ADRs) and applies the retro's lessons, and answers that PR's reviews. Use it in a Kai repository (one with a .kai/config) once a change is merged and deployed to integration, when someone says accept, verify, QA, or close out a ticket, or asks whether the running feature works.
argument-hint: <TICKET-KEY>
---

# Accept

Tests prove the code matches the criteria. Acceptance checks that the criteria matched the ticket, by watching the deployed feature run and trying to break it. When it passes, the ticket's working documents are removed, what was learned is folded back into the repository, and the ticket is done. The only documentation that stays is the ADRs; everything else is read from the code.

The engineer runs this once the deployment to integration is complete. Do not wait for or detect deployments.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly.

## 1. Prepare

- The key comes from `$ARGUMENTS`. Acceptance happens after merge, so the branch usually no longer carries it; ask if it is missing. Work from the base branch, up to date.
- Read `specs/<KEY>/spec.md` (its **Context** and **End-to-end verification**), the plan and evidence. With no spec, use the ticket and the plan.
- Confirm the integration environment and how to reach it, and that the change is there: compare what it reports as running (a version or health endpoint, if it has one) with `git rev-parse HEAD` on the base branch. If you cannot reach it, or it runs older code, say so and stop. Evidence from somewhere else is evidence of the wrong thing.
- Integration only, never production. Use synthetic test data. Never record personal data, credentials, or tokens.

## 2. Verify

Start from `${CLAUDE_PLUGIN_ROOT}/templates/accept.md` and save it as `specs/<KEY>/accept.md`. Run the spec's end-to-end steps exactly as written (curl sequence, contract test, UI walkthrough with browser tools if you have them), then every check each criterion needs, and record the command, the output, and the criteria it shows. If a step cannot be run as written, record that and why rather than improvising a different check: a procedure that does not work is a finding.

## 3. Try to break it

Switch to an adversarial stance, in a fresh context if you can (dispatch an agent with only the spec and the environment). Go beyond the criteria: the unhappy paths, boundaries (empty, huge, duplicate, malformed), repeated and concurrent actions, another user's data, signed-out and wrong-permission access, interruption halfway, and anything the spec-critic noted as uncovered. Record each attempt and what happened, including the ones that held. Stay inside integration; do not run anything destructive against shared data.

## 4. If something fails

A failure is a criterion that does not hold or a break that matters. For each:

1. Reproduce it and record the exact steps and output in `accept.md`.
2. Fix it through `/kai:implement` on a new branch `<KEY>-fix-<n>`, with the reproduction as the ticket text. The failing test is the reproduction as an automated test. The person approves the plan, as always.
3. After the fix PR is merged and the engineer says it is deployed, start again from step 1 and re-run everything that failed plus the full verification.

After 3 fix cycles, or if a failure needs a decision rather than a fix (the spec is wrong, or the behavior is disputed), stop and hand back to the person with `accept.md` and what you tried. A criterion that was wrong goes back to `/kai:spec`.

## 5. When it passes: retro

Run `/kai:retro <KEY>` before deleting anything, because it reads the ticket's spec, plan, evidence, reviews, and `accept.md`. It returns lessons and the exact changes that apply them.

## 6. Open the cleanup PR

On a branch `<KEY>-cleanup` from the base branch:

- Delete `specs/<KEY>/` entirely (spec, plan, evidence, `accept.md`) and any other document this ticket's work created, except ADRs under `docs/adr/`. Do not delete code, tests, `.kai/`, `CLAUDE.md`, skills, or hooks.
- Apply the retro's changes, each in its own commit (a hook, a skill, a `CLAUDE.md` line, an ADR, a deletion of an instruction nothing needed), so any one can be reverted alone. Commit the deletion on its own as `<KEY>: cleanup`.
- Push and open a PR titled `<KEY>: cleanup`. Its description holds what the files held, since they no longer will: the outcome, the verification and QA summary (what was run, what was attempted, what failed and was fixed in which PR), and the retro's lessons with the evidence for each.
- The gates exempt this branch when it deletes the ticket's spec or evidence.

## 7. Answer the cleanup PR's reviews

Follow step 7 of `/kai:implement`: wait for CI and every reviewer, fix what is right, defend with evidence what is not, stop on stalemates and non-convergence, and never merge or approve.

## 8. Tell the person

Report: the PR link, what verification and QA covered and found, the fix PRs it took, the lessons applied, and anything needing their decision. Leave adding the `accepted` label to a person, since releases take only accepted changes. Once the cleanup PR is merged by a person, the ticket is done from the implementation standpoint. Do not move or comment on the ticket in the tracker.
