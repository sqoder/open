import Foundation

enum TerminalLinkResolver {
    static func resolve(_ raw: String, workingDirectory: String?) -> URL? {
        let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }

        if let url = URL(string: target), let scheme = url.scheme?.lowercased() {
            if scheme == "file" {
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
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

        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}
