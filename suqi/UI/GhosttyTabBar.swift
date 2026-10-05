//
//  GhosttyTabBar.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Tab Drag Session Coordinator (AppKit NSDraggingSession)

@MainActor
public final class TabDragSessionCoordinator: ObservableObject {
    public static let shared = TabDragSessionCoordinator()

    public private(set) var activeTabId: UUID?
    private weak var sourceModel: SuqiWindowModel?
    private weak var sourceWindow: NSWindow?
    public var didDropInDestination: Bool = false

    private init() {}

    public func beginSession(tabId: UUID, sourceModel: SuqiWindowModel, sourceWindow: NSWindow) {
        self.activeTabId = tabId
        self.sourceModel = sourceModel
        self.sourceWindow = sourceWindow
        self.didDropInDestination = false
    }

    public func markDroppedInDestination() {
        self.didDropInDestination = true
    }

    public func sessionEnded(at screenPoint: NSPoint, operation: NSDragOperation) {
        defer {
            self.activeTabId = nil
            self.sourceModel = nil
            self.sourceWindow = nil
            self.didDropInDestination = false
        }

        guard let tabId = self.activeTabId,
              let sourceModel = self.sourceModel
        else { return }

        // If the drop was handled by a tab bar destination (reorder or tab transfer), do not detach
        if didDropInDestination {
            return
        }

        // Only detach if the source window has at least 2 tabs
        guard sourceModel.tabs.count > 1 else { return }

        // Check if mouse was released outside the source window frame
        let isOutsideSourceWindow: Bool
        if let window = sourceWindow {
            isOutsideSourceWindow = !NSPointInRect(screenPoint, window.frame)
        } else {
            isOutsideSourceWindow = true
        }

        if isOutsideSourceWindow {
            sourceModel.detachTabToNewWindow(id: tabId, at: screenPoint)
        }
    }
}

// MARK: - Native AppKit Tab Drag Handle (NSDraggingSession & NSDraggingSource)

public final class TabDragHandleView: NSView, NSDraggingSource {
    public var tab: SuqiTab
    public weak var model: SuqiWindowModel?
    public var onSelect: (() -> Void)?
    public var onHover: ((Bool) -> Void)?

    private var mouseDownPoint: NSPoint = .zero
    private var isDraggingSessionActive = false
    private var trackingArea: NSTrackingArea?

    public init(tab: SuqiTab, model: SuqiWindowModel, onSelect: @escaping () -> Void, onHover: @escaping (Bool) -> Void) {
        self.tab = tab
        self.model = model
        self.onSelect = onSelect
        self.onHover = onHover
        super.init(frame: .zero)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    public override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Yield trailing 24pt to SwiftUI close button
        if point.x > bounds.width - 24 {
            return nil
        }
        return super.hitTest(point)
    }

    public override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        isDraggingSessionActive = false
    }

    public override func mouseDragged(with event: NSEvent) {
        guard !isDraggingSessionActive else { return }
        let currentPoint = event.locationInWindow
        let dx = abs(currentPoint.x - mouseDownPoint.x)
        let dy = abs(currentPoint.y - mouseDownPoint.y)

        // Drag threshold of 4 points
        if dx > 4 || dy > 4 {
            isDraggingSessionActive = true
            startDraggingSession(with: event)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        if !isDraggingSessionActive {
            onSelect?()
        }
        isDraggingSessionActive = false
    }

    public override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }

    private func startDraggingSession(with event: NSEvent) {
        guard let window = self.window, let model = self.model else { return }

        let pboardItem = NSPasteboardItem()
        pboardItem.setString(tab.id.uuidString, forType: .string)
        pboardItem.setString(tab.id.uuidString, forType: NSPasteboard.PasteboardType("com.suqi.tab"))

        let dragItem = NSDraggingItem(pasteboardWriter: pboardItem)
        let dragBounds = self.bounds.size.width > 0 ? self.bounds : NSRect(x: 0, y: 0, width: 120, height: 23)
        let dragImage = createDragImage(title: tab.tabDisplayTitle.isEmpty ? tab.title : tab.tabDisplayTitle)
        dragItem.setDraggingFrame(dragBounds, contents: dragImage)

        TabDragSessionCoordinator.shared.beginSession(
            tabId: tab.id,
            sourceModel: model,
            sourceWindow: window
        )

        self.beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    private func createDragImage(title: String) -> NSImage {
        let size = self.bounds.size.width > 0 ? self.bounds.size : NSSize(width: 120, height: 23)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        NSColor.white.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95),
            .paragraphStyle: paragraphStyle
        ]
        let textRect = NSRect(x: 10, y: (size.height - 14) / 2, width: max(10, size.width - 20), height: 14)
        (title as NSString).draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    // MARK: - NSDraggingSource

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        DispatchQueue.main.async {
            TabDragSessionCoordinator.shared.sessionEnded(at: screenPoint, operation: operation)
        }
    }
}

public struct TabDragHandleRepresentable: NSViewRepresentable {
    let tab: SuqiTab
    let model: SuqiWindowModel
    let onSelect: () -> Void
    let onHover: (Bool) -> Void

    public func makeNSView(context: Context) -> TabDragHandleView {
        TabDragHandleView(tab: tab, model: model, onSelect: onSelect, onHover: onHover)
    }

    public func updateNSView(_ nsView: TabDragHandleView, context: Context) {
        nsView.tab = tab
        nsView.model = model
        nsView.onSelect = onSelect
        nsView.onHover = onHover
    }
}

// MARK: - GhosttyTabBar

public struct GhosttyTabBar: View {
    @ObservedObject public var model: SuqiWindowModel
    @State private var hoveredTabId: UUID?
    @State private var draggingTabId: UUID?
    @State private var isPlusHovered: Bool = false

    public init(model: SuqiWindowModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 0) {
            // macOS traffic lights + pin button clearance (~92pt)
            Spacer()
                .frame(width: 92)

            // Equal-width ultra-refined capsule tab segments
            HStack(spacing: 4) {
                ForEach(Array(model.tabs.enumerated()), id: \.element.id) { index, tab in
                    tabItem(tab: tab, index: index)
                }

                plusButton
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .padding(.trailing, 6)
        }
        .frame(height: 36)
        .background(Color.clear)
    }

    @ViewBuilder
    private func tabItem(tab: SuqiTab, index: Int) -> some View {
        let isActive = model.activeTabId == tab.id
        let isHovered = hoveredTabId == tab.id

        GhosttyTabItemView(
            tab: tab,
            model: model,
            index: index,
            isActive: isActive,
            isTabHovered: isHovered,
            onSelect: {
                model.selectTab(id: tab.id)
            },
            onClose: {
                model.closeTabWithConfirmation(id: tab.id, in: NSApp.keyWindow)
            },
            onHover: { hovering in
                hoveredTabId = hovering ? tab.id : nil
            }
        )
        .onHover { hovering in
            hoveredTabId = hovering ? tab.id : nil
        }
        .contextMenu {
            tabContextMenu(tab)
        }
        .onDrop(
            of: [UTType.text, UTType.plainText],
            delegate: TabDropDelegate(
                destinationTab: tab,
                model: model,
                draggingTabId: $draggingTabId
            )
        )
    }

    @ViewBuilder
    private func tabContextMenu(_ tab: SuqiTab) -> some View {
        Button("New Tab") {
            model.createNewTab()
        }
        Button("Split Right") {
            model.splitRight()
        }
        Button("Split Down") {
            model.splitDown()
        }
        if model.tabs.count > 1 {
            Divider()
            Button("Move Tab to New Window") {
                model.detachTabToNewWindow(id: tab.id)
            }
            Button("Close Other Tabs") {
                for other in model.tabs where other.id != tab.id {
                    _ = model.closeTab(id: other.id)
                }
            }
        }
        Divider()
        Button("Close Tab") {
            model.closeTabWithConfirmation(id: tab.id, in: NSApp.keyWindow)
        }
    }

    private var plusButton: some View {
        Button {
            model.createNewTab()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isPlusHovered ? Color.white.opacity(0.95) : Color.white.opacity(0.55))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(isPlusHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.045))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(isPlusHovered ? 0.12 : 0.03), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isPlusHovered = $0 }
        .help("New Tab (⌘T)")
    }
}

// MARK: - Individual Ultra-Refined Apple Capsule Tab Item View

private struct GhosttyTabItemView: View {
    @ObservedObject var tab: SuqiTab
    let model: SuqiWindowModel
    let index: Int
    let isActive: Bool
    let isTabHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onHover: (Bool) -> Void

    @State private var isCloseHovered: Bool = false

    var body: some View {
        ZStack {
            // Perfect continuous capsule background
            backgroundView

            // AppKit Tab Drag Handle with NSDraggingSession & hit-test pass-through
            TabDragHandleRepresentable(
                tab: tab,
                model: model,
                onSelect: onSelect,
                onHover: onHover
            )

            // Center: Tab title
            HStack(spacing: 0) {
                Spacer(minLength: 26)
                tabTitle
                Spacer(minLength: 26)
            }
            .allowsHitTesting(false)

            // Leading: active process indicator
            HStack {
                if tab.hasActiveProcess {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.65, blue: 0.25))
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: Color.orange.opacity(0.60), radius: 1.5)
                        .padding(.leading, 9)
                }
                Spacer()
            }
            .allowsHitTesting(false)

            // Trailing: shortcut badge (⌘N) or close button (on hover)
            HStack {
                Spacer()
                if isTabHovered {
                    closeButton
                        .padding(.trailing, 6)
                } else if index < 9 {
                    shortcutBadge
                        .padding(.trailing, 9)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 23)
        .contentShape(Capsule(style: .continuous))
    }

    private var tabTitle: some View {
        let title = tab.tabDisplayTitle.isEmpty ? tab.title : tab.tabDisplayTitle
        let textColor = isActive ? Color.white.opacity(0.96) : (isTabHovered ? Color.white.opacity(0.85) : Color.white.opacity(0.52))
        return Text(title)
            .font(.system(size: 11, weight: isActive ? .medium : .regular, design: .default))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var shortcutBadge: some View {
        Text("⌘\(index + 1)")
            .font(.system(size: 9.5, weight: isActive ? .medium : .regular, design: .default))
            .foregroundStyle(isActive ? Color.white.opacity(0.65) : Color.white.opacity(0.32))
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 6.5, weight: .bold))
                .foregroundStyle(isCloseHovered ? Color.white.opacity(0.95) : Color.white.opacity(0.60))
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(isCloseHovered ? Color.white.opacity(0.24) : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovered = $0 }
        .help("Close Tab (⌘W)")
    }

    private var backgroundView: some View {
        let fillColor: Color = isActive
            ? Color.white.opacity(0.135)
            : (isTabHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.025))

        let strokeColor: Color = isActive
            ? Color.white.opacity(0.18)
            : (isTabHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.015))

        let shadowColor: Color = isActive ? Color.black.opacity(0.15) : Color.clear

        return Capsule(style: .continuous)
            .fill(fillColor)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: isActive ? 0.65 : 0.5)
            )
            .shadow(color: shadowColor, radius: 1.5, y: 0.5)
    }
}

// MARK: - Tab Drop Delegate (Reordering & Cross-Window Transfer)

struct TabDropDelegate: DropDelegate {
    let destinationTab: SuqiTab
    let model: SuqiWindowModel
    @Binding var draggingTabId: UUID?

    func dropEntered(info: DropInfo) {
        guard let currentId = TabDragSessionCoordinator.shared.activeTabId ?? draggingTabId,
              currentId != destinationTab.id,
              let fromIndex = model.tabs.firstIndex(where: { $0.id == currentId }),
              let toIndex = model.tabs.firstIndex(where: { $0.id == destinationTab.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            model.moveTab(from: fromIndex, to: toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        TabDragSessionCoordinator.shared.markDroppedInDestination()
        draggingTabId = nil

        // Cross-window tab dragging support
        if let draggingId = TabDragSessionCoordinator.shared.activeTabId,
           !model.tabs.contains(where: { $0.id == draggingId }),
           let (sourceModel, sourceTab) = SuqiWindowManager.shared.findTabAndModel(id: draggingId) {
            sourceModel.removeTabWithoutClosingWindow(id: draggingId)
            let destIndex = model.tabs.firstIndex(where: { $0.id == destinationTab.id }) ?? model.tabs.count
            model.insertTab(sourceTab, at: destIndex)
            return true
        }

        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
