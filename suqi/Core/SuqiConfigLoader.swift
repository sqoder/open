//
//  SuqiConfigLoader.swift
//  suqi
//
//  Created for suqi Terminal.
//

import Foundation
import SwiftUI
import AppKit

public typealias GhosttyUserConfig = SuqiUserConfig

public struct SuqiUserConfig: Sendable {
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
    public var unfocusedSplitOpacity: Double = 0.75
    public var mouseScrollMultiplier: Double = 1.0
    public var command: String? = nil
    public var fontFeatures: [String] = []
    public var confirmCloseSurface: Bool = false

    public static func load() -> (config: SuqiUserConfig, filePath: String?) {
        let suqiPath = NSString(string: "~/.config/suqi/config").expandingTildeInPath
        let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath

        let targetPath: String? = {
            if FileManager.default.fileExists(atPath: suqiPath) {
                return suqiPath
            } else if FileManager.default.fileExists(atPath: ghosttyPath) {
                return ghosttyPath
            }
            return nil
        }()

        var cfg = SuqiUserConfig()
        guard let path = targetPath, let content = try? String(contentsOfFile: path, encoding: .utf8) else {
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
            default:
                break
            }
        }

        return (cfg, targetPath)
    }

    /// Updates configuration values and writes back to ~/.config/suqi/config with hot reload
    public static func saveValues(_ updates: [String: String]) {
        let suqiDir = NSString(string: "~/.config/suqi").expandingTildeInPath
        let suqiPath = NSString(string: "~/.config/suqi/config").expandingTildeInPath
        let ghosttyPath = NSString(string: "~/.config/ghostty/config").expandingTildeInPath

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: suqiDir) {
            try? fileManager.createDirectory(atPath: suqiDir, withIntermediateDirectories: true)
        }

        var lines: [String] = []
        if fileManager.fileExists(atPath: suqiPath) {
            if let content = try? String(contentsOfFile: suqiPath, encoding: .utf8) {
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
                if parts.count == 2, let newVal = remainingUpdates.removeValue(forKey: parts[0]) {
                    updatedLines.append("\(parts[0]) = \(newVal)")
                    continue
                }
            }
            updatedLines.append(line)
        }

        for (k, v) in remainingUpdates {
            updatedLines.append("\(k) = \(v)")
        }

        let newContent = updatedLines.joined(separator: "\n")
        try? newContent.write(toFile: suqiPath, atomically: true, encoding: .utf8)
        NotificationCenter.default.post(name: .suqiConfigDidChange, object: nil)
    }
}

extension Notification.Name {
    public static let suqiConfigDidChange = Notification.Name("SuqiConfigDidChange")
    public static let ghosttyConfigDidChange = suqiConfigDidChange
}

// MARK: - Configuration File Hot Reload Watcher (monitors ~/.config/suqi/config or fallback ~/.config/ghostty/config)

public typealias GhosttyConfigFileWatcher = SuqiConfigFileWatcher

@MainActor
public final class SuqiConfigFileWatcher: ObservableObject {
    public static let shared = SuqiConfigFileWatcher()

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    public init() {
        startWatching()
    }

    public func startWatching() {
        stopWatching()

        let (_, resolvedPath) = SuqiUserConfig.load()
        guard let path = resolvedPath else { return }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: .suqiConfigDidChange, object: nil)
            // Re-watch file upon changes to support atomic save/rename mechanisms (Vim/VSCode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.startWatching()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
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
        "-zsh", "-bash", "-fish", "suqi", "ghostty"
    ]

    public static func findLatestChildCwd(for parentPid: pid_t = getpid(), maxDepth: Int = 6) -> String? {
        func search(pid: pid_t, depth: Int) -> String? {
            guard depth <= maxDepth else { return nil }
            let children = getChildPids(for: pid)
            for child in children.reversed() {
                if let found = search(pid: child, depth: depth + 1) {
                    return found
                }
                if let cwd = getCwd(for: child), !cwd.isEmpty {
                    return cwd
                }
            }
            return nil
        }
        return search(pid: parentPid, depth: 1)
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

    public static func findLatestChildProcessName(for parentPid: pid_t = getpid(), maxDepth: Int = 6) -> String? {
        func search(pid: pid_t, depth: Int) -> String? {
            guard depth <= maxDepth else { return nil }
            let children = getChildPids(for: pid)
            for child in children.reversed() {
                let rawName = getProcessName(for: child)
                let clean = rawName?.lowercased() ?? ""
                if !clean.isEmpty && !shellProcessNames.contains(clean) {
                    return rawName
                }
                if let found = search(pid: child, depth: depth + 1) {
                    return found
                }
            }
            return nil
        }
        return search(pid: parentPid, depth: 1)
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
public enum SuqiDirectoryManager {
    public static let lastDirKey = "SuqiLastWorkingDirectory"
    private static let cacheFilePath = NSString(string: "~/.cache/suqi/last_working_directory").expandingTildeInPath

    /// Resolves the preferred working directory in order:
    /// 1. Explicit directory passed by caller (e.g. new tab / split inheriting active cwd)
    /// 2. Suqi config `working-directory` or `initial-working-directory` (or fallback config)
    /// 3. Disk cache file / UserDefaults (only if `restore-last-working-directory = true` in config)
    /// 4. User's Home directory (`NSHomeDirectory()`)
    public static func resolvedInitialWorkingDirectory(explicit: String? = nil) -> String {
        if let explicit, !explicit.isEmpty {
            let expanded = NSString(string: explicit).expandingTildeInPath
            if !expanded.isEmpty {
                return expanded
            }
        }

        let (config, _) = SuqiUserConfig.load()
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
                    if !expanded.isEmpty {
                        return expanded
                    }
                }
            }

            // Check UserDefaults
            if let saved = UserDefaults.standard.string(forKey: lastDirKey), !saved.isEmpty {
                let expanded = NSString(string: saved).expandingTildeInPath
                if !expanded.isEmpty {
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
            let cacheDir = NSString(string: "~/.cache/suqi").expandingTildeInPath
            try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
            try? expanded.write(toFile: cacheFilePath, atomically: true, encoding: .utf8)
        }
    }
}

