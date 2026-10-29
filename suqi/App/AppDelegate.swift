//
//  AppDelegate.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import GhosttyTerminal

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AppTerminalView.enableContextMenuPipeline
        _ = AppTerminalView.enableDragAndDropPipeline
        _ = SuqiConfigFileWatcher.shared
        _ = QuickTerminalController.shared
        _ = SuqiWindowManager.shared.createWindow()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag || SuqiWindowManager.shared.windowControllers.isEmpty {
            _ = SuqiWindowManager.shared.createWindow()
        } else if let first = SuqiWindowManager.shared.windowControllers.first {
            first.showWindow()
        }
        return true
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Dock Context Menu
    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(dockNewWindow), keyEquivalent: "")
        newWindowItem.target = self
        menu.addItem(newWindowItem)

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(dockNewTab), keyEquivalent: "")
        newTabItem.target = self
        menu.addItem(newTabItem)

        menu.addItem(NSMenuItem.separator())

        let quickTermItem = NSMenuItem(title: "Toggle Quick Terminal", action: #selector(dockToggleQuickTerminal), keyEquivalent: "")
        quickTermItem.target = self
        menu.addItem(quickTermItem)

        return menu
    }

    @objc private func dockNewWindow() {
        SuqiWindowManager.shared.createWindow()
    }

    @objc private func dockNewTab() {
        SuqiWindowManager.shared.activeWindowController?.model.createNewTab()
    }

    @objc private func dockToggleQuickTerminal() {
        QuickTerminalController.shared.toggle()
    }

    // MARK: - Services

    /// Finder Services entry: open the selected folder (or the selected file's folder) in a new suqi window
    @objc public func openInSuqi(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard let url = urls.first else {
            error.pointee = "No file provided" as NSString
            return
        }
        var isDirectory: ObjCBool = false
        let path = url.path
        let directory = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? path
            : url.deletingLastPathComponent().path
        SuqiWindowManager.shared.createWindow(workingDirectory: directory)
    }
}
