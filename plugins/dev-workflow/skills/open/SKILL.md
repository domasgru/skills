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
   - **Xcode**: the project is the `.xcworkspace`, else the `.xcodeproj`, else the `Package.swift` directory, nearest the checkout root; when several exist, the one whose target holds the focus file. Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xed -p <project> -l <line> <focus file>`, dropping `-l` without a line and the file without a focus file; the variable lets `xed` run even when `xcode-select` points at the Command Line Tools.
   - **VS Code**: run `code <checkout> -g <focus file>:<line>`, dropping `-g` and its argument without a focus file.

Done when the command exits 0. Report the IDE, the checkout, and the focus file it opened.
