import XCTest
import GhosttyTerminal
@testable import siqi

@MainActor
final class ShellEscapeTests: XCTestCase {
    func testEscapedShellPathRoundTripsThroughSh() throws {
        let cases = [
            "/tmp/plain.png",
            "/tmp/with space.png",
            "/tmp/quote'.png",
            "/tmp/parens (1) [2].png",
            "/tmp/back\\slash.png",
            "/tmp/dollar$var.png",
        ]
        for path in cases {
            let escaped = TerminalActionBridge.escapedShellPath(path)
            XCTAssertEqual(try sh("printf %s \(escaped)"), path)
        }
    }

    private func sh(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}

final class KeybindingParserTests: XCTestCase {
    func testParsesGhosttyStyleBinding() {
        let binding = SiqiUserConfig.parseKeybinding("cmd+shift+e=new_tab")
        XCTAssertEqual(binding?.key, "e")
        XCTAssertEqual(binding?.modifiers, ["cmd", "shift"])
        XCTAssertEqual(binding?.action, "new_tab")
    }

    func testRejectsMalformedBinding() {
        XCTAssertNil(SiqiUserConfig.parseKeybinding("noaction"))
        XCTAssertNil(SiqiUserConfig.parseKeybinding("=new_tab"))
    }
}

final class ChildProcessInfoTests: XCTestCase {
    func testFindsNewestNonShellChildNameAndCwd() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["5"]
        try process.run()
        defer {
            process.terminate()
            process.waitUntilExit()
        }
        // findLatestChildInfo() scans every child of this process, so other
        // children spawned by the test host can win "newest". Assert on the
        // sleep we spawned instead of on the winner.
        var foundSleep = false
        for _ in 0..<20 {
            let children = DarwinProcessHelper.getChildPids(for: getpid())
            if children.contains(where: { DarwinProcessHelper.getProcessName(for: $0) == "sleep" }) {
                foundSleep = true
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(foundSleep)
        XCTAssertNotNil(DarwinProcessHelper.findLatestChildInfo()?.cwd)
    }
}

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

final class WindowStatePersistenceTests: XCTestCase {
    func testPersistedStateSurvivesJSONRoundTrip() throws {
        let leaf = SiqiPersistedPane.leaf(cwd: "/tmp")
        let state = SiqiPersistedState(windows: [
            SiqiPersistedWindow(
                frame: [10, 20, 800, 500],
                activeTabIndex: 1,
                tabs: [
                    SiqiPersistedTab(activePaneIndex: 0, root: leaf),
                    SiqiPersistedTab(activePaneIndex: 1, root: .split(
                        axis: "horizontal", fraction: 0.5, first: leaf,
                        second: .leaf(cwd: "/Users")))
                ])
        ])
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(SiqiPersistedState.self, from: data), state)
    }
}

@MainActor
final class KeyEquivalentPolicyTests: XCTestCase {
    func testSettingsShortcutMatchesAsciiComma() {
        XCTAssertTrue(AppTerminalView.isSettingsShortcut(makeEvent(",", keyCode: 43, modifiers: .command)))
    }

    func testSettingsShortcutMatchesFullWidthCommaFromChineseInput() {
        XCTAssertTrue(AppTerminalView.isSettingsShortcut(makeEvent("，", keyCode: 43, modifiers: .command)))
    }

    func testSettingsShortcutIgnoresOtherKeys() {
        XCTAssertFalse(AppTerminalView.isSettingsShortcut(makeEvent("t", keyCode: 17, modifiers: .command)))
        XCTAssertFalse(AppTerminalView.isSettingsShortcut(makeEvent(",", keyCode: 43, modifiers: [.command, .shift])))
    }

    private func makeEvent(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

@MainActor
final class ContextMenuPolicyTests: XCTestCase {
    func testControlClickHandsOffToTerminal() {
        XCTAssertTrue(AppTerminalView.handsOffContextMenu(control: true, processRunning: false))
    }

    func testRunningProgramHandsOffToTerminal() {
        XCTAssertTrue(AppTerminalView.handsOffContextMenu(control: false, processRunning: true))
    }

    func testBareShellRightClickKeepsSiqiMenu() {
        XCTAssertFalse(AppTerminalView.handsOffContextMenu(control: false, processRunning: false))
    }
}

final class RestoredDirectoryTests: XCTestCase {
    func testMissingDirectoryFallsBackToHome() {
        XCTAssertEqual(
            SiqiWindowStateStore.usableDirectory("/definitely/not/here"),
            NSHomeDirectory()
        )
    }

    func testRegularFileFallsBackToHome() {
        XCTAssertEqual(SiqiWindowStateStore.usableDirectory("/etc/hosts"), NSHomeDirectory())
    }

    func testExistingDirectoryIsKept() {
        XCTAssertEqual(SiqiWindowStateStore.usableDirectory("/tmp"), "/tmp")
    }
}

@MainActor
final class CloseConfirmationPolicyTests: XCTestCase {
    func testConfirmsWhenEnabledAndAProcessRuns() {
        var config = SiqiUserConfig()
        config.confirmCloseSurface = true
        XCTAssertTrue(SiqiWindowModel.needsCloseConfirmation(config: config, runningProcessNames: ["sleep"]))
    }

    func testSkipsConfirmationWhenDisabled() {
        var config = SiqiUserConfig()
        config.confirmCloseSurface = false
        XCTAssertFalse(SiqiWindowModel.needsCloseConfirmation(config: config, runningProcessNames: ["sleep"]))
    }

    func testSkipsConfirmationWhenNothingRuns() {
        var config = SiqiUserConfig()
        config.confirmCloseSurface = true
        XCTAssertFalse(SiqiWindowModel.needsCloseConfirmation(config: config, runningProcessNames: []))
    }

    func testDefaultConfigConfirmsCloseWithRunningProcess() {
        XCTAssertTrue(SiqiWindowModel.needsCloseConfirmation(config: SiqiUserConfig(), runningProcessNames: ["sleep"]))
    }
}

@MainActor
final class KeybindingOverrideTests: XCTestCase {
    func testUserBindingClaimsCommandComma() {
        let bindings = [SiqiUserConfig.parseKeybinding("super+comma=new_tab")!]
        XCTAssertTrue(TerminalActionBridge.hasUserBinding(for: commaEvent(), in: bindings))
    }

    func testNoUserBindingLeavesCommandCommaToSettings() {
        XCTAssertFalse(TerminalActionBridge.hasUserBinding(for: commaEvent(), in: []))
    }

    private func commaEvent() -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        )!
    }
}

@MainActor
final class KeybindingLayoutTests: XCTestCase {
    func testCommaBindingMatchesByPhysicalKeyUnderChineseInput() {
        let bindings = [SiqiUserConfig.parseKeybinding("super+comma=new_tab")!]
        XCTAssertTrue(TerminalActionBridge.hasUserBinding(for: fullWidthCommaEvent(), in: bindings))
    }

    private func fullWidthCommaEvent() -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: "，",
            charactersIgnoringModifiers: "，",
            isARepeat: false,
            keyCode: 43
        )!
    }
}

final class WindowCornerRadiusConfigTests: XCTestCase {
    func testDefaultWindowCornerRadiusIs18() {
        let config = SiqiUserConfig()
        XCTAssertEqual(config.windowCornerRadius, 18.0)
    }

    func testCustomWindowCornerRadiusParses() {
        let text = "window-corner-radius = 22"
        let (config, _) = SiqiUserConfig.load(from: text)
        XCTAssertEqual(config.windowCornerRadius, 22.0)
    }
}
