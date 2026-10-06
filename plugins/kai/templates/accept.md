# Acceptance: {{KEY}} <title>

<!-- A working file: never commit it. Its summary goes in the cleanup PR's description. -->

- **Environment:** <integration environment and the commit it runs>
- **Run:** <date>, cycle <n>
- **Verdict:** Pending <!-- Pass | Fail -->

## Verification

For each step of the spec's end-to-end verification: what was run, what came back, and which criteria it shows.

### 1. <step>

~~~text
<command and output>
~~~

Shows: C1, C2. Observed: <what happened>

## Criteria

| Criterion | Observed | Holds? |
|---|---|---|
| C1 | <what was seen> | yes / no |

## Attempts to break it

| Attempt | Result |
|---|---|
| <what was tried> | held / broke: <what happened> |

## Failures

<Each failure with exact reproduction steps and output, and the fix PR that addressed it. "None" if all held.>
