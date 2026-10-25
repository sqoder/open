import Foundation

@main
struct TerminalLinkResolverTests {
    static func main() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let spacedFile = root.appendingPathComponent("notes with space.md")
        fm.createFile(atPath: spacedFile.path, contents: Data())

        let cases: [(String, String?, URL?)] = [
            (spacedFile.absoluteString, nil, spacedFile),
            (spacedFile.path, nil, spacedFile),
            ("~/missing-\(UUID().uuidString).md", nil, nil),
            ("docs/readme.md", root.path, root.appendingPathComponent("docs/readme.md")),
            ("https://example.com/docs", nil, URL(string: "https://example.com/docs")),
            ("/definitely/missing/suqi-file.md", nil, nil),
        ]

        for (raw, cwd, expected) in cases {
            if raw.hasPrefix("docs/") {
                let target = expected?.path ?? ""
                try! fm.createDirectory(at: URL(fileURLWithPath: target).deletingLastPathComponent(), withIntermediateDirectories: true)
                fm.createFile(atPath: target, contents: Data())
            }

            let actual = TerminalLinkResolver.resolve(raw, workingDirectory: cwd)
            precondition(actual == expected, "\(raw): expected \(String(describing: expected)), got \(String(describing: actual))")
        }

        print("TerminalLinkResolverTests passed")
    }
}
