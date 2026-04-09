---
description: Clean derived data then reinstall Pasted (fixes stale build artifacts)
---

Use when the build has stale artifacts or behaves unexpectedly after code changes.

## Steps

1. Kill any running Pasted instance
2. Clean DerivedData for the project
3. Regenerate the Xcode project from project.yml
4. Build and install

## Commands

!`pkill -x Pasted 2>/dev/null; echo "Killed Pasted (or wasn't running)"`

!`cd /Users/snirs/.superset/worktrees/pasted/Snir-Sharristh/use-httpsgithub.comgithubspec-kit-in-order-to-kick && make clean && make install 2>&1 | grep -E "(error:|BUILD|Installed|IMPORTANT)"`

Report the result.
