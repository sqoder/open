import AppKit
import Foundation

// MARK: - Data Models

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
    var modelName: String = "Gemini 3.8 Flash"
}

// MARK: - Native macOS Dashboard View (Clean, Professional, No Toy Emojis)

class MomiDashboardView: NSView {
    // 1. Header Row
    private let instanceLabel = NSTextField(labelWithString: "Antigravity Desktop")
    private let statusDot = NSTextField(labelWithString: "●")
    private let statusText = NSTextField(labelWithString: "待命")
    
    // 2. Primary Hero Metric
    private let speedNumber = NSTextField(labelWithString: "--")
    private let speedUnit = NSTextField(labelWithString: "tok/s")
    
    // 3. Three-Column Metric Grid
    private let durTitle = NSTextField(labelWithString: "上次耗时")
    private let durValue = NSTextField(labelWithString: "--")
    
    private let tokTitle = NSTextField(labelWithString: "生成词数")
    private let tokValue = NSTextField(labelWithString: "--")
    
    private let modelTitle = NSTextField(labelWithString: "活动模型")
    private let modelValue = NSTextField(labelWithString: "--")
    
    // 4. Subtle Hairline Divider
    private let divider = NSBox()
    
    // 5. History Section
    private let historyTitle = NSTextField(labelWithString: "最近吞吐流水")
    private let historyTableStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "暂无已完成的生成记录")
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 275))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        // --- 1. Header Row ---
        instanceLabel.font = .systemFont(ofSize: 11, weight: .medium)
        instanceLabel.textColor = .secondaryLabelColor
        instanceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instanceLabel)
        
        statusDot.font = .systemFont(ofSize: 8, weight: .bold)
        statusDot.textColor = .tertiaryLabelColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusDot)
        
        statusText.font = .systemFont(ofSize: 11, weight: .regular)
        statusText.textColor = .secondaryLabelColor
        statusText.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusText)
        
        // --- 2. Speed Hero ---
        speedNumber.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        speedNumber.textColor = .labelColor
        speedNumber.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedNumber)
        
        speedUnit.font = .systemFont(ofSize: 13, weight: .regular)
        speedUnit.textColor = .secondaryLabelColor
        speedUnit.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedUnit)
        
        // --- 3. Three-Column Metric Grid ---
        durTitle.font = .systemFont(ofSize: 10, weight: .regular)
        durTitle.textColor = .tertiaryLabelColor
        durTitle.translatesAutoresizingMaskIntoConstraints = false
        
        durValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        durValue.textColor = .labelColor
        durValue.translatesAutoresizingMaskIntoConstraints = false
        
        tokTitle.font = .systemFont(ofSize: 10, weight: .regular)
        tokTitle.textColor = .tertiaryLabelColor
        tokTitle.translatesAutoresizingMaskIntoConstraints = false
        
        tokValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        tokValue.textColor = .labelColor
        tokValue.translatesAutoresizingMaskIntoConstraints = false
        
        modelTitle.font = .systemFont(ofSize: 10, weight: .regular)
        modelTitle.textColor = .tertiaryLabelColor
        modelTitle.translatesAutoresizingMaskIntoConstraints = false
        
        modelValue.font = .systemFont(ofSize: 11.5, weight: .medium)
        modelValue.textColor = .labelColor
        modelValue.lineBreakMode = .byTruncatingTail
        modelValue.translatesAutoresizingMaskIntoConstraints = false
        
        let col1 = NSStackView(views: [durTitle, durValue])
        col1.orientation = .vertical
        col1.alignment = .leading
        col1.spacing = 2
        col1.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col1)
        
        let col2 = NSStackView(views: [tokTitle, tokValue])
        col2.orientation = .vertical
        col2.alignment = .leading
        col2.spacing = 2
        col2.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col2)
        
        let col3 = NSStackView(views: [modelTitle, modelValue])
        col3.orientation = .vertical
        col3.alignment = .leading
        col3.spacing = 2
        col3.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col3)
        
        // --- 4. Hairline Divider ---
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)
        
        // --- 5. History Section ---
        historyTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        historyTitle.textColor = .secondaryLabelColor
        historyTitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyTitle)
        
        historyTableStack.orientation = .vertical
        historyTableStack.spacing = 1
        historyTableStack.distribution = .fillEqually
        historyTableStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyTableStack)
        
        emptyLabel.font = .systemFont(ofSize: 11, weight: .regular)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            // Header Row
            instanceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            instanceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            
            statusText.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            statusText.centerYAnchor.constraint(equalTo: instanceLabel.centerYAnchor),
            
            statusDot.trailingAnchor.constraint(equalTo: statusText.leadingAnchor, constant: -4),
            statusDot.centerYAnchor.constraint(equalTo: statusText.centerYAnchor, constant: -0.5),
            
            // Speed Hero
            speedNumber.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            speedNumber.topAnchor.constraint(equalTo: instanceLabel.bottomAnchor, constant: 4),
            
            speedUnit.leadingAnchor.constraint(equalTo: speedNumber.trailingAnchor, constant: 6),
            speedUnit.firstBaselineAnchor.constraint(equalTo: speedNumber.firstBaselineAnchor),
            
            // 3-Column Metric Grid (Optimized widths so model names like "Gemini 3.8 Flash (Medium)" never truncate)
            col1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            col1.topAnchor.constraint(equalTo: speedNumber.bottomAnchor, constant: 8),
            col1.widthAnchor.constraint(equalToConstant: 54),
            
            col2.leadingAnchor.constraint(equalTo: col1.trailingAnchor, constant: 10),
            col2.topAnchor.constraint(equalTo: col1.topAnchor),
            col2.widthAnchor.constraint(equalToConstant: 64),
            
            col3.leadingAnchor.constraint(equalTo: col2.trailingAnchor, constant: 12),
            col3.topAnchor.constraint(equalTo: col1.topAnchor),
            col3.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            
            // Divider
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            divider.topAnchor.constraint(equalTo: col1.bottomAnchor, constant: 12),
            
            // History Section
            historyTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            historyTitle.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            
            historyTableStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            historyTableStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            historyTableStack.topAnchor.constraint(equalTo: historyTitle.bottomAnchor, constant: 6),
            historyTableStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: historyTableStack.centerYAnchor)
        ])
    }
    
    func update(instance: MonitoredInstance) {
        let last = instance.records.last
        
        // 1. Instance Title
        instanceLabel.stringValue = instance.name
        
        // 2. Status Dot & Text
        if instance.isGenerating {
            statusDot.textColor = .systemOrange
            statusText.stringValue = "生成中..."
            statusText.textColor = .systemOrange
        } else if last != nil {
            statusDot.textColor = .systemGreen
            statusText.stringValue = "活跃"
            statusText.textColor = .secondaryLabelColor
        } else {
            statusDot.textColor = .tertiaryLabelColor
            statusText.stringValue = "待命"
            statusText.textColor = .tertiaryLabelColor
        }
        
        // 3. Hero Speed Display
        if let spd = last?.tps, spd > 0 {
            speedNumber.stringValue = String(format: "%.1f", spd)
            if instance.isGenerating {
                speedNumber.textColor = .systemOrange
            } else if spd >= 40.0 {
                speedNumber.textColor = NSColor(red: 0.22, green: 0.82, blue: 0.48, alpha: 1.0)
            } else {
                speedNumber.textColor = .labelColor
            }
        } else {
            speedNumber.stringValue = "--"
            speedNumber.textColor = .secondaryLabelColor
        }
        
        // 4. Metric Columns
        if let r = last {
            durValue.stringValue = String(format: "%.1fs", r.duration)
            tokValue.stringValue = "\(r.tokens) tok"
        } else {
            durValue.stringValue = "--"
            tokValue.stringValue = "--"
        }
        
        modelValue.stringValue = instance.modelName
        modelValue.toolTip = instance.modelName
        
        // 5. History Table
        for v in historyTableStack.arrangedSubviews {
            historyTableStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        
        let recent = Array(instance.records.suffix(5).reversed())
        if recent.isEmpty {
            emptyLabel.isHidden = false
            historyTableStack.isHidden = true
        } else {
            emptyLabel.isHidden = true
            historyTableStack.isHidden = false
            
            // Header Row
            let header = createTableRow(index: "#", tokens: "词数", duration: "耗时", speed: "速率", isHeader: true)
            historyTableStack.addArrangedSubview(header)
            
            // Data Rows
            for (idx, r) in recent.enumerated() {
                let row = createTableRow(
                    index: "\(idx + 1)",
                    tokens: "\(r.tokens)",
                    duration: String(format: "%.1fs", r.duration),
                    speed: String(format: "%.1f tok/s", r.tps),
                    isHeader: false
                )
                historyTableStack.addArrangedSubview(row)
            }
        }
        
        needsDisplay = true
    }
    
    private func createTableRow(index: String, tokens: String, duration: String, speed: String, isHeader: Bool) -> NSView {
        let rowView = NSView()
        rowView.translatesAutoresizingMaskIntoConstraints = false
        rowView.heightAnchor.constraint(equalToConstant: isHeader ? 16 : 18).isActive = true
        
        let c1 = NSTextField(labelWithString: index)
        let c2 = NSTextField(labelWithString: tokens)
        let c3 = NSTextField(labelWithString: duration)
        let c4 = NSTextField(labelWithString: speed)
        
        let font = isHeader ? NSFont.systemFont(ofSize: 10, weight: .medium) : NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let textColor = isHeader ? NSColor.tertiaryLabelColor : NSColor.labelColor
        
        c1.font = font
        c1.textColor = isHeader ? textColor : NSColor.tertiaryLabelColor
        c1.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(c1)
        
        c2.font = font
        c2.textColor = textColor
        c2.alignment = .right
        c2.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(c2)
        
        c3.font = font
        c3.textColor = isHeader ? textColor : NSColor.secondaryLabelColor
        c3.alignment = .right
        c3.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(c3)
        
        c4.font = font
        c4.textColor = textColor
        c4.alignment = .right
        c4.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(c4)
        
        NSLayoutConstraint.activate([
            c1.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
            c1.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            c2.trailingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 105),
            c2.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            c3.trailingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 185),
            c3.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            c4.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
            c4.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
        ])
        
        return rowView
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var updateTimer: Timer?
    
    var instances: [MonitoredInstance] = []
    var activeInstanceIndex: Int = 0
    var isChecking: Bool = false
    
    // Persistent menu and dashboard view
    let mainMenu = NSMenu()
    let dashboardView = MomiDashboardView()
    let dashboardMenuItem = NSMenuItem()
    let instanceMenuItem = NSMenuItem(title: "监听实例", action: nil, keyEquivalent: "")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = nil
        statusItem.button?.title = "-- tok/s"
        
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
            )
        ]
        
        setupMenu()
        triggerBackgroundUpdate()
        
        // 1.5s refresh timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.triggerBackgroundUpdate()
        }
    }
    
    func setupMenu() {
        mainMenu.autoenablesItems = false
        mainMenu.delegate = self
        
        // 1. Dashboard View (Header, Speed Hero, Metrics, History Table)
        dashboardMenuItem.view = dashboardView
        mainMenu.addItem(dashboardMenuItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // 2. Instance Switcher Submenu
        updateInstanceSubmenu()
        mainMenu.addItem(instanceMenuItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // 3. Actions
        let refreshItem = NSMenuItem(title: "刷新数据", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        mainMenu.addItem(refreshItem)
        
        let openDirItem = NSMenuItem(title: "在访达中显示会话日志", action: #selector(openLogDirAction), keyEquivalent: "o")
        openDirItem.target = self
        mainMenu.addItem(openDirItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 momi", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        mainMenu.addItem(quitItem)
        
        statusItem.menu = mainMenu
    }
    
    func updateInstanceSubmenu() {
        guard activeInstanceIndex >= 0 && activeInstanceIndex < instances.count else { return }
        let active = instances[activeInstanceIndex]
        let now = Date()
        
        instanceMenuItem.title = "监听实例: \(active.name)"
        
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
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        guard activeInstanceIndex >= 0 && activeInstanceIndex < instances.count else { return }
        let active = instances[activeInstanceIndex]
        dashboardView.update(instance: active)
        updateInstanceSubmenu()
    }
    
    /// Ultra-fast 1-level session directory search (only 1-2ms, never enumerates 100k files)
    func fastFindLatestTranscript(in brainDir: URL) -> (url: URL, modDate: Date)? {
        guard let sessionDirs = try? FileManager.default.contentsOfDirectory(
            at: brainDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }
        
        let sortedDirs = sessionDirs.compactMap { url -> (URL, Date)? in
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = attrs.contentModificationDate else { return nil }
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        // Check only top 5 most recently modified session folders
        for (dir, _) in sortedDirs.prefix(5) {
            let transcript = dir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if let attrs = try? transcript.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = attrs.contentModificationDate {
                if date > latestDate {
                    latestDate = date
                    latestFile = transcript
                }
            }
        }
        
        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
    }
    
    /// Reads head of file (8KB) for initial session metadata
    func readHead(url: URL, maxBytes: Int = 8192) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: maxBytes)
        return String(data: data, encoding: .utf8)
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
    
    /// Safe and accurate model name extraction from user settings changes
    func extractModelName(from content: String) -> String? {
        guard content.contains("<USER_SETTINGS_CHANGE>") else { return nil }
        let pattern = #"Model Selection[`']?\s+from\s+\S+\s+to\s+(.+?)(?:\.\s+No need|\.\n|\n|</USER_SETTINGS_CHANGE>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        if let match = regex.firstMatch(in: content, options: [], range: range),
           let modelRange = Range(match.range(at: 1), in: content) {
            let model = String(content[modelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty && !model.contains("{") && !model.contains("let ") {
                return model
            }
        }
        return nil
    }
    
    func parseTranscript(url: URL, fileModDate: Date) -> (records: [TokenRecord], model: String?) {
        var detectedModel: String? = nil
        
        // 1. Extract model name safely from head (step 0) or tail
        if let head = readHead(url: url), let m = extractModelName(from: head) {
            detectedModel = m
        }
        
        guard let content = readTail(url: url) else { return ([], detectedModel) }
        
        if let m = extractModelName(from: content) {
            detectedModel = m
        }
        
        let rawLines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let lines: [String]
        if rawLines.count > 1 && !rawLines[0].hasPrefix("{") {
            lines = Array(rawLines.dropFirst())
        } else {
            lines = rawLines
        }
        
        let isoFormatter = ISO8601DateFormatter()
        var steps: [[String: Any]] = []
        
        for line in lines {
            if let data = line.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                steps.append(json)
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
    
    /// Background asynchronous update: NEVER blocks main thread or causes UI stutter
    func triggerBackgroundUpdate() {
        if isChecking { return }
        isChecking = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            var updatedInstances = self.instances
            var hasChanges = false
            
            for i in 0..<updatedInstances.count {
                if let latest = self.fastFindLatestTranscript(in: updatedInstances[i].brainDir) {
                    updatedInstances[i].latestURL = latest.url
                    updatedInstances[i].latestModDate = latest.modDate
                    
                    let generating = now.timeIntervalSince(latest.modDate) < 2.5
                    if generating != updatedInstances[i].isGenerating {
                        updatedInstances[i].isGenerating = generating
                        hasChanges = true
                    }
                    
                    if latest.modDate != updatedInstances[i].lastParsedModDate {
                        updatedInstances[i].lastParsedModDate = latest.modDate
                        let (recs, model) = self.parseTranscript(url: latest.url, fileModDate: latest.modDate)
                        if let model = model {
                            updatedInstances[i].modelName = model
                        }
                        if !recs.isEmpty {
                            updatedInstances[i].records = recs
                        }
                        hasChanges = true
                    }
                }
            }
            
            var bestIndex = self.activeInstanceIndex
            var bestDate: Date = .distantPast
            var anyGenerating = false
            
            for (idx, inst) in updatedInstances.enumerated() {
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
            
            DispatchQueue.main.async {
                self.isChecking = false
                self.instances = updatedInstances
                if self.activeInstanceIndex != bestIndex {
                    self.activeInstanceIndex = bestIndex
                    hasChanges = true
                }
                
                let active = self.instances[self.activeInstanceIndex]
                
                // Update status bar button text
                if let last = active.records.last {
                    if anyGenerating {
                        self.statusItem.button?.title = String(format: "%.1f t/s · 生成中", last.tps)
                    } else {
                        self.statusItem.button?.title = String(format: "%.1f tok/s", last.tps)
                    }
                } else {
                    self.statusItem.button?.title = "-- tok/s"
                }
                
                // Live update open menu dashboard without tearing menu
                if hasChanges {
                    self.dashboardView.update(instance: active)
                    self.updateInstanceSubmenu()
                }
            }
        }
    }
    
    @objc func switchInstanceAction(_ sender: NSMenuItem) {
        if sender.tag >= 0 && sender.tag < instances.count {
            activeInstanceIndex = sender.tag
            let active = instances[activeInstanceIndex]
            dashboardView.update(instance: active)
            updateInstanceSubmenu()
        }
    }
    
    @objc func refreshAction() {
        for i in 0..<instances.count {
            instances[i].lastParsedModDate = .distantPast
        }
        triggerBackgroundUpdate()
    }
    
    @objc func openLogDirAction() {
        guard activeInstanceIndex >= 0 && activeInstanceIndex < instances.count else { return }
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
