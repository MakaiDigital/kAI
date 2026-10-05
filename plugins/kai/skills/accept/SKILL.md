---
name: accept
description: Run a merged Kai change's end-to-end verification in the integration environment and record exactly what happened in specs/<KEY>/accept.md, so a person can judge whether the running feature matches the ticket. It never marks the change accepted. Use it in a Kai repository (one with a .kai/config) after a change is merged and deployed to integration, or when someone asks to accept, demo, walk through, or check a ticket in integration before the release.
argument-hint: <TICKET-KEY>
---

# Accept

Passing tests prove the code matches the criteria. Acceptance checks that the criteria matched the ticket, by watching the feature run, not by reading how it was built. Your job is to run the procedure and record the evidence. The judgment belongs to a person: product for user-facing behavior, the engineer or service owner for APIs and infrastructure, and two people for high-tier changes.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly.

## 1. Prepare

- The key comes from `$ARGUMENTS`. Acceptance happens after merge, so the branch usually no longer carries it; ask if it is missing.
- Read the spec's **Context** and **End-to-end verification** sections. With no spec, use the ticket's outcomes and the plan.
- Confirm which environment to use (integration, never production) and that the change is deployed there. If you cannot reach it, say so and stop. Running the procedure somewhere else would produce evidence of the wrong thing.

## 2. Run the procedure exactly as written

Start from `${CLAUDE_PLUGIN_ROOT}/templates/accept.md` and save it as `specs/<KEY>/accept.md`. For each step, run it as written (curl sequence, contract test, UI walkthrough with browser or screenshot tools if you have them) and record the command, the output, and the criteria it shows. If a step cannot be run as written, record that and why rather than improvising a different check. A procedure that does not work is itself a finding for the spec.

Use synthetic test data only. Never record personal data, credentials, or tokens in `accept.md`.

## 3. Hand over to the person

- Leave **Verdict: Pending** and **Accepted by** empty. You never mark acceptance, because the whole point is a human seeing it work.
- Fill the Criteria table's Observed column with what the run showed, and leave "Matches the outcome?" for the person.
- Commit `accept.md` on a branch (`<KEY>-accept`) and summarize for the person: what passed, what did not match, and what was unclear. Ask them to try the feature themselves against the **outcome**, not just the criteria list.
- When they accept, they fill in the verdict and their name, and add the `accepted` label to the change's merged PR; releases take only accepted changes. "Unclear" goes back to `/kai:spec` as a criterion question, and "not accepted" becomes a new ticket or a revert before the release is cut.
