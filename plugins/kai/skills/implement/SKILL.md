---
name: implement
description: Take a ticket to a reviewed, green pull request. Builds from the plan the Definition PR approved (or plans and stops for approval when none was merged), commits failing tests, writes the smallest code that passes them, proves it, reviews it independently, opens the PR, and answers its reviewers.
argument-hint: [TICKET-KEY]
disable-model-invocation: true
---

Follow `${CLAUDE_PLUGIN_ROOT}/references/implement.md`, and write for people by `${CLAUDE_PLUGIN_ROOT}/references/writing.md`. Arguments: $ARGUMENTS
