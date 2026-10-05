# Plan: {{KEY}} <title>

- **Spec:** [spec.md](spec.md) <!-- or the ticket link, when the change needed no spec -->
- **Status:** Proposed <!-- Proposed | Approved | Done -->
- **Approved by:** <name, date>

## Summary

<Two or three sentences: the approach and why it is the smallest change that achieves the outcome.>

## Files touched

| Path | Change | Why |
|---|---|---|
| `src/...` | modify | <criterion or outcome it serves> |

New files: <none, or each one with its reason>
New dependencies: <none, or each one with its reason>

## Tasks

Smallest first. Each task ends green.

1. <task>

## Tests

Named by behavior. Every test maps to a spec criterion (or, without a spec, a ticket outcome); every criterion has at least one test.

| Criterion | Test | File |
|---|---|---|
| C1 | `rejects_expired_token` | `tests/...` |

## Risks

<What could break, how we would notice, how we roll back.>

## Existing decisions relied on

<ADRs, conventions, or patterns this plan follows; "none" if not applicable.>

## Verification

<`kai verify` plus any manual or end-to-end check needed to show the outcome.>
