# Piloting Kai in a repository

How to install Kai in a real repository to try it, measure it, and send back feedback. Kai installs as a Claude Code plugin; you don't need to clone this repository.

## 1. Before you start

- **Tools.** You need Claude Code, `git`, and `jq`, and read access to `MakaiDigital/kAI` on GitHub while it is private.
- **The pilot repository.** Pick one that has a working test command and a few upcoming tickets. Small to medium changes are ideal.
- **Approval.** Kai builds on Superpowers, a community plugin, and its spec skill can read Jira or Linear through connectors. Check with your security team that both are approved before they touch company code.
- **A pilot branch.** Work on a separate branch in the pilot repository, for example `kai-pilot`, so nothing Kai-specific reaches its main branch until you decide to keep it.

## 2. Record a baseline

Before using Kai, note these for three to five recently finished tickets. Without a baseline you can't tell whether Kai helped.

| Ticket | Lead time (start to merge) | Review rounds | Human hours | Defects found after merge |
|---|---|---|---|---|
| | | | | |

## 3. Install the plugin (once per machine)

```sh
claude plugin marketplace add MakaiDigital/kAI
claude plugin install kai@makaidigital
```

This also installs Superpowers and feature-dev, which Kai builds on. Check with `claude plugin list`.

## 4. Set Kai up in the pilot repository

```sh
cd ~/path/to/pilot-repo
git switch -c kai-pilot
claude
```

Then, in Claude Code:

```
/kai:setup 1
```

Claude detects your ticket system, project prefixes, and test commands from the repository and asks you to confirm them. It previews the changes with `kai init --dry-run` and then writes them. It also proposes which paths in `.kai/tiers` are high risk (authentication, payments, migrations, public APIs), and commits everything on the pilot branch as `Set up Kai (level 1)`.

- **What it writes:** `.kai/config`, `.kai/tiers`, `.kai/constraints.md`, a block in `CLAUDE.md`, the marketplace and plugin entries in `.claude/settings.json`, and the CI workflow. Teammates who open the repository are prompted to install Kai.
- **CI while `MakaiDigital/kAI` is private:** the `kai` workflow uses its `kai-gates` action, which works because the repository allows access from the organization's repositories. The `kai review` workflow needs nothing from `kAI`: it runs the review agents setup copies into `.claude/agents/`.
- **Checking it works:** ask Claude "what's the next Kai step?". At the start of every session Kai tells Claude which ticket the branch is for and what comes next, so a sensible answer shows the hooks are running.

## 5. Run real tickets, one level at a time

Follow [using-kai.md](using-kai.md) for each ticket, and raise the level once the previous one feels routine.

| Week | Level | Try |
|---|---|---|
| 1 | 1 | `/kai:spec`, `/kai:implement` on two or three tickets |
| 2 | 2 | `/kai:spec` for medium-risk tickets, the two-PR flow, tuning `.kai/tiers` |
| 3 | 3 | Locked tests, the `contract` check, local review in `/kai:implement` (the CI review needs hosting, see below) |
| 4 | 4 | `/kai:accept` after a deploy (verify, QA, cleanup PR), `/kai:retro` for a sprint view, `kai metrics` |

To change level, run `/kai:setup <level>` again, or edit `KAI_LEVEL` in `.kai/config`.

## 6. Capture feedback

Keep one entry per ticket in a notes file outside the repository, or in a shared doc. Copy this template:

```markdown
## <TICKET-KEY>: <one-line summary>

- Level: <1-4>  Tier: <low/medium/high>
- Lead time: <start to merge>  Human hours: <estimate>
- Compared with the baseline: <faster / same / slower>, and why

### What worked
-

### What got in the way
- Skills that didn't start when they should have, or started when they shouldn't:
- Hook or check blocks that were wrong, or ones that should have fired and didn't:
- Plans that were too big or too vague, or tests that didn't match what you meant:
- Specs, or evidence you had to rewrite, and why:

### Evidence
<paste the relevant part of the transcript, a screenshot, or the file you had to fix>
```

The pasted transcript or file is what makes feedback actionable. "It planned badly" is hard to fix; the plan it produced, next to what you expected, is easy.

## 7. Bring the feedback back

- Open a Claude Code session in this repository and share the notes, by pasting them or pointing at the file. Each problem becomes a fix to a skill, hook, or check, plus an eval case in `plugins/kai/evals/` so it stays fixed.
- After a few tickets have merged in the pilot, run `kai metrics` and `/kai:retro` there for the data-driven view, and share those too.
- **Picking up fixes.** When a new version is released, run `claude plugin update kai@makaidigital` (or `/plugin`) and start a new session. Then run `/kai:setup` again to pick up changes to the repository files; anything that differs lands in `*.kai-new` for you to merge.

## Removing Kai

Delete these from the pilot repository, or simply drop the pilot branch:
- `.kai/`
- the kai block in `CLAUDE.md`
- the `makaidigital` and `kai@makaidigital` entries in `.claude/settings.json`
- `.claude/agents/contract-reviewer.md` and `spec-critic.md`
- `.github/workflows/kai*.yml`
- `REVIEW.md`

## Testing unreleased changes from a clone

People working on Kai itself can point a pilot at their local clone instead of a release. Changes then apply after `/reload-plugins`, with no release step:

```sh
claude plugin marketplace add ~/Development/Makai/kai
claude plugin install kai@makaidigital
```

Run `/kai:setup`, and ask it to use `--marketplace ~/Development/Makai/kai`. The resulting `.claude/settings.json` contains your local path, so keep that on the pilot branch only.

## Moving past the pilot

- Make the `kai-gates` action accessible to the organization's repositories, or make `MakaiDigital/kAI` public, so the CI checks run.
- For the level 3 AI review, add a Claude credential as a repository secret, pointed at an endpoint your security team has approved.
