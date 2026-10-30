//
//  QuickTerminalController.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import SwiftUI

public final class QuickTerminalPanel: NSPanel {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}

@MainActor
public final class QuickTerminalController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = QuickTerminalController()

    public private(set) var panel: QuickTerminalPanel?
    public private(set) var model: SiqiWindowModel?
    @Published public private(set) var isVisible: Bool = false
    private var isHiding = false
    private var animationGeneration = 0

    private override init() {
        super.init()
        setupLocalShortcut()
    }

    private var currentActiveScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }

    private func setupLocalShortcut() {
        // 1. Local keyboard monitor: Toggle on ⌃` when active, and dispatch all shortcuts (⌘V / ⌘D / ⌘W etc.) when Quick Terminal is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .control && (event.charactersIgnoringModifiers == "`" || event.charactersIgnoringModifiers == "~") {
                self.toggle()
                return nil
            }
            if self.isVisible, !self.isHiding, let panel = self.panel, let model = self.model, (panel.isKeyWindow || event.window === panel) {
                return TerminalActionBridge.dispatchKeyEvent(
                    event: event,
                    window: panel,
                    model: model,
                    onCloseRequested: { [weak self] in
                        self?.hide()
                    }
                )
            }
            return event
        }

        // 2. Global keyboard monitor: When in any other app, ⌃` smoothly slides out the drop-down Quick Terminal
        // Note: Global monitor requires macOS Accessibility permissions.
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .control && (event.charactersIgnoringModifiers == "`" || event.charactersIgnoringModifiers == "~") {
                Task { @MainActor in
                    self?.toggle()
                }
            }
        }
    }

    /// Checks if the application currently has macOS Accessibility permissions for global hotkeys
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system permission dialog for Accessibility
    public static func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func toggle() {
        if isHiding {
            show()
        } else if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Config-driven geometry

    private func screenForConfig(_ config: SiqiUserConfig) -> NSScreen? {
        config.quickTerminalScreen == "main" ? NSScreen.main : currentActiveScreen
    }

    private func targetFrame(for screen: NSScreen, config: SiqiUserConfig) -> NSRect {
        let visible = screen.visibleFrame
        let position = config.quickTerminalPosition
        var width = min(visible.width * 0.96, 1200)
        var height = visible.height * 0.50

        let parts = config.quickTerminalSize.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            if parts[0].hasSuffix("%"), let w = Double(parts[0].dropLast()) {
                width = visible.width * max(0.1, min(1.0, w / 100))
            }
            if parts[1].hasSuffix("%"), let h = Double(parts[1].dropLast()) {
                height = visible.height * max(0.1, min(1.0, h / 100))
            }
        } else if let size = parts.first, size.contains("x") {
            let dims = size.split(separator: "x").compactMap { Double($0) }
            if dims.count == 2 {
                width = dims[0]
                height = dims[1]
            }
        } else if let size = parts.first, size.hasSuffix("%"), let fraction = Double(size.dropLast()) {
            let value = max(0.1, min(1.0, fraction / 100))
            switch position {
            case "left", "right": width = visible.width * value
            default: height = visible.height * value
            }
        }

        let x: CGFloat
        let y: CGFloat
        switch position {
        case "bottom":
            x = visible.midX - width / 2
            y = visible.minY
        case "left":
            x = visible.minX
            y = visible.midY - height / 2
        case "right":
            x = visible.maxX - width
            y = visible.midY - height / 2
        case "center":
            x = visible.midX - width / 2
            y = visible.midY - height / 2
        default:
            x = visible.midX - width / 2
            y = visible.maxY - height
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func offscreenFrame(from target: NSRect, visible: NSRect, position: String) -> NSRect {
        switch position {
        case "bottom":
            return NSRect(x: target.minX, y: visible.minY - target.height, width: target.width, height: target.height)
        case "left":
            return NSRect(x: visible.minX - target.width, y: target.minY, width: target.width, height: target.height)
        case "right":
            return NSRect(x: visible.maxX, y: target.minY, width: target.width, height: target.height)
        default:
            return NSRect(x: target.minX, y: visible.maxY, width: target.width, height: target.height)
        }
    }

    public func windowDidResignKey(_ notification: Notification) {
        let (config, _) = SiqiUserConfig.load()
        if config.quickTerminalAutohide, isVisible, !isHiding {
            hide()
        }
    }

    public func show() {
        isHiding = false
        let (userConfig, _) = SiqiUserConfig.load()
        guard let screen = screenForConfig(userConfig) else { return }
        let targetFrame = targetFrame(for: screen, config: userConfig)

        if panel == nil {
            let model = SiqiWindowModel()
            self.model = model

            model.onCloseWindowRequested = { [weak self] in
                self?.hide()
            }

            let panel = QuickTerminalPanel(
                contentRect: targetFrame,
                styleMask: [.borderless, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = false
            panel.delegate = self

            let contentView = ContentView(model: model)
            let hosting = NSHostingView(rootView: contentView)
            hosting.wantsLayer = true
            hosting.layer?.cornerRadius = CGFloat(userConfig.windowCornerRadius)
            hosting.layer?.cornerCurve = .continuous
            hosting.layer?.masksToBounds = true
            panel.contentView = hosting

            self.panel = panel
        }

        guard let panel = self.panel else { return }

        let isTranslucent = userConfig.backgroundOpacity < 1.0 || userConfig.backgroundBlur > 0
        let baseBg = SiqiTheme.nsBackgroundColor(for: userConfig.themeName, customBackground: userConfig.background)
        if isTranslucent {
            panel.backgroundColor = baseBg.withAlphaComponent(CGFloat(userConfig.backgroundOpacity))
            let blurRadius = userConfig.backgroundBlur > 0 ? Int32(userConfig.backgroundBlur) : 20
            TerminalWindowController.applyWindowBlur(window: panel, radius: blurRadius)
        } else {
            panel.backgroundColor = baseBg
            TerminalWindowController.applyWindowBlur(window: panel, radius: 0)
        }

        panel.setFrame(
            offscreenFrame(from: targetFrame, visible: screen.visibleFrame, position: userConfig.quickTerminalPosition),
            display: false
        )
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Mark visible before the animation finishes: hide() bails out when this
        // is false, so a fast second toggle would otherwise be swallowed.
        isVisible = true

        let duration = userConfig.quickTerminalAnimationDuration
        if duration <= 0 {
            panel.setFrame(targetFrame, display: true)
            return
        }
        animationGeneration += 1
        let generation = animationGeneration
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self, self.animationGeneration == generation else { return }
            self.isVisible = true
        }
    }

    public func hide() {
        guard let panel = self.panel, isVisible, !isHiding else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let (userConfig, _) = SiqiUserConfig.load()
        let targetFrame = offscreenFrame(
            from: panel.frame,
            visible: screen.visibleFrame,
            position: userConfig.quickTerminalPosition
        )

        isHiding = true
        animationGeneration += 1
        let generation = animationGeneration
        let duration = userConfig.quickTerminalAnimationDuration
        if duration <= 0 {
            isVisible = false
            isHiding = false
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            // A show() during this animation bumps the generation; that stale
            // completion must not order the panel out again.
            guard let self, self.animationGeneration == generation else { return }
            self.isVisible = false
            self.isHiding = false
            panel.orderOut(nil)
        }
    }
}
