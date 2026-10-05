//
//  SuqiWindowModel.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import Combine

// MARK: - PaneNode (Split Tree Node)

public enum PaneNode: Identifiable, Equatable {
    case terminal(SuqiTerminalSession)
    indirect case split(id: UUID, axis: Axis, fraction: CGFloat, first: PaneNode, second: PaneNode)

    public var id: UUID {
        switch self {
        case .terminal(let session):
            return session.id
        case .split(let id, _, _, _, _):
            return id
        }
    }

    public static func == (lhs: PaneNode, rhs: PaneNode) -> Bool {
        switch (lhs, rhs) {
        case (.terminal(let s1), .terminal(let s2)):
            return s1.id == s2.id
        case (.split(let id1, let axis1, let frac1, let f1, let s1), .split(let id2, let axis2, let frac2, let f2, let s2)):
            return id1 == id2 && axis1 == axis2 && abs(frac1 - frac2) < 0.0001 && f1 == f2 && s1 == s2
        default:
            return false
        }
    }

    public var allSessions: [SuqiTerminalSession] {
        switch self {
        case .terminal(let session):
            return [session]
        case .split(_, _, _, let first, let second):
            return first.allSessions + second.allSessions
        }
    }

    public func findSession(id: UUID) -> SuqiTerminalSession? {
        switch self {
        case .terminal(let s):
            return s.id == id ? s : nil
        case .split(_, _, _, let first, let second):
            return first.findSession(id: id) ?? second.findSession(id: id)
        }
    }

    public func split(targetSessionId: UUID, axis: Axis, newSession: SuqiTerminalSession) -> PaneNode {
        switch self {
        case .terminal(let s):
            if s.id == targetSessionId {
                return .split(id: UUID(), axis: axis, fraction: 0.5, first: .terminal(s), second: .terminal(newSession))
            }
            return self
        case .split(let id, let currentAxis, let fraction, let first, let second):
            let newFirst = first.split(targetSessionId: targetSessionId, axis: axis, newSession: newSession)
            let newSecond = second.split(targetSessionId: targetSessionId, axis: axis, newSession: newSession)
            if newFirst != first || newSecond != second {
                return .split(id: UUID(), axis: currentAxis, fraction: fraction, first: newFirst, second: newSecond)
            }
            return self
        }
    }

    public func remove(sessionId: UUID) -> PaneNode? {
        switch self {
        case .terminal(let s):
            if s.id == sessionId {
                return nil
            }
            return self
        case .split(let id, let axis, let fraction, let first, let second):
            let newFirst = first.remove(sessionId: sessionId)
            let newSecond = second.remove(sessionId: sessionId)
            if let newFirst, let newSecond {
                if newFirst != first || newSecond != second {
                    return .split(id: UUID(), axis: axis, fraction: fraction, first: newFirst, second: newSecond)
                }
                return self
            } else if let newFirst {
                return newFirst
            } else if let newSecond {
                return newSecond
            } else {
                return nil
            }
        }
    }

    public func updatingFraction(splitId: UUID, fraction: CGFloat) -> PaneNode {
        switch self {
        case .terminal:
            return self
        case .split(let id, let axis, let currentFraction, let first, let second):
            if id == splitId {
                let clamped = min(max(fraction, 0.05), 0.95)
                return .split(id: id, axis: axis, fraction: clamped, first: first, second: second)
            }
            let newFirst = first.updatingFraction(splitId: splitId, fraction: fraction)
            let newSecond = second.updatingFraction(splitId: splitId, fraction: fraction)
            if newFirst != first || newSecond != second {
                return .split(id: id, axis: axis, fraction: currentFraction, first: newFirst, second: newSecond)
            }
            return self
        }
    }

    public func equalized() -> PaneNode {
        switch self {
        case .terminal:
            return self
        case .split(let id, let axis, _, let first, let second):
            return .split(id: id, axis: axis, fraction: 0.5, first: first.equalized(), second: second.equalized())
        }
    }

    /// Computes normalized rects [0, 1] x [0, 1] for each pane to support geometric directional navigation
    public func computeNormalizedFrames(in rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> [(UUID, CGRect)] {
        switch self {
        case .terminal(let s):
            return [(s.id, rect)]
        case .split(_, let axis, let fraction, let first, let second):
            if axis == .horizontal {
                let w1 = rect.width * fraction
                let r1 = CGRect(x: rect.minX, y: rect.minY, width: w1, height: rect.height)
                let r2 = CGRect(x: rect.minX + w1, y: rect.minY, width: max(0, rect.width - w1), height: rect.height)
                return first.computeNormalizedFrames(in: r1) + second.computeNormalizedFrames(in: r2)
            } else {
                let h1 = rect.height * fraction
                let r1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h1)
                let r2 = CGRect(x: rect.minX, y: rect.minY + h1, width: rect.width, height: max(0, rect.height - h1))
                return first.computeNormalizedFrames(in: r1) + second.computeNormalizedFrames(in: r2)
            }
        }
    }
}

public enum PaneDirection {
    case left
    case right
    case up
    case down
}

// MARK: - SuqiTab (Tab Model)

@MainActor
public final class SuqiTab: ObservableObject, Identifiable {
    public let id: UUID
    @Published public var rootPane: PaneNode
    @Published public var activeSessionId: UUID
    @Published public var isZoomed: Bool = false
    /// Monotonically increasing counter — forces SwiftUI to see pane tree mutations
    @Published public var paneVersion: Int = 0

    public init(session: SuqiTerminalSession) {
        self.id = UUID()
        self.rootPane = .terminal(session)
        self.activeSessionId = session.id
    }

    public var title: String {
        activeSession?.title ?? "zsh"
    }

    public var displayDirectory: String {
        activeSession?.displayDirectory ?? "~"
    }

    public var displayPathFormatted: String {
        activeSession?.displayPathFormatted ?? "~"
    }

    public var tabDisplayTitle: String {
        activeSession?.tabDisplayTitle ?? displayDirectory
    }

    public var hasActiveProcess: Bool {
        allSessions.contains { $0.hasActiveProcess }
    }

    public var activeSession: SuqiTerminalSession? {
        rootPane.findSession(id: activeSessionId) ?? rootPane.allSessions.first
    }

    public var allSessions: [SuqiTerminalSession] {
        rootPane.allSessions
    }

    public func splitActive(axis: Axis, newSession: SuqiTerminalSession) {
        let targetId = (rootPane.findSession(id: activeSessionId) != nil)
            ? activeSessionId
            : (rootPane.allSessions.first?.id ?? activeSessionId)
        rootPane = rootPane.split(targetSessionId: targetId, axis: axis, newSession: newSession)
        activeSessionId = newSession.id
        isZoomed = false
        paneVersion += 1
    }

    public func closeSession(id: UUID) -> Bool {
        if let session = rootPane.findSession(id: id) {
            session.tearDown()
        }
        if let newRoot = rootPane.remove(sessionId: id) {
            rootPane = newRoot
            if activeSessionId == id {
                activeSessionId = rootPane.allSessions.first?.id ?? UUID()
            }
            if rootPane.allSessions.count <= 1 {
                isZoomed = false
            }
            paneVersion += 1
            return true
        }
        return false
    }

    public func updateSplitFraction(splitId: UUID, fraction: CGFloat) {
        rootPane = rootPane.updatingFraction(splitId: splitId, fraction: fraction)
    }

    public func equalizeSplits() {
        rootPane = rootPane.equalized()
        isZoomed = false
        paneVersion += 1
    }

    public func toggleZoom() {
        if isZoomed {
            isZoomed = false
        } else if rootPane.allSessions.count > 1 {
            isZoomed = true
        }
    }

    public func focusPane(in direction: PaneDirection) {
        if isZoomed { isZoomed = false }
        let frames = rootPane.computeNormalizedFrames()
        guard let current = frames.first(where: { $0.0 == activeSessionId }) else { return }
        let curFrame = current.1

        var bestTarget: UUID?
        var bestScore: CGFloat = .greatestFiniteMagnitude

        for (id, frame) in frames where id != activeSessionId {
            let primaryGap: CGFloat
            let perpOverlap: CGFloat
            let centerDist: CGFloat

            switch direction {
            case .left:
                guard frame.maxX <= curFrame.minX + 0.001 else { continue }
                primaryGap = curFrame.minX - frame.maxX
                perpOverlap = max(0, min(curFrame.maxY, frame.maxY) - max(curFrame.minY, frame.minY))
                centerDist = abs(frame.midY - curFrame.midY)
            case .right:
                guard frame.minX >= curFrame.maxX - 0.001 else { continue }
                primaryGap = frame.minX - curFrame.maxX
                perpOverlap = max(0, min(curFrame.maxY, frame.maxY) - max(curFrame.minY, frame.minY))
                centerDist = abs(frame.midY - curFrame.midY)
            case .up:
                guard frame.maxY <= curFrame.minY + 0.001 else { continue }
                primaryGap = curFrame.minY - frame.maxY
                perpOverlap = max(0, min(curFrame.maxX, frame.maxX) - max(curFrame.minX, frame.minX))
                centerDist = abs(frame.midX - curFrame.midX)
            case .down:
                guard frame.minY >= curFrame.maxY - 0.001 else { continue }
                primaryGap = frame.minY - curFrame.maxY
                perpOverlap = max(0, min(curFrame.maxX, frame.maxX) - max(curFrame.minX, frame.minX))
                centerDist = abs(frame.midX - curFrame.midX)
            }

            let score = primaryGap * 10 - perpOverlap * 5 + centerDist
            if score < bestScore {
                bestScore = score
                bestTarget = id
            }
        }

        if let target = bestTarget {
            activeSessionId = target
        }
    }
}

// MARK: - SuqiWindowModel (Single Window Model)

@MainActor
public final class SuqiWindowModel: ObservableObject {
    @Published public private(set) var tabs: [SuqiTab] = []
    @Published public var activeTabId: UUID?
    @Published public var isSearching: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var pendingSafePaste: SafePasteRequest? = nil

    /// Window close callback
    public var onCloseWindowRequested: (() -> Void)?

    public var sessions: [SuqiTerminalSession] {
        tabs.flatMap { $0.allSessions }
    }

    public var activeTab: SuqiTab? {
        guard let activeTabId else { return tabs.first }
        return tabs.first { $0.id == activeTabId } ?? tabs.first
    }

    public var activeSession: SuqiTerminalSession? {
        activeTab?.activeSession
    }

    public var activeSessionId: UUID? {
        get { activeTab?.activeSessionId }
        set {
            if let val = newValue {
                activeTab?.activeSessionId = val
            }
        }
    }

    public var activeIndex: Int {
        guard let activeTabId else { return 0 }
        return tabs.firstIndex { $0.id == activeTabId } ?? 0
    }

    public init(initialWorkingDirectory: String? = nil) {
        let dir = SuqiDirectoryManager.resolvedInitialWorkingDirectory(explicit: initialWorkingDirectory)
        let session = SuqiTerminalSession(workingDirectory: dir)
        let tab = SuqiTab(session: session)
        self.tabs = [tab]
        self.activeTabId = tab.id
        attachSessionCallbacks(session)
    }

    public init(withTab tab: SuqiTab) {
        self.tabs = [tab]
        self.activeTabId = tab.id
        for session in tab.allSessions {
            attachSessionCallbacks(session)
        }
    }

    private func attachSessionCallbacks(_ session: SuqiTerminalSession) {
        session.onFocused = { [weak self, weak session] in
            guard let self, let session else { return }
            self.selectSession(id: session.id)
        }
        session.onClosed = { [weak self, weak session] in
            guard let self, let session else { return }
            _ = self.closeSession(id: session.id)
        }
    }

    /// Suspends background CWD polling for inactive tabs and resumes for the active tab to conserve CPU and energy
    public func synchronizeSessionTimers() {
        guard let currentTab = activeTab else { return }
        for tab in tabs {
            if tab.id == currentTab.id {
                for session in tab.allSessions {
                    session.resumeCwdMonitor(forceUpdate: true)
                }
            } else {
                for session in tab.allSessions {
                    session.pauseCwdMonitor()
                }
            }
        }
    }

    /// Sets keyboard focus (First Responder) to the active terminal view and synchronizes timers
    public func focusActiveSession() {
        synchronizeSessionTimers()
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.activeSession else { return }
            session.terminalView.window?.makeFirstResponder(session.terminalView)
        }
    }

    /// Closes a terminal session by ID (triggered by process exit or pane close)
    @discardableResult
    public func closeSession(id: UUID) -> Bool {
        objectWillChange.send()
        for tab in tabs {
            if tab.allSessions.contains(where: { $0.id == id }) {
                tab.objectWillChange.send()
                let hasPanesRemaining = tab.closeSession(id: id)
                if !hasPanesRemaining {
                    return closeTab(id: tab.id)
                }
                focusActiveSession()
                return true
            }
        }
        return false
    }

    // ⌘T: New Tab (inherits working directory from active session)
    @discardableResult
    public func createNewTab(workingDirectory: String? = nil) -> SuqiTerminalSession {
        objectWillChange.send()
        let initialDir = SuqiDirectoryManager.resolvedInitialWorkingDirectory(
            explicit: workingDirectory ?? activeSession?.fullDirectory
        )
        let session = SuqiTerminalSession(workingDirectory: initialDir)
        attachSessionCallbacks(session)
        let tab = SuqiTab(session: session)
        tabs.append(tab)
        activeTabId = tab.id
        focusActiveSession()
        return session
    }

    // ⌘D: Split Right
    @discardableResult
    public func splitRight(workingDirectory: String? = nil) -> SuqiTerminalSession {
        splitActivePane(axis: .horizontal, workingDirectory: workingDirectory)
    }

    // ⌘Shift+D: Split Down
    @discardableResult
    public func splitDown(workingDirectory: String? = nil) -> SuqiTerminalSession {
        splitActivePane(axis: .vertical, workingDirectory: workingDirectory)
    }

    @discardableResult
    public func splitActivePane(axis: Axis, workingDirectory: String? = nil) -> SuqiTerminalSession {
        objectWillChange.send()
        let initialDir = SuqiDirectoryManager.resolvedInitialWorkingDirectory(
            explicit: workingDirectory ?? activeSession?.fullDirectory
        )
        let session = SuqiTerminalSession(workingDirectory: initialDir)
        attachSessionCallbacks(session)

        if let currentTab = activeTab {
            currentTab.objectWillChange.send()
            currentTab.splitActive(axis: axis, newSession: session)
        } else {
            let tab = SuqiTab(session: session)
            tabs.append(tab)
            activeTabId = tab.id
        }
        focusActiveSession()
        return session
    }

    // ⌘W: Close active pane; if all panes closed, close tab; if last tab, close window
    @discardableResult
    public func closeActiveSession() -> Bool {
        objectWillChange.send()
        guard let currentTab = activeTab else {
            onCloseWindowRequested?()
            return false
        }

        currentTab.objectWillChange.send()
        let currentSessionId = currentTab.activeSessionId
        let hasPanesRemaining = currentTab.closeSession(id: currentSessionId)

        if !hasPanesRemaining {
            return closeTab(id: currentTab.id)
        }
        focusActiveSession()
        return true
    }

    /// Safely tears down and releases all terminal sessions across all tabs
    public func tearDownAllSessions() {
        for tab in tabs {
            for session in tab.allSessions {
                session.tearDown()
            }
        }
        tabs.removeAll()
    }

    /// Closes the active session, prompting user confirmation if a non-shell process is running
    public func closeActiveSessionWithConfirmation(in window: NSWindow?) {
        guard let session = activeSession else {
            _ = closeActiveSession()
            return
        }

        if session.hasActiveProcess, let proc = session.activeProcessName {
            let alert = NSAlert()
            alert.messageText = "Close session running '\(proc)'?"
            alert.informativeText = "Closing this session will terminate the running process."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Close")
            alert.addButton(withTitle: "Cancel")

            if let window {
                alert.beginSheetModal(for: window) { [weak self] response in
                    if response == .alertFirstButtonReturn {
                        self?.closeActiveSession()
                    }
                }
                return
            }
        }

        _ = closeActiveSession()
    }

    /// Closes a tab by ID, prompting user confirmation if any session in the tab has a running process
    public func closeTabWithConfirmation(id: UUID, in window: NSWindow?) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        let running = tab.allSessions.filter { $0.hasActiveProcess }
        if let first = running.first, let proc = first.activeProcessName {
            let alert = NSAlert()
            alert.messageText = "Close tab running '\(proc)'?"
            alert.informativeText = "There are active processes running in this tab. Closing it will terminate them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Close Tab")
            alert.addButton(withTitle: "Cancel")

            if let window {
                alert.beginSheetModal(for: window) { [weak self] response in
                    if response == .alertFirstButtonReturn {
                        _ = self?.closeTab(id: id)
                    }
                }
                return
            }
        }

        _ = closeTab(id: id)
    }

    @discardableResult
    public func closeTab(id: UUID) -> Bool {
        objectWillChange.send()
        guard tabs.count > 1 else {
            // Last tab closed, notify controller to close window
            onCloseWindowRequested?()
            return false
        }

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            let tab = tabs.remove(at: index)
            for session in tab.allSessions {
                session.tearDown()
            }
            if activeTabId == id {
                let newIndex = max(0, min(index, tabs.count - 1))
                activeTabId = tabs[newIndex].id
            }
            focusActiveSession()
        }
        return true
    }

    public func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
            focusActiveSession()
        }
    }

    public func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabId = tabs[index].id
        focusActiveSession()
    }

    public func selectSession(id: UUID) {
        for tab in tabs {
            if tab.allSessions.contains(where: { $0.id == id }) {
                activeTabId = tab.id
                tab.activeSessionId = id
                focusActiveSession()
                return
            }
        }
    }

    public func nextTab() {
        guard !tabs.isEmpty else { return }
        let next = (activeIndex + 1) % tabs.count
        activeTabId = tabs[next].id
        focusActiveSession()
    }

    public func previousTab() {
        guard !tabs.isEmpty else { return }
        let prev = (activeIndex - 1 + tabs.count) % tabs.count
        activeTabId = tabs[prev].id
        focusActiveSession()
    }

    public func nextPane() {
        guard let currentTab = activeTab else { return }
        let all = currentTab.allSessions
        guard all.count > 1 else { return }
        if let idx = all.firstIndex(where: { $0.id == currentTab.activeSessionId }) {
            let next = (idx + 1) % all.count
            currentTab.activeSessionId = all[next].id
            focusActiveSession()
        }
    }

    public func previousPane() {
        guard let currentTab = activeTab else { return }
        let all = currentTab.allSessions
        guard all.count > 1 else { return }
        if let idx = all.firstIndex(where: { $0.id == currentTab.activeSessionId }) {
            let prev = (idx - 1 + all.count) % all.count
            currentTab.activeSessionId = all[prev].id
            focusActiveSession()
        }
    }

    public func restartActiveSession() {
        activeSession?.restart()
    }

    public func clearActiveSession() {
        activeSession?.clearScreen()
    }

    /// Hot-reloads all terminal session configurations without killing running processes
    public func reloadAllSessions() {
        for session in sessions {
            session.reloadConfiguration()
        }
    }

    public func updateSplitFraction(splitId: UUID, fraction: CGFloat) {
        activeTab?.updateSplitFraction(splitId: splitId, fraction: fraction)
    }

    public func equalizeSplits() {
        activeTab?.equalizeSplits()
    }

    public func toggleZoom() {
        activeTab?.toggleZoom()
        focusActiveSession()
    }

    public func focusPane(in direction: PaneDirection) {
        activeTab?.focusPane(in: direction)
        focusActiveSession()
    }

    public func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < tabs.count,
              destinationIndex >= 0, destinationIndex < tabs.count,
              sourceIndex != destinationIndex else { return }
        objectWillChange.send()
        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
    }

    /// Confirms and pastes the safe-paste text into the active session
    public func confirmSafePaste(asSingleLine: Bool = false) {
        guard let req = pendingSafePaste else { return }
        let textToSend: String
        if asSingleLine {
            let lines = req.text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            textToSend = lines.joined(separator: " && ") + "\n"
        } else {
            textToSend = req.text
        }
        pendingSafePaste = nil
        activeSession?.send(textToSend)
        focusActiveSession()
    }

    /// Cancels the pending safe-paste operation
    public func cancelSafePaste() {
        pendingSafePaste = nil
        focusActiveSession()
    }

    /// Detaches a tab into a new standalone window, optionally positioned at a screen point
    public func detachTabToNewWindow(id: UUID, at screenPoint: NSPoint? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        objectWillChange.send()
        let tab = tabs.remove(at: index)
        if activeTabId == id {
            activeTabId = tabs.first?.id
        }
        SuqiWindowManager.shared.createWindow(withTab: tab, at: screenPoint)
        if tabs.isEmpty {
            onCloseWindowRequested?()
        } else {
            focusActiveSession()
        }
    }

    /// Removes a tab without closing the window (used for cross-window tab dragging)
    @discardableResult
    public func removeTabWithoutClosingWindow(id: UUID) -> SuqiTab? {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return nil }
        objectWillChange.send()
        let tab = tabs.remove(at: index)
        if activeTabId == id {
            activeTabId = tabs.first?.id
        }
        if tabs.isEmpty {
            onCloseWindowRequested?()
        } else {
            focusActiveSession()
        }
        return tab
    }

    /// Inserts an existing tab at the specified index (used for cross-window tab dragging)
    public func insertTab(_ tab: SuqiTab, at index: Int) {
        objectWillChange.send()
        let targetIndex = max(0, min(index, tabs.count))
        for session in tab.allSessions {
            attachSessionCallbacks(session)
        }
        tabs.insert(tab, at: targetIndex)
        activeTabId = tab.id
        focusActiveSession()
    }

    /// Background occlusion state handling for power efficiency
    public func pauseBackgroundRendering() {
        for session in sessions {
            _ = session.state.surface?.performBindingAction("pause")
            session.pauseCwdMonitor()
        }
    }

    public func resumeBackgroundRendering() {
        for session in sessions {
            _ = session.state.surface?.performBindingAction("resume")
        }
        synchronizeSessionTimers()
    }

    /// Toggles window stay-on-top pinned status (.floating window level)
    public func togglePin(in window: NSWindow? = nil) {
        objectWillChange.send()
        isPinned.toggle()
        let target = window ?? activeSession?.terminalView.window ?? NSApp.keyWindow
        if let target {
            target.level = isPinned ? .floating : .normal
            if isPinned {
                target.collectionBehavior.insert(.canJoinAllSpaces)
            } else {
                target.collectionBehavior.remove(.canJoinAllSpaces)
            }
        }
    }
}
