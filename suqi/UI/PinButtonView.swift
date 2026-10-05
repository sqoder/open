//
//  PinButtonView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import SwiftUI

// MARK: - Native AppKit Pin Button (1:1 with macOS Traffic Lights)

public final class NativePinButtonView: NSControl {
    public weak var model: SuqiWindowModel?
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?

    public var isPinned: Bool {
        model?.isPinned ?? false
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        updateTooltip()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func updateTooltip() {
        self.toolTip = isPinned ? "Unpin Window" : "Pin Window on Top (Always on Top)"
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        guard let model else { return }
        model.togglePin()
        updateTooltip()
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Exact circular button dimensions matching macOS traffic lights (14x14 pt)
        let circleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(ovalIn: circleRect)

        // Minimalist monochromatic Apple styling (NO loud orange)
        let bgColor: NSColor
        let strokeColor: NSColor
        let iconColor: NSColor

        if isPinned {
            bgColor = isHovered ? NSColor(white: 1.0, alpha: 0.28) : NSColor(white: 1.0, alpha: 0.20)
            strokeColor = isHovered ? NSColor(white: 1.0, alpha: 0.36) : NSColor(white: 1.0, alpha: 0.24)
            iconColor = NSColor.white.withAlphaComponent(0.96)
        } else {
            bgColor = isHovered ? NSColor(white: 1.0, alpha: 0.14) : NSColor(white: 1.0, alpha: 0.07)
            strokeColor = isHovered ? NSColor(white: 1.0, alpha: 0.18) : NSColor(white: 1.0, alpha: 0.05)
            iconColor = isHovered ? NSColor.white.withAlphaComponent(0.92) : NSColor.white.withAlphaComponent(0.60)
        }

        bgColor.setFill()
        path.fill()

        strokeColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Center SF Symbol pin icon inside the 14x14 button
        let symbolName = isPinned ? "pin.fill" : "pin"
        let pointSize: CGFloat = isPinned ? 6.5 : 7.0
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: isPinned ? .semibold : .medium)
        if let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pin")?.withSymbolConfiguration(config) {
            let tinted = baseImage.copy() as! NSImage
            tinted.lockFocus()
            iconColor.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()

            let iconSize = tinted.size
            let iconOrigin = NSPoint(
                x: round((bounds.width - iconSize.width) / 2.0),
                y: round((bounds.height - iconSize.height) / 2.0)
            )
            tinted.draw(in: NSRect(origin: iconOrigin, size: iconSize))
        }
    }
}
