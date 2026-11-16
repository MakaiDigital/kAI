# Prove

"Done" means evidence, not assertion. "All tests pass" is a claim; the command output that shows each planned test passing is evidence. Follow `superpowers:verification-before-completion` throughout.

If the repository has no `.kai/config`, it does not use Kai. Say so and verify directly.

## 1. Run the checks until they pass

- Get the key from the command's arguments, or from `kai key`.
- Commit your work first: `kai verify --evidence` refuses to describe uncommitted changes. Files the checks themselves leave behind (coverage, reports) belong in `.gitignore`, added in a commit of their own; never commit them with the work.
- Run `kai verify --evidence docs/specs/<KEY>/evidence.md`. It runs the team's checks (`KAI_VERIFY_CMDS` in `.kai/config`) from the repository root and records each command, its exit code, and its output. It rewrites the file on every run.
- If anything fails, find the cause with `superpowers:systematic-debugging`, fix it, and run again. Getting green by editing or skipping a test, or by trimming `KAI_VERIFY_CMDS`, hides the failure rather than fixing it.
- If a failure is genuinely unrelated to this change, show that it also fails on the base branch, and say so plainly rather than leaving it out.
- A test that fails and then passes on a second run is flaky, not fixed. Do not run it again until it passes, add a sleep or a retry, or skip it. Find the root cause. If you cannot, stop and show the person the runs: deleting or changing the test is their decision, and the PR description gives the reason.

## 2. Run the change

Passing tests show that the code matches the tests. Running the change shows that the feature works, so do both before the PR, not after the merge.

- Start the application the way the repository's `verify` skill says (`.claude/skills/verify/`, or a `verify` skill in a `.claude/skills/` folder nearer the code you changed). Without one, start it the way the README or `CLAUDE.md` says, and tell the person that `/kai:setup` writes the skill.
- Run each step of the spec's **End-to-end verification** that can run here: the browser for a screen, a request for an endpoint, the command for a tool. Without a spec, run what the plan's Verification section names. The criteria are the grading rubric: look for the observable response each one states, and try the unhappy paths they name.
- A step only the deployed system can show (real traffic, a production alert) stays for `/kai:accept`. Record it as LATER, never as PASS.
- If a step fails, the feature is broken even when every test passes. Fix it, add the test that would have caught it when one is missing (ask the person first when that changes a locked test), and start again from step 1.
- When nothing can run (a library with no entry point, a change to documents only), say so with the reason. Do not invent a run.

After the final verify run, since each run rewrites the file, append this section to `evidence.md`:

```markdown
## Observed

| Step | Criteria | What was run | What was seen | Result |
|---|---|---|---|---|
| 1 | C1, C2 | `curl -s -X POST localhost:3000/favorites -d '{"id":7}'` | `201 {"id":7,"saved":true}` | PASS |
| 3 | C4 | not run: needs production traffic | for acceptance | LATER |
```

- **What was seen** quotes the output, or says what the screen showed. Use synthetic data.
- With nothing to run, write `No end-to-end run: <reason>.` under the heading instead of the table.

## 3. Map the results to the plan

Then append this section to `evidence.md` with one row for each test in the plan's Tests table:

```markdown
## Planned tests

| Criterion | Test | Result | Output line |
|---|---|---|---|
| C1 | `rejects_expired_token` | PASS | `✓ rejects_expired_token (4 ms)` |
| C2 | `saves_favorite_on_tap` | MISSING | not found in output |
```

- **PASS** needs the quoted output line that shows the test passing. The quote is what makes it checkable by someone else.
- **MISSING** means the test is not in the output. It was never written, never ran, or was renamed without updating the plan. Treat it as a failure.
- **Tests can't show some behaviors** named in the ticket or spec, such as a UI flow or a real integration. The Observed table shows them: name its step as the evidence.

If `docs/specs/<KEY>/spec.md` exists, bring its Contract table in line. Set a row to PASS only when it has a quoted output line or an Observed step with Result PASS, and fill its Evidence column. Change only the Status and Evidence columns, and keep every criterion's row: dropping a row would quietly redefine the feature. Every quoted line must appear in the `evidence.md` committed with it, so redo steps 2 and 3 after any later `kai verify` run: quotes from an earlier run are the stale evidence reviewers send back.

## 4. Report

- If the output in `evidence.md` shows a secret or personal data, stop and ask the person before committing it.
- Commit `evidence.md` and any spec contract updates as `<KEY>: evidence`. End the commit message with a trailer that says how the change was verified: `Verified: checks, end-to-end` when the Observed table has a PASS step, otherwise `Verified: checks`. `git log --grep '^Verified: checks$'` then lists the changes nobody watched run.
- Give the result in one line (PASS or FAIL, with counts, and how many end-to-end steps were observed), point to `docs/specs/<KEY>/evidence.md`, and list anything failing, MISSING or LATER.
- Only when everything passes, point to the next step: `/kai:implement` continues from here (independent review, the pull request, and answering its reviews).
