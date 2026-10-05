//
//  SuqiApp.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit

@main
struct SuqiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    SuqiWindowManager.shared.createWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    SuqiWindowManager.shared.activeWindowController?.model.createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Split Right") {
                    SuqiWindowManager.shared.activeWindowController?.model.splitRight()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Down") {
                    SuqiWindowManager.shared.activeWindowController?.model.splitDown()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Toggle Split Zoom") {
                    SuqiWindowManager.shared.activeWindowController?.model.toggleZoom()
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Button("Equalize Splits") {
                    SuqiWindowManager.shared.activeWindowController?.model.equalizeSplits()
                }
                .keyboardShortcut("=", modifiers: [.command, .control])

                Divider()

                Button("Close Split / Tab") {
                    SuqiWindowManager.shared.activeWindowController?.closeCurrentTabOrWindow()
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Close Window") {
                    if let ctrl = SuqiWindowManager.shared.activeWindowController {
                        if ctrl.windowShouldClose(ctrl.window ?? NSWindow()) {
                            ctrl.closeWindow()
                        }
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            // MARK: - Edit Menu
            CommandMenu("Edit") {
                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: .command)

                Button("Copy") {
                    if !NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
                        SuqiWindowManager.shared.activeWindowController?.handleCopy()
                    }
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    SuqiWindowManager.shared.activeWindowController?.handlePaste()
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Paste Image as File Path") {
                    if let ctrl = SuqiWindowManager.shared.activeWindowController {
                        TerminalActionBridge.handlePaste(in: ctrl.window, model: ctrl.model, saveImageAsPath: true)
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .option])

                Divider()

                Button("Select All") {
                    if !NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) {
                        SuqiWindowManager.shared.activeWindowController?.handleSelectAll()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)

                Divider()

                Button("Find...") {
                    SuqiWindowManager.shared.activeWindowController?.model.isSearching.toggle()
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
                    SuqiWindowManager.shared.activeWindowController?.model.clearActiveSession()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Restart Active Session") {
                    SuqiWindowManager.shared.activeWindowController?.model.restartActiveSession()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Reload Configuration") {
                    SuqiWindowManager.shared.reloadAllWindows()
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])

                Divider()

                Button("Previous Tab") {
                    SuqiWindowManager.shared.activeWindowController?.model.previousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Next Tab") {
                    SuqiWindowManager.shared.activeWindowController?.model.nextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Divider()

                // Quick tab switching ⌘1 to ⌘9
                ForEach(1...9, id: \.self) { index in
                    Button("Select Tab \(index)") {
                        SuqiWindowManager.shared.activeWindowController?.model.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(0x30 + index)!)), modifiers: .command)
                }
            }

            // MARK: - View Menu
            CommandMenu("View") {
                Button("Increase Font Size") {
                    _ = SuqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("increase_font_size:1")
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    _ = SuqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("decrease_font_size:1")
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    _ = SuqiWindowManager.shared.activeWindowController?.model.activeSession?.state.performBindingAction("reset_font_size")
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Settings...") {
                    SuqiWindowManager.shared.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Open Configuration File") {
                    let suqiPath = NSString(string: "~/.config/suqi/config").expandingTildeInPath
                    let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath
                    let target = FileManager.default.fileExists(atPath: suqiPath) ? suqiPath : (FileManager.default.fileExists(atPath: ghosttyPath) ? ghosttyPath : suqiPath)
                    NSWorkspace.shared.open(URL(fileURLWithPath: target))
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }
        }
    }
}
