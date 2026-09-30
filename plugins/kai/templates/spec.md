# Spec: {{KEY}} <title>

- **Intent:** [intent.md](intent.md)
- **Tier:** <low | medium | high> (provisional; `kai tier` computes the real one from the files the change touches)
- **Status:** Draft <!-- Draft | Approved (approval = this file merged to the base branch) -->

## Criteria

One sentence, one behavior, one observable result each. Every criterion must be provable by a test, the end-to-end check, or a measurement.

- **C1** When <trigger>, the system shall <observable response>.
- **C2** If <unwanted condition>, then the system shall <observable response>.

## Out of scope

- <What this change will not do.>

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
