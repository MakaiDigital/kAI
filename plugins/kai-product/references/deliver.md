# Deliver to engineering

The spec is approved by merging them into the product's repository on their own, before any code: a Definition PR. Product confirms the criteria capture the ticket; engineering confirms they are complete and testable. Deliver the files one of two ways.

## With a GitHub connector that can write to the repository

1. Ask which repository if you do not know it.
2. Show the person the pull request you are about to open (title, files, and body) and wait for their go-ahead. Opening it notifies reviewers, so it is their call.
3. Create a branch from the default branch named after the ticket, such as `PAY-123-definition`. The key must be in the name: engineering's checks look for it.
4. Add the files under `specs/<KEY>/` (`spec.md`) and commit it with the message `<KEY>: spec`.
5. Open the pull request titled `<KEY>: definition`, with this body:

```markdown
## What and why
<two or three sentences from the spec's Context>

## For reviewers
- Product: do the criteria capture the ticket?
- Engineering: are they complete (error paths, permissions, limits) and can each one become a test?

## Open questions
<the spec's Review here list and open questions, each with an owner, or "None">
```

6. Share the link and say who should review. The repository's code owners are requested automatically.

## Without one

Give the person the finished file to download, named exactly `specs/<KEY>/spec.md`, and a short message they can send to their engineering lead:

> Here is the spec for <KEY>. Please open a Definition PR with it under `specs/<KEY>/` (branch `<KEY>-definition`, title "<KEY>: definition") so product and engineering can review the criteria before build starts.

## Either way

This file lives in the repository and stay in its history for good, visible to everyone with access. They must not contain customer personal data, credentials, or production records.
