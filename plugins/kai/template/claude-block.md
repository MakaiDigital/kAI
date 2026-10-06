## How we deliver (Kai)

- Every change is keyed to a ticket; branch names contain the key (`PAY-123-short-description`). Artifacts live in `specs/<KEY>/`.
- Commit subjects start with the key (`PAY-123: plan`). If the repository enforces Conventional Commits, write `type(PAY-123): …` instead, for example `test(PAY-123): failing tests`.
- Start with `/kai:spec <KEY>` (it reads the ticket and, from level 2, skips the spec only when the change touches nothing but low-tier files), implement with `/kai:implement` (plan and approval, failing tests, code, `/kai:prove`, independent review, then the PR and its reviews until they are satisfied). From level 4, `/kai:accept` runs the end-to-end check in integration after merge, and `/kai:retro` turns recurring lessons into CLAUDE.md lines, skills, ADRs, or tickets for hooks.
- From level 2, medium and high tier changes (see `.kai/tiers`) take two PRs: a Definition PR with `spec.md` and any ADR it needed (`/kai:spec`), merged before the Change PR with the code.
- "Done" means `kai verify` passed and its output is shown in `specs/<KEY>/evidence.md`, not a claim that tests pass.
- Never push to the base branch, merge or approve a pull request, add the `kai:tests-changed` label, bypass git hooks, or edit a test to make it pass. A wrong test is a question for the human.
- Follow the minimal-code standard in @.kai/constraints.md.
