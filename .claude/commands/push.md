---
description: Push current branch to GitHub (snirsh/pasted)
---

Push the current branch to the remote and report the result.

## Current state

- Branch: !`git branch --show-current`
- Unpushed commits: !`git log @{u}..HEAD --oneline 2>/dev/null || git log HEAD --oneline -5`

## Steps

1. Show what commits will be pushed
2. Push to origin
3. Report the remote URL / PR link if available

Push the branch now. If no upstream is set, use `git push -u origin <branch>`.
