---
description: Build, reinstall, and relaunch Pasted.app
---

Build the latest code, replace /Applications/Pasted.app, and relaunch it.

## Commands

Kill any running instance, build, install, then open:

!`cd /Users/snirs/.superset/worktrees/pasted/Snir-Sharristh/use-httpsgithub.comgithubspec-kit-in-order-to-kick && make install 2>&1 | grep -E "(error:|BUILD|Installed)"`

!`open /Applications/Pasted.app`

Report: build succeeded or show errors. Confirm the app relaunched.
If build failed, show full error output and diagnose.
