//
//  SuqiWindowManager.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import SwiftUI

@MainActor
public final class SuqiWindowManager: ObservableObject {
    public static let shared = SuqiWindowManager()

    @Published public private(set) var windowControllers: [TerminalWindowController] = []
    private var lastWindowTopLeft: NSPoint?

    private init() {}

    /// Returns the currently active terminal window controller
    public var activeWindowController: TerminalWindowController? {
        if let keyWindow = NSApp.keyWindow,
           let ctrl = windowControllers.first(where: { $0.window === keyWindow }) {
            return ctrl
        }
        if let mainWindow = NSApp.mainWindow,
           let ctrl = windowControllers.first(where: { $0.window === mainWindow }) {
            return ctrl
        }
        return windowControllers.last
    }

    /// Creates a new standalone terminal window
    @discardableResult
    public func createWindow(workingDirectory: String? = nil) -> TerminalWindowController {
        let fallbackDir = activeWindowController?.model.activeSession?.fullDirectory
        let initialDir = SuqiDirectoryManager.resolvedInitialWorkingDirectory(explicit: workingDirectory ?? fallbackDir)

        let model = SuqiWindowModel(initialWorkingDirectory: initialDir)
        let controller = TerminalWindowController(model: model)

        // First window restores saved geometry (window-save-state), or centers on screen;
        // Subsequent windows (⌘N) cascade naturally for standard macOS multi-window workflow
        guard let win = controller.window else {
            windowControllers.append(controller)
            controller.showWindow()
            return controller
        }

        let (cfg, _) = GhosttyUserConfig.load()
        let shouldSaveState = cfg.windowSaveState.lowercased() != "never"

        if windowControllers.isEmpty {
            // First window: restore saved position/size if available, else center
            var didRestore = false
            if shouldSaveState {
                didRestore = win.setFrameUsingName("SuqiTerminalWindow")
                if didRestore && (win.frame.width < 140 || win.frame.height < 60) {
                    var f = win.frame
                    f.size = NSSize(width: 80, height: 32)
                    win.setFrame(f, display: true)
                }
            }
            if !didRestore {
                win.center()
            }
            lastWindowTopLeft = win.frame.origin
            lastWindowTopLeft?.y += win.frame.height
        } else {
            // Subsequent windows (⌘N): inherit active window dimensions and cascade
            if let activeWin = activeWindowController?.window {
                var newFrame = win.frame
                newFrame.size = activeWin.frame.size
                win.setFrame(newFrame, display: false)
            }

            let refPoint = lastWindowTopLeft
                ?? activeWindowController?.window?.frame.origin.applying(.init(translationX: 0, y: activeWindowController?.window?.frame.height ?? 0))
                ?? win.frame.origin
            let nextPoint = win.cascadeTopLeft(from: refPoint)
            win.setFrameTopLeftPoint(nextPoint)
            lastWindowTopLeft = nextPoint
        }

        windowControllers.append(controller)
        controller.showWindow()

        // Sync saved frame after window display
        if shouldSaveState {
            controller.saveWindowFrameIfNeeded()
        }

        return controller
    }

    /// Creates a new standalone terminal window with an existing detached tab, optionally at a designated screen point
    @discardableResult
    public func createWindow(withTab tab: SuqiTab, at screenPoint: NSPoint? = nil) -> TerminalWindowController {
        let model = SuqiWindowModel(withTab: tab)
        let controller = TerminalWindowController(model: model)

        guard let win = controller.window else {
            windowControllers.append(controller)
            controller.showWindow()
            return controller
        }

        if let screenPoint {
            // Inherit dimensions from active window if present
            if let activeWin = activeWindowController?.window {
                var newFrame = win.frame
                newFrame.size = activeWin.frame.size
                win.setFrame(newFrame, display: false)
            }

            // Offset top-left so the tab bar is positioned naturally under the mouse
            var targetTopLeft = NSPoint(
                x: screenPoint.x - 80,
                y: screenPoint.y + 18
            )

            // Clamp inside screen visible bounds
            let targetScreen = NSScreen.screens.first(where: { NSPointInRect(screenPoint, $0.frame) }) ?? NSScreen.main
            if let visible = targetScreen?.visibleFrame {
                let winW = win.frame.width
                let winH = win.frame.height
                targetTopLeft.x = max(visible.minX, min(targetTopLeft.x, visible.maxX - winW))
                targetTopLeft.y = min(visible.maxY, max(targetTopLeft.y, visible.minY + winH))
            }

            win.setFrameTopLeftPoint(targetTopLeft)
            lastWindowTopLeft = targetTopLeft
        } else if let activeWin = activeWindowController?.window {
            var newFrame = win.frame
            newFrame.size = activeWin.frame.size
            win.setFrame(newFrame, display: false)
            let refPoint = lastWindowTopLeft
                ?? activeWin.frame.origin.applying(.init(translationX: 0, y: activeWin.frame.height))
            let nextPoint = win.cascadeTopLeft(from: refPoint)
            win.setFrameTopLeftPoint(nextPoint)
            lastWindowTopLeft = nextPoint
        } else {
            win.center()
        }

        windowControllers.append(controller)
        controller.showWindow()
        return controller
    }

    /// Finds a tab and its owning window model across all active windows
    public func findTabAndModel(id: UUID) -> (model: SuqiWindowModel, tab: SuqiTab)? {
        for controller in windowControllers {
            if let tab = controller.model.tabs.first(where: { $0.id == id }) {
                return (controller.model, tab)
            }
        }
        return nil
    }

    /// Removes a closed window controller
    public func removeWindow(_ controller: TerminalWindowController) {
        controller.saveWindowFrameIfNeeded()
        windowControllers.removeAll { $0 === controller }
        if windowControllers.isEmpty {
            lastWindowTopLeft = nil
        }
    }

    /// Reloads theme background colors across all windows
    public func updateAllThemeBackgrounds() {
        for controller in windowControllers {
            controller.updateThemeBackground()
        }
    }

    /// Hot-reloads terminal configurations and active sessions across all windows
    public func reloadAllWindows() {
        for controller in windowControllers {
            controller.model.reloadAllSessions()
            controller.updateThemeBackground()
        }
    }

    private var settingsWindow: NSWindow?

    /// Opens or brings to front the native Settings window
    public func openSettingsWindow() {
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Try standard macOS SwiftUI showSettingsWindow selector
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        // Fallback: Create dedicated native window hosting SettingsView
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
