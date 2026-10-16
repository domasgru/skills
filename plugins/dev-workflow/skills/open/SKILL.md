---
name: open
description: "Open the session's checkout (main or worktree) in Xcode or VS Code, at the file under discussion."
disable-model-invocation: true
metadata:
  internal: true
---

The **checkout** is the directory `git rev-parse --show-toplevel` prints: the main checkout or the worktree the session is in. The **focus file** is the file the conversation is centred on right now, with its line when one was named. Resolve it inside the checkout: a path that points into another checkout keeps its repo-relative part. No file under discussion means no focus file.

1. **Pick the IDE.** Xcode for Apple code: a focus file in Swift, Objective-C, a storyboard or an asset catalog, or, with no focus file, a checkout holding an `.xcworkspace`, `.xcodeproj` or `Package.swift`. VS Code for everything else.
2. **Open it.**
   - **Xcode**: the project is the one that runs an app, so the human can press Run: an `.xcworkspace`, else an `.xcodeproj`, else an XcodeGen `project.yml` (generated projects are usually gitignored, so a fresh worktree lacks them: run `xcodegen generate` in its directory first, which creates the `.xcodeproj` to open). Search the whole checkout, skipping build directories. When several apps exist, the one whose target holds the focus file, else the macOS one. A bare `Package.swift` directory is the project only when no app project exists: an app project already shows its local packages' sources, and Xcode lets only one window own a local package, so opening the package beside the app breaks the app's build with "Missing package product". Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xed -p <project> -l <line> <focus file>`, dropping `-l` without a line and the file without a focus file; the variable lets `xed` run even when `xcode-select` points at the Command Line Tools.
   - **VS Code**: run `code <checkout> -g <focus file>:<line>`, dropping `-g` and its argument without a focus file.

Done when the command exits 0. Report the IDE, the checkout, and the focus file it opened.
