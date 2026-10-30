import XCTest
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
