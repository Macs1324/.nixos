---
description: Scout → plan → implement → verify → review pipeline for a non-trivial change
argument-hint: <what to build>
---

Build this: $ARGUMENTS

Run the standard pipeline. Skip a phase only when it is obviously unnecessary, and say that you skipped it.

1. **Scout** — delegate to `scout` to map the relevant files, conventions, and tests. Do not read the codebase yourself yet.
2. **Plan** — hand the brief to `architect`. Show me the plan's Goal, Approach, and Steps and wait for my go-ahead before writing code. If the plan has open questions, ask them now, all at once.
3. **Implement** — if the plan's Parallelism section lists independent steps with disjoint files, spawn one `implementer` per step as a team with each owning its files; otherwise use a single `implementer`. Pass each one the full plan and its assignment.
4. **Verify** — delegate to `verifier`. If anything fails, send the verbatim failure back to the responsible `implementer` and repeat. Stop after two fix rounds and report.
5. **Review** — delegate to `reviewer`. Fix confirmed findings via `implementer`, re-verify.
6. **Report** — what changed (files), what was verified (commands), what was deliberately left out. Do not commit.
