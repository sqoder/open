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
    var menubarIcon: NSImage?
    var menuLogo: NSImage?
    
    var instances: [MonitoredInstance] = []
    var activeInstanceIndex: Int = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Load official Antigravity icons
        if let iconPath = Bundle.main.path(forResource: "menubar_icon", ofType: "png"),
           let img = NSImage(contentsOfFile: iconPath) {
            img.size = NSSize(width: 16, height: 16)
            menubarIcon = img
            statusItem.button?.image = img
            statusItem.button?.imagePosition = .imageLeft
        }
        
        if let logoPath = Bundle.main.path(forResource: "menu_logo", ofType: "png"),
           let img = NSImage(contentsOfFile: logoPath) {
            img.size = NSSize(width: 20, height: 20)
            menuLogo = img
        }
        
        statusItem.button?.title = " momi"
        
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
    
    /// Reads only tail of the file (64KB)
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
                
                // Extract model name
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
        
        // 3. Update status bar button with Antigravity logo + title
        if let last = active.records.last {
            if anyGenerating {
                statusItem.button?.title = String(format: " %.1f t/s · 生成中", last.tps)
            } else {
                statusItem.button?.title = String(format: " %.1f tok/s", last.tps)
            }
        } else {
            statusItem.button?.title = " momi"
        }
        
        rebuildMenu()
    }
    
    func rebuildMenu() {
        let menu = NSMenu()
        let active = instances[activeInstanceIndex]
        let last = active.records.last
        
        // 1. Header with Antigravity official icon
        let headerItem = NSMenuItem(title: "momi · Antigravity 测速仪", action: nil, keyEquivalent: "")
        if let logo = menuLogo {
            headerItem.image = logo
        }
        let headerAttr = NSMutableAttributedString()
        headerAttr.append(NSAttributedString(string: "momi · Antigravity 测速仪", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]))
        headerAttr.append(NSAttributedString(string: "  v1.2.1", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]))
        headerItem.attributedTitle = headerAttr
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Real-time Throughput (Hero Metric)
        let speedItem = NSMenuItem(title: "实时速率", action: nil, keyEquivalent: "")
        let speedAttr = NSMutableAttributedString()
        speedAttr.append(NSAttributedString(string: "实时速率:   ", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        
        if let spd = last?.tps, spd > 0 {
            let speedColor = active.isGenerating ? NSColor.systemOrange : NSColor.systemGreen
            let statusTag = active.isGenerating ? " (生成中 · \(active.shortTag))" : ""
            speedAttr.append(NSAttributedString(string: String(format: "%.1f tok/s%@", spd, statusTag), attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: speedColor
            ]))
        } else {
            speedAttr.append(NSAttributedString(string: "-- tok/s (等待生成)", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        speedItem.attributedTitle = speedAttr
        speedItem.isEnabled = false
        menu.addItem(speedItem)
        
        // 3. Last Turn Metrics
        let metricItem = NSMenuItem(title: "上次耗时", action: nil, keyEquivalent: "")
        let metricAttr = NSMutableAttributedString()
        metricAttr.append(NSAttributedString(string: "上次耗时:   ", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        if let r = last {
            metricAttr.append(NSAttributedString(string: String(format: "%.1fs (%d tokens)", r.duration, r.tokens), attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]))
        } else {
            metricAttr.append(NSAttributedString(string: "--", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]))
        }
        metricItem.attributedTitle = metricAttr
        metricItem.isEnabled = false
        menu.addItem(metricItem)
        
        // 4. Active Model
        let modelItem = NSMenuItem(title: "活动模型", action: nil, keyEquivalent: "")
        let modelAttr = NSMutableAttributedString()
        modelAttr.append(NSAttributedString(string: "活动模型:   ", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        modelAttr.append(NSAttributedString(string: active.modelName, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]))
        modelItem.attributedTitle = modelAttr
        modelItem.isEnabled = false
        menu.addItem(modelItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Recent Generations Table Header
        let tableHeader = NSMenuItem(title: "最近吞吐记录", action: nil, keyEquivalent: "")
        tableHeader.attributedTitle = NSAttributedString(string: "最近吞吐记录", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        tableHeader.isEnabled = false
        menu.addItem(tableHeader)
        
        let colTitle = NSMenuItem(title: "   序号        分词        耗时          速率", action: nil, keyEquivalent: "")
        colTitle.attributedTitle = NSAttributedString(string: "   序号        分词        耗时          速率", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor
        ])
        colTitle.isEnabled = false
        menu.addItem(colTitle)
        
        let recent = active.records.suffix(5).reversed()
        if recent.isEmpty {
            let emptyItem = NSMenuItem(title: "   暂无已完成的生成记录", action: nil, keyEquivalent: "")
            emptyItem.attributedTitle = NSAttributedString(string: "   暂无已完成的生成记录", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (idx, r) in recent.enumerated() {
                let row = String(format: "   #%-2d    %5d tok      %4.1fs      %5.1f tok/s", idx + 1, r.tokens, r.duration, r.tps)
                let item = NSMenuItem(title: row, action: nil, keyEquivalent: "")
                item.attributedTitle = NSAttributedString(string: row, attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ])
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Instance Switcher Submenu
        let now = Date()
        let instanceMenuTitle = "监听实例: \(active.name)"
        let instanceMenuItem = NSMenuItem(title: instanceMenuTitle, action: nil, keyEquivalent: "")
        instanceMenuItem.attributedTitle = NSAttributedString(string: instanceMenuTitle, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ])
        
        let subMenu = NSMenu()
        for (idx, inst) in instances.enumerated() {
            let isCur = (idx == activeInstanceIndex)
            let check = isCur ? "✓ " : "    "
            let statusDesc: String
            
            if inst.isGenerating {
                statusDesc = "生成中..."
            } else if isCur {
                statusDesc = "当前活跃"
            } else if inst.latestModDate != .distantPast {
                let diffMins = Int(now.timeIntervalSince(inst.latestModDate) / 60)
                if diffMins < 60 {
                    statusDesc = "\(diffMins) 分钟前"
                } else if diffMins < 1440 {
                    statusDesc = "\(diffMins / 60) 小时前"
                } else {
                    statusDesc = "离线"
                }
            } else {
                statusDesc = "离线"
            }
            
            let item = NSMenuItem(
                title: "\(check)\(inst.name) (\(statusDesc))",
                action: #selector(switchInstanceAction(_:)),
                keyEquivalent: ""
            )
            item.tag = idx
            item.target = self
            subMenu.addItem(item)
        }
        instanceMenuItem.submenu = subMenu
        menu.addItem(instanceMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 7. Actions (Clean Apple native items)
        let refreshItem = NSMenuItem(title: "刷新数据", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let openDirItem = NSMenuItem(title: "在访达中显示会话日志", action: #selector(openLogDirAction), keyEquivalent: "o")
        openDirItem.target = self
        menu.addItem(openDirItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 momi", action: #selector(quitAction), keyEquivalent: "q")
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
