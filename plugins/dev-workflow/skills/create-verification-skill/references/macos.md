# macOS apps (and browser extensions they talk to)

Pitfalls met while generating a verification skill for a SwiftUI/AppKit app with a Chrome extension. Each one cost a wrong step, a hung script or a risk to the user's real data. The generated skill handles every item that applies, and says which items don't.

## Tests first

- A Mac app with a UI-test target (`XCUITest`) already has the robust driver for single-app journeys: in-process waits, `doubleClick()`, `typeKey`, isolated launch environments, and CI. A journey that stays inside the app belongs there, as a test, not as a recipe. Check the scenario or engine tests first: they usually prove the behaviour already. What a UI test adds is the wiring: the control is there, and clicking it reaches the code those tests prove. The repo's testing plan may already list that gap (e.g. "no UI test clicks a control"). Point to it rather than inventing a broader suite.
- The accessibility driver the skill ships is for exploration, cross-app paths, screenshots and one-off proof. Keep it small: read, wait, press, double-click a row, the panel's Go to Folder, a few keys and screenshots.

## Isolation

- Find the debug-only switches for the data dirs: environment variables read in `#if DEBUG`, or launch arguments. Release builds usually ignore them. Build Debug.
- Launch the binary directly (`App.app/Contents/MacOS/App`) with `nohup … </dev/null >log 2>&1 &`, so the run owns the pid. `open -n` hides the pid and puts LaunchServices in between.
- Resolve scratch paths before handing them over: `/tmp` and `/var` are symlinks to `/private/...`, and an app that records real paths will disagree with you otherwise.
- **State that escapes the data-dir switches:** the app's `UserDefaults` domain (its bundle id) is the user's own, whatever the switches say. Neither `CFFIXED_USER_HOME` nor argument-domain launch arguments redirect what AppKit reads for it. The worst case is `NSOpenPanel`'s remembered folder (`NSOSPLastRootDirectory`, a bookmark; older systems used `NSNavLastRootDirectory`): the panel opens on a real folder of the user's, and one stray keystroke chooses it. Save the user's value, write a bookmark of a scratch folder (`URL.bookmarkData()`, as hex for `defaults write <id> <key> -data`), and put the value back when the last run stops. XCUITests that use a panel pollute the same domain, and the macOS UI-test runner is sandboxed: its `UserDefaults(suiteName:)` and any `defaults` it spawns write to its own container (`~/Library/Containers/<id>.xctrunner/…`), never to the app's real domain. Save and restore the domain outside the sandbox instead: in the scheme's test `preActions`/`postActions`, which run unsandboxed for both Xcode and `xcodebuild` (`defaults export` before, `defaults delete` plus `defaults import` after). After a full run, compare the domain with the copy saved before it: a restore nobody checked didn't happen.
- Other escapes to check: the Keychain, TCC grants, Login Items, URL-scheme and Native Messaging registrations. Any registration the app writes should go under the scratch home. Doctor checks that the real one is untouched.

## Driving through Accessibility (AXUIElement)

- The host app of the shell (Terminal, iTerm, the agent's app) needs **Accessibility** and **Screen Recording**. Doctor checks `AXIsProcessTrusted()` and `CGPreflightScreenCaptureAccess()`, and names the setting when one is missing.
- Address the app by pid (`AXUIElementCreateApplication(pid)`), never by name: two instances, or the user's own copy, share the name. Wait for `NSRunningApplication(processIdentifier:)` to appear right after launch.
- `NSRunningApplication.activate()` is ignored for a tool that isn't frontmost (cooperative activation). Set `kAXFrontmostAttribute` on the app element instead, and wait until it is frontmost before sending events.
- Rows that open on a double-click need real `CGEvent` clicks at the element's frame, with `mouseEventClickState` 1 then 2. AXPress doesn't double-click.
- Cap the walk's width (about 100 children per element): an open panel's file list can hold thousands of rows, and a full walk takes minutes.
- **Mouse and keyboard are global.** One driver per Mac at a time, and `xcodebuild test` with UI tests counts as one. Don't drive while the user works.
- **Open and save panels:** never type free text into them. When focus isn't where it seems, keystrokes fall through to the panel's type-select and can land on a real folder (Desktop) with the default button enabled. Instead, open Go to Folder (`cmd+shift+g`), set the value of the field `PathTextField` through Accessibility, confirm, and wait until the location pop-up (`where popup`) names the expected folder before pressing `OKButton`. Going to a file selects it in its folder. Going to a folder opens it, and the default button then chooses the folder shown. An unsupported file can still be selected this way, even though it is greyed out.

## Chrome and its extensions

- Branded Chrome (137+) ignores `--load-extension`. Use Chrome for Testing or Chromium (a Playwright or `@puppeteer/browsers` install), and pin its version where you can.
- A fixed extension ID comes from the manifest's `key`, so a native-messaging host's `allowed_origins` can name it.
- With `--user-data-dir=<scratch>`, Chrome looks for user-level native-messaging hosts in `<scratch>/NativeMessagingHosts/`. Put the manifest there, never in the user's profile.
- Chrome passes its environment to the native host it starts. Start Chrome with the app's debug data-dir variables, and the helper writes into scratch too. Doctor reads Chrome's environment (`ps eww`) to check it.
- Chrome exposes web content (an extension's in-page UI) to Accessibility only when asked. Set `AXManualAccessibility` and `AXEnhancedUserInterface` on Chrome's app element. Chrome reports an error yet builds the tree a moment later, so use waits, not one-shot reads. Never set these on the app under test: in AppKit they change behaviour.
- The Extensions menu is a bubble that closes when Chrome loses focus, and its contents appear a moment after it opens. Press its button once, wait for the action, then press it. Its name changes with site access ("Extensions allowed on this site…" or "not allowed…").
- Chrome names an extension action in two lines (the title, then the site access). Match a name on its first line.
- The first page load in a new profile takes seconds, and the profile's preferences, where the loaded extension shows, are written a few seconds later. Wait for both.
- Serve test pages from `127.0.0.1` (content scripts often match only `http(s)`), started with `exec` so the recorded pid is the server itself.

## Teardown

- Quit through the app's own menu item (pressed via Accessibility), so it shuts down cleanly. Give it a deadline, then signal the pid, and report a hang on quit as a finding.
- Before signalling a recorded pid, check that it still runs what the run started (`ps -o comm=` or `ps -o command=` against the binary, or a profile path in its arguments). A stranded run's pid may have been reused.
- `cd <dir> && pwd -P`, then check the result is a direct child of the scratch root, before `chmod -R` and `rm -rf`.
- Copy every log (app, browser, server) into the evidence dir before removing the run dir.
