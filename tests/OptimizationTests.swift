import XCTest
@testable import suqi

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
        let binding = SuqiUserConfig.parseKeybinding("cmd+shift+e=new_tab")
        XCTAssertEqual(binding?.key, "e")
        XCTAssertEqual(binding?.modifiers, ["cmd", "shift"])
        XCTAssertEqual(binding?.action, "new_tab")
    }

    func testRejectsMalformedBinding() {
        XCTAssertNil(SuqiUserConfig.parseKeybinding("noaction"))
        XCTAssertNil(SuqiUserConfig.parseKeybinding("=new_tab"))
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
        Thread.sleep(forTimeInterval: 0.2)

        let info = DarwinProcessHelper.findLatestChildInfo()
        XCTAssertEqual(info?.name, "sleep")
        XCTAssertNotNil(info?.cwd)
    }
}
