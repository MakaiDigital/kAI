---
name: adr
description: Record an architecture decision for a Kai repository as docs/adr/NNNN-title.md, comparing two or three options and their trade-offs before the humans decide. Use it when a change needs a new service, dependency, data store, external integration, public interface, or trust boundary, when someone asks to write an ADR, record or document a decision, or compare architectural approaches, or when a spec or plan would contradict an existing ADR.
argument-hint: [decision title]
---

# Architecture decision record

Make expensive-to-reverse decisions deliberately and write them down, so later sessions, human or agent, follow them instead of re-deciding. Most changes fit existing ADRs and conventions. If this one does, say so, name the ADRs it relies on, and stop.

1. **Survey what exists.** Read `docs/adr/`, and dispatch the `feature-dev:code-explorer` agent to map the relevant code and patterns without flooding the main context. A new decision that contradicts an accepted ADR has to supersede it explicitly; silently diverging is how architectures rot.
2. **Lay out real options.** Ask the `feature-dev:code-architect` agent for two or three realistic options, always including "extend what we already have". Compare them in the template's options table on complexity, cost to run, reversibility, and team familiarity, against the intent's and spec's constraints. Rating every option on the same dimensions keeps the favorite from winning by being described more generously.
3. **Let the humans decide.** Present the options with a recommendation and the reasoning behind it. The tech lead or service owner decides. Security is consulted when identity, secrets, or trust boundaries are involved.
4. **Write it down.** Number the ADR one higher than the highest in `docs/adr/`, starting at `0001`. Fill `${CLAUDE_PLUGIN_ROOT}/templates/adr.md`, save it as `docs/adr/NNNN-short-title.md` with Status: Proposed, and commit it on the ticket's branch as `<KEY>: ADR NNNN`. Merging makes it Accepted.
5. **Link it.** Reference the ADR from the spec's Interfaces section and include it in the ticket's Definition PR, so the decision and the criteria that depend on it are approved together. If the ticket has no intent or spec yet, that is normal: point to `/kai:intent` and `/kai:spec` as the next steps, and the ADR ships in the same Definition PR.
