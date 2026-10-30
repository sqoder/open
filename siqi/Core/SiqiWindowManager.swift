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

    public private(set) var preferredWindowSize: NSSize? = {
        if let str = UserDefaults.standard.string(forKey: "SiqiPreferredWindowSize") {
            let size = NSSizeFromString(str)
            if size.width >= 140 && size.height >= 60 {
                return size
            }
        }
        return nil
    }()

    public private(set) var lastWindowFrame: NSRect? = {
        if let str = UserDefaults.standard.string(forKey: "SiqiLastWindowFrame") {
            let rect = NSRectFromString(str)
            if rect.width >= 140 && rect.height >= 60 {
                return rect
            }
        }
        return nil
    }()

    public func updatePreferredWindowSize(_ size: NSSize) {
        guard size.width >= 140, size.height >= 60 else { return }
        preferredWindowSize = size
        UserDefaults.standard.set(NSStringFromSize(size), forKey: "SiqiPreferredWindowSize")
    }

    public func updateLastWindowFrame(_ frame: NSRect) {
        guard frame.width >= 140, frame.height >= 60 else { return }
        lastWindowFrame = frame
        updatePreferredWindowSize(frame.size)
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "SiqiLastWindowFrame")
    }

    private var saveStateWorkItem: DispatchWorkItem?

    public func scheduleSaveWindowState() {
        saveStateWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveWindowState()
        }
        saveStateWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

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

        // 1. Determine target window size from active window, preferred size, or last saved frame
        let targetSize: NSSize = {
            if let activeWin = activeWindowController?.window, activeWin.frame.width >= 140, activeWin.frame.height >= 60 {
                return activeWin.frame.size
            }
            if let preferred = preferredWindowSize, preferred.width >= 140, preferred.height >= 60 {
                return preferred
            }
            if let last = lastWindowFrame?.size, last.width >= 140, last.height >= 60 {
                return last
            }
            return win.frame.size
        }()

        var frame = win.frame
        frame.size = targetSize

        if windowControllers.isEmpty {
            // First window: restore saved position if available, else center
            var didRestore = false
            if shouldSaveState {
                if let last = lastWindowFrame {
                    frame.origin = last.origin
                    didRestore = true
                } else if win.setFrameUsingName("SiqiTerminalWindow") {
                    frame = win.frame
                    didRestore = true
                }
            }
            if didRestore {
                // Ensure restored frame is clamped on visible screen
                let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main
                if let visible = targetScreen?.visibleFrame {
                    frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
                    frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))
                }
                win.setFrame(frame, display: false)
            } else {
                win.setFrame(frame, display: false)
                win.center()
            }
            lastWindowTopLeft = win.frame.origin
            lastWindowTopLeft?.y += win.frame.height
        } else {
            // Subsequent windows (⌘N): inherit dimensions and cascade naturally
            win.setFrame(frame, display: false)
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
            scheduleSaveWindowState()
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

        let targetSize = activeWindowController?.window?.frame.size ?? preferredWindowSize ?? win.frame.size
        var newFrame = win.frame
        newFrame.size = targetSize
        win.setFrame(newFrame, display: false)

        if let screenPoint {
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
            let refPoint = lastWindowTopLeft
                ?? activeWin.frame.origin.applying(.init(translationX: 0, y: activeWin.frame.height))
            let nextPoint = win.cascadeTopLeft(from: refPoint)
            win.setFrameTopLeftPoint(nextPoint)
            lastWindowTopLeft = nextPoint
        } else {
            win.center()
            lastWindowTopLeft = win.frame.origin
            lastWindowTopLeft?.y += win.frame.height
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
        if let win = controller.window, win.frame.width >= 140, win.frame.height >= 60 {
            updateLastWindowFrame(win.frame)
        }
        windowControllers.removeAll { $0 === controller }
        if windowControllers.isEmpty {
            lastWindowTopLeft = nil
            SiqiWindowStateStore.clear()
        } else {
            saveWindowState()
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
        // Reuse the same window across open/close and minimize; only the first
        // call builds it.
        if let win = settingsWindow {
            win.deminiaturize(nil)
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

    /// Foreground programs across every window, for the quit confirmation (X-05)
    public var runningProcessNames: [String] {
        windowControllers.flatMap { controller in
            controller.model.sessions.filter { $0.hasActiveProcess }.compactMap { $0.activeProcessName }
        }
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
                var targetRect = NSRect(
                    x: persisted.frame[0], y: persisted.frame[1],
                    width: persisted.frame[2], height: persisted.frame[3]
                )
                // Ensure size is valid
                if targetRect.width < 140 || targetRect.height < 60 {
                    targetRect.size = preferredWindowSize ?? NSSize(width: 800, height: 500)
                }
                // Clamp inside visible bounds so it doesn't open off-screen
                let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(targetRect) }) ?? NSScreen.main
                if let visible = targetScreen?.visibleFrame {
                    targetRect.origin.x = max(visible.minX, min(targetRect.origin.x, visible.maxX - targetRect.width))
                    targetRect.origin.y = max(visible.minY, min(targetRect.origin.y, visible.maxY - targetRect.height))
                }
                window.setFrame(targetRect, display: false)
                updateLastWindowFrame(targetRect)
                lastWindowTopLeft = NSPoint(x: targetRect.origin.x, y: targetRect.origin.y + targetRect.height)
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

    public static func clear() {
        try? FileManager.default.removeItem(atPath: filePath)
    }

    public static func load() -> SiqiPersistedState? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        return try? JSONDecoder().decode(SiqiPersistedState.self, from: data)
    }

    /// A restored pane falls back to home when its saved directory is gone
    /// (deleted project, unmounted volume).
    public static func usableDirectory(_ path: String) -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return NSHomeDirectory()
        }
        return path
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
            return .terminal(SiqiTerminalSession(workingDirectory: SiqiWindowStateStore.usableDirectory(cwd)))
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
