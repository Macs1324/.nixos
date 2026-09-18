---
description: Correctness and security review of the current diff or a given target
argument-hint: [branch, commit range, PR number, or path — defaults to uncommitted changes]
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(gh pr:*)
---

Review target: $ARGUMENTS (if empty: `git diff HEAD` plus untracked files).

Run `reviewer` and `security-reviewer` in parallel on the same target. When both return:

1. Merge their findings, removing duplicates.
2. For each finding, open the file and confirm it yourself. Drop anything you cannot confirm.
3. Present the confirmed list ranked by severity, each as `path:line — problem — trigger — fix`.
4. End with a one-line verdict: ship / fix first / needs discussion.

Do not apply fixes. Do not pad the list with style comments.
