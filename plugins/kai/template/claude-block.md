## How we deliver (Kai)

- Every change is keyed to a ticket; branch names contain the key (`PAY-123-short-description`). Artifacts live in `specs/<KEY>/`.
- Start with `/kai:spec <KEY>` (it reads the ticket, and skips the spec for simple tickets and bugs), implement with `/kai:implement` (plan and approval, failing tests, code, `/kai:prove`, independent review, then the PR and its reviews until they are satisfied). From level 4, `/kai:accept` runs the end-to-end check in integration after merge, and `/kai:retro` turns recurring lessons into hooks, skills, ADRs, or CLAUDE.md lines.
- From level 2, medium and high tier changes (see `.kai/tiers`) take two PRs: a Definition PR with `spec.md` and any ADR it needed (`/kai:spec`), merged before the Change PR with the code.
- "Done" means `kai verify` passed and its output is shown in `specs/<KEY>/evidence.md`, not a claim that tests pass.
- Never push to a protected branch, bypass git hooks, or edit a test to make it pass. A wrong test is a question for the human.
- Follow the minimal-code standard in @.kai/constraints.md.
