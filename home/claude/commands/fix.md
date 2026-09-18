---
description: Reproduce, root-cause, fix, and regression-test a bug
argument-hint: <bug description, error output, or issue link>
---

Fix this bug: $ARGUMENTS

1. **Reproduce** — delegate to `verifier` to reproduce the failure and capture the exact output. If it cannot be reproduced, stop and tell me what was tried.
2. **Root cause** — delegate to `scout` with the failure output to locate the code path. Then read the relevant code yourself and state the root cause in one or two sentences, with `path:line`. A fix without a stated root cause is not acceptable.
3. **Fix** — the smallest change that addresses the cause, not the symptom. Use `implementer` if it spans several files; otherwise do it directly.
4. **Regression test** — add a test that fails without the fix and passes with it, in the repo's existing test style. If the repo has no test infrastructure for this area, say so instead of inventing one.
5. **Verify** — `verifier` runs the new test plus the surrounding suite.
6. **Report** — root cause, the change, the test, verbatim verification output. Do not commit.
