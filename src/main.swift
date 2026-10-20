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

// MARK: - UI Components: Rounded Card View

class RoundedCardView: NSView {
    var customBgColor: NSColor
    var customBorderColor: NSColor
    var cornerRadius: CGFloat
    
    init(frame: NSRect = .zero, bgColor: NSColor, borderColor: NSColor, cornerRadius: CGFloat = 10) {
        self.customBgColor = bgColor
        self.customBorderColor = borderColor
        self.cornerRadius = cornerRadius
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        customBgColor.setFill()
        path.fill()
        customBorderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

// MARK: - UI Components: Pill Badge View

class PillBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")
    var bgColor: NSColor
    var cornerRadius: CGFloat
    
    init(text: String, font: NSFont, textColor: NSColor, bgColor: NSColor, cornerRadius: CGFloat = 5) {
        self.bgColor = bgColor
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        
        label.stringValue = text
        label.font = font
        label.textColor = textColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func update(text: String, textColor: NSColor? = nil, bgColor: NSColor? = nil) {
        label.stringValue = text
        if let textColor = textColor {
            label.textColor = textColor
        }
        if let bgColor = bgColor {
            self.bgColor = bgColor
        }
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        bgColor.setFill()
        path.fill()
        super.draw(dirtyRect)
    }
}

// MARK: - Dashboard Card View (Custom NSView for NSMenuItem)

class MomiDashboardView: NSView {
    // --- Top Hero Card ---
    private let heroCard = RoundedCardView(
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.04) },
        borderColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.08) },
        cornerRadius: 10
    )
    
    private let instanceBadge = PillBadgeView(
        text: "⚡ Antigravity",
        font: .systemFont(ofSize: 10, weight: .semibold),
        textColor: NSColor.secondaryLabelColor,
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.06) },
        cornerRadius: 5
    )
    
    private let statusBadge = PillBadgeView(
        text: "● 待命",
        font: .systemFont(ofSize: 10, weight: .bold),
        textColor: NSColor.secondaryLabelColor,
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.06) },
        cornerRadius: 5
    )
    
    private let speedLabel = NSTextField(labelWithString: "--")
    private let unitLabel = NSTextField(labelWithString: "tok/s")
    
    private let durationChip = PillBadgeView(
        text: "⏱ --s",
        font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
        textColor: NSColor.secondaryLabelColor,
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.05) },
        cornerRadius: 4
    )
    private let tokensChip = PillBadgeView(
        text: "📊 -- tok",
        font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
        textColor: NSColor.secondaryLabelColor,
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.05) },
        cornerRadius: 4
    )
    private let modelChip = PillBadgeView(
        text: "🧠 --",
        font: .systemFont(ofSize: 10.5, weight: .medium),
        textColor: NSColor.secondaryLabelColor,
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.05) },
        cornerRadius: 4
    )
    
    // --- History Section ---
    private let historyTitle = NSTextField(labelWithString: "最近吞吐记录")
    private let historySub = NSTextField(labelWithString: "近 5 轮")
    private let historyCard = RoundedCardView(
        bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.04) : NSColor(white: 0.0, alpha: 0.03) },
        borderColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.1) : NSColor(white: 0.0, alpha: 0.07) },
        cornerRadius: 9
    )
    
    private let tableStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "暂无已完成的生成记录")
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 295))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        // 1. Hero Card
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(heroCard)
        
        instanceBadge.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(instanceBadge)
        
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(statusBadge)
        
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        speedLabel.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
        heroCard.addSubview(speedLabel)
        
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.font = .systemFont(ofSize: 13, weight: .medium)
        unitLabel.textColor = NSColor.secondaryLabelColor
        heroCard.addSubview(unitLabel)
        
        let chipsStack = NSStackView(views: [durationChip, tokensChip, modelChip])
        chipsStack.orientation = .horizontal
        chipsStack.spacing = 5
        chipsStack.distribution = .fill
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(chipsStack)
        
        // 2. History Section Header
        historyTitle.translatesAutoresizingMaskIntoConstraints = false
        historyTitle.font = .systemFont(ofSize: 11, weight: .bold)
        historyTitle.textColor = NSColor.secondaryLabelColor
        addSubview(historyTitle)
        
        historySub.translatesAutoresizingMaskIntoConstraints = false
        historySub.font = .systemFont(ofSize: 10, weight: .regular)
        historySub.textColor = NSColor.tertiaryLabelColor
        addSubview(historySub)
        
        // 3. History Card
        historyCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(historyCard)
        
        tableStack.orientation = .vertical
        tableStack.spacing = 2
        tableStack.distribution = .fillEqually
        tableStack.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(tableStack)
        
        emptyLabel.font = .systemFont(ofSize: 11, weight: .regular)
        emptyLabel.textColor = NSColor.tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            // Hero Card Layout
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            heroCard.heightAnchor.constraint(equalToConstant: 116),
            
            instanceBadge.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            instanceBadge.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 10),
            instanceBadge.heightAnchor.constraint(equalToConstant: 20),
            
            statusBadge.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            statusBadge.centerYAnchor.constraint(equalTo: instanceBadge.centerYAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),
            
            speedLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            speedLabel.topAnchor.constraint(equalTo: instanceBadge.bottomAnchor, constant: 4),
            
            unitLabel.leadingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: 6),
            unitLabel.firstBaselineAnchor.constraint(equalTo: speedLabel.firstBaselineAnchor),
            
            chipsStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            chipsStack.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -12),
            chipsStack.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 5),
            chipsStack.heightAnchor.constraint(equalToConstant: 20),
            
            durationChip.heightAnchor.constraint(equalToConstant: 20),
            tokensChip.heightAnchor.constraint(equalToConstant: 20),
            modelChip.heightAnchor.constraint(equalToConstant: 20),
            
            // History Section Header Layout
            historyTitle.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 11),
            historyTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            
            historySub.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            historySub.centerYAnchor.constraint(equalTo: historyTitle.centerYAnchor),
            
            // History Card Layout
            historyCard.topAnchor.constraint(equalTo: historyTitle.bottomAnchor, constant: 6),
            historyCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            historyCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            historyCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            
            tableStack.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 6),
            tableStack.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 10),
            tableStack.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -10),
            tableStack.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -6),
            
            emptyLabel.centerXAnchor.constraint(equalTo: historyCard.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: historyCard.centerYAnchor)
        ])
    }
    
    func update(instance: MonitoredInstance) {
        let last = instance.records.last
        
        // 1. Instance Source Badge
        instanceBadge.update(text: "⚡ \(instance.name)")
        
        // 2. Status Badge
        if instance.isGenerating {
            statusBadge.update(
                text: "⚡ 生成中",
                textColor: NSColor.systemOrange,
                bgColor: NSColor.systemOrange.withAlphaComponent(0.16)
            )
        } else if last != nil {
            statusBadge.update(
                text: "● 活跃",
                textColor: NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0),
                bgColor: NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 0.15)
            )
        } else {
            statusBadge.update(
                text: "● 待命",
                textColor: NSColor.secondaryLabelColor,
                bgColor: NSColor(white: 1.0, alpha: 0.08)
            )
        }
        
        // 3. Hero Speed Display
        if let spd = last?.tps, spd > 0 {
            speedLabel.stringValue = String(format: "%.1f", spd)
            if instance.isGenerating || spd >= 40.0 {
                speedLabel.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
            } else if spd >= 20.0 {
                speedLabel.textColor = NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
            } else {
                speedLabel.textColor = NSColor.labelColor
            }
        } else {
            speedLabel.stringValue = "--"
            speedLabel.textColor = NSColor.secondaryLabelColor
        }
        
        // 4. Sub-Metric Chips
        if let r = last {
            durationChip.update(text: String(format: "⏱ %.1fs", r.duration))
            tokensChip.update(text: "📊 \(r.tokens) tok")
        } else {
            durationChip.update(text: "⏱ --s")
            tokensChip.update(text: "📊 -- tok")
        }
        
        // Clean Model Name display (e.g. "Gemini 3.8 Flash (Medium)" -> shortened if needed)
        var shortModel = instance.modelName
        if shortModel.count > 19 {
            shortModel = shortModel.replacingOccurrences(of: " (High)", with: " (H)")
                                   .replacingOccurrences(of: " (Medium)", with: " (M)")
                                   .replacingOccurrences(of: " (Low)", with: " (L)")
        }
        modelChip.update(text: "🧠 \(shortModel)")
        modelChip.toolTip = "活动模型: \(instance.modelName)"
        
        // 5. Recent History Table
        for v in tableStack.arrangedSubviews {
            tableStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        
        let recent = Array(instance.records.suffix(5).reversed())
        if recent.isEmpty {
            emptyLabel.isHidden = false
            tableStack.isHidden = true
        } else {
            emptyLabel.isHidden = true
            tableStack.isHidden = false
            
            // Header Row
            let header = createTableRow(index: "轮次", tokens: "分词", duration: "耗时", speed: "速率", isHeader: true)
            tableStack.addArrangedSubview(header)
            
            // Data Rows
            for (idx, r) in recent.enumerated() {
                let row = createTableRow(
                    index: "#\(idx + 1)",
                    tokens: "\(r.tokens) tok",
                    duration: String(format: "%.1fs", r.duration),
                    speed: String(format: "%.1f tok/s", r.tps),
                    isHeader: false,
                    tps: r.tps
                )
                tableStack.addArrangedSubview(row)
            }
        }
        
        needsDisplay = true
    }
    
    private func createTableRow(index: String, tokens: String, duration: String, speed: String, isHeader: Bool, tps: Double = 0) -> NSView {
        let rowView = NSView()
        rowView.translatesAutoresizingMaskIntoConstraints = false
        rowView.heightAnchor.constraint(equalToConstant: isHeader ? 16 : 19).isActive = true
        
        let c1: NSView
        let c2 = NSTextField(labelWithString: tokens)
        let c3 = NSTextField(labelWithString: duration)
        let c4 = NSTextField(labelWithString: speed)
        
        let font = isHeader ? NSFont.systemFont(ofSize: 10, weight: .medium) : NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let textColor = isHeader ? NSColor.tertiaryLabelColor : NSColor.labelColor
        
        if isHeader {
            let label = NSTextField(labelWithString: index)
            label.font = font
            label.textColor = textColor
            label.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(label)
            label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor).isActive = true
            label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor).isActive = true
            c1 = label
        } else {
            let badge = PillBadgeView(
                text: index,
                font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .bold),
                textColor: NSColor.secondaryLabelColor,
                bgColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.06) },
                cornerRadius: 3.5
            )
            badge.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(badge)
            badge.leadingAnchor.constraint(equalTo: rowView.leadingAnchor).isActive = true
            badge.centerYAnchor.constraint(equalTo: rowView.centerYAnchor).isActive = true
            badge.heightAnchor.constraint(equalToConstant: 15).isActive = true
            c1 = badge
        }
        _ = c1
        
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
        
        c4.font = isHeader ? font : NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        if !isHeader {
            if tps >= 40.0 {
                c4.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
            } else if tps >= 20.0 {
                c4.textColor = NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
            } else {
                c4.textColor = NSColor.labelColor
            }
        } else {
            c4.textColor = textColor
        }
        c4.alignment = .right
        c4.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(c4)
        
        NSLayoutConstraint.activate([
            c2.trailingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 110),
            c2.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            c3.trailingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 175),
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
        
        // 1. Dashboard View (Hero Card + History Table)
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
            
            // Priority A: generating instance
            // Priority B: most recently modified instance
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
