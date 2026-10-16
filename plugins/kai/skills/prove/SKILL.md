---
name: prove
description: Prove a ticketed change works before anyone calls it done. Runs the team's checks with kai verify, writes specs/<KEY>/evidence.md, maps every planned test and criterion to a quoted passing line, and updates the spec's contract.
argument-hint: [TICKET-KEY]
disable-model-invocation: true
---

Follow `${CLAUDE_PLUGIN_ROOT}/references/prove.md`. Arguments: $ARGUMENTS
