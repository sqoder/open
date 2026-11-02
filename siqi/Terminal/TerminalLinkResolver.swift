import Foundation

enum TerminalLinkResolver {
    static func resolve(_ raw: String, workingDirectory: String?) -> URL? {
        let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }

        if let url = URL(string: target), let scheme = url.scheme?.lowercased() {
            if scheme == "file" {
                let path = url.path
                if FileManager.default.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
                if let decoded = path.removingPercentEncoding, FileManager.default.fileExists(atPath: decoded) {
                    return URL(fileURLWithPath: decoded)
                }
                return nil
            }
            return url
        }

        let path: String
        if target.hasPrefix("/") {
            path = target
        } else if target.hasPrefix("~/") {
            path = NSString(string: target).expandingTildeInPath
        } else if let workingDirectory, !workingDirectory.isEmpty {
            path = URL(fileURLWithPath: workingDirectory).appendingPathComponent(target).path
        } else {
            return nil
        }

        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // Smart fallback: check common subfolders if target is a simple filename or relative path
        if let workingDirectory, !workingDirectory.isEmpty, !target.hasPrefix("/") {
            let candidates = ["docs", "docx", "doc", "src", "tests", "test"]
            for folder in candidates {
                let candidatePath = URL(fileURLWithPath: workingDirectory)
                    .appendingPathComponent(folder)
                    .appendingPathComponent(target).path
                if FileManager.default.fileExists(atPath: candidatePath) {
                    return URL(fileURLWithPath: candidatePath)
                }
            }
        }

        return nil
    }

    static func resolveDisplayPath(_ raw: String, workingDirectory: String?) -> String {
        let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return "" }

        if let resolvedUrl = resolve(target, workingDirectory: workingDirectory) {
            if resolvedUrl.isFileURL {
                return resolvedUrl.path
            } else {
                return resolvedUrl.absoluteString
            }
        }

        if target.lowercased().hasPrefix("file://") {
            if let url = URL(string: target) {
                return url.path
            }
            return String(target.dropFirst("file://".count))
        }

        if target.lowercased().hasPrefix("http://") || target.lowercased().hasPrefix("https://") {
            return target
        }

        if target.hasPrefix("/") {
            return target
        } else if target.hasPrefix("~/") {
            return NSString(string: target).expandingTildeInPath
        } else if let workingDirectory, !workingDirectory.isEmpty {
            return URL(fileURLWithPath: workingDirectory).appendingPathComponent(target).path
        }

        return target
    }
}
