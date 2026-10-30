//
//  SiqiWindowManager.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import SwiftUI

@MainActor
public final class SiqiWindowManager: ObservableObject {
    public static let shared = SiqiWindowManager()

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
        let initialDir = SiqiDirectoryManager.resolvedInitialWorkingDirectory(explicit: workingDirectory ?? fallbackDir)

        let model = SiqiWindowModel(initialWorkingDirectory: initialDir)
        let controller = TerminalWindowController(model: model)

        // First window restores saved geometry (window-save-state), or centers on screen;
        // Subsequent windows (⌘N) cascade naturally for standard macOS multi-window workflow
        guard let win = controller.window else {
            windowControllers.append(controller)
            controller.showWindow()
            return controller
        }

        let (cfg, _) = SiqiUserConfig.load()
        let shouldSaveState = cfg.windowSaveState.lowercased() != "never"

        if windowControllers.isEmpty {
            // First window: restore saved position/size if available, else center
            var didRestore = false
            if shouldSaveState {
                didRestore = win.setFrameUsingName("SiqiTerminalWindow")
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
    public func createWindow(withTab tab: SiqiTab, at screenPoint: NSPoint? = nil) -> TerminalWindowController {
        let model = SiqiWindowModel(withTab: tab)
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
    public func findTabAndModel(id: UUID) -> (model: SiqiWindowModel, tab: SiqiTab)? {
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

        // Host SettingsView in a real window: the SwiftUI Settings scene opens an
        // empty 500×500 window on this build (F-02).
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

    // MARK: - Window / Tab / Pane Restore (F-08)

    /// Snapshots every window's tabs and split tree; skipped when window-save-state=never
    public func saveWindowState() {
        let (cfg, _) = SiqiUserConfig.load()
        guard cfg.windowSaveState.lowercased() != "never" else { return }

        let windows: [SiqiPersistedWindow] = windowControllers.compactMap { controller in
            guard let window = controller.window else { return nil }
            let model = controller.model
            guard !model.tabs.isEmpty else { return nil }
            let tabs = model.tabs.map { tab -> SiqiPersistedTab in
                let sessions = tab.allSessions
                let activeIndex = sessions.firstIndex { $0.id == tab.activeSessionId } ?? 0
                return SiqiPersistedTab(activePaneIndex: activeIndex, root: SiqiPersistedPane(node: tab.rootPane))
            }
            let activeTabIndex = model.tabs.firstIndex { $0.id == model.activeTabId } ?? 0
            let frame = window.frame
            return SiqiPersistedWindow(
                frame: [frame.minX, frame.minY, frame.width, frame.height],
                activeTabIndex: activeTabIndex,
                tabs: tabs
            )
        }
        guard !windows.isEmpty else { return }
        SiqiWindowStateStore.save(SiqiPersistedState(windows: windows))
    }

    /// Rebuilds the saved windows; returns false when there is nothing to restore
    @discardableResult
    public func restoreWindowsFromState() -> Bool {
        let (cfg, _) = SiqiUserConfig.load()
        guard cfg.windowSaveState.lowercased() != "never",
              let state = SiqiWindowStateStore.load(),
              !state.windows.isEmpty else { return false }

        for persisted in state.windows {
            let tabs = persisted.tabs.map { persistedTab -> SiqiTab in
                let root = persistedTab.root.buildNode()
                let sessions = root.allSessions
                let activeId = sessions.indices.contains(persistedTab.activePaneIndex)
                    ? sessions[persistedTab.activePaneIndex].id
                    : (sessions.first?.id ?? UUID())
                return SiqiTab(rootPane: root, activeSessionId: activeId)
            }
            guard !tabs.isEmpty else { continue }
            let activeTabId = tabs.indices.contains(persisted.activeTabIndex)
                ? tabs[persisted.activeTabIndex].id
                : tabs.first?.id
            let model = SiqiWindowModel(tabs: tabs, activeTabId: activeTabId)
            let controller = TerminalWindowController(model: model)
            if persisted.frame.count == 4, let window = controller.window {
                window.setFrame(
                    NSRect(x: persisted.frame[0], y: persisted.frame[1],
                           width: persisted.frame[2], height: persisted.frame[3]),
                    display: false
                )
            }
            windowControllers.append(controller)
            controller.showWindow()
        }
        return !windowControllers.isEmpty
    }
}

// MARK: - Persisted Window State

public indirect enum SiqiPersistedPane: Codable, Equatable {
    case leaf(cwd: String)
    case split(axis: String, fraction: Double, first: SiqiPersistedPane, second: SiqiPersistedPane)
}

public struct SiqiPersistedTab: Codable, Equatable {
    public var activePaneIndex: Int
    public var root: SiqiPersistedPane
}

public struct SiqiPersistedWindow: Codable, Equatable {
    public var frame: [Double]
    public var activeTabIndex: Int
    public var tabs: [SiqiPersistedTab]
}

public struct SiqiPersistedState: Codable, Equatable {
    public var windows: [SiqiPersistedWindow]
}

public enum SiqiWindowStateStore {
    public static let filePath = NSString(string: "~/.cache/siqi/window-state.json").expandingTildeInPath

    public static func save(_ state: SiqiPersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let dir = (filePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }

    public static func load() -> SiqiPersistedState? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        return try? JSONDecoder().decode(SiqiPersistedState.self, from: data)
    }
}

@MainActor
extension SiqiPersistedPane {
    init(node: PaneNode) {
        switch node {
        case .terminal(let session):
            self = .leaf(cwd: session.fullDirectory)
        case .split(_, let axis, let fraction, let first, let second):
            self = .split(
                axis: axis == .horizontal ? "horizontal" : "vertical",
                fraction: Double(fraction),
                first: SiqiPersistedPane(node: first),
                second: SiqiPersistedPane(node: second)
            )
        }
    }

    func buildNode() -> PaneNode {
        switch self {
        case .leaf(let cwd):
            return .terminal(SiqiTerminalSession(workingDirectory: cwd))
        case .split(let axis, let fraction, let first, let second):
            return .split(
                id: UUID(),
                axis: axis == "vertical" ? .vertical : .horizontal,
                fraction: CGFloat(fraction),
                first: first.buildNode(),
                second: second.buildNode()
            )
        }
    }
}
