# kAI

The repository for Kai's Claude Code plugins (`plugins/kai`, `plugins/kai-product`), the `makaidigital` marketplace, and the CI action. `kai init` (driven by `/kai:setup`) sets up a repository.

## Check before committing

```sh
shellcheck plugins/kai/bin/kai plugins/kai/scripts/*/*.sh
bats tests/bats
claude plugin validate . && claude plugin validate plugins/kai && claude plugin validate plugins/kai-product
```

## Gotchas

- Keep it simple. Add a gate or script only for a rule that must always hold and that GitHub (branch protection, reviews, CODEOWNERS) cannot enforce. Otherwise put it in a skill.
- `plugins/kai/scripts/**` are sourced by `bin/kai`, not executed, so variables cross files. That is why each script's `# shellcheck` header disables SC2034/SC2154. Keep those disables per file, never in `.shellcheckrc`.
- Scripts must run under POSIX `sh`, and tests under macOS bash 3.2: no negative array indexes, no `timeout`, and `sed -i` only with a backup suffix.
- In `bin/kai`, the hook preamble reads fields from a heredoc that drops trailing empty lines. Every `read` there needs `|| :`, or hooks die under `set -e` when a field is empty.
- Plugin `dependencies` belong on the marketplace entry, never in `plugin.json`. Declared in the manifest, they stop the plugin loading anywhere they aren't installed, including `claude plugin eval` runs.
- Superpowers is listed through a `git-subdir` source pointing at its `skills/` folder, with the chosen skills named on the entry. That is how we load a subset without its hooks; `strict: false` cannot do it.
- `plugins/kai-product/templates/*` must stay byte-identical to `plugins/kai/templates/*` (a test checks). `kai-product` must have no `bin/`, hooks, or shell commands, or claude.ai and Cowork will not install it.
- Bump `version` in a plugin's `plugin.json` whenever you change it. Installed users only receive a new version.
- Skill evals (`claude plugin eval plugins/kai --scaffold --allow-tools Bash Write Edit --trust-plugin`) cost real model calls. On macOS the eval sandbox breaks Apple's git wrapper, so the cases that commit only pass on Linux.
- `kai init` copies `plugins/kai/agents/*.md` into repositories (level 3) so the CI review needs no plugin install. Keep those agents self-contained: no `kai` commands or plugin paths.
- Everything else that ends up in a user's repository lives in `plugins/kai/template/`. `kai init` never overwrites a file; it writes `*.kai-new` next to one that differs. Keep its `CLAUDE.md` block markers unchanged, or existing repositories get a second block.
