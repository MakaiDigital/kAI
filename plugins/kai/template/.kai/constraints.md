# Implementation constraints

The minimal-code standard. It applies to every change, whoever or whatever writes it.

- Implement only what the ticket (and spec, when there is one) requires. No functionality, configuration, or flags that nothing asks for.
- Prefer the smallest change that makes the tests pass. Modify existing code before adding new code.
- No new files, modules, or dependencies unless the approved plan lists them.
- No abstraction for a single use. Extract a helper once three similar call sites exist, not before.
- No speculative generality: no interfaces with one implementation, no plugin points, no future-proofing.
- Handle the error cases the ticket or spec names. Do not add defensive handling for states that cannot occur.
- Reuse what the codebase already has (HTTP client, logger, test helpers) instead of adding a second one.
- Do not refactor outside the task. Note it for a separate ticket instead.
- No comments that restate the code, no docstrings on trivial functions, no logging nobody asked for.
- If you see a simpler approach than the plan's, propose it in the plan, or, when it appears later, update the plan and say so.
- Before finishing, trace every added file, function, and dependency to the plan. Remove anything that does not trace.
- **Exception for security-sensitive code** (authentication, authorization, payments, secrets, trust boundaries): fail closed and validate all inputs, even where the ticket is silent.
