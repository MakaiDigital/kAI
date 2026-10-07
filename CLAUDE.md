# kAI

The repository for Kai's Claude Code plugins (`plugins/kai`, `plugins/kai-product`), the `makaidigital` marketplace, and the CI action. `kai init` (driven by `/kai:setup`) sets up a repository.

## Check before committing

```sh
shellcheck plugins/kai/bin/kai plugins/kai/scripts/*/*.sh
shellcheck -s bash plugins/kai/evals/*/scaffold.sh plugins/kai/evals/_fixture/make_repo.sh
bats tests/bats
claude plugin validate . && claude plugin validate plugins/kai && claude plugin validate plugins/kai-product
```

## Gotchas

- Keep it simple. Add a gate or script only for a rule that must always hold and that GitHub (branch protection, reviews, CODEOWNERS) cannot enforce. Otherwise put it in a skill.
- `plugins/kai/scripts/**` are sourced by `bin/kai`, not executed, so variables cross files. That is why each script's `# shellcheck` header disables SC2034/SC2154. Keep those disables per file, never in `.shellcheckrc`.
- Scripts must run under POSIX `sh`, and tests under macOS bash 3.2: no negative array indexes, no `timeout`, and `sed -i` only with a backup suffix.
- CI's Ubuntu job installs shellcheck 0.9.0 from apt, which still flags notes that brew's 0.11 doesn't (for example SC2015 on `A && B || C`). Write an `if` instead, or check with 0.9.0 before pushing.
- In `bin/kai`, the hook preamble reads fields from a heredoc that drops trailing empty lines. Every `read` there needs `|| :`, or hooks die under `set -e` when a field is empty.
- Plugin `dependencies` belong on the marketplace entry, never in `plugin.json`. Declared in the manifest, they stop the plugin loading anywhere they aren't installed, including `claude plugin eval` runs.
- Superpowers is listed through a `git-subdir` source pointing at its `skills/` folder, with the chosen skills named on the entry. That is how we load a subset without its hooks; `strict: false` cannot do it.
- `plugins/kai-product/templates/*` must stay byte-identical to `plugins/kai/templates/*` (a test checks). A top-level `bin/` stops claude.ai and Cowork from installing `kai-product`, chat ignores hooks, and its skills can't run `kai`.
- Bump `version` in a plugin's `plugin.json` whenever you change it (CI checks). Installed users only receive a new version. Merging to main tags `v<version>` (CI), and `kai init` pins repositories to the commit that tag points at, so a version with no tag breaks every new install.
- Skill evals (`claude plugin eval plugins/kai --scaffold --allow-tools Bash Write Edit --trust-plugin`) cost real model calls. On macOS the eval sandbox breaks Apple's git wrapper, so the cases that commit only pass on Linux.
- `kai init` copies `plugins/kai/agents/*.md` into repositories (level 3) so the CI review needs no plugin install. Keep those agents self-contained: no `kai` commands or plugin paths.
- Skills, templates and scripts share literal strings: the `<KEY>: failing tests` subject, `Result: **PASS**`, the `kai verify on commit <sha>` line, the plan's `## Tests` table, the `## Planned tests` and `## Contract` tables, the `<!-- kai-review -->` marker and the `Reviewed commit` line. Change both sides together.
- CI judges a PR by the base branch's `.kai/config` and `.kai/tiers` (the action restores them), and the CI review reads `REVIEW.md`, `CLAUDE.md` and its agents from the base branch. Workflow files still run as the PR has them, so a PR can change its own checks until CODEOWNERS or a ruleset covers `.github/workflows/`.
- `/kai:accept` deletes a ticket's `specs/<KEY>/`, so anything that reads specs from the base branch (`kai metrics`, gates, retros) must also work from git history or tolerate their absence. The cleanup PR passes the gates only because it changes nothing but Markdown; there is no exemption for it.
- Everything else that ends up in a user's repository lives in `plugins/kai/template/`. `kai init` writes `*.kai-new` next to a file that differs, except a workflow that differs only in its `kai-gates` or `claude-code-action` ref, which it updates in place. Keep its `CLAUDE.md` block markers unchanged, or existing repositories get a second block.
