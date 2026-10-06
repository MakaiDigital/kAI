# Contributing to Kai

Thanks for helping. Kai is below 1.0 and is being proven on Makai's own projects first, so skills, commands, and file formats can still change between minor versions.

## Before you start

- **Bugs, questions, and ideas:** open an [issue](https://github.com/MakaiDigital/kAI/issues). For a bug, include the Kai version (`claude plugin list`), your Claude Code version (`claude --version`), the level in `.kai/config`, and what Claude produced (the transcript, plan, or file) next to what you expected. "It planned badly" is hard to fix. The plan it produced is easy.
- **Pull requests:** send small fixes directly. For anything bigger, such as a new skill, hook, gate, or `kai init` option, or a change to the flow, open an issue first so we can agree on the approach before you spend time on it.
- **Security vulnerabilities:** don't open a public issue. [Report them privately](https://github.com/MakaiDigital/kAI/security/advisories/new) instead.

## Design principles

Kai stays thin on purpose. Check a change against these before you write it:

- **Assemble, don't build.** If a maintained plugin already does the job (Superpowers, or one of Anthropic's official plugins), pin it in the marketplace rather than writing our own.
- **Skill text before code.** Add a hook, gate, or script only for a rule that must always hold and that GitHub (branch protection, reviews, CODEOWNERS) can't enforce. Everything else is an instruction in a skill.
- **Nothing extra to install.** Scripts are POSIX `sh` and `jq`, so Kai needs nothing beyond Claude Code, `git`, `jq`, and `gh`.

## Set up

You need `git` 2.36 or newer, `jq`, `shellcheck`, `bats`, and Claude Code.

```sh
brew install jq shellcheck bats-core    # or: apt-get install jq shellcheck bats
```

Fork the repository and clone your fork. To try your changes in a real repository without releasing them, point it at your clone, as described in [Testing unreleased changes from a clone](docs/pilot.md#testing-unreleased-changes-from-a-clone).

```
.claude-plugin/marketplace.json   the makaidigital marketplace: kai plus pinned upstream plugins
plugins/kai/                      the plugin: skills, hooks, templates, bin/kai, scripts
plugins/kai/template/             files kai init writes into a repository
plugins/kai/evals/                skill eval cases
plugins/kai-product/              Kai for Product: spec skill for claude.ai and Cowork
actions/kai-gates/                composite GitHub Action used by the installed workflow
tests/bats/                       tests for the CLI, hooks, gates, and kai init
```

## Making a change

Read the Gotchas in [CLAUDE.md](CLAUDE.md) before your first change. They're written for Claude, but they apply to you too: scripts must run under POSIX `sh` and tests under macOS bash 3.2, CI uses an older shellcheck than Homebrew, and several literal strings are shared between skills, templates, and scripts.

- **Tests.** A change to the CLI, a hook, a gate, or `kai init` needs a bats test in `tests/bats/`.
- **Skills.** A change to a skill, template, or hook needs an eval case in `plugins/kai/evals/` (or `plugins/kai-product/evals/`) that would have caught the problem, so it stays fixed.
- **Versions.** Bump `version` in a plugin's `.claude-plugin/plugin.json` in any pull request that changes the plugin outside its `evals/`: a patch for a fix, a minor for anything else until 1.0. CI checks this, and counts `actions/kai-gates/` as part of `kai`. Installed users only receive a new version, and merging to main tags `kai`'s `v<version>`, which `kai init` pins repositories to.
- **Upstream pins.** Bump a pin in `.claude-plugin/marketplace.json` in its own pull request, so it's reviewed on its own.
- **Docs.** If you change what users see, update the [README](README.md) or [Using Kai](docs/using-kai.md) in the same pull request.

### Run the checks

CI runs these on Ubuntu and macOS:

```sh
shellcheck plugins/kai/bin/kai plugins/kai/scripts/*/*.sh
shellcheck -s bash plugins/kai/evals/*/scaffold.sh plugins/kai/evals/_fixture/make_repo.sh
bats tests/bats
claude plugin validate . && claude plugin validate plugins/kai && claude plugin validate plugins/kai-product
```

### Run the skill evals

Each case under `plugins/kai/evals/` builds a small fixture repository (`_fixture/make_repo.sh`), sends a realistic prompt, and grades the resulting files and git commands. CI doesn't run them, so run them yourself whenever a skill, template, or hook changes:

```sh
claude plugin eval plugins/kai --scaffold --allow-tools Bash Write Edit --trust-plugin
```

This makes real model calls with your credentials: by default 3 runs per case, plus the same again without the plugin for comparison. Add `--runs 1 --ablation none` for a quick check.

Run the suite on Linux (a CI runner, WSL, or a container). On macOS the eval sandbox blocks Apple's `/usr/bin/git` wrapper, so every case that commits fails there.

## Pull requests

- Keep each pull request to one change.
- Title it in [Conventional Commits](https://www.conventionalcommits.org/) form, scoped by plugin: `fix(kai): …`, `feat(kai-product): …`, `docs: …`.
- Say what changed and why. For a skill change, list the eval cases you ran and their results.
- Sign off every commit (see below).
- CI must pass, and a maintainer reviews and merges every pull request.

### Sign off your commits

Kai uses the [Developer Certificate of Origin](https://developercertificate.org/) (DCO). Signing off certifies that you wrote the change, or otherwise have the right to submit it under the project's license. Add the sign-off with `git commit -s`, which appends this line using your git `user.name` and `user.email`:

```
Signed-off-by: Your Name <you@example.com>
```

If you forgot, run `git commit --amend -s` for the last commit, or `git rebase --signoff origin/main` for every commit on your branch, then force-push.

### AI-assisted contributions

Kai is built with Claude Code, and you're welcome to use it or any other assistant. You're responsible for every line you submit: read it, run the checks, and be ready to explain it in review. Your sign-off covers AI-generated code too. Claude Code picks up the repository's gotchas from [CLAUDE.md](CLAUDE.md).

## License

Contributions are licensed under the [Apache License 2.0](LICENSE), the same as the project.
