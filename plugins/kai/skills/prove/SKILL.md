---
name: prove
description: Prove a ticketed change works in a Kai repository (one with a .kai/config) before anyone calls it done. It runs the team's checks with kai verify, writes specs/<KEY>/evidence.md, maps every planned test and spec criterion to a quoted passing line, and updates the spec's contract. Use it whenever implementation looks finished, before committing the final work or opening a pull request, or when someone asks "does it work?", "are we done?", or asks to prove, check, or confirm a ticketed change. Prefer it over a generic verify in Kai repositories.
argument-hint: [TICKET-KEY]
---

# Prove

"Done" means evidence, not assertion. "All tests pass" is a claim; the command output that shows each planned test passing is evidence. Follow `superpowers:verification-before-completion` throughout.

If the repository has no `.kai/config`, it does not use Kai. Say so and verify directly.

## 1. Run the checks until they pass

- Get the key from `$ARGUMENTS` or `kai key`.
- Run `kai verify --evidence specs/<KEY>/evidence.md`. It runs the team's checks (`KAI_VERIFY_CMDS` in `.kai/config`) from the repository root and records each command, its exit code, and its output. It rewrites the file on every run.
- If anything fails, find the cause with `superpowers:systematic-debugging`, fix it, and run again. Getting green by editing or skipping a test, or by trimming `KAI_VERIFY_CMDS`, hides the failure rather than fixing it.
- If a failure is genuinely unrelated to this change, show that it also fails on the base branch, and say so plainly rather than leaving it out.

## 2. Map the results to the plan

After the final verify run, since each run rewrites the file, append this section to `evidence.md` with one row for each test in the plan's Tests table:

```markdown
## Planned tests

| Criterion | Test | Result | Output line |
|---|---|---|---|
| C1 | `rejects_expired_token` | PASS | `✓ rejects_expired_token (4 ms)` |
| C2 | `saves_favorite_on_tap` | MISSING | not found in output |
```

- **PASS** needs the quoted output line that shows the test passing. The quote is what makes it checkable by someone else.
- **MISSING** means the test is not in the output. It was never written, never ran, or was renamed without updating the plan. Treat it as a failure.
- **Tests can't show some behaviors** named in the intent or spec, such as a UI flow or a real integration. Run the end-to-end procedure (or describe exactly what you checked) and record what you observed.

If `specs/<KEY>/spec.md` exists, bring its Contract table in line. Set a row to PASS only when it has a quoted output line or recorded observation, and fill its Evidence column. Change only the Status and Evidence columns, and keep every criterion's row: dropping a row would quietly redefine the feature.

## 3. Report

- Commit `evidence.md` and any spec contract updates as `<KEY>: evidence`.
- Give the result in one line (PASS or FAIL, with counts), point to `specs/<KEY>/evidence.md`, and list anything failing or MISSING.
- Only when everything passes, point to the next step: `/kai:ship` at `KAI_LEVEL` 3 or higher, otherwise push the branch and open a pull request that links the intent, spec, plan, and evidence.
