# Review guidelines

Read by the `contract-reviewer` agent locally (`/kai:implement`) and in CI. Owned by the tech lead; tune it when reviews get noisy or miss things.

## What to review

1. Evidence: every PASS in the contract matches a passing test in `kai verify` output.
2. Scope: every changed file, function, and dependency traces to a criterion or planned task.
3. Decisions: ADRs and existing patterns are followed; existing helpers are reused.
4. Correctness: logic errors, unhandled error paths the criteria name, empty or null input, off-by-one errors, races.
5. Security: injection (SQL, command, template), cross-site scripting, broken authentication or authorization, secrets in code, server-side request forgery, path traversal, insecure deserialization, sensitive data in logs.
6. Performance: N+1 queries, unbounded queries or loops, missing indexes on new queries, resource leaks, quadratic work on hot paths.

## Severities

- **blocking**: the contract is not actually met, the change is wrong, or it adds unplanned scope.
- **note**: worth knowing; the author decides.

## Skip

- Formatting and naming (linters own these).
- Generated files and lockfiles.
