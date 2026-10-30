# siqi QA Findings Fix Plan (F-01 … F-08)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the eight failures recorded in `docs/testing/findings.md` against baseline `dc2a726`.

**Architecture:** Surgical fixes in the existing models/controllers; one new persistence layer for window/tab/pane restore, kept inside `SiqiWindowManager.swift` so no `project.pbxproj` edit is needed.

**Tech Stack:** Swift 5.10, SwiftUI + AppKit, GhosttyTerminal (libghostty-spm), XCTest (app-hosted).

**Spec:** `docs/testing/findings.md` (F-01 … F-08) and `docs/testing/manual-test-plan.md`.

## Global Constraints

- macOS 14 deployment target; Swift 5.10; 4-space indent; match existing file style.
- No new dependencies. No new source files unless listed (avoids pbxproj surgery).
- Every behavior change traces to one finding ID in its commit message.
- All existing tests must keep passing.

## Review Focus

- `⌘W` on the last pane must close the tab, and closing a tab whose shell already exited must not double-close the window.
- Settings must render controls, not an empty window.
- Right-click must never steal a TUI's click, and control-click must never show siqi's menu.
- `⌘K` must clear immediately without typing into the shell.
- Restored panes must never point at a missing cwd or leave a window with zero tabs.

---

### Task 1: F-01 — closing the last pane closes the tab

**Files:**
- Modify: `siqi/Terminal/SiqiWindowModel.swift:208-226` (`SiqiTab.closeSession`)
- Test: `tests/OptimizationTests.swift` (append `SiqiTabCloseTests`)

**Interfaces:**
- Produces: `SiqiTab.closeSession(id:) -> Bool` keeps its meaning — `true` = panes remain, `false` = tab is empty.

Root cause: when the tab holds one session, `rootPane.remove` returns `nil`, and the fallback `return !rootPane.allSessions.isEmpty` inspects the *unchanged* tree, so it always reports "panes remain". The session is torn down but the tab survives (verified live: blank pane, tab stays).

- [ ] **Step 1: Write failing tests**

```swift
@MainActor
final class SiqiTabCloseTests: XCTestCase {
    func testClosingLastSessionReportsNoPanesRemaining() {
        let session = SiqiTerminalSession(workingDirectory: NSHomeDirectory())
        let tab = SiqiTab(session: session)
        XCTAssertFalse(tab.closeSession(id: session.id))
    }

    func testClosingOneOfTwoPanesKeepsTab() {
        let first = SiqiTerminalSession(workingDirectory: NSHomeDirectory())
        let tab = SiqiTab(session: first)
        let second = SiqiTerminalSession(workingDirectory: NSHomeDirectory())
        tab.splitActive(axis: .horizontal, newSession: second)
        XCTAssertTrue(tab.closeSession(id: second.id))
        XCTAssertEqual(tab.allSessions.map(\.id), [first.id])
    }

    func testClosingUnknownSessionReportsWhatRemains() {
        let session = SiqiTerminalSession(workingDirectory: NSHomeDirectory())
        let tab = SiqiTab(session: session)
        XCTAssertTrue(tab.closeSession(id: UUID()))
    }
}
```

- [ ] **Step 2: Run tests, verify first test fails**

Run: `xcodebuild test -project siqi.xcodeproj -scheme siqi -destination 'platform=macOS' -only-testing:siqiTests/SiqiTabCloseTests`
Expected: `testClosingLastSessionReportsNoPanesRemaining` fails (returns `true`).

- [ ] **Step 3: Fix `SiqiTab.closeSession`**

```swift
public func closeSession(id: UUID) -> Bool {
    guard let session = rootPane.findSession(id: id) else {
        // Already closed elsewhere (e.g. the shell exited while ⌘W ran): report
        // what is left instead of letting callers close the whole tab.
        return !rootPane.allSessions.isEmpty
    }
    session.tearDown()
    guard let newRoot = rootPane.remove(sessionId: id) else { return false }
    rootPane = newRoot
    if activeSessionId == id {
        activeSessionId = rootPane.allSessions.first?.id ?? UUID()
    }
    if rootPane.allSessions.count <= 1 { isZoomed = false }
    paneVersion += 1
    return true
}
```

- [ ] **Step 4: Run tests, verify all three pass**

- [ ] **Step 5: Commit** — `fix(tabs): report an empty tab when the last pane closes (F-01)`

---

### Task 2: F-05 — ⌘K clears the screen instead of typing `clear`

**Files:**
- Modify: `siqi/Terminal/SiqiTerminalSession.swift:311-313` (`clearScreen`)

**Interfaces:**
- Consumes: `TerminalViewState.performBindingAction(_:) -> Bool` (already used for font actions).

Root cause: `state.send("clear\n")` writes into the pty as if the user typed it.

- [ ] **Step 1: Implement**

```swift
public func clearScreen() {
    _ = state.performBindingAction("clear_screen")
}
```

- [ ] **Step 2: Build and verify manually** — run app, `echo BEFORE_CLEAR`, press `⌘K`: screen clears immediately, no `clear` text appears at the prompt.

- [ ] **Step 3: Commit** — `fix(session): send ghostty clear_screen action for ⌘K (F-05)`

---

### Task 3: F-06 — duplicate Edit and View menus

**Files:**
- Modify: `siqi/App/SiqiApp.swift:73-114` (Edit) and `:174-205` (View)

**Interfaces:**
- Consumes: existing button bodies; no behavior change.

Root cause: `CommandMenu("Edit")` / `CommandMenu("View")` append *new* menus next to the standard ones (confirmed live: `siqi, File, Edit, View, Edit, Terminal, View, Window, Help`).

- [ ] **Step 1: Replace `CommandMenu("Edit")` with standard groups**

`CommandGroup(replacing: .pasteboard)` holding Cut / Copy / Paste / Paste Image as File Path / Divider / Select All, and `CommandGroup(replacing: .textEditing)` holding Find… (`⌘F`, toggles `model.isSearching`).

- [ ] **Step 2: Replace `CommandMenu("View")` with `CommandGroup(after: .toolbar)`**

Same four buttons (font size +/-, reset, Divider, Settings…, Open Configuration File), inserted into the existing View menu.

- [ ] **Step 3: Replace the app-menu Settings item**

Add `CommandGroup(replacing: .appSettings) { Button("Settings…") { SiqiWindowManager.shared.openSettingsWindow() }.keyboardShortcut(",", modifiers: .command) }` so SwiftUI's automatic Settings item cannot open the blank SwiftUI window.

- [ ] **Step 4: Verify manually** — menu bar reads `siqi, File, Edit, View, Terminal, Window, Help`; Edit contains Cut/Copy/Paste/Select All/Find; View contains font items + Settings.

- [ ] **Step 5: Commit** — `fix(menus): fold custom items into the standard Edit and View menus (F-06)`

---

### Task 4: F-02 — Settings opens blank

**Files:**
- Modify: `siqi/Core/SiqiWindowManager.swift:185-217` (`openSettingsWindow`)

Root cause: `NSApp.sendAction(Selector(("showSettingsWindow:")))` succeeds and shows the SwiftUI `Settings` scene window, which renders empty (reproduced live: 500×500 blank window at (0,669)).

- [ ] **Step 1: Drop the `showSettingsWindow:` attempt**

Remove the `sendAction` branch; always build the dedicated `NSWindow` + `NSHostingView(rootView: SettingsView())` (already present below it). Keep the `settingsWindow` reuse check.

- [ ] **Step 2: Verify manually** — `⌘,` and the app-menu Settings both open one 480×580 window containing the Appearance/Font/Window/Cursor/Startup/Privacy sections. If it is still blank, the defect is in `SettingsView` itself — stop and report before changing more.

- [ ] **Step 3: Commit** — `fix(settings): host SettingsView in a real AppKit window (F-02)`

---

### Task 5: F-04 — control-click must not open siqi's menu

**Files:**
- Modify: `siqi/Terminal/AppTerminalView+ContextMenu.swift:229-282` (both swizzles)

Root cause: control-click arrives as `rightMouseDown`; the swizzle shows the menu whenever no foreground process owns the pty.

- [ ] **Step 1: Implement** — at the top of the swizzled `rightMouseDown` block:

```swift
if event.modifierFlags.contains(.control) { return }
```

and in the swizzled `menu(for:)` block, return `nil` when `event.modifierFlags.contains(.control)`.

- [ ] **Step 2: Verify manually** — bare shell: `⌃`-click shows no siqi menu; plain right-click still shows it.

- [ ] **Step 3: Commit** — `fix(context-menu): ignore control-click (F-04)`

---

### Task 6: F-03 — a running TUI owns the right-click

**Files:**
- Modify: `siqi/Terminal/SiqiTerminalSession.swift:179-228` (process lookup)
- Modify: `siqi/Terminal/AppTerminalView+ContextMenu.swift:241-254`

**Interfaces:**
- Produces: `SiqiTerminalSession.activeProcessNameFresh() -> String?` — same result as `activeProcessName` with the 1-second cache bypassed.

Note: not reproducible on `dc2a726` in a live probe (`top` running → no menu; bare shell → menu). The remaining defect is the 1s process cache: a right-click within one second of launching a TUI still sees the shell and steals the click.

- [ ] **Step 1: Refactor the lookup** — `private func processName(fresh: Bool) -> String?` containing today's body; `activeProcessName` calls `processName(fresh: false)`; add `public func activeProcessNameFresh() -> String? { processName(fresh: true) }` where `fresh == true` skips `latestProcessInfo`.

- [ ] **Step 2: Use the fresh lookup in the right-click swizzle** — replace `session.hasActiveProcess` with `session.activeProcessNameFresh() != nil` (same forwarding branch).

- [ ] **Step 3: Verify manually** — start `top`, right-click within ~0.3 s: no siqi menu.

- [ ] **Step 4: Commit** — `fix(context-menu): read the foreground process without the 1s cache (F-03)`

---

### Task 7: F-07 — tab title and foreground dot never update

**Files:**
- Modify: `siqi/Terminal/SiqiWindowModel.swift` (`SiqiTab`)

Root cause: `SiqiTab` reads session state in computed properties but never forwards `SiqiTerminalSession.objectWillChange`, so `SiqiTabItemView` never re-renders. Process detection itself works (proved by the right-click probe).

- [ ] **Step 1: Implement**

Add `private var sessionObservers: [UUID: AnyCancellable] = [:]` and:

```swift
private func observeSession(_ session: SiqiTerminalSession) {
    guard sessionObservers[session.id] == nil else { return }
    sessionObservers[session.id] = session.objectWillChange.sink { [weak self] _ in
        self?.objectWillChange.send()
    }
}
```

Call it from `init(session:)`, from `splitActive` for `newSession`, and add `func observeAllSessions()` (loops `allSessions`) called by `SiqiWindowModel.insertTab` and by the restore initializer from Task 8.

- [ ] **Step 2: Verify manually** — two tabs, run `top` in one: its title becomes `top` and the orange dot appears within ~1 s.

- [ ] **Step 3: Commit** — `fix(tabs): forward session changes so titles and process dots update (F-07)`

---

### Task 8: F-08 — restore tabs and split structure on relaunch

**Files:**
- Modify: `siqi/Core/SiqiWindowManager.swift` (persisted structs, save, restore)
- Modify: `siqi/Terminal/SiqiWindowModel.swift` (`SiqiTab.init(rootPane:activeSessionId:)`, `SiqiWindowModel.init(tabs:activeTabId:)`)
- Modify: `siqi/App/AppDelegate.swift` (restore on launch, save on terminate)
- Test: `tests/OptimizationTests.swift` (persisted-state round trip)

**Interfaces:**
- Produces:
  - `struct SiqiPersistedPane: Codable, Equatable { var cwd: String?; var axis: String?; var fraction: Double?; var first: SiqiPersistedPane?; var second: SiqiPersistedPane? }`
  - `struct SiqiPersistedTab: Codable, Equatable { var activePaneIndex: Int; var root: SiqiPersistedPane }`
  - `struct SiqiPersistedWindow: Codable, Equatable { var frame: [Double]; var activeTabIndex: Int; var tabs: [SiqiPersistedTab] }`
  - `struct SiqiPersistedState: Codable, Equatable { var windows: [SiqiPersistedWindow] }`
  - `enum SiqiWindowStateStore { static func save(_:); static func load() -> SiqiPersistedState? }` — file at `~/.cache/siqi/window-state.json`
  - `SiqiWindowManager.saveWindowState()`, `SiqiWindowManager.restoreWindowsFromState() -> Bool`
  - `SiqiTab.init(rootPane: PaneNode, activeSessionId: UUID)`
  - `SiqiWindowModel.init(tabs: [SiqiTab], activeTabId: UUID?)`

- [ ] **Step 1: Write the round-trip test**

```swift
final class WindowStatePersistenceTests: XCTestCase {
    func testPersistedStateSurvivesJSONRoundTrip() throws {
        let leaf = SiqiPersistedPane(cwd: "/tmp", axis: nil, fraction: nil, first: nil, second: nil)
        let state = SiqiPersistedState(windows: [
            SiqiPersistedWindow(
                frame: [10, 20, 800, 500],
                activeTabIndex: 1,
                tabs: [
                    SiqiPersistedTab(activePaneIndex: 0, root: leaf),
                    SiqiPersistedTab(activePaneIndex: 1, root: SiqiPersistedPane(
                        cwd: nil, axis: "horizontal", fraction: 0.5, first: leaf,
                        second: SiqiPersistedPane(cwd: "/Users", axis: nil, fraction: nil, first: nil, second: nil)))
                ])
        ])
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(SiqiPersistedState.self, from: data), state)
    }
}
```

- [ ] **Step 2: Run it, verify it fails to compile** (types missing).

- [ ] **Step 3: Add the persisted types + store + conversions**

`SiqiPersistedPane.from(_ node: PaneNode)` maps leaf → `cwd`, split → `axis` (`"horizontal"`/`"vertical"`), `fraction`, children. `func buildNode() -> PaneNode` maps back, creating `SiqiTerminalSession(workingDirectory: cwd)` per leaf; a split node with a missing child degrades to its present child, and a node with neither degrades to a leaf in `NSHomeDirectory()`.

`save` writes atomically and is skipped when `windowSaveState == "never"`. `load` returns `nil` on any decode/IO error.

- [ ] **Step 4: Add model initializers**

`SiqiTab.init(rootPane:activeSessionId:)` sets the tree, id, active session, then `observeAllSessions()`. `SiqiWindowModel.init(tabs:activeTabId:)` stores the tabs, sets `activeTabId` to the given id when it exists (else the first tab), and runs `attachSessionCallbacks` for every session in every tab.

- [ ] **Step 5: Add save/restore to `SiqiWindowManager`**

`saveWindowState()` snapshots every controller: frame as `[minX, minY, width, height]`, active tab index, each tab's `SiqiPersistedTab` (active pane index = index of `activeSessionId` in `allSessions`). `restoreWindowsFromState()` rebuilds each window: tabs from `buildNode()`, model from `SiqiWindowModel(tabs:activeTabId:)`, controller via `TerminalWindowController(model:)`, then `window.setFrame(NSRect(...), display: false)`, append, `showWindow()`, `saveWindowFrameIfNeeded()`; returns `false` when there is no saved state.

- [ ] **Step 6: Wire AppDelegate**

`applicationDidFinishLaunching`: replace the unconditional `createWindow()` with `if !SiqiWindowManager.shared.restoreWindowsFromState() { _ = SiqiWindowManager.shared.createWindow() }`. Add `applicationWillTerminate` → `SiqiWindowManager.shared.saveWindowState()`.

- [ ] **Step 7: Run tests** — all pass.

- [ ] **Step 8: Verify manually** — window with two tabs + one split, `⌘Q`, relaunch: two tabs, split geometry and cwds restored. Then `window-save-state=never`: relaunch gives a single default window.

- [ ] **Step 9: Commit** — `feat(window): persist and restore tabs and panes (F-08)`

---

### Task 9: Full verification

- [ ] `xcodebuild test -project siqi.xcodeproj -scheme siqi -destination 'platform=macOS'` → 0 failures.
- [ ] `./scripts/install.sh` → Release build installed.
- [ ] Live re-check of F-01, F-02, F-04, F-05, F-06, F-07, F-08 with screenshots in `docs/testing/evidence/`.
- [ ] Update `docs/testing/findings.md` with fix status and evidence paths.
