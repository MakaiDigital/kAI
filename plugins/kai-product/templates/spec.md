---
key: {{KEY}}
ticket: <link to the Jira, Linear, or GitHub ticket>
tier: <low | medium | high>
status: draft
adr: <docs/adr/NNNN-title.md, or none>
---

# Spec: {{KEY}} <title>

<!-- status: draft | approved. Approval = this file merged to the base branch. tier is provisional: `kai tier` computes the real one from the files the change touches. -->

## Review here

What a person must judge before approving. Everything else follows from the ticket. Each item names its criterion and carries a `⚠ review` marker where it appears below.

- ⚠ <An assumption the ticket did not confirm, a number chosen without a source, a criterion added for an unhappy path, a security or data implication, or a decision recorded in an ADR.>

## Context

- **Problem:** <What is wrong or missing, for whom, and how we know. From the ticket.>
- **Outcome:** <What is true for the user when this is done. The result, not the implementation.>
- **Success metric:** <Target, how it is measured, and when it is evaluated. Or "none stated in the ticket".>
- **Constraints:** <Deadlines, compliance, performance, compatibility.>
- **Out of scope:** <What this change will not do.>
- **Open questions:** <Each with an owner, or "None".>

## Criteria

One sentence, one behavior, one observable result each. Every criterion must be provable by a test, the end-to-end check, or a measurement.

- **C1** When <trigger>, the system shall <observable response>.
- **C2** If <unwanted condition>, then the system shall <observable response>.

## Interfaces touched

<Surfaces, not files: endpoints, screens, tables or schemas, events, feature flags, external systems.>

## End-to-end verification

<A runnable procedure a person can follow to watch the feature work: a curl sequence, a UI walkthrough, a contract test.>

## Security

<Required for high tier: authentication, authorization, input validation, secrets, data classification, failure mode (fail closed). Otherwise "No security-relevant surface.">

## Contract

Every criterion has a row. Status stays FAIL until `/kai:prove` shows evidence.

| Criterion | Test | Status | Evidence |
|---|---|---|---|
| C1 | `proposed_test_name` | FAIL | |
| C2 | `proposed_test_name` | FAIL | |
