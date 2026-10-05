//
//  PinButtonView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit

public struct PinButtonView: View {
    @ObservedObject public var model: SuqiWindowModel
    @State private var isAreaHovered: Bool = false
    @State private var isButtonHovered: Bool = false

    public init(model: SuqiWindowModel) {
        self.model = model
    }

    private var shouldShow: Bool {
        isAreaHovered || isButtonHovered || model.isPinned
    }

    // High-end minimalist Apple monochrome style — NO loud orange
    private var pinColor: Color {
        if model.isPinned {
            return Color.white.opacity(0.96)
        } else if isButtonHovered {
            return Color.white.opacity(0.90)
        } else {
            return Color.white.opacity(0.55)
        }
    }

    private var backgroundFill: Color {
        if model.isPinned {
            return Color.white.opacity(isButtonHovered ? 0.25 : 0.18)
        } else if isButtonHovered {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.045)
        }
    }

    private var borderStroke: Color {
        if model.isPinned {
            return Color.white.opacity(isButtonHovered ? 0.32 : 0.22)
        } else if isButtonHovered {
            return Color.white.opacity(0.15)
        } else {
            return Color.white.opacity(0.035)
        }
    }

    public var body: some View {
        ZStack {
            // Invisible hover trigger area right next to the traffic lights
            Color.clear
                .frame(width: 28, height: 36)
                .contentShape(Rectangle())
                .onHover { isAreaHovered = $0 }

            Button {
                model.togglePin()
            } label: {
                buttonContent
            }
            .buttonStyle(.plain)
            .onHover { isButtonHovered = $0 }
            .opacity(shouldShow ? 1.0 : 0.0)
            .scaleEffect(shouldShow ? 1.0 : 0.82)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: shouldShow)
            .animation(.spring(response: 0.25, dampingFraction: 0.70), value: model.isPinned)
            .help(model.isPinned ? "Unpin Window (Click to restore normal level)" : "Pin Window on Top (Always on Top)")
        }
    }

    private var buttonContent: some View {
        Circle()
            .fill(backgroundFill)
            .overlay(
                Circle()
                    .strokeBorder(borderStroke, lineWidth: 0.5)
            )
            .overlay(
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 7.0, weight: model.isPinned ? .semibold : .medium))
                    .foregroundStyle(pinColor)
                    .rotationEffect(.degrees(model.isPinned ? -30 : 0))
            )
            .frame(width: 14, height: 14) // Exactly 14x14 pt to match macOS traffic lights (red, yellow, green)
            .shadow(color: model.isPinned ? Color.black.opacity(0.25) : Color.clear, radius: 1.5, y: 0.5)
            .frame(width: 20, height: 20) // Comfortable touch/click target
            .contentShape(Circle())
    }
}
