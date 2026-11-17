---
name: setup
description: Set Kai up in this repository, or upgrade an existing setup. Works out the ticket system, prefixes, test commands and level, then writes the config, risk tiers, CLAUDE.md block, settings, and CI workflows with kai init.
argument-hint: [level 1-4]
disable-model-invocation: true
---

# Set up Kai

Get this repository ready for Kai in a few minutes, without anyone having to know the options. `kai init` does the writing and never overwrites your changes: when one of Kai's files differs from the new version, it writes `<file>.kai-new` beside it for you to merge (a workflow that differs only in the action versions Kai pins is updated in place).

Write everything a person reviews by `${CLAUDE_PLUGIN_ROOT}/references/writing.md`.

## 1. Look before asking

- The working directory must be a git repository. If `.kai/config` already exists, this is an **upgrade**: read the current `KAI_LEVEL` and settings from it, and skip to step 3 with `--dry-run` so the person sees what would change. `kai init` never touches their `.kai/config` or `.kai/tiers`, so if the person asks for a different level than the current `KAI_LEVEL`, set it in `.kai/config` yourself and pass the same `--level`.
- On an upgrade, if `.claude/settings.json` sets `permissions.defaultMode` to `plan`, say that Kai before 0.10.0 set it so that every session started in plan mode, and offer to remove it: `/kai:implement` now enters plan mode itself, and other requests no longer need it. Remove it only if the person agrees, since they may have set it themselves.
- Work out sensible defaults from the repository, so the questions are confirmations rather than blanks:
  - **Ticket system and prefixes:** look at branch names and recent commit messages (`git branch -a`, `git log --oneline -50`) for keys like `PAY-123` (Jira or Linear) or `#42` (GitHub).
  - **Test commands:** look at `package.json` scripts, `Makefile`, `pyproject.toml`, `go.mod`, `Cargo.toml`, or CI workflows. Prefer the commands CI already runs, including lint and type checks, one per line.
  - **CI:** GitHub Actions is used if `.github/workflows/` exists or the `origin` remote is on GitHub. Otherwise plan on `--no-ci`. Kai's workflow runs the gates, not your tests: those already run locally and in the repository's own CI. If no workflow runs the tests on a pull request, the evidence is only what the author's session reported: propose adding the toolchain steps and `gates: ticket-ref definition tests-locked contract verify` to `kai.yml`, so CI runs `KAI_VERIFY_CMDS` itself.
  - **How to run the application:** look for a dev server, a CLI entry point, a simulator, a compose file, or an existing `verify` skill under `.claude/skills/`. Step 5 writes the skill from this.
  - **An existing Claude review workflow** (one using `anthropics/claude-code-action` for PR review): at level 3 and above, Kai adds its own review workflow. Point out the overlap and ask whether to keep both. Kai's review keeps its own single comment (marked `<!-- kai-review -->`, posted by `github-actions[bot]`), so the two coexist without overwriting each other, but two reviews on every PR may be one too many. If the person keeps only theirs, delete `.github/workflows/kai-review.yml` after step 3. One well-tuned reviewer finds more than two stacked ones: tune `REVIEW.md` before adding a reviewer.
  - **Review credentials:** Kai's review reads an `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` repository secret, and skips with a notice when neither exists.
- Check `gh auth status`. For a private marketplace, git must also clone without a prompt (`gh auth setup-git`).

## 2. Confirm with the person

Ask in one batch (AskUserQuestion when available), with your detected defaults preselected:

- Ticket system (`jira`, `linear`, or `github`) and project prefixes.
- The commands that must pass before work is done.
- The adoption level, from `$ARGUMENTS` if given. Recommend **1** for a team new to Kai: implement and prove, with guardrail hooks. Raise it later by re-running setup. Level 2 adds specs and risk tiers, 3 adds locked tests and AI review, 4 adds acceptance, retros, and metrics.

## 3. Preview, then write

Run `kai init --dry-run` with the answers (`--provider`, `--prefixes`, `--verify` once per command, `--level`, and `--no-ci` if there is no GitHub Actions) and show what it would write. Then run it without `--dry-run`. `kai init --help` lists every option. Use `--marketplace <path>` only when testing Kai from a local clone.

Say that the settings it writes deny `gh pr merge` and adding the `kai:tests-changed` label, and make Claude ask before a push to the base branch.

## 4. Set the risk tiers

`.kai/tiers` maps paths to `low`, `medium`, or `high`; anything unlisted is medium. Scan the repository for surfaces that deserve `high` (authentication, authorization, payments, secrets, migrations, public API definitions, infrastructure, `.github/workflows/`), propose the exact lines, and add the ones the person agrees with. Getting this right matters from level 2, because the tier decides which changes need a spec and which need a human code read.

## 5. Write the verify skill

`/kai:prove` runs the change end to end before the pull request, and it needs to know how. Write that down once as a project skill, `.claude/skills/verify/SKILL.md`, so every session starts and drives the application the same way. Keep an existing one, and offer to improve it.

- Its frontmatter has `name: verify` and a `description` that says to use it to run and observe a change before committing. Leave model invocation on: Claude must be able to use it.
- Its body says how to start the application (the command, the port or binary, how to know it is ready, test accounts and seed data that are synthetic), how to drive it (the browser tools for a screen, `curl` for an endpoint, the command for a tool, a simulator for mobile), what a healthy run looks like, and how to stop it.
- Run it yourself before you commit it: start the application, do one real action, and stop it. Fix the skill until that works twice in a row. A smoke test that fails for its own reasons teaches Claude to ignore it.
- Keep it fast. A slow step belongs in a note about when to run it, not in every run.
- For a large repository, put a `verify` skill in a `.claude/skills/` folder near each application, and say in each which paths it covers.
- A library with nothing to start needs no skill. Say so, and `/kai:prove` records `No end-to-end run` with that reason.

## 6. Fill the review checks (level 3)

`REVIEW.md` holds what the reviewer looks for in this repository. Ask the people who own the code for the failures that matter most, and write each as a row of its **Checks** table: a trigger a diff can show, the question to ask, and the incident or PR behind it. Three good rows beat twenty vague ones. On an upgrade, an existing `REVIEW.md` without a Checks table is left alone by `kai init`: offer to add the table from `${CLAUDE_PLUGIN_ROOT}/template/REVIEW.md`.

## 7. Commit and hand off

- Commit the setup on a branch named `kai-setup` with the message `Set up Kai (level <N>)`, and suggest opening a pull request so the team sees it. Branches starting with `kai-setup` need no ticket key, so the setup PR passes Kai's own checks.
- Tell the person what happens next:
  - Teammates who open the repository in Claude Code are prompted to install Kai.
  - A change must not be able to change the checks that judge it. Kai's gates and review already read `.kai/config`, `.kai/tiers`, `REVIEW.md` and the review agents from the base branch, but a workflow file runs as the pull request has it. Propose a `CODEOWNERS` entry that gives `.github/workflows/`, `.kai/`, `REVIEW.md` and `.claude/` to the tech lead, and tell the person to require code-owner review in branch protection.
  - To add a gate to a repository that is already in use, list it in `KAI_OBSERVE` in `.kai/config` first. An observed gate reports what it would have blocked and never fails the check. Read a week of its reports, fix the false alarms, then remove it from `KAI_OBSERVE`.
  - On GitHub, protect the main branch: require a pull request, an approval, and the `kai` check. Branch protection and rulesets need a paid GitHub plan for private repositories; until then, only Kai's permission rules stand in the way of a push to the base branch.
  - From level 2, `/kai:spec` writes the plan into the Definition PR, and merging it approves the plan. When `/kai:implement` asks to approve a plan instead (level 1, a low-tier change, or a fix), approve it with "Yes, and use auto mode", so Claude carries the work to the pull request without asking again.
  - Start the first change with `/kai:spec <KEY>`.
- If any `*.kai-new` files were written, list them and offer to merge each one. Until a workflow or agent `.kai-new` is merged, CI keeps running the old file, so the upgrade isn't finished. Require the `kai` check only once the new `kai.yml` is in, since an older one reports its check under another name.
