---
description: Verify, review, and commit the current work (never pushes)
argument-hint: [optional commit message hint]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

Prepare the current changes for a commit. Hint: $ARGUMENTS

Context:
- Status: !`git status --short`
- Recent commit style: !`git log --oneline -8`

1. Delegate to `verifier`. If anything the change touches fails, stop and report; do not commit broken work.
2. Delegate to `reviewer`. If there are findings, show them to me and stop; do not commit over known bugs.
3. Stage only the files that belong to this change. Never `git add -A` when unrelated files are dirty.
4. Write a commit message in the style of the recent log (short, lowercase, imperative for this repo unless the log shows otherwise). Body only if the why is not obvious from the diff.
5. Commit. Do not push.
