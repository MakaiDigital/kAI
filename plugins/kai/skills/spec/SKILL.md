---
name: spec
description: Turn a Kai intent into numbered, testable acceptance criteria (EARS form) plus a contract mapping each criterion to a test, saved as specs/<KEY>/spec.md and approved through a Definition PR before any code. Use it in a Kai repository (one with a .kai/config) after /kai:intent, whenever someone asks to spec out a ticket, write acceptance criteria or requirements, define "done", or when a medium or high tier change is about to be built without a merged spec.
argument-hint: [TICKET-KEY]
---

# Spec

Write `specs/<KEY>/spec.md`: acceptance criteria precise enough that two engineers, or an engineer and an agent, cannot read them differently, each provable by a test, an end-to-end step, or a measurement. Most of the final code's quality is decided here, because the plan, the tests, and the review all trace back to these criteria. Leave implementation and file names to the plan.

If the repository has no `.kai/config`, it does not use Kai. Say so and help directly.

## 1. Gather context

- Get the key from `$ARGUMENTS` or `kai key`, and read `specs/<KEY>/intent.md`. If there is no intent, run `/kai:intent` first: criteria without an agreed goal just encode guesses.
- Read the ADRs in `docs/adr/` and any existing specs that touch the same surfaces, so new criteria do not contradict earlier decisions.
- Apply any policy or standards skills you have (security, API, UX, compliance). Meeting a policy while writing the spec is far cheaper than discovering a conflict in review.

## 2. Propose the criteria

Start from `${CLAUDE_PLUGIN_ROOT}/templates/spec.md`. Number the criteria C1, C2, and so on, and write each one in an EARS pattern. The fixed shapes force a trigger and an observable response, which is exactly what a test needs:

| Pattern | Shape |
|---|---|
| Ubiquitous | The system shall … |
| Event-driven | **When** <trigger>, the system shall … |
| State-driven | **While** <state>, the system shall … |
| Unwanted behavior | **If** <condition>, **then** the system shall … |
| Optional feature | **Where** <feature is present>, the system shall … |

Good criteria:

- **Cover one behavior with one observable result.** A criterion with two results becomes a test that can half-pass.
- **Include the unhappy paths** people forget: signed out, permission denied, network down, duplicate action, invalid input, item no longer available.
- **Put a number on quality words.** "Fast" or "reliable" means nothing until you say how fast or how reliable.
- **Can be proved.** If no test, end-to-end step, or measurement could prove it, it is a wish. Rewrite it, or move it to the intent's open questions.
- **Use synthetic data.** Never include real personal data, credentials, or production records.
- **Rest on facts you have looked at.** When a criterion states something outside the repository's code (a live page or element, a third-party script or library, a quota, a model's output), probe it read-only (curl, a headless browser, the library's source) and quote the output in the spec. If you cannot probe it, make it an open question instead of asserting it. Show the arithmetic behind any number, and when a check could only ever come out one way, add a positive control that proves it can see the thing.
- **Measure model behavior, don't specify its mechanism.** For something an AI model decides, write an evaluation set first: at least 20 questions, a held-out part of at least 10 written after any tuning, a baseline score, and a threshold in the criterion. Run each question 3 times and state the spread. One answer is never the target.

Propose the criteria to the person, ask about whatever the intent leaves open (AskUserQuestion when available), and revise. An agent proposing and humans editing finds more gaps than either working alone.

## 3. Complete the spec

- **Out of scope**: be explicit. Unstated boundaries get filled with guesses.
- **Interfaces touched**: surfaces such as endpoints, screens, tables, flags, and external systems, not file paths.
- **End-to-end verification**: a procedure someone can actually run to watch the feature work. It becomes the acceptance check later.
- **Tier**: estimate it from the interfaces and `.kai/tiers` (`kai tier` computes it once code exists). High tier also needs the Security section.
- **Contract**: one row per criterion, status FAIL, evidence empty. Give each row a proposed test name taken from the criterion's own words, such as `If a request has no valid token, then return 401` → `rejects_missing_token_with_401`. When a criterion can only be proved by the end-to-end check or a measurement, say so in the Test column (`e2e step 3`, `integration: p95 < 300 ms`).

## 4. Open the Definition PR

The intent and spec are approved by merging them on their own, before any code. That merge is the sign-off the `definition` CI gate looks for.

1. Work on a branch that contains the key, for example `<KEY>-definition`, so the `ticket-ref` gate recognizes it.
2. Commit `specs/<KEY>/intent.md` and `spec.md` (plus any ADR) with the message `<KEY>: intent and spec`.
3. Open a pull request with only those files, titled `<KEY>: definition`. Product confirms the criteria capture the intent. Engineering confirms they are complete and testable.
4. After it merges, build on a fresh branch with `/kai:build`.

If the change needs a new service, dependency, data store, external integration, or trust boundary, run `/kai:adr` first and include the ADR in the same PR.
