//
//  AppTerminalView+ContextMenu.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import GhosttyTerminal

@MainActor
public final class TerminalContextMenuBridge: NSObject {
    public static let shared = TerminalContextMenuBridge()

    private weak var currentTerminalView: AppTerminalView?

    public func buildMenu(for view: AppTerminalView) -> NSMenu {
        self.currentTerminalView = view
        if let model = targetModel,
           let session = model.tabs.flatMap({ $0.allSessions }).first(where: { $0.terminalView === view }) {
            model.activeSessionId = session.id
        }

        let menu = NSMenu(title: "Terminal Context")
        menu.allowsContextMenuPlugIns = false
        menu.autoenablesItems = false

        let isMultiPane = (targetModel?.activeTab?.allSessions.count ?? 1) > 1

        // 1. Copy
        let copyItem = NSMenuItem(title: "Copy", action: #selector(menuCopy), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = .command
        copyItem.target = self
        menu.addItem(copyItem)

        // 2. Paste
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(menuPaste), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = .command
        pasteItem.target = self
        menu.addItem(pasteItem)

        // 3. Select All
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(menuSelectAll), keyEquivalent: "a")
        selectAllItem.keyEquivalentModifierMask = .command
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Split Right
        let splitRightItem = NSMenuItem(title: "Split Right", action: #selector(menuSplitRight), keyEquivalent: "d")
        splitRightItem.keyEquivalentModifierMask = .command
        splitRightItem.target = self
        menu.addItem(splitRightItem)

        // 5. Split Down
        let splitDownItem = NSMenuItem(title: "Split Down", action: #selector(menuSplitDown), keyEquivalent: "d")
        splitDownItem.keyEquivalentModifierMask = [.command, .shift]
        splitDownItem.target = self
        menu.addItem(splitDownItem)

        // Equalize Splits
        let equalizeItem = NSMenuItem(title: "Equalize Splits", action: #selector(menuEqualizeSplits), keyEquivalent: "=")
        equalizeItem.keyEquivalentModifierMask = [.command, .control]
        equalizeItem.target = self
        equalizeItem.isEnabled = isMultiPane
        menu.addItem(equalizeItem)

        // Toggle Split Zoom
        let zoomItem = NSMenuItem(title: "Toggle Split Zoom", action: #selector(menuToggleZoom), keyEquivalent: "\r")
        zoomItem.keyEquivalentModifierMask = [.command, .shift]
        zoomItem.target = self
        zoomItem.isEnabled = isMultiPane
        menu.addItem(zoomItem)

        menu.addItem(NSMenuItem.separator())

        // Find...
        let findItem = NSMenuItem(title: "Find...", action: #selector(menuFind), keyEquivalent: "f")
        findItem.keyEquivalentModifierMask = .command
        findItem.target = self
        menu.addItem(findItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Clear Screen
        let clearItem = NSMenuItem(title: "Clear Screen", action: #selector(menuClear), keyEquivalent: "k")
        clearItem.keyEquivalentModifierMask = .command
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        // 7. New Tab
        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(menuNewTab), keyEquivalent: "t")
        newTabItem.keyEquivalentModifierMask = .command
        newTabItem.target = self
        menu.addItem(newTabItem)

        // 8. New Window
        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(menuNewWindow), keyEquivalent: "n")
        newWindowItem.keyEquivalentModifierMask = .command
        newWindowItem.target = self
        menu.addItem(newWindowItem)

        menu.addItem(NSMenuItem.separator())

        // 9. Close Pane
        let closeItem = NSMenuItem(
            title: isMultiPane ? "Close Pane" : "Close Tab",
            action: #selector(menuClosePane),
            keyEquivalent: "w"
        )
        closeItem.keyEquivalentModifierMask = .command
        closeItem.target = self
        menu.addItem(closeItem)

        return menu
    }

    private var targetModel: SiqiWindowModel? {
        guard let view = currentTerminalView else {
            return SiqiWindowManager.shared.activeWindowController?.model
        }
        if let window = view.window {
            if window is QuickTerminalPanel {
                return QuickTerminalController.shared.model
            }
            if let wc = window.windowController as? TerminalWindowController {
                return wc.model
            }
        }
        return SiqiWindowManager.shared.activeWindowController?.model
    }

    private var targetWindow: NSWindow? {
        currentTerminalView?.window ?? SiqiWindowManager.shared.activeWindowController?.window
    }

    @objc private func menuCopy() {
        if let model = targetModel {
            TerminalActionBridge.handleCopy(in: targetWindow, model: model)
        }
    }

    @objc private func menuPaste() {
        if let model = targetModel {
            TerminalActionBridge.handlePaste(in: targetWindow, model: model)
        }
    }

    @objc private func menuSelectAll() {
        if let model = targetModel {
            TerminalActionBridge.handleSelectAll(model: model)
        }
    }

    @objc private func menuSplitRight() {
        targetModel?.splitRight()
    }

    @objc private func menuSplitDown() {
        targetModel?.splitDown()
    }

    @objc private func menuEqualizeSplits() {
        targetModel?.equalizeSplits()
    }

    @objc private func menuToggleZoom() {
        targetModel?.toggleZoom()
    }

    @objc private func menuFind() {
        targetModel?.isSearching = true
    }

    @objc private func menuClear() {
        targetModel?.clearActiveSession()
    }

    @objc private func menuNewTab() {
        targetModel?.createNewTab()
    }

    @objc private func menuNewWindow() {
        SiqiWindowManager.shared.createWindow(workingDirectory: targetModel?.activeSession?.fullDirectory)
    }

    @objc private func menuClosePane() {
        guard let model = targetModel else { return }
        _ = model.closeActiveSession()
    }
}

extension AppTerminalView {
    private static var originalMouseDownIMP: IMP?
    private static var originalRightMouseDownIMP: IMP?

    /// Enables native terminal context menu pipeline and focus tracking
    public static let enableContextMenuPipeline: Void = {
        // 0. Swizzle mouseDown: focus tracking for multi-pane split setups
        if let originalMouseDown = class_getInstanceMethod(AppTerminalView.self, #selector(NSResponder.mouseDown(with:))) {
            originalMouseDownIMP = method_getImplementation(originalMouseDown)
            let mouseBlock: @convention(block) (AnyObject, NSEvent) -> Void = { target, event in
                guard let view = target as? AppTerminalView else { return }
                if let window = view.window {
                    let model: SiqiWindowModel? = {
                        if window is QuickTerminalPanel { return QuickTerminalController.shared.model }
                        if let wc = window.windowController as? TerminalWindowController { return wc.model }
                        return SiqiWindowManager.shared.activeWindowController?.model
                    }()
                    if let model, let session = model.tabs.flatMap({ $0.allSessions }).first(where: { $0.terminalView === view }) {
                        if model.activeSessionId != session.id {
                            model.activeSessionId = session.id
                        }
                    }
                }
                if let originalIMP = AppTerminalView.originalMouseDownIMP {
                    typealias Fn = @convention(c) (AnyObject, Selector, NSEvent) -> Void
                    let fn = unsafeBitCast(originalIMP, to: Fn.self)
                    fn(view, #selector(NSResponder.mouseDown(with:)), event)
                }
            }
            let swizzledMouseDownIMP = imp_implementationWithBlock(mouseBlock)
            method_setImplementation(originalMouseDown, swizzledMouseDownIMP)
        }

        // 1. Swizzle rightMouseDown: focus tracking and context menu presentation
        if let originalMethod = class_getInstanceMethod(AppTerminalView.self, #selector(NSResponder.rightMouseDown(with:))) {
            originalRightMouseDownIMP = method_getImplementation(originalMethod)
            let block: @convention(block) (AnyObject, NSEvent) -> Void = { target, event in
                guard let view = target as? AppTerminalView else { return }
                view.window?.makeFirstResponder(view)

                if let window = view.window {
                    let model: SiqiWindowModel? = {
                        if window is QuickTerminalPanel { return QuickTerminalController.shared.model }
                        if let wc = window.windowController as? TerminalWindowController { return wc.model }
                        return SiqiWindowManager.shared.activeWindowController?.model
                    }()
                    if let model, let session = model.tabs.flatMap({ $0.allSessions }).first(where: { $0.terminalView === view }) {
                        if model.activeSessionId != session.id {
                            model.activeSessionId = session.id
                        }
                    }
                }

                // Call original implementation to maintain terminal mouse coordinates and selection state
                if let originalIMP = AppTerminalView.originalRightMouseDownIMP {
                    typealias Fn = @convention(c) (AnyObject, Selector, NSEvent) -> Void
                    let fn = unsafeBitCast(originalIMP, to: Fn.self)
                    fn(view, #selector(NSResponder.rightMouseDown(with:)), event)
                }

                let menu = TerminalContextMenuBridge.shared.buildMenu(for: view)
                NSMenu.popUpContextMenu(menu, with: event, for: view)
            }
            let swizzledIMP = imp_implementationWithBlock(block)
            method_setImplementation(originalMethod, swizzledIMP)
        }

        // 2. Swizzle menu(for:)
        if let menuMethod = class_getInstanceMethod(AppTerminalView.self, #selector(NSView.menu(for:))) {
            let menuBlock: @convention(block) (AnyObject, NSEvent) -> NSMenu? = { target, event in
                guard let view = target as? AppTerminalView else { return nil }
                return TerminalContextMenuBridge.shared.buildMenu(for: view)
            }
            let swizzledIMP = imp_implementationWithBlock(menuBlock)
            method_setImplementation(menuMethod, swizzledIMP)
        }
    }()
}
