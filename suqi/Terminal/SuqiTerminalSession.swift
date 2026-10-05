//
//  SuqiTerminalSession.swift
//  suqi
//
//  Created for suqi Terminal.
//

import Foundation
import SwiftUI
import Combine
import GhosttyTerminal
import GhosttyTheme

@MainActor
public final class SuqiTerminalSession: ObservableObject, Identifiable, Equatable {
    public let id: UUID
    public let createdAt: Date

    @Published public private(set) var state: TerminalViewState
    @Published public var customTitle: String?
    public var initialWorkingDirectory: String
    public var onFocused: (() -> Void)?
    public var onClosed: (() -> Void)?
    public let terminalView: AppTerminalView
    private var cancellables = Set<AnyCancellable>()
    private var cwdMonitorTimer: Timer?
    private var lastKnownDirectory: String = ""

    public nonisolated static func == (lhs: SuqiTerminalSession, rhs: SuqiTerminalSession) -> Bool {
        lhs.id == rhs.id
    }

    public init(id: UUID = UUID(), workingDirectory: String? = nil) {
        self.id = id
        self.createdAt = Date()
        let initialDir = SuqiDirectoryManager.resolvedInitialWorkingDirectory(explicit: workingDirectory)
        self.initialWorkingDirectory = initialDir
        self.lastKnownDirectory = initialDir
        let state = Self.buildTerminalViewState(workingDirectory: initialDir)
        self.state = state

        let view = AppTerminalView(frame: .zero)
        view.delegate = state
        view.controller = state.controller
        view.configuration = state.configuration
        view.registerTerminalDragTypes()
        self.terminalView = view

        bindState()
        startCwdMonitor()
    }

    private func bindState() {
        cancellables.removeAll()

        state.onClose = { [weak self] _ in
            guard let self else { return }
            self.onClosed?()
        }

        state.$isFocused
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                self.onFocused?()
                let current = self.fullDirectory
                SuqiDirectoryManager.saveLastWorkingDirectory(current)
            }
            .store(in: &cancellables)

        state.$workingDirectory
            .sink { [weak self] newDir in
                guard let self else { return }
                if let newDir, !newDir.isEmpty {
                    self.lastKnownDirectory = newDir
                    SuqiDirectoryManager.saveLastWorkingDirectory(newDir)
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        state.$title
            .sink { [weak self] _ in
                guard let self else { return }
                let current = self.fullDirectory
                SuqiDirectoryManager.saveLastWorkingDirectory(current)
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        state.$scrollbar
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .ghosttyConfigDidChange)
            .sink { [weak self] _ in
                self?.reloadConfiguration()
            }
            .store(in: &cancellables)
    }

    public private(set) var isCwdMonitorActive: Bool = false

    /// Suspends background CWD polling timer to eliminate idle CPU wakeups when tab or window is inactive
    public func pauseCwdMonitor() {
        cwdMonitorTimer?.invalidate()
        cwdMonitorTimer = nil
        isCwdMonitorActive = false
    }

    /// Resumes CWD polling timer and performs an immediate directory synchronization
    public func resumeCwdMonitor(forceUpdate: Bool = true) {
        if forceUpdate {
            let current = self.fullDirectory
            if current != self.lastKnownDirectory {
                self.lastKnownDirectory = current
                SuqiDirectoryManager.saveLastWorkingDirectory(current)
                self.objectWillChange.send()
            }
        }
        guard cwdMonitorTimer == nil else { return }
        isCwdMonitorActive = true
        cwdMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isCwdMonitorActive else { return }
                let current = self.fullDirectory
                if current != self.lastKnownDirectory {
                    self.lastKnownDirectory = current
                    SuqiDirectoryManager.saveLastWorkingDirectory(current)
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func startCwdMonitor() {
        resumeCwdMonitor(forceUpdate: false)
    }

    public var title: String {
        if let customTitle, !customTitle.isEmpty {
            return customTitle
        }
        if !state.title.isEmpty {
            return state.title
        }
        return "zsh"
    }

    /// Detects active foreground process running in this session (e.g. vim, nvim, ssh, python, cargo, agy, claude, codex)
    public var activeProcessName: String? {
        let raw = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultShells: Set<String> = [
            "zsh", "bash", "fish", "sh", "tcsh", "csh", "ksh", "login",
            "-zsh", "-bash", "-fish", "suqi"
        ]
        if !raw.isEmpty {
            let firstToken = raw.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
            let cleanToken = firstToken.hasPrefix("-") ? String(firstToken.dropFirst()) : firstToken
            if !defaultShells.contains(cleanToken) {
                return raw
            }
        }

        // Fallback: query kernel process table for child processes
        if let kernelProc = DarwinProcessHelper.findLatestChildProcessName() {
            let cleanKernel = kernelProc.lowercased()
            if !defaultShells.contains(cleanKernel) {
                return kernelProc
            }
        }

        return nil
    }

    /// Indicates whether a non-shell foreground process is running
    public var hasActiveProcess: Bool {
        activeProcessName != nil
    }

    /// Formatted tab title combining active process or formatted path (e.g. ~/Desktop/siqi)
    public var tabDisplayTitle: String {
        if let proc = activeProcessName {
            return proc.components(separatedBy: .whitespaces).first ?? proc
        }
        return displayPathFormatted
    }

    public var displayDirectory: String {
        let full = fullDirectory
        if full == NSHomeDirectory() {
            return "~"
        }
        let last = URL(fileURLWithPath: full).lastPathComponent
        return last.isEmpty ? "~" : last
    }

    public var displayPathFormatted: String {
        let full = fullDirectory
        let home = NSHomeDirectory()
        if full == home {
            return "~"
        }
        if full.hasPrefix(home + "/") {
            return "~" + full.dropFirst(home.count)
        }
        return full
    }

    public var fullDirectory: String {
        if let cwd = state.workingDirectory, !cwd.isEmpty {
            return cwd
        }
        if let childCwd = DarwinProcessHelper.findLatestChildCwd(), !childCwd.isEmpty {
            return childCwd
        }
        return initialWorkingDirectory
    }

    /// In-place hot reload of themes, fonts, cursor, and configuration without restarting running processes
    public func reloadConfiguration() {
        let (userConfig, _) = GhosttyUserConfig.load()
        let theme = Self.buildTerminalTheme(userConfig: userConfig)
        state.setTheme(theme)
        let config = Self.buildTerminalConfiguration(userConfig: userConfig)
        state.setTerminalConfiguration(config)
        _ = state.surface?.performBindingAction("reload_config")
        objectWillChange.send()
    }

    /// Destroys terminal session, releasing Metal, DisplayLink, and observer resources
    public func tearDown() {
        cwdMonitorTimer?.invalidate()
        cwdMonitorTimer = nil
        SuqiDirectoryManager.saveLastWorkingDirectory(fullDirectory)
        cancellables.removeAll()
        onFocused = nil
        onClosed = nil
        terminalView.removeFromSuperview()
        _ = state.surface?.performBindingAction("close_surface")
    }

    deinit {
        cwdMonitorTimer?.invalidate()
        cancellables.removeAll()
    }

    public func restart() {
        let currentCwd = state.workingDirectory ?? initialWorkingDirectory
        self.state = Self.buildTerminalViewState(workingDirectory: currentCwd)
        terminalView.delegate = state
        terminalView.controller = state.controller
        terminalView.configuration = state.configuration
        bindState()
    }

    public func send(_ text: String) {
        state.send(text)
    }

    public func clearScreen() {
        state.send("clear\n")
    }

    public static func buildTerminalConfiguration(userConfig: GhosttyUserConfig) -> TerminalConfiguration {
        let cursorStyle: TerminalCursorStyle
        switch userConfig.cursorStyle {
        case "block":
            cursorStyle = .block
        case "underline":
            cursorStyle = .underline
        default:
            cursorStyle = .bar
        }

        return TerminalConfiguration { builder in
            builder.withFontSize(Float(userConfig.fontSize))
            builder.withFontFamily(userConfig.fontFamily)
            builder.withCursorStyle(cursorStyle)
            builder.withCursorStyleBlink(userConfig.cursorBlink)
            // Render default terminal canvas transparent; unified visual effect layer provides background
            if userConfig.backgroundOpacityCells {
                builder.withCustom("background-opacity-cells", "true")
                builder.withBackgroundOpacity(userConfig.backgroundOpacity)
            } else {
                builder.withBackgroundOpacity(0)
            }
            builder.withWindowPaddingX(userConfig.windowPaddingX)
            builder.withWindowPaddingY(userConfig.windowPaddingY)
            // Disable window-padding-balance to anchor top padding strictly and prevent prompt jitter during resizing
            builder.withCustom("window-padding-balance", "false")
            builder.withCustom("window-padding-color", "extend")
            if userConfig.adjustCellHeight != 0 {
                builder.withCustom("adjust-cell-height", "\(userConfig.adjustCellHeight)")
            }
            if userConfig.fontThicken {
                builder.withCustom("font-thicken", "true")
            }
            if userConfig.copyOnSelect {
                builder.withCustom("copy-on-select", "clipboard")
            }
            if let bg = userConfig.background {
                let cleanBg = bg.trimmingCharacters(in: CharacterSet(charactersIn: "#\"\' "))
                builder.withCustom("background", "#\(cleanBg)")
            }
            builder.withCustom("keybind", "super+c=copy_to_clipboard")
            builder.withCustom("keybind", "super+a=select_all")
        }
    }

    public static func buildTerminalTheme(userConfig: GhosttyUserConfig) -> TerminalTheme {
        let cleanBg: String? = userConfig.background?.trimmingCharacters(in: CharacterSet(charactersIn: "#\"\' "))

        guard let themeDef = GhosttyThemeCatalog.theme(named: userConfig.themeName) else {
            let defConfig = TerminalConfiguration { builder in
                if userConfig.backgroundOpacityCells {
                    builder.withCustom("background-opacity-cells", "true")
                    builder.withBackgroundOpacity(userConfig.backgroundOpacity)
                } else {
                    builder.withBackgroundOpacity(0)
                }
                if let cleanBg {
                    builder.withBackground("#\(cleanBg)")
                }
            }
            return TerminalTheme(light: defConfig, dark: defConfig)
        }

        let baseConfig = themeDef.toTerminalConfiguration()
        let customConfig = TerminalConfiguration(startingFrom: baseConfig) { builder in
            if userConfig.backgroundOpacityCells {
                builder.withCustom("background-opacity-cells", "true")
                builder.withBackgroundOpacity(userConfig.backgroundOpacity)
            } else {
                builder.withBackgroundOpacity(0)
            }
            if let cleanBg {
                builder.withBackground("#\(cleanBg)")
            }
        }
        return TerminalTheme(light: customConfig, dark: customConfig)
    }

    public static func buildTerminalViewState(workingDirectory: String) -> TerminalViewState {
        let (userConfig, resolvedPath) = GhosttyUserConfig.load()
        let theme = buildTerminalTheme(userConfig: userConfig)
        let config = buildTerminalConfiguration(userConfig: userConfig)

        let configSource: TerminalController.ConfigSource = {
            if let resolvedPath {
                return .file(resolvedPath)
            }
            return .none
        }()

        let viewState = TerminalViewState(
            configSource: configSource,
            theme: theme,
            terminalConfiguration: config
        )

        let resolvedDir: String = {
            if workingDirectory.isEmpty || workingDirectory == "~" {
                return NSHomeDirectory()
            }
            return NSString(string: workingDirectory).expandingTildeInPath
        }()

        viewState.configuration = TerminalSurfaceOptions(
            backend: .exec,
            workingDirectory: resolvedDir,
            envVars: [
                "TERM_PROGRAM": "ghostty",
                "TERM_PROGRAM_VERSION": "1.3.1"
            ]
        )

        return viewState
    }
}
