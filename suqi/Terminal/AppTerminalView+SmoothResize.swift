//
//  AppTerminalView+SmoothResize.swift
//  suqi
//
//  Created for suqi Terminal.
//

import AppKit
import GhosttyTerminal

extension AppTerminalView {
    private static var originalSetFrameSizeIMP: IMP?

    /// High-performance macOS native rendering pipeline:
    /// 1. Bypasses screenshot layer magic and multi-frame synchronous blocking render
    /// 2. Adopts underlying IOSurfaceLayer contentsGravity = .topLeft to eliminate Core Animation stretch distortion during live resize
    /// 3. Sets layerContentsRedrawPolicy = .never to prevent AppKit from clearing layers during live resize
    /// 4. Direct invocation of fitToSize() matching official sizeDidChange pipeline
    public static let enableSmoothResizePipeline: Void = {
        guard let method = class_getInstanceMethod(AppTerminalView.self, #selector(NSView.setFrameSize(_:))) else {
            return
        }

        guard let superMethod = class_getInstanceMethod(NSView.self, #selector(NSView.setFrameSize(_:))) else {
            return
        }

        originalSetFrameSizeIMP = method_getImplementation(superMethod)

        let swizzledBlock: @convention(block) (AnyObject, NSSize) -> Void = { target, newSize in
            guard let view = target as? AppTerminalView else { return }

            let sizeChanged = (newSize.width != view.frame.size.width || newSize.height != view.frame.size.height)

            // 1. Call NSView native underlying setFrameSize
            if let originalIMP = AppTerminalView.originalSetFrameSizeIMP {
                typealias Fn = @convention(c) (AnyObject, Selector, NSSize) -> Void
                let fn = unsafeBitCast(originalIMP, to: Fn.self)
                fn(view, #selector(NSView.setFrameSize(_:)), newSize)
            }

            // 2. Anchor top-left to eliminate raster bitmap stretching during live resizing
            view.layer?.contentsGravity = .topLeft
            if let sublayers = view.layer?.sublayers {
                for sub in sublayers {
                    sub.contentsGravity = .topLeft
                }
            }
            view.layerContentsRedrawPolicy = .never

            // 3. Notify terminal engine to synchronize dimensions and schedule next DisplayLink frame
            if sizeChanged && newSize.width >= 10 && newSize.height >= 10 {
                view.fitToSize()
            }
        }

        let swizzledIMP = imp_implementationWithBlock(swizzledBlock)
        method_setImplementation(method, swizzledIMP)
    }()
}
