# Cmd-Click File Opening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cmd-clicking a file or document link in Suqi open it with the macOS default application, matching Ghostty.

**Architecture:** Resolve Ghostty's `open_url` payload to a `URL`, then hand it to `NSWorkspace`. File and directory targets must exist; web URLs pass through unchanged.

**Tech Stack:** Swift 5.10, AppKit, GhosttyTerminal 1.3.7.

**Spec:** The user's request to add Ghostty-like Cmd-click document opening, using the system default editor/application.

## Global Constraints

- Do not add editor selection or configuration.
- Open web URLs with the system default browser.
- Only open existing local files/directories for path-like targets.
- Keep the change surgical; no unrelated refactoring.

## Review Focus

- A `file://` URL with percent-encoded spaces opens the original file.
- Absolute, `~/`, and working-directory-relative paths resolve correctly.
- A missing local path is ignored instead of launching an unrelated app.
- An HTTP URL still opens normally.

---

### Task 1: Resolve terminal link targets

**Files:**
- Create: `suqi/Terminal/TerminalLinkResolver.swift`
- Test: `tests/TerminalLinkResolverTests.swift`

**Interfaces:**
- Produces: `TerminalLinkResolver.resolve(_ raw: String, workingDirectory: String?) -> URL?`

- [x] **Step 1: Write the failing resolver test**

Create a standalone Swift test covering `file://`, absolute, `~/`, relative, HTTP, and missing paths.

- [x] **Step 2: Run the test and verify it fails**

Run: `swiftc -parse-as-library suqi/Terminal/TerminalLinkResolver.swift tests/TerminalLinkResolverTests.swift -o /tmp/suqi-link-resolver-tests`

Expected: compilation fails because `TerminalLinkResolver` does not exist.

- [x] **Step 3: Implement the resolver**

Use `URL(string:)` for URI schemes, `URL(fileURLWithPath:)` for local paths, and `FileManager.fileExists` for local targets.

- [x] **Step 4: Run the test and verify it passes**

Run: `swiftc -parse-as-library suqi/Terminal/TerminalLinkResolver.swift tests/TerminalLinkResolverTests.swift -o /tmp/suqi-link-resolver-tests && /tmp/suqi-link-resolver-tests`

Expected: all checks pass.

### Task 2: Wire Ghostty's open-url delegate

**Files:**
- Modify: `suqi/Terminal/SuqiTerminalSession.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `TerminalLinkResolver.resolve(_:workingDirectory:)`
- Consumes: `TerminalSurfaceOpenURLDelegate.terminalDidRequestOpenURL(_:kind:)`

- [x] **Step 1: Add the delegate conformance**

Extend `TerminalViewState` with `TerminalSurfaceOpenURLDelegate`; the handler resolves against `workingDirectory` and calls `NSWorkspace.shared.open(_:)`.

- [x] **Step 2: Build the app**

Run: `xcodebuild -project suqi.xcodeproj -scheme suqi -configuration Debug -destination 'platform=macOS' build`

Expected: `BUILD SUCCEEDED`.

- [x] **Step 3: Verify the shortcut in the running app**

Print an existing Markdown file path in a Suqi terminal, Cmd-click it, and confirm the default editor opens that file.

- [x] **Step 4: Document the shortcut**

Add Cmd-click file opening to the README shortcuts table.
