//
//  SiqiConfigLoader.swift
//  siqi
//
//  Created for siqi Terminal.
//

import Foundation
import SwiftUI
import AppKit

public typealias GhosttyUserConfig = SiqiUserConfig

public struct SiqiKeybinding: Equatable, Sendable {
    public let key: String
    public let modifiers: Set<String>
    public let action: String
}

public struct SiqiUserConfig: Sendable {
    public var themeName: String = "Catppuccin Mocha"
    public var fontFamily: String = "Maple Mono NF"
    public var fontSize: Double = 13.0
    public var fontThicken: Bool = true
    public var backgroundOpacity: Double = 1.0
    public var backgroundOpacityCells: Bool = false
    public var backgroundBlur: Int = 0
    public var windowPaddingX: Int = 12
    public var windowPaddingY: Int = 8
    public var cursorStyle: String = "bar"
    public var cursorBlink: Bool = true
    public var copyOnSelect: Bool = true
    public var adjustCellHeight: Int = 0
    public var macosTitlebarStyle: String = "tabs"
    public var shellIntegration: String = "zsh"
    public var windowSaveState: String = "always"
    public var windowWidth: Int? = nil
    public var windowHeight: Int? = nil
    public var background: String? = "30333E"
    public var foreground: String? = nil
    public var workingDirectory: String? = nil
    public var restoreLastWorkingDirectory: Bool = false
    public var unfocusedSplitOpacity: Double = 1.0
    public var mouseScrollMultiplier: Double = 1.0
    public var command: String? = nil
    public var fontFeatures: [String] = []
    public var confirmCloseSurface: Bool = false
    public var keybindings: [SiqiKeybinding] = []
    public var quickTerminalPosition: String = "top"
    public var quickTerminalScreen: String = "mouse"
    public var quickTerminalAutohide: Bool = true
    public var quickTerminalAnimationDuration: Double = 0.2
    public var quickTerminalSize: String = "50%"

    /// Parses a Ghostty-style `keybind = cmd+shift+e=new_tab` value
    public static func parseKeybinding(_ value: String) -> SiqiKeybinding? {
        guard let separator = value.lastIndex(of: "=") else { return nil }
        let trigger = value[..<separator]
        let action = value[value.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !action.isEmpty else { return nil }
        var modifiers: Set<String> = []
        var key = ""
        for part in trigger.split(separator: "+") {
            switch part.lowercased() {
            case "cmd", "super", "command": modifiers.insert("cmd")
            case "ctrl", "control": modifiers.insert("ctrl")
            case "alt", "opt", "option": modifiers.insert("alt")
            case "shift": modifiers.insert("shift")
            default: key = part.lowercased()
            }
        }
        guard !key.isEmpty else { return nil }
        return SiqiKeybinding(key: key, modifiers: modifiers, action: action)
    }

    // mtime+size cache: every body evaluation used to re-read and re-parse the config file
    private static var cache: (config: SiqiUserConfig, filePath: String, mtime: Date, size: UInt64)?
    // load() is reachable from background callers, so the cache needs a lock.
    private static let cacheLock = NSLock()

    public static func load() -> (config: SiqiUserConfig, filePath: String?) {
        let siqiPath = NSString(string: "~/.config/siqi/config").expandingTildeInPath
        let legacySuqiPath = NSString(string: "~/.config/suqi/config").expandingTildeInPath
        let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath

        let targetPath: String? = {
            if FileManager.default.fileExists(atPath: siqiPath) {
                return siqiPath
            } else if FileManager.default.fileExists(atPath: legacySuqiPath) {
                return legacySuqiPath
            } else if FileManager.default.fileExists(atPath: ghosttyPath) {
                return ghosttyPath
            }
            return nil
        }()

        var cfg = SiqiUserConfig()
        guard let path = targetPath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? UInt64 else {
            return (cfg, nil)
        }
        cacheLock.lock()
        let cached = Self.cache
        cacheLock.unlock()
        if let cached, cached.filePath == path, cached.mtime == mtime, cached.size == size {
            return (cached.config, path)
        }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return (cfg, nil)
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))

            switch key {
            case "theme":
                cfg.themeName = val
            case "font-family":
                cfg.fontFamily = val
            case "font-size":
                if let v = Double(val) { cfg.fontSize = v }
            case "font-thicken":
                cfg.fontThicken = (val.lowercased() == "true")
            case "adjust-cell-height":
                if let v = Int(val) { cfg.adjustCellHeight = v }
            case "background-opacity":
                if let v = Double(val) { cfg.backgroundOpacity = v }
            case "background-opacity-cells":
                cfg.backgroundOpacityCells = (val.lowercased() == "true")
            case "background-blur":
                if let v = Int(val) { cfg.backgroundBlur = v }
                else if val.lowercased() == "true" { cfg.backgroundBlur = 20 }
            case "window-padding-x":
                if let v = Int(val) { cfg.windowPaddingX = v }
            case "window-padding-y":
                if let v = Int(val) { cfg.windowPaddingY = v }
            case "macos-titlebar-style":
                cfg.macosTitlebarStyle = val
            case "window-save-state":
                cfg.windowSaveState = val
            case "window-width":
                if let v = Int(val) { cfg.windowWidth = v }
            case "window-height":
                if let v = Int(val) { cfg.windowHeight = v }
            case "cursor-style":
                cfg.cursorStyle = val
            case "cursor-style-blink":
                cfg.cursorBlink = (val.lowercased() == "true")
            case "copy-on-select":
                cfg.copyOnSelect = (val.lowercased() == "clipboard" || val.lowercased() == "true")
            case "shell-integration":
                cfg.shellIntegration = val
            case "working-directory", "initial-working-directory":
                cfg.workingDirectory = val
            case "restore-last-working-directory":
                cfg.restoreLastWorkingDirectory = (val.lowercased() == "true")
            case "background":
                cfg.background = val
            case "foreground":
                cfg.foreground = val
            case "unfocused-split-opacity":
                if let v = Double(val) { cfg.unfocusedSplitOpacity = max(0.0, min(1.0, v)) }
            case "mouse-scroll-multiplier":
                if let v = Double(val) { cfg.mouseScrollMultiplier = max(0.1, min(10.0, v)) }
            case "command":
                let trimmedCmd = val.trimmingCharacters(in: .whitespaces)
                cfg.command = trimmedCmd.isEmpty ? nil : trimmedCmd
            case "font-feature":
                let features = val.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                for f in features where !f.isEmpty {
                    cfg.fontFeatures.append(f)
                }
            case "confirm-close-surface":
                cfg.confirmCloseSurface = (val.lowercased() == "true")
            case "keybind":
                if let binding = Self.parseKeybinding(val) {
                    cfg.keybindings.append(binding)
                }
            case "quick-terminal-position":
                cfg.quickTerminalPosition = val.lowercased()
            case "quick-terminal-screen":
                cfg.quickTerminalScreen = val.lowercased()
            case "quick-terminal-autohide":
                cfg.quickTerminalAutohide = (val.lowercased() == "true")
            case "quick-terminal-animation-duration":
                if let v = Double(val) { cfg.quickTerminalAnimationDuration = max(0, v) }
            case "quick-terminal-size":
                cfg.quickTerminalSize = val
            default:
                break
            }
        }

        cacheLock.lock()
        Self.cache = (cfg, path, mtime, size)
        cacheLock.unlock()
        return (cfg, path)
    }

    /// Updates configuration values and writes back to ~/.config/siqi/config with hot reload
    public static func saveValues(_ updates: [String: String]) {
        let siqiDir = NSString(string: "~/.config/siqi").expandingTildeInPath
        let siqiPath = NSString(string: "~/.config/siqi/config").expandingTildeInPath
        let legacySuqiPath = NSString(string: "~/.config/suqi/config").expandingTildeInPath
        let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: siqiDir) {
            try? fileManager.createDirectory(atPath: siqiDir, withIntermediateDirectories: true)
        }

        var lines: [String] = []
        if fileManager.fileExists(atPath: siqiPath) {
            if let content = try? String(contentsOfFile: siqiPath, encoding: .utf8) {
                lines = content.components(separatedBy: .newlines)
            }
        } else if fileManager.fileExists(atPath: legacySuqiPath) {
            if let content = try? String(contentsOfFile: legacySuqiPath, encoding: .utf8) {
                lines = content.components(separatedBy: .newlines)
            }
        } else if fileManager.fileExists(atPath: ghosttyPath) {
            if let content = try? String(contentsOfFile: ghosttyPath, encoding: .utf8) {
                lines = content.components(separatedBy: .newlines)
            }
        }

        var remainingUpdates = updates
        var updatedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, let newVal = updates[parts[0]] {
                    updatedLines.append("\(parts[0]) = \(newVal)")
                    remainingUpdates.removeValue(forKey: parts[0])
                    continue
                }
            }
            updatedLines.append(line)
        }

        for (k, v) in remainingUpdates {
            updatedLines.append("\(k) = \(v)")
        }

        let newContent = updatedLines.joined(separator: "\n")
        // Write back to the file we load from: a config that started life as
        // ~/.config/ghostty/config would otherwise fork on the first edit and
        // later edits to the original would stop taking effect.
        let targetPath = SiqiUserConfig.load().filePath ?? siqiPath
        do {
            try newContent.write(toFile: targetPath, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Failed to write config to %@: %@", targetPath, error.localizedDescription)
        }
        NotificationCenter.default.post(name: .siqiConfigDidChange, object: nil)
    }
}

extension Notification.Name {
    public static let siqiConfigDidChange = Notification.Name("SiqiConfigDidChange")
    public static let ghosttyConfigDidChange = siqiConfigDidChange
}

// MARK: - Configuration File Hot Reload Watcher (monitors ~/.config/siqi/config or fallback ~/.config/ghostty/config)

public typealias GhosttyConfigFileWatcher = SiqiConfigFileWatcher

@MainActor
public final class SiqiConfigFileWatcher: ObservableObject {
    public static let shared = SiqiConfigFileWatcher()

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    public init() {
        startWatching()
    }

    public func startWatching() {
        stopWatching()

        let (_, resolvedPath) = SiqiUserConfig.load()
        guard let path = resolvedPath else { return }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        // Cancel handlers run asynchronously, by which time fileDescriptor may
        // already point at a newer source; close the fd this source owns.
        let watchedFd = fileDescriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: .siqiConfigDidChange, object: nil)
            // Re-watch file upon changes to support atomic save/rename mechanisms (Vim/VSCode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.startWatching()
            }
        }

        source.setCancelHandler {
            close(watchedFd)
        }

        source.resume()
        self.fileSource = source
    }

    public func stopWatching() {
        fileSource?.cancel()
        fileSource = nil
        fileDescriptor = -1
    }
}

// MARK: - Darwin Process Helper (Direct Kernel CWD Inspection)

#if canImport(Darwin)
import Darwin

public enum DarwinProcessHelper {
    public static func getCwd(for pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var vpi = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, Int32(size))
        if result == size {
            return withUnsafePointer(to: &vpi.pvi_cdir.vip_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cStr in
                    let path = String(cString: cStr).trimmingCharacters(in: .whitespacesAndNewlines)
                    return path.isEmpty ? nil : path
                }
            }
        }
        return nil
    }

    public static func getChildPids(for parentPid: pid_t) -> [pid_t] {
        let count = proc_listchildpids(parentPid, nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count))
        let actual = proc_listchildpids(parentPid, &pids, count * Int32(MemoryLayout<pid_t>.stride))
        guard actual > 0 else { return [] }
        return Array(pids.prefix(Int(actual)))
    }

    private static let shellProcessNames: Set<String> = [
        "zsh", "bash", "fish", "sh", "tcsh", "csh", "ksh", "login",
        "-zsh", "-bash", "-fish", "siqi", "ghostty"
    ]

    public struct ChildProcessInfo {
        public let name: String?
        public let cwd: String?
    }

    /// One process-table walk for the newest foreground child: its name and working directory
    public static func findLatestChildInfo(for parentPid: pid_t = getpid(), maxDepth: Int = 6) -> ChildProcessInfo? {
        var name: String?
        var cwd: String?
        func search(pid: pid_t, depth: Int) -> Bool {
            guard depth <= maxDepth else { return false }
            for child in getChildPids(for: pid).reversed() {
                if name == nil, let rawName = getProcessName(for: child) {
                    let clean = rawName.lowercased()
                    if !clean.isEmpty && !shellProcessNames.contains(clean) {
                        name = rawName
                    }
                }
                if cwd == nil, let found = getCwd(for: child), !found.isEmpty {
                    cwd = found
                }
                if name != nil && cwd != nil { return true }
                if search(pid: child, depth: depth + 1) { return true }
            }
            return false
        }
        _ = search(pid: parentPid, depth: 1)
        guard name != nil || cwd != nil else { return nil }
        return ChildProcessInfo(name: name, cwd: cwd)
    }

    public static func getProcessName(for pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: 256)
        let ret = proc_name(pid, &buf, 256)
        if ret > 0 {
            let name = String(cString: buf).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    public static func hasDescendantProcess(for parentPid: pid_t = getpid(), matching keywords: Set<String>, maxDepth: Int = 6) -> Bool {
        func search(pid: pid_t, depth: Int) -> Bool {
            guard depth <= maxDepth else { return false }
            let children = getChildPids(for: pid)
            for child in children {
                if let rawName = getProcessName(for: child)?.lowercased() {
                    for kw in keywords {
                        if rawName.contains(kw) { return true }
                    }
                }
                if search(pid: child, depth: depth + 1) {
                    return true
                }
            }
            return false
        }
        return search(pid: parentPid, depth: 1)
    }
}
#endif

// MARK: - Working Directory Manager (Persistent Last Working Directory)

@MainActor
public enum SiqiDirectoryManager {
    public static let lastDirKey = "SiqiLastWorkingDirectory"
    private static let cacheFilePath = NSString(string: "~/.cache/siqi/last_working_directory").expandingTildeInPath

    /// Resolves the preferred working directory in order:
    /// 1. Explicit directory passed by caller (e.g. new tab / split inheriting active cwd)
    /// 2. Siqi config `working-directory` or `initial-working-directory` (or fallback config)
    /// 3. Disk cache file / UserDefaults (only if `restore-last-working-directory = true` in config)
    /// 4. User's Home directory (`NSHomeDirectory()`)
    public static func resolvedInitialWorkingDirectory(explicit: String? = nil) -> String {
        if let explicit, !explicit.isEmpty {
            let expanded = NSString(string: explicit).expandingTildeInPath
            if !expanded.isEmpty {
                return expanded
            }
        }

        let (config, _) = SiqiUserConfig.load()
        if let configDir = config.workingDirectory, !configDir.isEmpty {
            let expanded = NSString(string: configDir).expandingTildeInPath
            if !expanded.isEmpty {
                return expanded
            }
        }

        // Only restore previous working directory across cold starts if explicitly enabled in user config
        if config.restoreLastWorkingDirectory {
            // Check disk cache file
            if let fileContent = try? String(contentsOfFile: cacheFilePath, encoding: .utf8) {
                let trimmed = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let expanded = NSString(string: trimmed).expandingTildeInPath
                    if FileManager.default.fileExists(atPath: expanded) {
                        return expanded
                    }
                }
            }

            // Check UserDefaults
            if let saved = UserDefaults.standard.string(forKey: lastDirKey), !saved.isEmpty {
                let expanded = NSString(string: saved).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    return expanded
                }
            }
        }

        return NSHomeDirectory()
    }

    public static var lastWorkingDirectory: String {
        resolvedInitialWorkingDirectory()
    }

    public static func saveLastWorkingDirectory(_ path: String?) {
        guard let path, !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
            UserDefaults.standard.set(expanded, forKey: lastDirKey)

            // Also atomically persist to disk cache file
            let cacheDir = NSString(string: "~/.cache/siqi").expandingTildeInPath
            try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
            try? expanded.write(toFile: cacheFilePath, atomically: true, encoding: .utf8)
        }
    }
}

