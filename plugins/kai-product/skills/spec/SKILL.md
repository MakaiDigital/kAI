---
name: spec
description: Help a product manager turn an intent into numbered, testable acceptance criteria (EARS form) that engineering builds and tests against with Kai, including the unhappy paths people usually forget, then deliver them as a Definition PR. Use it whenever someone wants acceptance criteria, requirements, user stories turned into something testable, a definition of done, or a spec for a ticket, after the intent is written.
argument-hint: [TICKET-KEY]
---

# Acceptance criteria

Write the spec: numbered acceptance criteria precise enough that product, engineering, and an AI agent all read them the same way, each one checkable by a test or by watching the feature run. Engineering turns every criterion into a test before writing code, so a missing criterion becomes missing behavior, and a vague one becomes a guess.

## 1. Start from the intent

Use the intent written earlier in this conversation, or ask the person to share it (or the ticket key, to read it with a GitHub connector from `specs/<KEY>/intent.md`). If there is no intent yet, write it first with the `intent` skill: criteria without an agreed goal only encode guesses.

## 2. Propose the criteria

Start from `${CLAUDE_PLUGIN_ROOT}/templates/spec.md`. Number the criteria C1, C2, and so on, and write each one in one of these shapes. Each shape forces a trigger and a result someone can check:

| Shape | Example |
|---|---|
| The system shall … | The system shall let a shopper see and change only their own favorites. |
| **When** <something happens>, the system shall … | When a signed-in shopper taps the filled heart, the system shall remove the product from their favorites. |
| **While** <a state holds>, the system shall … | While a sale has ended, the system shall show its items as read-only. |
| **If** <something goes wrong>, **then** the system shall … | If the network is unavailable, then the app shall restore the heart and show "Couldn't save, try again." |
| **Where** <an option applies>, the system shall … | Where the shopper has loyalty status, the system shall show early-access products. |

Good criteria:

- **One behavior, one visible result each.** A criterion with two results can half-pass.
- **Cover the unhappy paths:** signed out, no permission, network down, doing it twice, item no longer available. Draft these yourself; they are the ones people forget.
- **Numbers instead of adjectives.** Say how fast or how many instead of "fast" or "easy".
- **Checkable.** If nothing could show a criterion passing, it is a wish. Rewrite it, or move it to open questions.
- **Made-up data only.**

Present the criteria in plain language, mark the ones that need engineering's judgment (limits, error handling, security) as proposals for engineering to confirm, and revise with the person. Proposing criteria and letting people edit finds more gaps than writing from scratch.

## 3. Complete the spec

- **Out of scope**: say it explicitly, or the gap gets filled with guesses.
- **Interfaces touched**: the screens, APIs, data, or outside systems involved, in plain words. No file names.
- **End-to-end verification**: the steps someone would follow to watch it work. This becomes the acceptance check after release.
- **Tier**: your estimate of the risk (low, medium, or high; anything touching sign-in, payments, personal data, or public APIs is high). Engineering confirms it.
- **Contract**: one row per criterion with a proposed test name taken from the criterion's words, status FAIL, evidence empty. It looks technical, but it is what lets everyone check later that each criterion was actually tested.

## 4. Deliver

Follow `${CLAUDE_PLUGIN_ROOT}/references/deliver.md` to send the intent and spec to engineering together as the Definition PR. Once it merges, engineering builds against it with Kai.
