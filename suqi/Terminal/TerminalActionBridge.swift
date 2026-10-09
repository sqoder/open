//
//  TerminalActionBridge.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import GhosttyTerminal

@MainActor
public enum TerminalActionBridge {
    public static func findTerminalView(in view: NSView) -> AppTerminalView? {
        if let tv = view as? AppTerminalView {
            return tv
        }
        for subview in view.subviews {
            if let found = findTerminalView(in: subview) {
                return found
            }
        }
        return nil
    }

    public static func getActiveTerminalView(for window: NSWindow?) -> AppTerminalView? {
        guard let window else { return nil }
        if let tv = window.firstResponder as? AppTerminalView {
            return tv
        }
        if let contentView = window.contentView, let tv = findTerminalView(in: contentView) {
            return tv
        }
        return nil
    }

    public static func isTextInputFocused(in window: NSWindow?) -> Bool {
        guard let window, let responder = window.firstResponder else { return false }
        if responder is NSText || responder is NSTextField || responder is NSSearchField {
            if responder is AppTerminalView { return false }
            return true
        }
        return false
    }

    /// Detects whether the active terminal session is running a multimodal AI CLI tool
    public static func isAiCliActive(in session: SuqiTerminalSession?) -> Bool {
        guard let session else { return false }
        let aiToolKeywords: Set<String> = [
            "agy", "claude", "codex", "opencode", "aider", "gemini", "chatgpt", "llm", "sgpt"
        ]
        if let proc = session.activeProcessName?.lowercased() {
            for kw in aiToolKeywords {
                if proc.contains(kw) { return true }
            }
        }
        if DarwinProcessHelper.hasDescendantProcess(matching: aiToolKeywords) {
            return true
        }
        return false
    }

    /// Checks whether the pasteboard contains image data (in-memory or image file URLs)
    public static func pasteboardContainsImage(_ pb: NSPasteboard) -> Bool {
        // 1. Raw image objects in memory
        if pb.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }
        if let types = pb.types {
            let imageTypes: Set<NSPasteboard.PasteboardType> = [.png, .tiff]
            if types.contains(where: { imageTypes.contains($0) || $0.rawValue.lowercased().contains("image") || $0.rawValue.lowercased().contains("png") }) {
                return true
            }
        }
        // 2. Image file URLs (e.g. screenshots saved to disk like Glint, CleanShot, Finder copied images)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "tiff", "svg"]
            if urls.allSatisfy({ imageExtensions.contains($0.pathExtension.lowercased()) }) {
                return true
            }
        }
        return false
    }

    /// Extracts PNG data from the system clipboard
    public static func getPasteboardImageData(_ pb: NSPasteboard) -> Data? {
        if let data = pb.data(forType: .png) {
            return data
        }
        if let data = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: data),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first,
           let tiff = first.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first,
           let data = try? Data(contentsOf: first) {
            return data
        }
        return nil
    }

    /// Automatically writes an in-memory clipboard image to ~/.cache/suqi/pastes/ and returns the file path
    public static func savePasteboardImageToDisk(_ pb: NSPasteboard) -> String? {
        guard let imgData = getPasteboardImageData(pb) else { return nil }
        let cacheDir = NSString(string: "~/.cache/suqi/pastes").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "paste_\(formatter.string(from: Date())).png"
        let filePath = (cacheDir as NSString).appendingPathComponent(filename)

        do {
            try imgData.write(to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            return nil
        }
    }

    public static func handlePaste(in window: NSWindow?, model: SuqiWindowModel, saveImageAsPath: Bool = false) {
        guard let window else { return }
        let terminalView = getActiveTerminalView(for: window)

        if let terminalView, window.firstResponder !== terminalView {
            window.makeFirstResponder(terminalView)
        }

        let pb = NSPasteboard.general

        // 1. Explicitly requested (⌥⌘V): save in-memory screenshot to disk and paste its path, or paste file path
        if saveImageAsPath {
            if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
                let paths = urls.map { $0.path.replacingOccurrences(of: " ", with: "\\ ") }
                let text = paths.joined(separator: " ") + " "
                model.activeSession?.send(text)
                return
            }
            if let savedPath = savePasteboardImageToDisk(pb) {
                let escaped = savedPath.replacingOccurrences(of: " ", with: "\\ ") + " "
                model.activeSession?.send(escaped)
                return
            }
        }

        // 2. Multimodal AI CLI flow vs. Standard shell image paste:
        if pasteboardContainsImage(pb) {
            let isAi = isAiCliActive(in: model.activeSession)
            if isAi, let terminalView {
                // In an AI CLI session (agy, claude, codex, etc.): synthesize Control+V to stream raw image
                terminalView.triggerImagePasteShortcut()
                return
            } else if let savedPath = savePasteboardImageToDisk(pb) {
                // In standard terminal (zsh, bash, python, vim): auto-save to disk and paste escaped path to prevent ^V garbage
                let escaped = savedPath.replacingOccurrences(of: " ", with: "\\ ") + " "
                model.activeSession?.send(escaped)
                return
            }
        }

        // 3. Finder non-image files copied: paste escaped file paths (e.g. /path/to/script.py )
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            let paths = urls.map { $0.path.replacingOccurrences(of: " ", with: "\\ ") }
            let text = paths.joined(separator: " ") + " "
            model.activeSession?.send(text)
            return
        }

        // 4. Standard text paste from clipboard (Safe Paste Guard evaluation)
        if let clipText = pb.string(forType: .string), !clipText.isEmpty {
            if let request = SafePasteGuard.evaluate(text: clipText) {
                model.pendingSafePaste = request
                return
            }
        }

        if let session = model.activeSession {
            _ = session.state.performBindingAction("paste_from_clipboard")
        }
    }

    public static func handleCopy(in window: NSWindow?, model: SuqiWindowModel) {
        if let terminalView = getActiveTerminalView(for: window), terminalView.copySelectedTextToPasteboard() {
            return
        }
        if let session = model.activeSession {
            _ = session.state.performBindingAction("copy_to_clipboard")
        }
    }

    public static func handleSelectAll(model: SuqiWindowModel) {
        if let session = model.activeSession {
            _ = session.state.performBindingAction("select_all")
        }
    }

    /// Unified key event dispatcher handling all core keyboard shortcuts
    public static func dispatchKeyEvent(
        event: NSEvent,
        window: NSWindow,
        model: SuqiWindowModel,
        onCloseRequested: @escaping () -> Void
    ) -> NSEvent? {
        let isRelevant = window.isKeyWindow || window.isMainWindow || event.window === window
        guard isRelevant else { return event }

        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])

        // When text input cursor is inside a native text field (such as ⌘F search bar), pass ⌘C / ⌘V / ⌘A / ⌘X through
        if isTextInputFocused(in: window) {
            // Esc: close search bar and return focus to terminal
            if event.keyCode == 53 && model.isSearching {
                model.isSearching = false
                if let tv = getActiveTerminalView(for: window) {
                    window.makeFirstResponder(tv)
                }
                return nil
            }
            if flags == .command {
                let char = event.charactersIgnoringModifiers?.lowercased()
                if char == "c" || char == "v" || char == "a" || char == "x" {
                    return event // Allow native text editing behavior
                }
                if char == "f" {
                    model.isSearching = false
                    if let tv = getActiveTerminalView(for: window) {
                        window.makeFirstResponder(tv)
                    }
                    return nil
                }
            }
        }

        // Safe Paste modal active: intercept Return and Esc
        if model.pendingSafePaste != nil {
            if event.keyCode == 53 { // Esc: Cancel
                model.cancelSafePaste()
                return nil
            }
            if event.keyCode == 36 || event.charactersIgnoringModifiers == "\r" { // Return / Enter
                let asSingleLine = flags.contains(.option)
                model.confirmSafePaste(asSingleLine: asSingleLine)
                return nil
            }
            return nil // Block terminal keystrokes while confirmation modal is visible
        }

        // 1. ⌥⌘V (Save clipboard image to disk and paste escaped file path)
        if flags == [.command, .option] && event.charactersIgnoringModifiers?.lowercased() == "v" {
            handlePaste(in: window, model: model, saveImageAsPath: true)
            return nil
        }

        // 1b. ⌘V (Smart image or text paste)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "v" {
            handlePaste(in: window, model: model, saveImageAsPath: false)
            return nil
        }

        // 2. ⌘C (Copy selected text)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "c" {
            handleCopy(in: window, model: model)
            return nil
        }

        // 3. ⌘A (Select all)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "a" {
            handleSelectAll(model: model)
            return nil
        }

        // 4. ⌘N (New standalone window)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "n" {
            SuqiWindowManager.shared.createWindow(workingDirectory: model.activeSession?.fullDirectory)
            return nil
        }

        // 5. ⌘T (New tab)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "t" {
            model.createNewTab()
            return nil
        }

        // 6. ⌘D (Split Right)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "d" {
            model.splitRight()
            return nil
        }

        // 7. ⌘Shift+D (Split Down)
        if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "d" {
            model.splitDown()
            return nil
        }

        // 8. ⌃⌘= (Equalize Splits)
        if flags == [.control, .command] && (event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+") {
            model.equalizeSplits()
            return nil
        }

        // 9. ⌘Shift+Enter (Toggle Split Zoom)
        if flags == [.command, .shift] && (event.keyCode == 36 || event.charactersIgnoringModifiers == "\r") {
            model.toggleZoom()
            return nil
        }

        // 10. ⌃⌘H / ⌃⌘J / ⌃⌘K / ⌃⌘L and ⌃⌘ Arrow keys (Directional pane navigation)
        if flags == [.control, .command] {
            let char = event.charactersIgnoringModifiers?.lowercased()
            if char == "h" || event.specialKey == .leftArrow {
                model.focusPane(in: .left)
                return nil
            }
            if char == "l" || event.specialKey == .rightArrow {
                model.focusPane(in: .right)
                return nil
            }
            if char == "k" || event.specialKey == .upArrow {
                model.focusPane(in: .up)
                return nil
            }
            if char == "j" || event.specialKey == .downArrow {
                model.focusPane(in: .down)
                return nil
            }
        }

        // 11. ⌘F (Scrollback search)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "f" {
            model.isSearching.toggle()
            return nil
        }

        // 12. ⌥⌘Left / ⌥⌘Right / ⌥⌘Up / ⌥⌘Down / ⌥⌘[ / ⌥⌘] (Directional and sequential pane navigation)
        if flags == [.command, .option] {
            if event.specialKey == .leftArrow {
                model.focusPane(in: .left)
                return nil
            }
            if event.specialKey == .rightArrow {
                model.focusPane(in: .right)
                return nil
            }
            if event.specialKey == .upArrow {
                model.focusPane(in: .up)
                return nil
            }
            if event.specialKey == .downArrow {
                model.focusPane(in: .down)
                return nil
            }
            if event.charactersIgnoringModifiers == "[" {
                model.previousPane()
                return nil
            }
            if event.charactersIgnoringModifiers == "]" {
                model.nextPane()
                return nil
            }
        }

        // 13. ⌘W (Close active pane / tab / window)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "w" {
            model.closeActiveSession()
            return nil
        }

        // 14. ⌘Shift+W (Close entire window)
        if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "w" {
            onCloseRequested()
            return nil
        }

        // 15. ⌘1 .. ⌘9 (Switch to tab)
        if flags == .command, let char = event.charactersIgnoringModifiers?.first, char >= "1" && char <= "9" {
            if let tabIndex = Int(String(char)) {
                model.selectTab(at: tabIndex - 1)
                return nil
            }
        }

        // 16. ⌘[ / ⌘] (Previous / Next tab)
        if flags == .command && event.charactersIgnoringModifiers == "[" {
            model.previousTab()
            return nil
        }
        if flags == .command && event.charactersIgnoringModifiers == "]" {
            model.nextTab()
            return nil
        }

        // 17. ⌘Shift+[ / ⌘Shift+] (Previous / Next tab variant)
        if flags == [.command, .shift] {
            if event.charactersIgnoringModifiers == "{" || event.charactersIgnoringModifiers == "[" {
                model.previousTab()
                return nil
            }
            if event.charactersIgnoringModifiers == "}" || event.charactersIgnoringModifiers == "]" {
                model.nextTab()
                return nil
            }
        }

        // 18. ⌘K (Clear scrollback)
        if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "k" {
            model.clearActiveSession()
            return nil
        }

        // 19. ⌘+ / ⌘= / ⌘- / ⌘0 (Dynamic font size scaling)
        if flags == .command || flags == [.command, .shift] {
            let char = event.charactersIgnoringModifiers
            if char == "=" || char == "+" {
                _ = model.activeSession?.state.performBindingAction("increase_font_size:1")
                return nil
            } else if char == "-" {
                _ = model.activeSession?.state.performBindingAction("decrease_font_size:1")
                return nil
            } else if char == "0" {
                _ = model.activeSession?.state.performBindingAction("reset_font_size")
                return nil
            }
        }

        // 20. ⌘, (Open Native Settings View)
        if flags == .command && event.charactersIgnoringModifiers == "," {
            SuqiWindowManager.shared.openSettingsWindow()
            return nil
        }

        // 20b. ⌥⌘, (Open configuration file in text editor)
        if flags == [.command, .option] && event.charactersIgnoringModifiers == "," {
            let (_, path) = SuqiUserConfig.load()
            let target = path ?? NSString(string: "~/.config/suqi/config").expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: target))
            return nil
        }

        // 21. ⌘Shift+, (Reload configuration)
        if flags == [.command, .shift] && (event.charactersIgnoringModifiers == "<" || event.charactersIgnoringModifiers == ",") {
            SuqiWindowManager.shared.reloadAllWindows()
            return nil
        }

        return event
    }
}
