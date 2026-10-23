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
    let sourceTag: String
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

// MARK: - Mini Sparkline Bar Chart View (Throughput Histogram)

class SparklineBarChartView: NSView {
    struct BarItem {
        let index: Int
        let tps: Double
        let tokens: Int
        let isLatest: Bool
    }
    
    private var items: [BarItem] = []
    
    func setItems(_ records: [(index: Int, tps: Double, tokens: Int)]) {
        self.items = records.enumerated().map { (offset, r) in
            BarItem(index: r.index, tps: r.tps, tokens: r.tokens, isLatest: offset == 0)
        }
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !items.isEmpty else { return }
        
        let maxTps = max(10.0, items.map { $0.tps }.max() ?? 60.0)
        let count = items.count
        let totalWidth = bounds.width
        let barWidth: CGFloat = min(42.0, (totalWidth - CGFloat(count - 1) * 8.0) / CGFloat(count))
        let maxBarHeight: CGFloat = 32.0
        let bottomY: CGFloat = 16.0
        
        for (i, item) in items.enumerated() {
            let x = CGFloat(i) * (barWidth + 8.0)
            let ratio = CGFloat(min(1.0, max(0.1, item.tps / maxTps)))
            let barH = ratio * maxBarHeight
            let barRect = NSRect(x: x, y: bottomY, width: barWidth, height: barH)
            
            // Capsule bar
            let path = NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4)
            if item.isLatest {
                NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 0.85).setFill()
            } else {
                NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.16) : NSColor(white: 0.0, alpha: 0.12) }.setFill()
            }
            path.fill()
            
            // Speed label above bar
            let spdStr = String(format: "%.0f", item.tps)
            let spdAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: item.isLatest ? .bold : .medium),
                .foregroundColor: item.isLatest ? NSColor.labelColor : NSColor.secondaryLabelColor
            ]
            let spdSize = (spdStr as NSString).size(withAttributes: spdAttr)
            let spdRect = NSRect(x: x + (barWidth - spdSize.width) / 2, y: bottomY + barH + 2, width: spdSize.width, height: spdSize.height)
            (spdStr as NSString).draw(in: spdRect, withAttributes: spdAttr)
            
            // Index label below bar
            let idxStr = "#\(item.index)"
            let idxAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            let idxSize = (idxStr as NSString).size(withAttributes: idxAttr)
            let idxRect = NSRect(x: x + (barWidth - idxSize.width) / 2, y: 0, width: idxSize.width, height: idxSize.height)
            (idxStr as NSString).draw(in: idxRect, withAttributes: idxAttr)
        }
    }
}

// MARK: - Modern Unified Dashboard View

class MomiDashboardView: NSView {
    // 1. Hero Card Container
    private let heroCard = NSView()
    
    // Header
    private let instanceTag = NSTextField(labelWithString: "Antigravity")
    private let statusDot = NSTextField(labelWithString: "●")
    private let statusLabel = NSTextField(labelWithString: "待命")
    
    // Speed Display
    private let speedNumber = NSTextField(labelWithString: "--")
    private let speedUnit = NSTextField(labelWithString: "tok/s")
    private let peakLabel = NSTextField(labelWithString: "峰值 --")
    
    // Sparkline Histogram
    private let chartView = SparklineBarChartView()
    
    // Meta footer inside Hero Card
    private let metaFooter = NSTextField(labelWithString: "⏱ --s 耗时  ·  -- tok  ·  Gemini 3.8 Flash")
    
    // 2. Stream Timeline Section
    private let streamTitle = NSTextField(labelWithString: "最近流水记录")
    private let streamStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "暂无已完成的生成记录")
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 336, height: 326))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        // --- 1. Hero Card ---
        heroCard.wantsLayer = true
        heroCard.layer?.cornerRadius = 12
        heroCard.layer?.backgroundColor = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.04) }.cgColor
        heroCard.layer?.borderWidth = 0.5
        heroCard.layer?.borderColor = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.08) }.cgColor
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(heroCard)
        
        instanceTag.font = .systemFont(ofSize: 11.5, weight: .semibold)
        instanceTag.textColor = .labelColor
        instanceTag.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(instanceTag)
        
        statusDot.font = .systemFont(ofSize: 8, weight: .bold)
        statusDot.textColor = .tertiaryLabelColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(statusDot)
        
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(statusLabel)
        
        speedNumber.font = .monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        speedNumber.textColor = .labelColor
        speedNumber.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(speedNumber)
        
        speedUnit.font = .systemFont(ofSize: 13, weight: .medium)
        speedUnit.textColor = .secondaryLabelColor
        speedUnit.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(speedUnit)
        
        peakLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        peakLabel.textColor = .tertiaryLabelColor
        peakLabel.alignment = .right
        peakLabel.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(peakLabel)
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(chartView)
        
        metaFooter.font = .systemFont(ofSize: 10.5, weight: .regular)
        metaFooter.textColor = .secondaryLabelColor
        metaFooter.lineBreakMode = .byTruncatingTail
        metaFooter.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(metaFooter)
        
        // --- 2. Stream Timeline Section ---
        streamTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        streamTitle.textColor = .secondaryLabelColor
        streamTitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(streamTitle)
        
        streamStack.orientation = .vertical
        streamStack.spacing = 3
        streamStack.distribution = .fillEqually
        streamStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(streamStack)
        
        emptyLabel.font = .systemFont(ofSize: 11, weight: .regular)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            // Hero Card
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            heroCard.heightAnchor.constraint(equalToConstant: 168),
            
            instanceTag.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            instanceTag.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 12),
            
            statusLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: instanceTag.centerYAnchor),
            
            statusDot.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -4),
            statusDot.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor, constant: -0.5),
            
            speedNumber.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            speedNumber.topAnchor.constraint(equalTo: instanceTag.bottomAnchor, constant: 2),
            
            speedUnit.leadingAnchor.constraint(equalTo: speedNumber.trailingAnchor, constant: 6),
            speedUnit.firstBaselineAnchor.constraint(equalTo: speedNumber.firstBaselineAnchor),
            
            peakLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            peakLabel.firstBaselineAnchor.constraint(equalTo: speedNumber.firstBaselineAnchor),
            
            chartView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            chartView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            chartView.topAnchor.constraint(equalTo: speedNumber.bottomAnchor, constant: 6),
            chartView.heightAnchor.constraint(equalToConstant: 52),
            
            metaFooter.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            metaFooter.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            metaFooter.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 8),
            
            // Stream Section
            streamTitle.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 11),
            streamTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            
            streamStack.topAnchor.constraint(equalTo: streamTitle.bottomAnchor, constant: 6),
            streamStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            streamStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            streamStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: streamStack.centerYAnchor)
        ])
    }
    
    func update(
        displaySpeed: Double,
        isConcurrent: Bool,
        activeGeneratingCount: Int,
        activeInstanceName: String,
        latestRecord: TokenRecord?,
        allRecords: [TokenRecord],
        activeModelName: String
    ) {
        // 1. Instance Title & Concurrency Badge
        if isConcurrent {
            instanceTag.stringValue = "Antigravity (双路并发)"
            statusDot.textColor = .systemOrange
            statusLabel.stringValue = "双实例生成中..."
            statusLabel.textColor = .systemOrange
        } else if activeGeneratingCount > 0 {
            instanceTag.stringValue = activeInstanceName
            statusDot.textColor = .systemOrange
            statusLabel.stringValue = "生成中..."
            statusLabel.textColor = .systemOrange
        } else if latestRecord != nil {
            instanceTag.stringValue = activeInstanceName
            statusDot.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
            statusLabel.stringValue = "活跃"
            statusLabel.textColor = .secondaryLabelColor
        } else {
            instanceTag.stringValue = "Antigravity"
            statusDot.textColor = .tertiaryLabelColor
            statusLabel.stringValue = "待命"
            statusLabel.textColor = .tertiaryLabelColor
        }
        
        // 2. Hero Speed
        if displaySpeed > 0 {
            speedNumber.stringValue = String(format: "%.1f", displaySpeed)
            if activeGeneratingCount > 0 {
                speedNumber.textColor = .systemOrange
            } else if displaySpeed >= 80.0 {
                speedNumber.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
            } else if displaySpeed >= 40.0 {
                speedNumber.textColor = NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 1.0)
            } else {
                speedNumber.textColor = .labelColor
            }
        } else {
            speedNumber.stringValue = "--"
            speedNumber.textColor = .secondaryLabelColor
        }
        
        // 3. Peak Speed
        let maxTps = allRecords.map { $0.tps }.max() ?? 0.0
        if maxTps > 0 {
            peakLabel.stringValue = String(format: "峰值 %.1f", maxTps)
        } else {
            peakLabel.stringValue = "峰值 --"
        }
        
        // 4. Sparkline Histogram (Recent 5 turns)
        let recent5 = Array(allRecords.prefix(5))
        if !recent5.isEmpty {
            chartView.isHidden = false
            chartView.setItems(recent5.enumerated().map { (idx, r) in
                (index: idx + 1, tps: r.tps, tokens: r.tokens)
            })
        } else {
            chartView.isHidden = true
        }
        
        // 5. Metadata Footer
        if let r = latestRecord {
            let durStr = String(format: "%.1fs 耗时", r.duration)
            let tokStr = "\(r.tokens) tokens"
            let srcStr = r.sourceTag.isEmpty ? "" : " · \(r.sourceTag)"
            metaFooter.stringValue = "⏱ \(durStr)  ·  \(tokStr)  ·  \(activeModelName)\(srcStr)"
        } else {
            metaFooter.stringValue = "⏱ --s 耗时  ·  -- tokens  ·  \(activeModelName)"
        }
        
        // 6. Stream Timeline Section
        for v in streamStack.arrangedSubviews {
            streamStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        
        if allRecords.isEmpty {
            emptyLabel.isHidden = false
            streamStack.isHidden = true
        } else {
            emptyLabel.isHidden = true
            streamStack.isHidden = false
            
            for (idx, r) in recent5.enumerated() {
                let row = createStreamRow(
                    idx: idx + 1,
                    sourceTag: r.sourceTag,
                    tokens: r.tokens,
                    duration: r.duration,
                    tps: r.tps,
                    maxTps: maxTps
                )
                streamStack.addArrangedSubview(row)
            }
        }
        
        needsDisplay = true
    }
    
    private func createStreamRow(idx: Int, sourceTag: String, tokens: Int, duration: Double, tps: Double, maxTps: Double) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let idxLabel = NSTextField(labelWithString: "#\(idx)")
        idxLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        idxLabel.textColor = .tertiaryLabelColor
        idxLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(idxLabel)
        
        // Source Tag Badge (CLI / Desktop)
        let tagLabel = NSTextField(labelWithString: sourceTag)
        tagLabel.font = .systemFont(ofSize: 9, weight: .medium)
        tagLabel.textColor = .secondaryLabelColor
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(tagLabel)
        
        let detailLabel = NSTextField(labelWithString: "\(tokens) tok · \(String(format: "%.1fs", duration))")
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .labelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(detailLabel)
        
        // Mini Progress Speed Bar
        let barContainer = NSView()
        barContainer.wantsLayer = true
        barContainer.layer?.cornerRadius = 2
        barContainer.layer?.backgroundColor = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.06) }.cgColor
        barContainer.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(barContainer)
        
        let barFill = NSView()
        barFill.wantsLayer = true
        barFill.layer?.cornerRadius = 2
        let ratio = CGFloat(min(1.0, max(0.1, maxTps > 0 ? tps / maxTps : 0.5)))
        let fillColor: NSColor
        if tps >= 80.0 {
            fillColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 0.85)
        } else if tps >= 40.0 {
            fillColor = NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 0.85)
        } else {
            fillColor = NSColor(white: 1.0, alpha: 0.35)
        }
        barFill.layer?.backgroundColor = fillColor.cgColor
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barContainer.addSubview(barFill)
        
        let speedLabel = NSTextField(labelWithString: String(format: "%.1f tok/s", tps))
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        speedLabel.textColor = tps >= 80.0 ? NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0) : .labelColor
        speedLabel.alignment = .right
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(speedLabel)
        
        NSLayoutConstraint.activate([
            idxLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            idxLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            idxLabel.widthAnchor.constraint(equalToConstant: 20),
            
            tagLabel.leadingAnchor.constraint(equalTo: idxLabel.trailingAnchor, constant: 2),
            tagLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            tagLabel.widthAnchor.constraint(equalToConstant: 44),
            
            detailLabel.leadingAnchor.constraint(equalTo: tagLabel.trailingAnchor, constant: 4),
            detailLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            speedLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
            speedLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            speedLabel.widthAnchor.constraint(equalToConstant: 80),
            
            barContainer.trailingAnchor.constraint(equalTo: speedLabel.leadingAnchor, constant: -8),
            barContainer.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            barContainer.widthAnchor.constraint(equalToConstant: 42),
            barContainer.heightAnchor.constraint(equalToConstant: 4),
            
            barFill.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barContainer.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
            barFill.widthAnchor.constraint(equalTo: barContainer.widthAnchor, multiplier: ratio)
        ])
        
        return row
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var updateTimer: Timer?
    
    var instances: [MonitoredInstance] = []
    var isChecking: Bool = false
    
    // Persistent menu and dashboard view
    let mainMenu = NSMenu()
    let dashboardView = MomiDashboardView()
    let dashboardMenuItem = NSMenuItem()
    
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
        
        // 1. Dashboard View (Hero Card + Sparkline Chart + Stream List)
        dashboardMenuItem.view = dashboardView
        mainMenu.addItem(dashboardMenuItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // 2. Clean Actions (NO manual instance switching - auto combined & smart detected!)
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
    
    func menuWillOpen(_ menu: NSMenu) {
        updateDashboardState()
    }
    
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
    
    func readHead(url: URL, maxBytes: Int = 8192) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: maxBytes)
        return String(data: data, encoding: .utf8)
    }
    
    func readTail(url: URL, maxBytes: UInt64 = 65536) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
    
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
    
    func parseTranscript(url: URL, fileModDate: Date, sourceTag: String) -> (records: [TokenRecord], model: String?) {
        var detectedModel: String? = nil
        
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
                    records.append(TokenRecord(step: stepIdx, tokens: outTokens, duration: dur, tps: tps, hasTool: hasTool, text: text, date: tStart, sourceTag: sourceTag))
                }
            } else {
                let dur = max(0.5, fileModDate.timeIntervalSince(tStart))
                if outTokens > 0 {
                    let tps = Double(outTokens) / dur
                    records.append(TokenRecord(step: stepIdx, tokens: outTokens, duration: dur, tps: tps, hasTool: hasTool, text: text, date: tStart, sourceTag: sourceTag))
                }
            }
        }
        return (records, detectedModel)
    }
    
    /// Background asynchronous update: monitors both instances simultaneously
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
                        let (recs, model) = self.parseTranscript(url: latest.url, fileModDate: latest.modDate, sourceTag: updatedInstances[i].shortTag)
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
            
            DispatchQueue.main.async {
                self.isChecking = false
                self.instances = updatedInstances
                if hasChanges {
                    self.updateDashboardState()
                }
            }
        }
    }
    
    /// Computes aggregated throughput, handles concurrency, updates UI
    func updateDashboardState() {
        // Find generating instances
        let generatingInstances = instances.filter { $0.isGenerating }
        let isConcurrent = generatingInstances.count > 1
        
        // Merge all records chronologically
        var allRecords: [TokenRecord] = []
        for inst in instances {
            allRecords.append(contentsOf: inst.records)
        }
        allRecords.sort { $0.date > $1.date }
        
        let latestRecord = allRecords.first
        
        // Speed calculation
        let displaySpeed: Double
        if isConcurrent {
            // Sum throughput of both generating engines!
            displaySpeed = generatingInstances.reduce(0.0) { $0 + ($1.records.last?.tps ?? 0.0) }
            statusItem.button?.title = String(format: "%.1f t/s · 双路并发", displaySpeed)
        } else if let gen = generatingInstances.first {
            displaySpeed = gen.records.last?.tps ?? 0.0
            statusItem.button?.title = String(format: "%.1f t/s · 生成中", displaySpeed)
        } else if let last = latestRecord {
            displaySpeed = last.tps
            statusItem.button?.title = String(format: "%.1f tok/s", displaySpeed)
        } else {
            displaySpeed = 0.0
            statusItem.button?.title = "-- tok/s"
        }
        
        // Determine active instance display name
        let activeName: String
        let activeModel: String
        if isConcurrent {
            activeName = "Antigravity (双路并发)"
            activeModel = instances.map { $0.modelName }.joined(separator: " + ")
        } else if let gen = generatingInstances.first {
            activeName = gen.name
            activeModel = gen.modelName
        } else if let mostRecent = instances.max(by: { $0.latestModDate < $1.latestModDate }), mostRecent.latestModDate != .distantPast {
            activeName = mostRecent.name
            activeModel = mostRecent.modelName
        } else {
            activeName = "Antigravity"
            activeModel = instances.first?.modelName ?? "Gemini 3.8 Flash"
        }
        
        dashboardView.update(
            displaySpeed: displaySpeed,
            isConcurrent: isConcurrent,
            activeGeneratingCount: generatingInstances.count,
            activeInstanceName: activeName,
            latestRecord: latestRecord,
            allRecords: allRecords,
            activeModelName: activeModel
        )
    }
    
    @objc func refreshAction() {
        for i in 0..<instances.count {
            instances[i].lastParsedModDate = .distantPast
        }
        triggerBackgroundUpdate()
    }
    
    @objc func openLogDirAction() {
        let mostRecent = instances.max(by: { $0.latestModDate < $1.latestModDate })
        if let dir = mostRecent?.latestURL?.deletingLastPathComponent() {
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
