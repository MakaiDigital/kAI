---
name: accept
description: Accept a merged Kai change in the integration environment. It verifies the deployed change against the spec and ticket, tries to break it with adversarial QA, and if something fails opens a fix PR through the /kai:implement flow and verifies again. When verification and QA pass it runs the retro for the ticket, then opens one cleanup PR that deletes the ticket's working documents in specs/<KEY>/ and applies the retro's instruction changes, and answers that PR's reviews. Use it in a Kai repository (one with a .kai/config) once a change is merged and deployed to integration, when someone says accept, verify, QA, or close out a ticket, or asks whether the running feature works. It is for after merge and deploy; local work before merge uses /kai:prove.
argument-hint: <TICKET-KEY>
---

# Accept

Tests prove the code matches the criteria. Acceptance checks that the criteria matched the ticket, by watching the deployed feature run and trying to break it. When it passes, the ticket's working documents in `specs/<KEY>/` are removed, what was learned is folded back into the repository, and the ticket is done.

The engineer runs this once the deployment to integration is complete. Do not wait for or detect deployments.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly. Below `KAI_LEVEL` 4, acceptance isn't part of the repository's flow: run it only if the person asks.

## 1. Prepare

- The key comes from `$ARGUMENTS`. Acceptance happens after merge, so the branch usually no longer carries it; ask if it is missing. Work from the base branch, up to date.
- Read `specs/<KEY>/spec.md` (its **Context** and **End-to-end verification**), the plan and evidence. With no spec, use the ticket and the plan.
- Confirm the integration environment and how to reach it, and that the change is there: the commit it reports as running (a version or health endpoint, if it has one) must contain the ticket's latest merge commit, which after a fix cycle is the fix PR's (`git merge-base --is-ancestor <merge commit> <deployed commit>`). If you cannot reach it, or it runs older code, say so and stop. Evidence from somewhere else is evidence of the wrong thing.
- Integration only. With no integration environment, say so and ask the person. Use production only when they say so, and then run only step 2's verification, within the limits they set (requests, accounts, data); skip step 3, and record in `accept.md` that it ran in production at their request. Without QA there is no Verdict: leave it Pending and hand back before the retro, since accepting without QA is their call.
- Use synthetic test data. Never record personal data, credentials, or tokens.

## 2. Verify

Start from `${CLAUDE_PLUGIN_ROOT}/templates/accept.md` and save it as `specs/<KEY>/accept.md`. It is a working file: never commit it; its summary goes in the cleanup PR description. Run the spec's end-to-end steps exactly as written (curl sequence, contract test, UI walkthrough with browser tools if you have them), then every check each criterion needs, and record the command, the output, and the criteria it shows. If a step cannot be run as written, record that and why rather than improvising a different check: a procedure that does not work is a finding. A step only production can show (real traffic, a production alert) is the exception: record it as not run, for the release owner.

## 3. Try to break it

Switch to an adversarial stance, in a fresh context if you can (dispatch an agent with only the spec and the environment). Go beyond the criteria: the unhappy paths, boundaries (empty, huge, duplicate, malformed), repeated and concurrent actions, another user's data, signed-out and wrong-permission access, interruption halfway, and anything the spec-critic noted as uncovered. Record each attempt and what happened, including the ones that held. Run against integration, a preview deployment, or a local production build, never production, and do not run anything destructive against shared data.

At the end, set **Verdict** in `accept.md` to Pass when every criterion held and no attempt broke the feature, otherwise Fail.

## 4. If something fails

A failure is a criterion that does not hold or a break that matters. For each:

1. Reproduce it and record the exact steps and output in `accept.md`.
2. Fix it through `/kai:implement` on a new branch `<KEY>-fix-<n>` from the up-to-date base (`git fetch origin && git switch --no-track -c <KEY>-fix-<n> origin/<KAI_BASE_BRANCH>`), with the reproduction as the ticket text. The failing test is the reproduction as an automated test; put it in a new test file when the original test file is locked. Leave `accept.md` uncommitted. The person approves the plan, as always.
3. After the fix PR is merged and the engineer says it is deployed, start again from step 1 and re-run everything that failed plus the full verification.

After 3 fix cycles, or if a failure needs a decision rather than a fix (the spec is wrong, or the behavior is disputed), stop and hand back to the person with `accept.md` and what you tried. A criterion that was wrong goes back to `/kai:spec`.

## 5. When it passes: retro

First create the cleanup branch from the up-to-date base: `git fetch origin && git switch --no-track -c <KEY>-cleanup origin/<KAI_BASE_BRANCH>`. Then run `/kai:retro <KEY>` there, before deleting anything, because it reads the ticket's spec, plan, evidence, reviews, and `accept.md`. It commits its instruction changes on this branch and lists the lessons that need a ticket.

## 6. Open the cleanup PR

On `<KEY>-cleanup`:

- Delete only `specs/<KEY>/`: `git rm -r` its tracked files, and commit that alone as `<KEY>: cleanup`.
- The PR changes only Markdown: this deletion and the retro's instruction changes, each in its own commit so any one can be reverted alone. That keeps it low tier, so it passes every gate without an exemption; the retro puts changes to files `.kai/tiers` ranks higher in their own PR. Lessons that need a hook, script, setting, or workflow are listed for the person to ticket.
- Push with `git push -u origin <KEY>-cleanup` and open a PR titled `<KEY>: cleanup`. Its description holds what the files held, since they no longer will: the outcome, the verification and QA summary from `accept.md` (what was run, what was attempted, what failed and was fixed in which PR), and the retro's lessons with the evidence for each. Then remove the untracked `accept.md`.

## 7. Answer the cleanup PR's reviews

Follow step 7 of `/kai:implement`: wait for CI and the automated reviewers, fix what is right, defend with evidence what is not, stop on stalemates and non-convergence, and never merge or approve.

## 8. Tell the person

Report: the PR link, what verification and QA covered and found, the fix PRs it took, the lessons applied and those listed for a ticket, and anything needing their decision. The `accepted` label on the change PR is the person's sign-off; leave it to them. Once the cleanup PR is merged by a person, the ticket is done from the implementation standpoint. Do not move or comment on the ticket in the tracker.
