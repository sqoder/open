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

struct MonitoredInstance {
    let name: String
    let shortTag: String
    let brainDir: URL
    var latestURL: URL?
    var latestModDate: Date = .distantPast
    var lastParsedModDate: Date = .distantPast
    var isGenerating: Bool = false
    var records: [TokenRecord] = []
    var modelName: String = "Gemini 3.8 Flash (High)"
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var updateTimer: Timer?
    var avatarImage: NSImage?
    
    var instances: [MonitoredInstance] = []
    var activeInstanceIndex: Int = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⚡ momi"
        
        // Load avatar icon
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: iconPath) {
            img.size = NSSize(width: 28, height: 28)
            avatarImage = img
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        instances = [
            MonitoredInstance(
                name: "Antigravity Desktop",
                shortTag: "Desktop",
                brainDir: home.appendingPathComponent(".gemini/antigravity/brain")
            ),
            MonitoredInstance(
                name: "Antigravity CLI",
                shortTag: "CLI",
                brainDir: home.appendingPathComponent(".gemini/antigravity-cli/brain")
            ),
            MonitoredInstance(
                name: "Antigravity IDE",
                shortTag: "IDE",
                brainDir: home.appendingPathComponent(".gemini/antigravity-ide/brain")
            )
        ]
        
        updateMetrics()
        
        // 1.5s refresh timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func findLatestTranscript(in dir: URL) -> (url: URL, modDate: Date)? {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
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
    
    /// Reads only the tail (64KB) to avoid loading giant files into RAM
    func readTail(url: URL, maxBytes: UInt64 = 65536) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
    
    func parseTranscript(url: URL, fileModDate: Date) -> (records: [TokenRecord], model: String?) {
        guard let content = readTail(url: url) else { return ([], nil) }
        let rawLines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let lines: [String]
        if rawLines.count > 1 && !rawLines[0].hasPrefix("{") {
            lines = Array(rawLines.dropFirst())
        } else {
            lines = rawLines
        }
        
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
        let now = Date()
        
        // 1. Scan and update all instances
        for i in 0..<instances.count {
            if let latest = findLatestTranscript(in: instances[i].brainDir) {
                instances[i].latestURL = latest.url
                instances[i].latestModDate = latest.modDate
                let generating = now.timeIntervalSince(latest.modDate) < 2.5
                instances[i].isGenerating = generating
                
                // Only re-parse if modified
                if latest.modDate != instances[i].lastParsedModDate {
                    instances[i].lastParsedModDate = latest.modDate
                    let (recs, model) = parseTranscript(url: latest.url, fileModDate: latest.modDate)
                    if let model = model {
                        instances[i].modelName = model
                    }
                    if !recs.isEmpty {
                        instances[i].records = recs
                    }
                }
            }
        }
        
        // 2. Determine active instance:
        // Priority A: generating instance
        // Priority B: most recently modified instance
        var bestIndex = 0
        var bestDate: Date = .distantPast
        var anyGenerating = false
        
        for (idx, inst) in instances.enumerated() {
            if inst.isGenerating {
                bestIndex = idx
                anyGenerating = true
                break
            }
            if inst.latestModDate > bestDate {
                bestDate = inst.latestModDate
                bestIndex = idx
            }
        }
        activeInstanceIndex = bestIndex
        let active = instances[activeInstanceIndex]
        
        // 3. Update status bar button
        if let last = active.records.last {
            if anyGenerating {
                statusItem.button?.title = String(format: "⚡ %.1f t/s [生成中·%@]", last.tps, active.shortTag)
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
        let active = instances[activeInstanceIndex]
        
        // Header
        let headerItem = NSMenuItem(title: "  momi · AI 实时测速仪", action: nil, keyEquivalent: "")
        headerItem.attributedTitle = NSAttributedString(string: "  momi · AI 实时测速仪  v1.1.0", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13)
        ])
        if let img = avatarImage {
            headerItem.image = img
        }
        menu.addItem(headerItem)
        
        let sourceStatus = active.isGenerating ? "🟢 正在生成 (实时监听)" : "🟢 活跃监听中"
        let sourceItem = NSMenuItem(title: "\(sourceStatus): \(active.name)", action: nil, keyEquivalent: "")
        sourceItem.attributedTitle = NSAttributedString(string: "\(sourceStatus): \(active.name)", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        menu.addItem(sourceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Current active instance metrics
        if let last = active.records.last {
            let speedText = String(format: "当前速度:  %.1f tokens/s", last.tps)
            let speedItem = NSMenuItem(title: speedText, action: nil, keyEquivalent: "")
            speedItem.attributedTitle = NSAttributedString(string: speedText, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.systemGreen
            ])
            menu.addItem(speedItem)
            
            let detailItem = NSMenuItem(title: String(format: "上次耗时:  %.1fs · %d tokens", last.duration, last.tokens), action: nil, keyEquivalent: "")
            menu.addItem(detailItem)
        }
        
        menu.addItem(NSMenuItem(title: "当前模型:  \(active.modelName)", action: nil, keyEquivalent: ""))
        
        if let url = active.latestURL {
            let sessionID = url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            let shortID = sessionID.count > 12 ? String(sessionID.prefix(12)) + "..." : sessionID
            menu.addItem(NSMenuItem(title: "会话 ID:  \(shortID)", action: nil, keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Multi-instance status overview
        let instHeader = NSMenuItem(title: "📱 监听中的实例:", action: nil, keyEquivalent: "")
        instHeader.attributedTitle = NSAttributedString(string: "📱 监听中的实例:", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 12)
        ])
        menu.addItem(instHeader)
        
        let now = Date()
        for (idx, inst) in instances.enumerated() {
            let isActive = (idx == activeInstanceIndex)
            let icon: String
            let desc: String
            
            if inst.isGenerating {
                icon = "🔥"
                desc = "生成中..."
            } else if isActive {
                icon = "🟢"
                if let r = inst.records.last {
                    desc = String(format: "活跃 · %.1f t/s", r.tps)
                } else {
                    desc = "活跃"
                }
            } else if inst.latestModDate != .distantPast {
                let diffMins = Int(now.timeIntervalSince(inst.latestModDate) / 60)
                icon = "⚪"
                if diffMins < 60 {
                    desc = "\(diffMins) 分钟前"
                } else {
                    let diffHours = diffMins / 60
                    desc = "\(diffHours) 小时前"
                }
            } else {
                icon = "⚪"
                desc = "无记录 / 离线"
            }
            
            let title = String(format: "  %@ %@: %@", icon, inst.name, desc)
            let item = NSMenuItem(title: title, action: #selector(switchInstanceAction(_:)), keyEquivalent: "")
            item.tag = idx
            item.target = self
            if isActive {
                item.attributedTitle = NSAttributedString(string: title, attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: NSColor.labelColor
                ])
            } else {
                item.attributedTitle = NSAttributedString(string: title, attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ])
            }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // History section of active instance
        let historyTitle = "📊 最近生成记录 (\(active.shortTag)):"
        let historyHeader = NSMenuItem(title: historyTitle, action: nil, keyEquivalent: "")
        historyHeader.attributedTitle = NSAttributedString(string: historyTitle, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 12)
        ])
        menu.addItem(historyHeader)
        
        let recent = active.records.suffix(5).reversed()
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
        
        let openDirItem = NSMenuItem(title: "📂 打开当前会话目录", action: #selector(openLogDirAction), keyEquivalent: "o")
        openDirItem.target = self
        menu.addItem(openDirItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "❌ 退出 momi", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func switchInstanceAction(_ sender: NSMenuItem) {
        if sender.tag >= 0 && sender.tag < instances.count {
            activeInstanceIndex = sender.tag
            rebuildMenu()
        }
    }
    
    @objc func refreshAction() {
        for i in 0..<instances.count {
            instances[i].lastParsedModDate = .distantPast
        }
        updateMetrics()
    }
    
    @objc func openLogDirAction() {
        let active = instances[activeInstanceIndex]
        if let dir = active.latestURL?.deletingLastPathComponent() {
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
