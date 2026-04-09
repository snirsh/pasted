---
description: Build and reinstall Pasted.app to /Applications
---

Build the project and reinstall to `/Applications/Pasted.app`.

## Steps

1. Run `make install` from the project root
2. Report the result — build success/failure, any errors
3. Remind the user to relaunch the app (kill existing instance first)

## Command

!`cd /Users/snirs/.superset/worktrees/pasted/Snir-Sharristh/use-httpsgithub.comgithubspec-kit-in-order-to-kick && make install 2>&1 | grep -E "(error:|warning:|BUILD|Installed|IMPORTANT)"`

Report results. If build failed, show the full errors and diagnose the issue.
