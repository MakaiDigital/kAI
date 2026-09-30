## How we deliver (Kai)

- Every change is keyed to a ticket; branch names contain the key (`PAY-123-short-description`). Artifacts live in `specs/<KEY>/`.
- Start with `/kai:intent <KEY>`, build with `/kai:build` (plan, approval, failing tests, then code), and finish with `/kai:prove` (and `/kai:ship` from level 3). From level 4, `/kai:accept` runs the end-to-end check in integration after merge, and `/kai:retro` turns recurring lessons into hooks, skills, ADRs, or CLAUDE.md lines.
- From level 2, medium and high tier changes (see `.kai/tiers`) take two PRs: a Definition PR with `intent.md` and `spec.md` (`/kai:spec`), merged before the Change PR with the code. Record architecture decisions with `/kai:adr`.
- "Done" means `kai verify` passed and its output is shown in `specs/<KEY>/evidence.md`, not a claim that tests pass.
- Never push to a protected branch, bypass git hooks, or edit a test to make it pass. A wrong test is a question for the human.
- Follow the minimal-code standard in @.kai/constraints.md.
