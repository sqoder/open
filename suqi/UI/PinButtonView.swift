//
//  PinButtonView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import SwiftUI

// MARK: - Native AppKit Pin Button (Slightly larger, lower, hidden by default)

public final class NativePinButtonView: NSControl {
    public weak var model: SuqiWindowModel?
    private var isAreaHovered: Bool = false
    private var containerTrackingArea: NSTrackingArea?

    public var isPinned: Bool {
        model?.isPinned ?? false
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.alphaValue = 0.0 // Hidden by default ("平时是隐藏状态")
        updateTooltip()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.alphaValue = 0.0
    }

    public func updateTooltip() {
        self.toolTip = isPinned ? "Unpin Window (Click to restore normal level)" : "Pin Window on Top (Always on Top)"
    }

    public func updateContainerTracking() {
        guard let container = self.superview else { return }
        if let existing = containerTrackingArea {
            container.removeTrackingArea(existing)
        }
        // Hover zone encompasses the traffic lights row through the pin button (x: 0..110)
        let hoverRect = NSRect(x: 0, y: 0, width: 110, height: container.bounds.height)
        let area = NSTrackingArea(
            rect: hoverRect,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        container.addTrackingArea(area)
        self.containerTrackingArea = area
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateContainerTracking()
        updateVisibility(animated: false)
    }

    public override func mouseEntered(with event: NSEvent) {
        isAreaHovered = true
        updateVisibility(animated: true)
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        isAreaHovered = false
        updateVisibility(animated: true)
        needsDisplay = true
    }

    private func isMouseInHoverZone() -> Bool {
        guard let window, let container = self.superview else { return false }
        let screenPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let mouseInContainer = container.convert(windowPoint, from: nil)
        let hoverRect = NSRect(x: 0, y: 0, width: 110, height: container.bounds.height)
        return NSPointInRect(mouseInContainer, hoverRect)
    }

    public func updateVisibility(animated: Bool) {
        let shouldBeVisible = isPinned || isAreaHovered || isMouseInHoverZone()
        let targetAlpha: CGFloat = shouldBeVisible ? 1.0 : 0.0

        guard abs(self.alphaValue - targetAlpha) > 0.01 else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().alphaValue = targetAlpha
            }
        } else {
            self.alphaValue = targetAlpha
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard let model else { return }
        model.togglePin()
        updateTooltip()
        updateVisibility(animated: true)
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let isHovered = isAreaHovered || isMouseInHoverZone()
        // Exact circular button dimensions matching macOS traffic lights (14x14 pt)
        let circleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(ovalIn: circleRect)

        // Monochromatic Apple glass styling (NO loud orange)
        let bgColor: NSColor
        let strokeColor: NSColor
        let iconColor: NSColor

        if isPinned {
            bgColor = isHovered ? NSColor(white: 1.0, alpha: 0.30) : NSColor(white: 1.0, alpha: 0.22)
            strokeColor = isHovered ? NSColor(white: 1.0, alpha: 0.40) : NSColor(white: 1.0, alpha: 0.26)
            iconColor = NSColor.white.withAlphaComponent(0.96)
        } else {
            bgColor = isHovered ? NSColor(white: 1.0, alpha: 0.16) : NSColor(white: 1.0, alpha: 0.08)
            strokeColor = isHovered ? NSColor(white: 1.0, alpha: 0.20) : NSColor(white: 1.0, alpha: 0.06)
            iconColor = isHovered ? NSColor.white.withAlphaComponent(0.95) : NSColor.white.withAlphaComponent(0.65)
        }

        bgColor.setFill()
        path.fill()

        strokeColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Crisp SF Symbol pin icon (pointSize: 7.0 for pinned, 7.5 for unpinned)
        let symbolName = isPinned ? "pin.fill" : "pin"
        let pointSize: CGFloat = isPinned ? 7.0 : 7.5
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
