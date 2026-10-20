import AppKit
import Foundation

struct TokenRecord {
    let step: Int
    let tokens: Int
    let duration: Double
    let tps: Double
    let hasTool: Bool
    let text: String
    let date: Date
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var updateTimer: Timer?
    var lastTranscriptURL: URL?
    var lastRecords: [TokenRecord] = []
    var currentModelName: String = "Gemini 3.8 Flash (High)"
    var avatarImage: NSImage?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⚡ momi"
        
        // Load avatar icon
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: iconPath) {
            img.size = NSSize(width: 28, height: 28)
            avatarImage = img
        }
        
        updateMetrics()
        
        // 1.5s refresh timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func getLatestTranscriptFile() -> (url: URL, modDate: Date)? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let brainDir = home.appendingPathComponent(".gemini/antigravity/brain")
        guard let enumerator = FileManager.default.enumerator(
            at: brainDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        ) else { return nil }
        
        var latestURL: URL?
        var latestDate: Date = .distantPast
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "transcript.jsonl" {
                if let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attrs.contentModificationDate {
                    if modDate > latestDate {
                        latestDate = modDate
                        latestURL = fileURL
                    }
                }
            }
        }
        
        if let url = latestURL {
            return (url, latestDate)
        }
        return nil
    }
    
    func parseTranscript(url: URL, fileModDate: Date) -> (records: [TokenRecord], model: String?) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return ([], nil) }
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let isoFormatter = ISO8601DateFormatter()
        var steps: [[String: Any]] = []
        var detectedModel: String? = nil
        
        for line in lines {
            if let data = line.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                steps.append(json)
                
                // Try extract model name
                if detectedModel == nil, let contentStr = json["content"] as? String {
                    if let range = contentStr.range(of: "Model Selection` from None to ") {
                        let substr = contentStr[range.upperBound...]
                        if let endLine = substr.firstIndex(of: ".") {
                            detectedModel = String(substr[..<endLine]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }
        
        var records: [TokenRecord] = []
        for i in 0..<steps.count {
            let step = steps[i]
            guard (step["source"] as? String) == "MODEL",
                  (step["type"] as? String) == "PLANNER_RESPONSE" else { continue }
            
            let outTokens = (step["output_tokens"] as? Int) ?? 0
            guard let createdAtStr = step["created_at"] as? String,
                  let tStart = isoFormatter.date(from: createdAtStr) else { continue }
            
            let stepIdx = (step["step_index"] as? Int) ?? 0
            let hasTool = (step["tool_calls"] as? [[String: Any]])?.isEmpty == false
            let text = (step["content"] as? String) ?? ""
            
            if i + 1 < steps.count {
                let nextStep = steps[i + 1]
                let nextType = (nextStep["type"] as? String) ?? ""
                if ["GENERIC", "MODEL", "TOOL"].contains(nextType),
                   let nextAtStr = nextStep["created_at"] as? String,
                   let tEnd = isoFormatter.date(from: nextAtStr) {
                    let dur = max(0.5, tEnd.timeIntervalSince(tStart))
                    let tps = Double(outTokens) / dur
                    records.append(TokenRecord(step: stepIdx, tokens: outTokens, duration: dur, tps: tps, hasTool: hasTool, text: text, date: tStart))
                }
            } else {
                let dur = max(0.5, fileModDate.timeIntervalSince(tStart))
                if outTokens > 0 {
                    let tps = Double(outTokens) / dur
                    records.append(TokenRecord(step: stepIdx, tokens: outTokens, duration: dur, tps: tps, hasTool: hasTool, text: text, date: tStart))
                }
            }
        }
        return (records, detectedModel)
    }
    
    @objc func updateMetrics() {
        guard let latest = getLatestTranscriptFile() else {
            statusItem.button?.title = "⚡ -- tok/s"
            return
        }
        
        lastTranscriptURL = latest.url
        let (records, model) = parseTranscript(url: latest.url, fileModDate: latest.modDate)
        if let model = model {
            currentModelName = model
        }
        lastRecords = records
        
        let isGenerating = Date().timeIntervalSince(latest.modDate) < 2.0
        
        if let last = records.last {
            if isGenerating {
                statusItem.button?.title = String(format: "⚡ %.1f t/s (生成中)", last.tps)
            } else {
                statusItem.button?.title = String(format: "⚡ %.1f tok/s", last.tps)
            }
        } else {
            statusItem.button?.title = "⚡ momi"
        }
        
        rebuildMenu()
    }
    
    func rebuildMenu() {
        let menu = NSMenu()
        
        // Header
        let headerItem = NSMenuItem(title: "  momi · AI 测速仪", action: nil, keyEquivalent: "")
        headerItem.attributedTitle = NSAttributedString(string: "  momi · AI 实时测速仪", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 14)
        ])
        if let img = avatarImage {
            headerItem.image = img
        }
        menu.addItem(headerItem)
        
        let sourceItem = NSMenuItem(title: "🟢 正在监听: Antigravity", action: nil, keyEquivalent: "")
        sourceItem.attributedTitle = NSAttributedString(string: "🟢 正在监听: Antigravity", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        menu.addItem(sourceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if let last = lastRecords.last {
            let speedItem = NSMenuItem(title: String(format: "当前速度:  %.1f tokens/s", last.tps), action: nil, keyEquivalent: "")
            speedItem.attributedTitle = NSAttributedString(string: String(format: "当前速度:  %.1f tokens/s", last.tps), attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.systemGreen
            ])
            menu.addItem(speedItem)
            
            let detailItem = NSMenuItem(title: String(format: "上次耗时:  %.1fs · %d tokens", last.duration, last.tokens), action: nil, keyEquivalent: "")
            menu.addItem(detailItem)
        }
        
        menu.addItem(NSMenuItem(title: "当前模型:  \(currentModelName)", action: nil, keyEquivalent: ""))
        
        if let url = lastTranscriptURL {
            let sessionID = url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            let shortID = sessionID.count > 12 ? String(sessionID.prefix(12)) + "..." : sessionID
            menu.addItem(NSMenuItem(title: "会话 ID:  \(shortID)", action: nil, keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // History section
        let historyHeader = NSMenuItem(title: "📊 最近生成记录:", action: nil, keyEquivalent: "")
        historyHeader.attributedTitle = NSAttributedString(string: "📊 最近生成记录:", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 12)
        ])
        menu.addItem(historyHeader)
        
        let recent = lastRecords.suffix(5).reversed()
        if recent.isEmpty {
            let emptyItem = NSMenuItem(title: "  暂无记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (idx, r) in recent.enumerated() {
                let text = String(format: "  %d. %d tok · %.1fs → %.1f tok/s", idx + 1, r.tokens, r.duration, r.tps)
                let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
                item.attributedTitle = NSAttributedString(string: text, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                ])
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Actions
        let refreshItem = NSMenuItem(title: "🔄 立即刷新", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let openDirItem = NSMenuItem(title: "📂 打开会话日志目录", action: #selector(openLogDirAction), keyEquivalent: "o")
        openDirItem.target = self
        menu.addItem(openDirItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "❌ 退出 momi", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func refreshAction() {
        updateMetrics()
    }
    
    @objc func openLogDirAction() {
        if let dir = lastTranscriptURL?.deletingLastPathComponent() {
            NSWorkspace.shared.open(dir)
        }
    }
    
    @objc func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
