# Deliver to engineering

The intent and spec are approved by merging them into the product's repository on their own, before any code: a Definition PR. Product confirms the criteria capture the intent; engineering confirms they are complete and testable. Deliver the files one of two ways.

## With a GitHub connector that can write to the repository

1. Ask which repository if you do not know it.
2. Show the person the pull request you are about to open (title, files, and body) and wait for their go-ahead. Opening it notifies reviewers, so it is their call.
3. Create a branch from the default branch named after the ticket, such as `PAY-123-definition`. The key must be in the name: engineering's checks look for it.
4. Add the files under `specs/<KEY>/` (`intent.md`, and `spec.md` when there is one) and commit them with the message `<KEY>: intent and spec` (or `<KEY>: intent` for an intent alone).
5. Open the pull request titled `<KEY>: definition`, with this body:

```markdown
## What and why
<two or three sentences from the intent>

## For reviewers
- Product: do the criteria capture the intent?
- Engineering: are they complete (error paths, permissions, limits) and can each one become a test?

## Open questions
<from the intent and spec, each with an owner, or "None">
```

6. Share the link and say who should review. The repository's code owners are requested automatically.

## Without one

Give the person the finished files to download, named exactly `specs/<KEY>/intent.md` and `specs/<KEY>/spec.md`, and a short message they can send to their engineering lead:

> Here are the intent and spec for <KEY>. Please open a Definition PR with them under `specs/<KEY>/` (branch `<KEY>-definition`, title "<KEY>: definition") so product and engineering can review the criteria before build starts.

## Either way

These files live in the repository and stay in its history for good, visible to everyone with access. They must not contain customer personal data, credentials, or production records.
