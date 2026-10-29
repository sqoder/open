//
//  AppTerminalView+Paste.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import GhosttyTerminal

// MARK: - AppTerminalView Image Paste Extension

extension AppTerminalView {
    /// Triggers a synthetic Control+V key event matching physical keyboard input.
    ///
    /// Modern AI CLI agents (such as agy, Claude Code, Codex, OpenCode, etc.)
    /// intercept Control+V to read raw image payloads directly from the macOS clipboard.
    public func triggerImagePasteShortcut() {
        let timestamp = ProcessInfo.processInfo.systemUptime
        let windowNum = window?.windowNumber ?? 0

        guard let downEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .control,
            timestamp: timestamp,
            windowNumber: windowNum,
            context: nil,
            characters: "\u{16}",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: 0x09
        ) else { return }

        guard let upEvent = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: .control,
            timestamp: timestamp + 0.005,
            windowNumber: windowNum,
            context: nil,
            characters: "\u{16}",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: 0x09
        ) else { return }

        self.keyDown(with: downEvent)
        self.keyUp(with: upEvent)
    }
}
