## How we deliver (Kai)

- Kai's workflow (ticket, spec, plan, failing tests, evidence, pull request) runs only when someone types one of its commands: `/kai:spec`, `/kai:implement`, `/kai:prove`, `/kai:accept`, `/kai:retro`, or `/kai:adr`. Otherwise, handle the request directly, without specs, plans, or evidence files. If someone asks for that work in words, name the command that does it.
- In every session: never push to the base branch, merge or approve a pull request, add the `kai:tests-changed` label, or bypass git hooks.
- This repository's `kai` CI check needs a ticket key in the branch name or pull request title, and from level 2 a merged spec and plan for medium and high tier code.
