//
//  AppTerminalView+IME.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import GhosttyTerminal

// MARK: - AppTerminalView IME Window Level Extension

extension AppTerminalView {
    /// Informs the input method engine (IME) of the host window level.
    /// AppTerminalView defaults to un-implemented NSTextInputClient.windowLevel(),
    /// which causes WindowServer to default candidate popups below floating windows.
    /// Implementing windowLevel() lifts IME candidate overlays above the terminal.
    @objc open func windowLevel() -> Int {
        if let window {
            return Int(window.level.rawValue)
        }
        return Int(NSWindow.Level.normal.rawValue)
    }
}
