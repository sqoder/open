//
//  ContentView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    public init(material: NSVisualEffectView.Material = .underWindowBackground, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct ContentView: View {
    @ObservedObject public var model: SuqiWindowModel
    @State private var configReloadToken = UUID()

    public init(model: SuqiWindowModel) {
        self.model = model
    }

    private var userConfig: SuqiUserConfig {
        _ = configReloadToken
        return SuqiUserConfig.load().config
    }

    private var isTranslucent: Bool {
        userConfig.backgroundOpacity < 1.0 || userConfig.backgroundBlur > 0
    }

    private var themeBg: Color {
        SuqiTheme.backgroundColor(for: userConfig.themeName, customBackground: userConfig.background)
    }

    public var body: some View {
        GeometryReader { windowProxy in
            let windowWidth = windowProxy.size.width
            let windowHeight = windowProxy.size.height
            let isMiniCapsule = windowHeight <= 36 || windowWidth < 120

            ZStack(alignment: .topLeading) {
                if isMiniCapsule {
                    // Mini compact state: window drag surface with traffic light buttons and expand button
                    ZStack(alignment: .trailing) {
                        WindowDragArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Button {
                            if let window = NSApp.keyWindow,
                               let wc = window.windowController as? TerminalWindowController {
                                wc.restoreFromCapsule()
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .help("Restore Window Size (Double-click capsule)")
                    }
                } else {
                    VStack(spacing: 0) {
                        // Top title/tab bar area (height: 36): background handles native drag/double-click zoom, foreground renders tabs
                        ZStack(alignment: .center) {
                            WindowDragArea()
                                .frame(height: 36)

                            if model.tabs.count > 1 && windowWidth > 140 {
                                SuqiTabBar(model: model)
                                    .frame(height: 36)
                            }
                        }
                        .frame(height: 36)

                        // Terminal workspace (multi-tab, split panes, zoom, and scrollback search)
                        ZStack(alignment: .topTrailing) {
                            if let activeTab = model.activeTab {
                                ActiveTabView(tab: activeTab, model: model)
                                    .id(activeTab.id)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color.clear
                            }

                            if model.isSearching {
                                TerminalSearchBar(model: model)
                                    .padding(.top, 6)
                                    .padding(.trailing, 14)
                                    .transition(.opacity)
                                    .zIndex(999)
                            }

                            if let request = model.pendingSafePaste {
                                SafePasteModalView(request: request, model: model)
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                    .zIndex(1000)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 80, minHeight: 32)
        .background(isTranslucent ? Color.clear : themeBg)
        .ignoresSafeArea()
        .transaction { $0.animation = nil }
        // Support dragging files from Finder and text directly into terminal window
        .onDrop(of: [.fileURL, .plainText, .utf8PlainText, .text], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let path = url?.path {
                            let escaped = path.replacingOccurrences(of: " ", with: "\\ ")
                            DispatchQueue.main.async {
                                model.activeSession?.send(escaped + " ")
                            }
                        }
                    }
                } else {
                    _ = provider.loadObject(ofClass: String.self) { text, _ in
                        if let text, !text.isEmpty {
                            DispatchQueue.main.async {
                                model.activeSession?.send(text)
                            }
                        }
                    }
                }
            }
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .suqiConfigDidChange)) { _ in
            configReloadToken = UUID()
        }
    }
}

public struct ActiveTabView: View {
    @ObservedObject var tab: SuqiTab
    let model: SuqiWindowModel

    public init(tab: SuqiTab, model: SuqiWindowModel) {
        self.tab = tab
        self.model = model
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            if tab.isZoomed, let activeSession = tab.activeSession {
                SuqiTerminalView(session: activeSession, model: model)
                    .id(activeSession.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Minimalist zoom badge (Suqi style)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("ZOOMED · ⌘⇧↩ Unzoom")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.60))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
                .padding(.top, 6)
                .padding(.trailing, 10)
                .onTapGesture {
                    tab.toggleZoom()
                }
            } else {
                PaneContainerView(node: tab.rootPane, model: model)
                    .id(tab.id)
            }
        }
    }
}

public struct TerminalSearchBar: View {
    @ObservedObject var model: SuqiWindowModel
    @State private var query: String = ""

    public init(model: SuqiWindowModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 6) {
            SearchFieldRepresentable(
                text: $query,
                onCommit: {
                    _ = model.activeSession?.state.surface?.navigateSearch(forward: true)
                },
                onReverseCommit: {
                    _ = model.activeSession?.state.surface?.navigateSearch(forward: false)
                },
                onCancel: {
                    closeSearch()
                }
            )
            .frame(width: 180, height: 22)
            .onChange(of: query) { _, newQuery in
                _ = model.activeSession?.state.surface?.search(newQuery)
            }

            // Prev Match
            Button {
                _ = model.activeSession?.state.surface?.navigateSearch(forward: false)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 16, height: 16)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Previous Match (⇧Enter)")

            // Next Match
            Button {
                _ = model.activeSession?.state.surface?.navigateSearch(forward: true)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 16, height: 16)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Next Match (Enter)")

            // Close Search
            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Close Search (Esc)")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        .onAppear {
            _ = model.activeSession?.state.surface?.startSearch()
        }
    }

    private func closeSearch() {
        model.isSearching = false
        _ = model.activeSession?.state.surface?.endSearch()
    }
}

// MARK: - AppKit Search Field (Ensures 100% First Responder acquisition on ⌘F)

struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onReverseCommit: () -> Void = {}
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search scrollback..."
        field.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.isBordered = false
        field.backgroundColor = .clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldRepresentable

        init(_ parent: SearchFieldRepresentable) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                if isShift {
                    parent.onReverseCommit()
                } else {
                    parent.onCommit()
                }
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

public struct PaneContainerView: View {
    let node: PaneNode
    let model: SuqiWindowModel

    public init(node: PaneNode, model: SuqiWindowModel) {
        self.node = node
        self.model = model
    }

    public var body: some View {
        switch node {
        case .terminal(let session):
            SuqiTerminalView(session: session, model: model)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .split(let splitId, let axis, let fraction, let first, let second):
            GeometryReader { proxy in
                let size = proxy.size
                if size.width > 20 && size.height > 20 {
                    let safeFraction = (fraction.isNaN || !fraction.isFinite) ? 0.5 : min(max(fraction, 0.05), 0.95)
                    if axis == .horizontal {
                        let dividerThickness: CGFloat = 1
                        let availableWidth = max(0, size.width - dividerThickness)
                        let firstWidth = max(0, availableWidth * safeFraction)
                        let secondWidth = max(0, availableWidth - firstWidth)

                        HStack(spacing: 0) {
                            PaneContainerView(node: first, model: model)
                                .frame(width: firstWidth, height: size.height)

                            SplitDividerView(
                                axis: .horizontal,
                                splitId: splitId,
                                currentFraction: safeFraction,
                                availableLength: availableWidth,
                                model: model
                            )
                            .frame(width: dividerThickness, height: size.height)

                            PaneContainerView(node: second, model: model)
                                .frame(width: secondWidth, height: size.height)
                        }
                        .frame(width: size.width, height: size.height)
                    } else {
                        let dividerThickness: CGFloat = 1
                        let availableHeight = max(0, size.height - dividerThickness)
                        let firstHeight = max(0, availableHeight * safeFraction)
                        let secondHeight = max(0, availableHeight - firstHeight)

                        VStack(spacing: 0) {
                            PaneContainerView(node: first, model: model)
                                .frame(width: size.width, height: firstHeight)

                            SplitDividerView(
                                axis: .vertical,
                                splitId: splitId,
                                currentFraction: safeFraction,
                                availableLength: availableHeight,
                                model: model
                            )
                            .frame(width: size.width, height: dividerThickness)

                            PaneContainerView(node: second, model: model)
                                .frame(width: size.width, height: secondHeight)
                        }
                        .frame(width: size.width, height: size.height)
                    }
                } else {
                    Color.clear
                }
            }
            .id(splitId)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Split Divider (AppKit NSView draggable split bar)

public struct SplitDividerView: NSViewRepresentable {
    let axis: Axis
    let splitId: UUID
    let currentFraction: CGFloat
    let availableLength: CGFloat
    let model: SuqiWindowModel

    public init(axis: Axis, splitId: UUID, currentFraction: CGFloat, availableLength: CGFloat, model: SuqiWindowModel) {
        self.axis = axis
        self.splitId = splitId
        self.currentFraction = currentFraction
        self.availableLength = availableLength
        self.model = model
    }

    public func makeNSView(context: Context) -> SplitDividerNSView {
        let view = SplitDividerNSView()
        view.axis = axis
        view.splitId = splitId
        view.currentFraction = currentFraction
        view.availableLength = availableLength
        view.model = model
        return view
    }

    public func updateNSView(_ nsView: SplitDividerNSView, context: Context) {
        nsView.axis = axis
        nsView.splitId = splitId
        nsView.currentFraction = currentFraction
        nsView.availableLength = availableLength
        nsView.model = model
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

public final class SplitDividerNSView: NSView {
    var axis: Axis = .horizontal
    var splitId: UUID = UUID()
    var currentFraction: CGFloat = 0.5
    var availableLength: CGFloat = 100
    weak var model: SuqiWindowModel?

    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var dragStartFraction: CGFloat = 0.5

    private var isHovering = false {
        didSet {
            if oldValue != isHovering {
                needsDisplay = true
            }
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.zPosition = 1000
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.zPosition = 1000
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        let cursor = (axis == .horizontal) ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown
        let hitRect = bounds.insetBy(dx: axis == .horizontal ? -4 : 0, dy: axis == .vertical ? -4 : 0)
        addCursorRect(hitRect, cursor: cursor)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return super.hitTest(point) }
        let localPoint = convert(point, from: superview)
        let hitRect = bounds.insetBy(dx: axis == .horizontal ? -4 : 0, dy: axis == .vertical ? -4 : 0)
        if hitRect.contains(localPoint) {
            return self
        }
        return super.hitTest(point)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let color = (isHovering || isDragging)
            ? NSColor.white.withAlphaComponent(0.35)
            : NSColor.white.withAlphaComponent(0.08)
        color.setFill()
        bounds.fill()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let hitRect = bounds.insetBy(dx: axis == .horizontal ? -4 : 0, dy: axis == .vertical ? -4 : 0)
        let area = NSTrackingArea(
            rect: hitRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    public override func cursorUpdate(with event: NSEvent) {
        let cursor = (axis == .horizontal) ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown
        cursor.set()
    }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            model?.updateSplitFraction(splitId: splitId, fraction: 0.5)
            return
        }

        guard availableLength > 20 else { return }
        isDragging = true
        needsDisplay = true
        dragStartLocation = event.locationInWindow
        dragStartFraction = currentFraction

        if let win = window as? SuqiTerminalWindow {
            win.isSplitDragging = true
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging, availableLength > 20 else { return }
        let currentLocation = event.locationInWindow
        let delta = (axis == .horizontal)
            ? (currentLocation.x - dragStartLocation.x)
            : -(currentLocation.y - dragStartLocation.y)

        guard !delta.isNaN, !availableLength.isNaN else { return }
        let computedFraction = dragStartFraction + (delta / availableLength)
        guard !computedFraction.isNaN, computedFraction.isFinite else { return }
        let newFraction = min(max(computedFraction, 0.08), 0.92)

        if abs(newFraction - currentFraction) >= 0.002 {
            model?.updateSplitFraction(splitId: splitId, fraction: newFraction)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        needsDisplay = true

        if let win = window as? SuqiTerminalWindow {
            win.isSplitDragging = false
        }

        let currentLocation = event.locationInWindow
        let delta = (axis == .horizontal)
            ? (currentLocation.x - dragStartLocation.x)
            : -(currentLocation.y - dragStartLocation.y)

        if !delta.isNaN && !availableLength.isNaN {
            let computedFraction = dragStartFraction + (delta / availableLength)
            if !computedFraction.isNaN && computedFraction.isFinite {
                let finalFraction = min(max(computedFraction, 0.08), 0.92)
                model?.updateSplitFraction(splitId: splitId, fraction: finalFraction)
            }
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil && isDragging {
            isDragging = false
        }
    }
}
