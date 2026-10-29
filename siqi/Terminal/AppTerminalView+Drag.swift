//
//  AppTerminalView+Drag.swift
//  siqi
//
//  Created for siqi Terminal.
//

import AppKit
import UniformTypeIdentifiers
import GhosttyTerminal

extension AppTerminalView {
    public static let enableDragAndDropPipeline: Void = {
        // 1. draggingEntered:
        let enterBlock: @convention(block) (AnyObject, NSDraggingInfo) -> NSDragOperation = { target, sender in
            guard target is AppTerminalView else { return [] }
            let pboard = sender.draggingPasteboard
            if let types = pboard.types, !types.isEmpty {
                return .copy
            }
            return []
        }
        let enterIMP = imp_implementationWithBlock(enterBlock)
        class_replaceMethod(
            AppTerminalView.self,
            #selector(NSDraggingDestination.draggingEntered(_:)),
            enterIMP,
            "Q@:@"
        )

        // 2. draggingUpdated:
        let updatedBlock: @convention(block) (AnyObject, NSDraggingInfo) -> NSDragOperation = { target, sender in
            guard target is AppTerminalView else { return [] }
            return .copy
        }
        let updatedIMP = imp_implementationWithBlock(updatedBlock)
        class_replaceMethod(
            AppTerminalView.self,
            #selector(NSDraggingDestination.draggingUpdated(_:)),
            updatedIMP,
            "Q@:@"
        )

        // 3. prepareForDragOperation:
        let prepareBlock: @convention(block) (AnyObject, NSDraggingInfo) -> Bool = { target, sender in
            return true
        }
        let prepareIMP = imp_implementationWithBlock(prepareBlock)
        class_replaceMethod(
            AppTerminalView.self,
            #selector(NSDraggingDestination.prepareForDragOperation(_:)),
            prepareIMP,
            "B@:@"
        )

        // 4. performDragOperation:
        let performBlock: @convention(block) (AnyObject, NSDraggingInfo) -> Bool = { target, sender in
            guard let view = target as? AppTerminalView else { return false }
            let pboard = sender.draggingPasteboard

            // A. File URLs (Finder files dragged into terminal)
            if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
                let paths = urls.map { $0.path.replacingOccurrences(of: " ", with: "\\ ") }
                let text = paths.joined(separator: " ") + " "
                AppTerminalView.dispatchTerminalInput(text, to: view)
                return true
            }

            // B. Filenames pasteboard type
            if let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !filenames.isEmpty {
                let paths = filenames.map { $0.replacingOccurrences(of: " ", with: "\\ ") }
                let text = paths.joined(separator: " ") + " "
                AppTerminalView.dispatchTerminalInput(text, to: view)
                return true
            }

            // C. Plain text strings (Glint speech-to-text drag, standard AppKit text drags)
            if let str = pboard.string(forType: .string), !str.isEmpty {
                AppTerminalView.dispatchTerminalInput(str, to: view)
                return true
            }
            if let str = pboard.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text")), !str.isEmpty {
                AppTerminalView.dispatchTerminalInput(str, to: view)
                return true
            }
            if let str = pboard.string(forType: NSPasteboard.PasteboardType("public.plain-text")), !str.isEmpty {
                AppTerminalView.dispatchTerminalInput(str, to: view)
                return true
            }
            if let str = pboard.string(forType: NSPasteboard.PasteboardType("NSStringPboardType")), !str.isEmpty {
                AppTerminalView.dispatchTerminalInput(str, to: view)
                return true
            }
            if let strings = pboard.readObjects(forClasses: [NSString.self], options: nil) as? [String], let first = strings.first, !first.isEmpty {
                AppTerminalView.dispatchTerminalInput(first, to: view)
                return true
            }

            return false
        }
        let performIMP = imp_implementationWithBlock(performBlock)
        class_replaceMethod(
            AppTerminalView.self,
            #selector(NSDraggingDestination.performDragOperation(_:)),
            performIMP,
            "B@:@"
        )
    }()

    private static func dispatchTerminalInput(_ text: String, to view: AppTerminalView) {
        view.window?.makeFirstResponder(view)
        if let state = view.delegate as? TerminalViewState {
            _ = state.send(text)
        } else {
            view.sendText(text)
        }
    }

    /// Registers the full array of text and file dragging types for AppTerminalView
    public func registerTerminalDragTypes() {
        registerForDraggedTypes([
            .fileURL,
            .string,
            .rtf,
            .html,
            .URL,
            NSPasteboard.PasteboardType("NSStringPboardType"),
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.plain-text"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }
}
