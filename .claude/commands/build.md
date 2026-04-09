---
description: Build Pasted without installing (faster feedback loop)
---

Run a release build and report any errors. Does not copy to /Applications.

## Command

!`cd /Users/snirs/.superset/worktrees/pasted/Snir-Sharristh/use-httpsgithub.comgithubspec-kit-in-order-to-kick && xcodebuild -project Pasted.xcodeproj -scheme Pasted -configuration Release build 2>&1 | grep -E "(error:|warning: |BUILD SUCCEEDED|BUILD FAILED)" | head -40`

If there are errors, show them in full and diagnose. If build succeeded, confirm briefly.
