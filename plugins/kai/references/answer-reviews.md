# Hand the pull request to Steward

From here, Steward looks after a change or a fix PR. It waits for CI and the reviewers, fixes what is right, defends with evidence what is not, keeps the branch up to date, and follows this repository's rules in `.claude/skills/steward/SKILL.md`: who to trust, fix or defend or concede, never touch locked tests, run the checks after a fix, and when to stop. It never approves or merges, and it never proves a change: the evidence stays the person's. A Definition PR and a cleanup PR are not handed over: their reviews are decisions about what to build and about the team's rules, and a person settles those.

If `.claude/skills/steward/SKILL.md` is missing, Kai was set up before Steward: tell the person that `/kai:setup` adds it, and that until then Steward answers by its own defaults. PR Steward reads the file from the default branch, so a copy that exists only on this branch does not reach it yet.

Read the PR's labels and comments with `gh pr view <n> --json labels,comments`, then take the first case that fits:

- **The PR has the `claude-pr-steward-watching` label.** PR Steward already looks after it. Start nothing.
- **`KAI_SHIP=1` in `.kai/config`.** PR Steward runs in the cloud as `claude[bot]`, and the organization pays for its work.
  - If a comment on the PR already holds `@claude steward`, or PR Steward has commented on the PR (its first comment is headed **Claude PR Steward**), PR Steward was asked or started before, and it stopped or did not start. Do not ask again. Tell the person so, and that a new `@claude steward` comment from them starts it.
  - Otherwise ask it to start with `gh pr comment <n> --body '@claude steward'`, then read the labels once more.
  - With the `claude-pr-steward-watching` label, it has started. The person steers it with `@claude <instruction>` and stops it with `@claude stop`.
  - Without the label, tell the person that PR Steward has not started yet, and that nobody watches the PR until the label appears. PR Steward adds the label only when it starts, which can be after this check, so the person looks at the PR again before they do anything else. Pass on PR Steward's comment if it left one. If the label is still missing then and PR Steward left no comment, it may be off for this repository or for their GitHub account, which an Owner of the Claude organization changes. In that case they can type `/steward +github-actions` in this session: tell them what a watch needs, as in the next case.
- **Otherwise,** the person starts a watch in this session. Tell them to type `/steward +github-actions`, and tell them what a watch needs:
  - `+github-actions` makes the watch read what Kai's CI posts on the PR (the gates report and the Kai review). A watch that is started again needs it again. A watch reads only the first 4,000 characters of a comment, so the person reads the rest of a long Kai review themselves. `/ship` is the wrong command here: it reviews the change a second time and commits every uncommitted file.
  - It needs Claude Code 2.1.330 or later, GitHub CLI 2.63 or later, and git 2.38 or later, in a terminal session in auto mode. In another permission mode it waits at each prompt. It does not start in plan mode or bypass-permissions mode, in a background session, with Remote Control on, or on native Windows.
  - The watch lives in this session and this checkout, for up to seven days and on the person's own usage. They keep the session open, the computer awake, and this branch checked out. They start the next ticket in a second clone of the repository. A worktree is not enough: it shares git's settings with this checkout, and a `git push -u` there ends the watch. `/tasks` shows the watch, and `/steward stop` ends it.
  - It merges the base branch and runs this repository's code on their computer with their credentials. It is only for a repository where they trust everyone who can merge to the base branch or push to this branch. `/ship terms` shows its limits.

If Claude Code says that no watch can start, pass on the reason it gives. The person can then ask in this session for one pass over the PR's reviews by the rules in `.claude/skills/steward/SKILL.md`.

Then report and stop. Do not poll the PR yourself.
