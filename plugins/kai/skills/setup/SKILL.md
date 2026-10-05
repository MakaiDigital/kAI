---
name: setup
description: Set Kai up in the current repository, or upgrade an existing setup. It works out the ticket system, project prefixes, test commands, and adoption level, then runs kai init to write .kai/config, risk tiers, the CLAUDE.md block, Claude Code settings, and CI workflows. Use it whenever someone wants to install, add, enable, configure, or upgrade Kai in a repository, or asks how to start using Kai here.
argument-hint: [level 1-4]
---

# Set up Kai

Get this repository ready for Kai in a few minutes, without anyone having to know the options. `kai init` does the writing and never overwrites a file: when one of Kai's files differs from the new version, it writes `<file>.kai-new` beside it for you to merge.

## 1. Look before asking

- The working directory must be a git repository. If `.kai/config` already exists, this is an **upgrade**: read the current `KAI_LEVEL` and settings from it, and skip to step 3 with `--dry-run` so the person sees what would change. `kai init` never touches their `.kai/config` or `.kai/tiers`.
- Work out sensible defaults from the repository, so the questions are confirmations rather than blanks:
  - **Ticket system and prefixes:** look at branch names and recent commit messages (`git branch -a`, `git log --oneline -50`) for keys like `PAY-123` (Jira or Linear) or `#42` (GitHub).
  - **Test commands:** look at `package.json` scripts, `Makefile`, `pyproject.toml`, `go.mod`, `Cargo.toml`, or CI workflows. Prefer the commands CI already runs, including lint and type checks, one per line.
  - **CI:** GitHub Actions is used if `.github/workflows/` exists or the `origin` remote is on GitHub. Otherwise plan on `--no-ci`. Kai's workflow runs the gates, not your tests: those already run locally and in the repository's own CI.
  - **An existing Claude review workflow** (one using `anthropics/claude-code-action` for PR review): at level 3 and above, Kai adds its own review workflow. Point out the overlap and ask whether to keep both. Kai's review keeps its own single comment (marked `<!-- kai-review -->`, posted by `github-actions`), so the two coexist without overwriting each other, but two reviews on every PR may be one too many. If the person keeps only theirs, delete `.github/workflows/kai-review.yml` after step 3.
  - **Review credentials:** Kai's review reads an `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` repository secret, and skips with a notice when neither exists.

## 2. Confirm with the person

Ask in one batch (AskUserQuestion when available), with your detected defaults preselected:

- Ticket system (`jira`, `linear`, or `github`) and project prefixes.
- The commands that must pass before work is done.
- The adoption level, from `$ARGUMENTS` if given. Recommend **1** for a team new to Kai: implement and prove, with guardrail hooks. Raise it later by re-running setup. Level 2 adds specs and risk tiers, 3 adds locked tests and AI review, 4 adds acceptance, retros, and metrics.

## 3. Preview, then write

Run `kai init --dry-run` with the answers (`--provider`, `--prefixes`, `--verify` once per command, `--level`, and `--no-ci` if there is no GitHub Actions) and show what it would write. Then run it without `--dry-run`. `kai init --help` lists every option. Use `--marketplace <path>` only when testing Kai from a local clone.

## 4. Set the risk tiers

`.kai/tiers` maps paths to `low`, `medium`, or `high`; anything unlisted is medium. Scan the repository for surfaces that deserve `high` (authentication, authorization, payments, secrets, migrations, public API definitions, infrastructure, `.github/workflows/`), propose the exact lines, and add the ones the person agrees with. Getting this right matters from level 2, because the tier decides which changes need a spec and which need a human code read.

## 5. Commit and hand off

- Commit the setup on a branch named `kai-setup` with the message `Set up Kai (level <N>)`, and suggest opening a pull request so the team sees it. Branches starting with `kai-setup` need no ticket key, so the setup PR passes Kai's own checks.
- Tell the person what happens next:
  - Teammates who open the repository in Claude Code are prompted to install Kai.
  - On GitHub, protect the main branch: require a pull request, an approval, and the `kai` check.
  - Start the first change with `/kai:spec <KEY>`.
- If any `*.kai-new` files were written, list them and offer to merge each one.
