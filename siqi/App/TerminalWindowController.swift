//
//  TerminalWindowController.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import SwiftUI
import GhosttyTerminal
import Combine

public final class SiqiHostingView<Content: View>: NSHostingView<Content> {
    public override var intrinsicContentSize: NSSize {
        NSSize(width: 80, height: 32)
    }

    public override var fittingSize: NSSize {
        NSSize(width: 80, height: 32)
    }
}

public final class SiqiTerminalWindow: NSWindow {
    public var isFullScreenTransitioning: Bool = false
    public var isSplitDragging: Bool = false
    public let pinButton = NativePinButtonView(frame: NSRect(x: 0, y: 0, width: 14, height: 14))

    override public var inLiveResize: Bool {
        return super.inLiveResize || isSplitDragging
    }

    override public var minSize: NSSize {
        get { NSSize(width: 80, height: 32) }
        set { super.minSize = NSSize(width: 80, height: 32) }
    }

    override public var contentMinSize: NSSize {
        get { NSSize(width: 80, height: 32) }
        set { super.contentMinSize = NSSize(width: 80, height: 32) }
    }

    override public func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var rect = super.constrainFrameRect(frameRect, to: screen)
        if rect.size.width < 140 || rect.size.height < 60 {
            rect.size.width = 80
            rect.size.height = 32
        }
        return rect
    }

    public var cornerRadius: CGFloat = 18.0 {
        didSet {
            updateCornerRadius()
        }
    }

    override public func layoutIfNeeded() {
        super.layoutIfNeeded()
        adjustTrafficLights()
        cleanTitlebarDecorations()
        updateCornerRadius()
    }

    override public func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag)
        adjustTrafficLights()
        cleanTitlebarDecorations()
        updateCornerRadius()
    }

    override public func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        adjustTrafficLights()
        cleanTitlebarDecorations()
        updateCornerRadius()
    }

    override public func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        adjustTrafficLights()
        cleanTitlebarDecorations()
        updateCornerRadius()
    }

    public func updateCornerRadius() {
        let isFull = styleMask.contains(.fullScreen)
        let actualRadius: CGFloat = isFull ? 0 : cornerRadius
        if let themeFrame = contentView?.superview {
            themeFrame.wantsLayer = true
            themeFrame.layer?.cornerRadius = actualRadius
            themeFrame.layer?.cornerCurve = .continuous
            themeFrame.layer?.masksToBounds = !isFull
        }
        if let content = contentView {
            content.wantsLayer = true
            content.layer?.cornerRadius = actualRadius
            content.layer?.cornerCurve = .continuous
            content.layer?.masksToBounds = !isFull
        }
        invalidateShadow()
    }

    public func adjustTrafficLights() {
        guard !styleMask.contains(.fullScreen), !isFullScreenTransitioning else {
            pinButton.isHidden = true
            return
        }
        guard let close = standardWindowButton(.closeButton),
              let mini = standardWindowButton(.miniaturizeButton),
              let zoom = standardWindowButton(.zoomButton),
              let container = close.superview else {
            pinButton.isHidden = true
            return
        }

        // Modern macOS breathing room: offset traffic lights comfortably under the 28pt rounded corner (18pt from top, 18pt from left)
        let superHeight = container.frame.height
        let targetY: CGFloat = max(0, superHeight - 14.0 - 18.0)
        let targetStartX: CGFloat = 18.0
        let spacing: CGFloat = 20.0

        close.setFrameOrigin(NSPoint(x: targetStartX, y: targetY))
        mini.setFrameOrigin(NSPoint(x: targetStartX + spacing, y: targetY))
        zoom.setFrameOrigin(NSPoint(x: targetStartX + spacing * 2, y: targetY))

        if pinButton.superview !== container {
            container.addSubview(pinButton)
        }
        // Exact 1:1 alignment with traffic lights: same targetY baseline, height (14pt), and 20pt equidistant interval
        pinButton.frame = NSRect(x: targetStartX + spacing * 3, y: targetY, width: 14.0, height: 14.0)
        pinButton.updateContainerTracking()
        pinButton.isHidden = (frame.width < 120)
    }

    /// Native clean styling: hides redundant system titlebar background & decoration layers that cause double corner outlines
    public func cleanTitlebarDecorations() {
        guard let titlebarContainer = contentView?.superview?.subviews.first(where: {
            NSStringFromClass(type(of: $0)).contains("NSTitlebarContainerView")
        }) else { return }

        for sub in titlebarContainer.subviews {
            let subName = NSStringFromClass(type(of: sub))
            if subName.contains("NSTitlebarBackgroundView") || subName.contains("_NSTitlebarDecorationView") {
                sub.isHidden = true
            }
            for inner in sub.subviews {
                let innerName = NSStringFromClass(type(of: inner))
                if innerName.contains("NSTitlebarBackgroundView") || innerName.contains("NSVisualEffectView") {
                    inner.isHidden = true
                }
            }
        }
    }
}

// MARK: - Native WindowServer Blur Bridge

private typealias CGSConnectionID = UnsafeMutableRawPointer

@_silgen_name("CGSDefaultConnectionForThread")
private func CGSDefaultConnectionForThread() -> CGSConnectionID?

@_silgen_name("CGSSetWindowBackgroundBlurRadius")
private func CGSSetWindowBackgroundBlurRadius(_ connection: CGSConnectionID?, _ windowNumber: Int, _ radius: Int32) -> Int32

@MainActor
public final class TerminalWindowController: NSWindowController, NSWindowDelegate {
    public let model: SiqiWindowModel
    private var eventMonitor: Any?

    public static func applyWindowBlur(window: NSWindow, radius: Int32) {
        if let conn = CGSDefaultConnectionForThread() {
            _ = CGSSetWindowBackgroundBlurRadius(conn, window.windowNumber, radius)
        }
    }

    /// macos-titlebar-style: "native" restores the system titlebar; other styles keep siqi's own chrome
    public static func applyTitlebarStyle(_ style: String, to window: NSWindow) {
        if style.lowercased() == "native" {
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        } else {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }

    public init(model: SiqiWindowModel) {
        self.model = model

        let (userConfig, _) = SiqiUserConfig.load()
        let isTranslucent = userConfig.backgroundOpacity < 1.0 || userConfig.backgroundBlur > 0

        // Parse initial window size from window-width / window-height config
        let initialWidth: CGFloat = {
            let font = NSFont(name: userConfig.fontFamily, size: userConfig.fontSize)
                ?? NSFont.monospacedSystemFont(ofSize: userConfig.fontSize, weight: .regular)
            let cellWidth = font.maximumAdvancement.width > 0 ? font.maximumAdvancement.width : (userConfig.fontSize * 0.60)
            let padding = CGFloat(userConfig.windowPaddingX * 2)
            if let w = userConfig.windowWidth {
                return w > 200 ? CGFloat(w) : CGFloat(w) * cellWidth + padding
            }
            return 100 * cellWidth + padding // Default 100 columns
        }()
        let initialHeight: CGFloat = {
            let font = NSFont(name: userConfig.fontFamily, size: userConfig.fontSize)
                ?? NSFont.monospacedSystemFont(ofSize: userConfig.fontSize, weight: .regular)
            let cellHeight = ceil(font.ascender - font.descender + font.leading) + CGFloat(userConfig.adjustCellHeight)
            let padding = CGFloat(userConfig.windowPaddingY * 2) + 36 // 36pt titlebar
            if let h = userConfig.windowHeight {
                return h > 150 ? CGFloat(h) : CGFloat(h) * cellHeight + padding
            }
            return 30 * cellHeight + padding // Default 30 rows
        }()

        let window = SiqiTerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "siqi"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Disable isMovableByWindowBackground so mouse dragging passes cleanly to Terminal for text selection
        window.isMovableByWindowBackground = false
        let baseBg = SiqiTheme.nsBackgroundColor(for: userConfig.themeName, customBackground: userConfig.background)
        let targetBg = isTranslucent ? baseBg.withAlphaComponent(CGFloat(userConfig.backgroundOpacity)) : baseBg
        window.isOpaque = false
        window.backgroundColor = .clear
        let blurRadius = isTranslucent ? (userConfig.backgroundBlur > 0 ? Int32(userConfig.backgroundBlur) : 20) : 0
        Self.applyWindowBlur(window: window, radius: blurRadius)
        window.cornerRadius = CGFloat(userConfig.windowCornerRadius)
        window.hasShadow = true
        window.minSize = NSSize(width: 80, height: 32)
        window.contentMinSize = NSSize(width: 80, height: 32)
        window.isReleasedWhenClosed = false

        // Persist window size and position
        if userConfig.windowSaveState.lowercased() != "never" {
            window.setFrameAutosaveName("SiqiTerminalWindow")
        }

        let contentView = ContentView(model: model)
        let hostingView = SiqiHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = targetBg.cgColor
        hostingView.layer?.cornerRadius = CGFloat(userConfig.windowCornerRadius)
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView
        window.updateCornerRadius()

        // Connect native pin button to window model
        window.pinButton.model = model

        super.init(window: window)
        window.delegate = self

        // Bind window close request (smoothly close window when last tab is closed)
        model.onCloseWindowRequested = { [weak self] in
            self?.closeWindow()
        }

        model.$isPinned
            .receive(on: DispatchQueue.main)
            .sink { [weak window] _ in
                window?.pinButton.updateTooltip()
                window?.pinButton.needsDisplay = true
            }
            .store(in: &cancellables)

        setupKeyEventMonitor()
        setupOcclusionStateObserver()
    }

    private var cancellables = Set<AnyCancellable>()
    private var occlusionObserver: Any?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupOcclusionStateObserver() {
        guard let window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self, let window = self.window else { return }
            let isVisible = window.occlusionState.contains(.visible)
            if isVisible {
                self.model.resumeBackgroundRendering()
            } else {
                self.model.pauseBackgroundRendering()
            }
        }
    }

    private func setupKeyEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window else {
                return event
            }
            return TerminalActionBridge.dispatchKeyEvent(
                event: event,
                window: window,
                model: self.model,
                onCloseRequested: { [weak self] in
                    guard let self, let window = self.window else { return }
                    if self.windowShouldClose(window) {
                        self.closeWindow()
                    }
                }
            )
        }
    }

    public func getActiveTerminalView() -> AppTerminalView? {
        TerminalActionBridge.getActiveTerminalView(for: window)
    }

    public func handlePaste() {
        TerminalActionBridge.handlePaste(in: window, model: model)
    }

    public func handleCopy() {
        TerminalActionBridge.handleCopy(in: window, model: model)
    }

    public func handleSelectAll() {
        TerminalActionBridge.handleSelectAll(model: model)
    }

    public var previousExpandedFrame: NSRect?

    public func closeCurrentTabOrWindow() {
        model.closeActiveSessionWithConfirmation(in: window)
    }

    public func closeWindow() {
        saveWindowFrameIfNeeded()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        SiqiWindowManager.shared.removeWindow(self)
        model.tearDownAllSessions()
        window?.close()
    }

    public func saveWindowFrameIfNeeded() {
        guard let window = self.window else { return }
        // Prevent secondary cascaded windows from overwriting the main window autosave geometry
        guard SiqiWindowManager.shared.windowControllers.first === self || SiqiWindowManager.shared.windowControllers.count <= 1 else {
            return
        }
        let (userConfig, _) = SiqiUserConfig.load()
        if userConfig.windowSaveState.lowercased() != "never" {
            if window.frame.width < 140 || window.frame.height < 60 {
                var f = window.frame
                f.size = NSSize(width: 80, height: 32)
                window.setFrame(f, display: false)
            }
            window.saveFrame(usingName: "SiqiTerminalWindow")
        }
    }

    /// Smoothly restores the window from compact 80x32 capsule mode back to standard terminal dimensions
    public func restoreFromCapsule() {
        guard let window = self.window else { return }
        let targetFrame: NSRect = {
            if let prev = previousExpandedFrame, prev.width >= 200, prev.height >= 100 {
                return prev
            }
            let screen = window.screen ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: 900, height: 600)
            let width: CGFloat = 800
            let height: CGFloat = 500
            let x = window.frame.minX
            let y = window.frame.maxY - height
            return NSRect(
                x: max(screenFrame.minX, min(x, screenFrame.maxX - width)),
                y: max(screenFrame.minY, min(y, screenFrame.maxY - height)),
                width: width,
                height: height
            )
        }()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }

    public func updateThemeBackground() {
        guard let window = self.window else { return }
        let (userConfig, _) = SiqiUserConfig.load()
        Self.applyTitlebarStyle(userConfig.macosTitlebarStyle, to: window)
        let isTranslucent = userConfig.backgroundOpacity < 1.0 || userConfig.backgroundBlur > 0
        let baseBg = SiqiTheme.nsBackgroundColor(for: userConfig.themeName, customBackground: userConfig.background)
        let targetBg = isTranslucent ? baseBg.withAlphaComponent(CGFloat(userConfig.backgroundOpacity)) : baseBg

        window.isOpaque = false
        window.backgroundColor = .clear

        let blurRadius = isTranslucent ? (userConfig.backgroundBlur > 0 ? Int32(userConfig.backgroundBlur) : 20) : 0
        Self.applyWindowBlur(window: window, radius: blurRadius)

        if let termWin = window as? SiqiTerminalWindow {
            termWin.cornerRadius = CGFloat(userConfig.windowCornerRadius)
            termWin.updateCornerRadius()
        }
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = targetBg.cgColor
        window.contentView?.layer?.cornerRadius = CGFloat(userConfig.windowCornerRadius)
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
        window.invalidateShadow()
    }

    public func showWindow() {
        guard let window = self.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        let (config, _) = SiqiUserConfig.load()
        guard config.confirmCloseSurface else {
            return true
        }

        let running = model.sessions.filter { $0.hasActiveProcess }
        if let first = running.first, let proc = first.activeProcessName {
            let alert = NSAlert()
            alert.messageText = "Close window with running process '\(proc)'?"
            alert.informativeText = "Closing this window will terminate all active processes running inside it."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Close Window")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn
        }
        return true
    }

    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if let win = self.window, win.frame.width >= 140 && win.frame.height >= 60 {
            previousExpandedFrame = win.frame
        }
        if frameSize.width < 140 || frameSize.height < 60 {
            return NSSize(width: 80, height: 32)
        }
        return NSSize(
            width: max(80, frameSize.width),
            height: max(32, frameSize.height)
        )
    }

    public func windowDidResize(_ notification: Notification) {
        saveWindowFrameIfNeeded()
        (window as? SiqiTerminalWindow)?.adjustTrafficLights()
    }

    public func windowDidMove(_ notification: Notification) {
        saveWindowFrameIfNeeded()
    }

    public func windowWillClose(_ notification: Notification) {
        saveWindowFrameIfNeeded()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        SiqiWindowManager.shared.removeWindow(self)
        model.tearDownAllSessions()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        (window as? SiqiTerminalWindow)?.adjustTrafficLights()
        if let terminalView = getActiveTerminalView() {
            window?.makeFirstResponder(terminalView)
        }
    }

    public func windowWillEnterFullScreen(_ notification: Notification) {
        (window as? SiqiTerminalWindow)?.isFullScreenTransitioning = true
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        (window as? SiqiTerminalWindow)?.isFullScreenTransitioning = false
    }

    public func windowWillExitFullScreen(_ notification: Notification) {
        (window as? SiqiTerminalWindow)?.isFullScreenTransitioning = true
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        let terminalWin = window as? SiqiTerminalWindow
        terminalWin?.isFullScreenTransitioning = false
        DispatchQueue.main.async {
            terminalWin?.adjustTrafficLights()
        }
    }
}
