//
//  SiqiApp.swift
//  siqi
//
//  Created for siqi Terminal.
//

import SwiftUI
import AppKit
import Carbon

@main
struct SiqiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var secureInputEnabled = IsSecureEventInputEnabled()

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            // Replace the automatic Settings item so it cannot open the blank
            // SwiftUI settings window (F-02).
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SiqiWindowManager.shared.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    SiqiWindowManager.shared.createWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    SiqiWindowManager.shared.activeWindowController?.model.createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Split Right") {
                    SiqiWindowManager.shared.activeWindowController?.model.splitRight()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Down") {
                    SiqiWindowManager.shared.activeWindowController?.model.splitDown()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Toggle Split Zoom") {
                    SiqiWindowManager.shared.activeWindowController?.model.toggleZoom()
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Button("Equalize Splits") {
                    SiqiWindowManager.shared.activeWindowController?.model.equalizeSplits()
                }
                .keyboardShortcut("=", modifiers: [.command, .control])

                Divider()

                Button("Close Split / Tab") {
                    SiqiWindowManager.shared.activeWindowController?.closeCurrentTabOrWindow()
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Close Window") {
                    if let ctrl = SiqiWindowManager.shared.activeWindowController {
                        if ctrl.windowShouldClose(ctrl.window ?? NSWindow()) {
                            ctrl.closeWindow()
                        }
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            // MARK: - Edit Menu (standard placement, no duplicate menu)
            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: .command)

                Button("Copy") {
                    if !NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
                        SiqiWindowManager.shared.activeWindowController?.handleCopy()
                    }
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    SiqiWindowManager.shared.activeWindowController?.handlePaste()
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Paste Image as File Path") {
                    if let ctrl = SiqiWindowManager.shared.activeWindowController {
                        TerminalActionBridge.handlePaste(in: ctrl.window, model: ctrl.model, saveImageAsPath: true)
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .option])

                Divider()

                Button("Select All") {
                    if !NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) {
                        SiqiWindowManager.shared.activeWindowController?.handleSelectAll()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    SiqiWindowManager.shared.activeWindowController?.model.isSearching.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // MARK: - Terminal Menu
            CommandMenu("Terminal") {
                Button("Toggle Quick Terminal") {
                    QuickTerminalController.shared.toggle()
                }
                .keyboardShortcut("`", modifiers: .control)

                Divider()

                Button("Clear Scrollback") {
                    SiqiWindowManager.shared.activeWindowController?.model.clearActiveSession()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Restart Active Session") {
                    SiqiWindowManager.shared.activeWindowController?.model.restartActiveSession()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Reload Configuration") {
                    SiqiWindowManager.shared.reloadAllWindows()
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])

                Divider()

                Button(secureInputEnabled ? "Disable Secure Keyboard Entry" : "Enable Secure Keyboard Entry") {
                    if secureInputEnabled {
                        DisableSecureEventInput()
                    } else {
                        EnableSecureEventInput()
                    }
                    secureInputEnabled = IsSecureEventInputEnabled()
                }

                Divider()

                Button("Previous Tab") {
                    SiqiWindowManager.shared.activeWindowController?.model.previousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Next Tab") {
                    SiqiWindowManager.shared.activeWindowController?.model.nextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Divider()

                // Quick tab switching ⌘1 to ⌘9
                ForEach(1...9, id: \.self) { index in
                    Button("Select Tab \(index)") {
                        SiqiWindowManager.shared.activeWindowController?.model.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(0x30 + index)!)), modifiers: .command)
                }
            }

            // MARK: - View Menu (items folded into the standard View menu)
            CommandGroup(after: .toolbar) {
                Button("Increase Font Size") {
                    _ = SiqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("increase_font_size:1")
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    _ = SiqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("decrease_font_size:1")
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    _ = SiqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("reset_font_size")
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Settings...") {
                    SiqiWindowManager.shared.openSettingsWindow()
                }

                Button("Open Configuration File") {
                    let siqiPath = NSString(string: "~/.config/siqi/config").expandingTildeInPath
                    let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath
                    let target = FileManager.default.fileExists(atPath: siqiPath) ? siqiPath : (FileManager.default.fileExists(atPath: ghosttyPath) ? ghosttyPath : siqiPath)
                    NSWorkspace.shared.open(URL(fileURLWithPath: target))
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }
        }
    }
}
