//
//  SuqiTerminalView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit
import GhosttyTerminal

public struct PersistentTerminalSurfaceView: NSViewRepresentable {
    let session: SuqiTerminalSession

    public func makeNSView(context: Context) -> AppTerminalView {
        session.terminalView.removeFromSuperview()
        session.terminalView.registerTerminalDragTypes()
        return session.terminalView
    }

    public func updateNSView(_ nsView: AppTerminalView, context: Context) {
        nsView.registerTerminalDragTypes()
    }
}

public struct SuqiTerminalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var session: SuqiTerminalSession
    @ObservedObject var model: SuqiWindowModel

    public init(session: SuqiTerminalSession, model: SuqiWindowModel) {
        self.session = session
        self.model = model
    }

    private var isMultiPane: Bool {
        (model.activeTab?.allSessions.count ?? 1) > 1
    }

    private var isActivePane: Bool {
        model.activeSessionId == session.id
    }

    @State private var configReloadToken = UUID()

    private var userConfig: GhosttyUserConfig {
        _ = configReloadToken
        return GhosttyUserConfig.load().config
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            PersistentTerminalSurfaceView(session: session)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transaction { $0.animation = nil }

            // Minimalist scrollbar (clean #9D9FA2 thumb, hidden by default, fades in during scrolling)
            TerminalScrollbarView(session: session)

            // Smooth dimming overlay for unfocused split pane (unfocused-split-opacity)
            if isMultiPane && !isActivePane {
                let dimOpacity = max(0.0, min(1.0, 1.0 - userConfig.unfocusedSplitOpacity))
                if dimOpacity > 0.001 {
                    Color.black
                        .opacity(dimOpacity)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.15), value: isActivePane)
                }
            }

            // Subtle border indicator for active pane in split mode
            if isMultiPane && isActivePane {
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            session.state.adopt(colorScheme: colorScheme)
            if model.activeSessionId == session.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    session.terminalView.window?.makeFirstResponder(session.terminalView)
                }
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            session.state.adopt(colorScheme: newScheme)
        }
        .onChange(of: model.activeSessionId) { _, newId in
            if newId == session.id {
                session.terminalView.window?.makeFirstResponder(session.terminalView)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ghosttyConfigDidChange)) { _ in
            configReloadToken = UUID()
        }
    }
}

// MARK: - Minimalist Scrollbar (#9D9FA2, auto-hiding)

struct TerminalScrollbarView: View {
    @ObservedObject var session: SuqiTerminalSession
    @State private var isVisible: Bool = false
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    @State private var dragStartThumbY: CGFloat = 0
    @State private var hideTask: DispatchWorkItem? = nil

    // Color #9D9FA2
    private let thumbColor = Color(red: 157/255.0, green: 159/255.0, blue: 162/255.0)

    var body: some View {
        if let scrollbar = session.state.scrollbar, scrollbar.total > scrollbar.len {
            GeometryReader { proxy in
                let height = proxy.size.height
                let total = max(1, scrollbar.total)
                let len = scrollbar.len
                let offset = scrollbar.offset
                let maxOffset = max(1, total - len)

                let visibleRatio = CGFloat(len) / CGFloat(total)
                let thumbHeight = max(28, min(height, height * visibleRatio))
                let trackDistance = max(0, height - thumbHeight)

                let progress = CGFloat(min(offset, maxOffset)) / CGFloat(maxOffset)
                let currentThumbY = trackDistance * progress

                let barWidth: CGFloat = (isHovering || isDragging) ? 6.5 : 4.5

                ZStack(alignment: .topTrailing) {
                    // Transparent gesture target without obscuring terminal content
                    Color.clear
                        .frame(width: 16)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDragging {
                                        isDragging = true
                                        dragStartThumbY = currentThumbY
                                    }
                                    showScrollbar()
                                    let deltaY = value.translation.height
                                    let newThumbY = min(max(0, dragStartThumbY + deltaY), trackDistance)
                                    let newProgress = trackDistance > 0 ? (newThumbY / trackDistance) : 1.0
                                    let targetRow = UInt(round(Double(newProgress) * Double(maxOffset)))
                                    _ = session.state.scrollToRow(targetRow)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    scheduleHide()
                                }
                        )

                    // Render #9D9FA2 scrollbar thumb
                    Capsule(style: .continuous)
                        .fill(thumbColor)
                        .frame(width: barWidth, height: thumbHeight)
                        .offset(x: -2.5, y: currentThumbY)
                        .opacity(isVisible ? (isDragging ? 1.0 : (isHovering ? 0.95 : 0.85)) : 0.0)
                        .animation(.easeInOut(duration: 0.25), value: isVisible)
                        .animation(.easeInOut(duration: 0.15), value: barWidth)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        showScrollbar()
                        scheduleHide(delay: 0.8)
                    } else if !isDragging {
                        scheduleHide(delay: 0.5)
                    }
                }
            }
            .onChange(of: session.state.scrollbar?.offset) { _, _ in
                showAndScheduleHide()
            }
            .onChange(of: session.state.scrollbar?.total) { _, _ in
                showAndScheduleHide()
            }
            .onDisappear {
                hideTask?.cancel()
                hideTask = nil
            }
        }
    }

    private func showScrollbar() {
        hideTask?.cancel()
        hideTask = nil
        withAnimation(.easeInOut(duration: 0.12)) {
            isVisible = true
        }
    }

    private func scheduleHide(delay: Double = 0.65) {
        hideTask?.cancel()
        let task = DispatchWorkItem {
            guard !isDragging else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                isVisible = false
            }
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func showAndScheduleHide() {
        showScrollbar()
        if !isDragging {
            scheduleHide(delay: 0.65)
        }
    }
}
