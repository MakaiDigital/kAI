# Hand the pull request to Steward

From here, Steward looks after the PR. It waits for CI and the reviewers, fixes what is right, defends with evidence what is not, keeps the branch up to date, and follows this repository's rules in `.claude/skills/steward/SKILL.md`: who to trust, fix or defend or concede, never touch locked tests, prove again after a fix, and stop after three rounds. It never approves or merges.

If `.claude/skills/steward/SKILL.md` is missing, Kai was set up before Steward: tell the person that `/kai:setup` adds it, and that until then Steward answers by its own defaults.

- **With Claude Ship** (`KAI_SHIP=1` in `.kai/config`), PR Steward runs in the cloud. If the PR does not have the `claude-pr-steward-watching` label, start it with `gh pr comment <n> --body '@claude steward'`. It works as `claude[bot]`, and the person steers it with `@claude <instruction>` or `@claude stop` on the PR.
- **Without Claude Ship**, tell the person to type `/steward` in this session. It watches the PR from their machine, as them, until it is merged or closed, for up to seven days, and needs Claude Code 2.1.330 or later and a signed-in `gh`. `/steward` restarts a watch that stopped.

If the watch ends before people have reviewed, `/steward` or a `@claude steward` comment restarts it. Then report and stop. Do not poll the PR yourself.
