import AppKit
import Foundation

// MARK: - Monitored Instance Model

enum InstanceType {
    case antigravity
    case qoder
}

struct MonitoredInstance {
    let name: String
    let shortTag: String
    let type: InstanceType
    let baseDir: URL
    var latestURL: URL?
    var latestModDate: Date = .distantPast
    var lastParsedModDate: Date = .distantPast
    var isGenerating: Bool = false
    var currentSpeed: Double = 0.0
    var totalSessionTokens: Int = 0
    var lastTrackedFileSize: UInt64 = 0
    var modelName: String = "Gemini 3.8 Flash"
}

// MARK: - Agent Table Dashboard

class AgentTableRowView: NSView {
    private let iconView = NSImageView()
    private let modelLabel = NSTextField(labelWithString: "--")
    private let speedLabel = NSTextField(labelWithString: "--")
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        
        modelLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        modelLabel.textColor = .labelColor
        modelLabel.lineBreakMode = .byTruncatingTail
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelLabel)
        
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        speedLabel.textColor = .secondaryLabelColor
        speedLabel.alignment = .right
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedLabel)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            modelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            modelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            modelLabel.trailingAnchor.constraint(lessThanOrEqualTo: speedLabel.leadingAnchor, constant: -12),
            
            speedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            speedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            speedLabel.widthAnchor.constraint(equalToConstant: 86),
        ])
    }
    
    func update(instance: MonitoredInstance, icon: NSImage?) {
        iconView.image = icon
        iconView.toolTip = instance.name
        modelLabel.stringValue = instance.modelName
        modelLabel.toolTip = instance.modelName
        
        if instance.isGenerating && instance.currentSpeed > 0 {
            speedLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            speedLabel.stringValue = String(format: "%.1f t/s", instance.currentSpeed)
            speedLabel.textColor = .systemOrange
        } else {
            speedLabel.font = .systemFont(ofSize: 12, weight: .regular)
            speedLabel.stringValue = "—"
            speedLabel.textColor = .tertiaryLabelColor
        }
    }
}

class MomiDashboardView: NSView {
    private let headerAgent = NSTextField(labelWithString: "Agent")
    private let headerModel = NSTextField(labelWithString: "模型")
    private let headerSpeed = NSTextField(labelWithString: "速度")
    
    private let rowsStack = NSStackView()
    private var rowViews: [AgentTableRowView] = []
    
    private let separator = NSBox()
    private let totalCaption = NSTextField(labelWithString: "累计使用 Token")
    private let totalValue = NSTextField(labelWithString: "--")
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 172))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        for label in [headerAgent, headerModel, headerSpeed] {
            label.font = .systemFont(ofSize: 10, weight: .semibold)
            label.textColor = .tertiaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        headerSpeed.alignment = .right
        
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        rowsStack.distribution = .fill
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        
        totalCaption.font = .systemFont(ofSize: 10.5, weight: .regular)
        totalCaption.textColor = .tertiaryLabelColor
        totalCaption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(totalCaption)
        
        totalValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        totalValue.textColor = .labelColor
        totalValue.alignment = .right
        totalValue.translatesAutoresizingMaskIntoConstraints = false
        addSubview(totalValue)
        
        NSLayoutConstraint.activate([
            headerAgent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headerAgent.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            headerAgent.heightAnchor.constraint(equalToConstant: 16),
            
            headerModel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            headerModel.centerYAnchor.constraint(equalTo: headerAgent.centerYAnchor),
            
            headerSpeed.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            headerSpeed.centerYAnchor.constraint(equalTo: headerAgent.centerYAnchor),
            headerSpeed.widthAnchor.constraint(equalToConstant: 86),
            
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: headerAgent.bottomAnchor, constant: 4),
            
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            separator.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 6),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            totalCaption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            totalCaption.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 7),
            totalCaption.heightAnchor.constraint(equalToConstant: 18),
            totalCaption.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            
            totalValue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            totalValue.centerYAnchor.constraint(equalTo: totalCaption.centerYAnchor),
            totalValue.leadingAnchor.constraint(greaterThanOrEqualTo: totalCaption.trailingAnchor, constant: 12),
        ])
    }
    
    func configure(with instances: [MonitoredInstance]) {
        guard rowViews.count != instances.count else { return }
        
        for row in rowViews {
            rowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        
        rowViews = instances.map { _ in
            let row = AgentTableRowView()
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            return row
        }
        
        setFrameSize(NSSize(width: 340, height: 70 + CGFloat(instances.count) * 34))
    }
    
    func update(with instances: [MonitoredInstance]) {
        configure(with: instances)
        
        for (row, instance) in zip(rowViews, instances) {
            row.update(instance: instance, icon: icon(for: instance))
        }
        
        let totalTokens = instances.reduce(0) { $0 + $1.totalSessionTokens }
        if totalTokens > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            totalValue.stringValue = formatter.string(from: NSNumber(value: totalTokens)) ?? "\(totalTokens)"
        } else {
            totalValue.stringValue = "--"
        }
    }
    
    private func icon(for instance: MonitoredInstance) -> NSImage? {
        let name: String
        switch instance.type {
        case .qoder:
            name = "agent_qoder"
        case .antigravity:
            name = instance.shortTag == "CLI" ? "agent_antigravity_cli" : "agent_antigravity"
        }
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        return image
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
                type: .antigravity,
                baseDir: home.appendingPathComponent(".gemini/antigravity/brain")
            ),
            MonitoredInstance(
                name: "Antigravity CLI",
                shortTag: "CLI",
                type: .antigravity,
                baseDir: home.appendingPathComponent(".gemini/antigravity-cli/brain")
            ),
            MonitoredInstance(
                name: "Qoder",
                shortTag: "Qoder",
                type: .qoder,
                baseDir: home.appendingPathComponent(".qoder/projects"),
                modelName: "DeepSeek-Flash"
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
        
        // 1. Agent table dashboard
        dashboardView.configure(with: instances)
        dashboardMenuItem.view = dashboardView
        mainMenu.addItem(dashboardMenuItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // 2. Actions (No manual instance switching needed!)
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
    
    func fastFindLatestTranscript(for instance: MonitoredInstance) -> (url: URL, modDate: Date)? {
        switch instance.type {
        case .antigravity:
            return fastFindLatestAntigravityTranscript(in: instance.baseDir)
        case .qoder:
            return fastFindLatestQoderTranscript(in: instance.baseDir)
        }
    }
    
    func fastFindLatestAntigravityTranscript(in brainDir: URL) -> (url: URL, modDate: Date)? {
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
    
    func fastFindLatestQoderTranscript(in projectsDir: URL) -> (url: URL, modDate: Date)? {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        let sortedDirs = projectDirs.compactMap { url -> (URL, Date)? in
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = attrs.contentModificationDate else { return nil }
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        
        for (dir, _) in sortedDirs.prefix(5) {
            if let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) {
                for f in files where f.pathExtension == "jsonl" {
                    if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]),
                       let date = attrs.contentModificationDate {
                        if date > latestDate {
                            latestDate = date
                            latestFile = f
                        }
                    }
                }
            }
        }
        
        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
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
    
    func sanitizeModelName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for char in ["`", "\u{27}", "\"", "\\", "\n", "\r", "<", ">"] {
            if let idx = s.firstIndex(of: Character(char)) {
                s = String(s[..<idx])
            }
        }
        while s.hasSuffix(".") || s.hasSuffix(" ") {
            s = String(s.dropLast())
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractModelName(from content: String) -> String? {
        guard content.contains("Model Selection") else { return nil }
        let pattern = #"(?:setting\s+)?[`\x27]?Model Selection[`\x27]?\s+from\s+.+?\s+to\s+(.+?)(?:\.\s+(?:No need|If reporting)|</USER_SETTINGS_CHANGE>|\.\s*\n|\.\s*$|\n)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        if let lastMatch = matches.last,
           let modelRange = Range(lastMatch.range(at: 1), in: content) {
            let rawModel = String(content[modelRange])
            let cleaned = sanitizeModelName(rawModel)
            if !cleaned.isEmpty && !cleaned.contains("{") && !cleaned.contains("let ") {
                return cleaned
            }
        }
        return nil
    }
    
    func updateSessionTokens(url: URL, instance: inout MonitoredInstance) {
        switch instance.type {
        case .antigravity:
            updateAntigravitySessionTokens(url: url, instance: &instance)
        case .qoder:
            updateQoderSessionTokens(url: url, instance: &instance)
        }
    }
    
    /// Incrementally scans new bytes from Antigravity transcript
    func updateAntigravitySessionTokens(url: URL, instance: inout MonitoredInstance) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        
        if fileSize < instance.lastTrackedFileSize {
            instance.totalSessionTokens = 0
            instance.lastTrackedFileSize = 0
            instance.currentSpeed = 0
        }
        
        handle.seek(toFileOffset: instance.lastTrackedFileSize)
        let newData = handle.readDataToEndOfFile()
        guard !newData.isEmpty else { return }
        
        let processData: Data
        if let lastNewline = newData.lastIndex(of: 0x0A) {
            processData = newData.subdata(in: 0..<lastNewline + 1)
            instance.lastTrackedFileSize += UInt64(processData.count)
        } else {
            return
        }
        
        if let str = String(data: processData, encoding: .utf8) {
            // Track model changes ONLY in authentic USER_EXPLICIT steps
            if str.contains("<USER_SETTINGS_CHANGE>") {
                let lines = str.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("<USER_SETTINGS_CHANGE>"),
                       let data = line.data(using: .utf8),
                       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                       (json["source"] as? String) == "USER_EXPLICIT",
                       let userContent = json["content"] as? String,
                       let m = extractModelName(from: userContent) {
                        instance.modelName = m
                    }
                }
            }
            
            let pattern = #"\"output_tokens\":\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: str, range: NSRange(str.startIndex..., in: str))
                for m in matches {
                    if let r = Range(m.range(at: 1), in: str), let n = Int(str[r]) {
                        instance.totalSessionTokens += n
                    }
                }
            }
        }
    }
    
    /// Incrementally scans new bytes from Qoder session
    func updateQoderSessionTokens(url: URL, instance: inout MonitoredInstance) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        
        if fileSize < instance.lastTrackedFileSize {
            instance.totalSessionTokens = 0
            instance.lastTrackedFileSize = 0
            instance.isGenerating = false
            instance.currentSpeed = 0
        }
        
        handle.seek(toFileOffset: instance.lastTrackedFileSize)
        let newData = handle.readDataToEndOfFile()
        guard !newData.isEmpty else { return }
        
        let processData: Data
        if let lastNewline = newData.lastIndex(of: 0x0A) {
            processData = newData.subdata(in: 0..<lastNewline + 1)
            instance.lastTrackedFileSize += UInt64(processData.count)
        } else {
            return
        }
        
        guard let str = String(data: processData, encoding: .utf8) else { return }
        let lines = str.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        var lastEventType: String?
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            
            let type = (json["type"] as? String) ?? ""
            if type == "user" || type == "assistant" {
                lastEventType = type
            }
            
            if type == "runtime-config", let m = json["model"] as? String {
                instance.modelName = m == "dfmodel" ? "DeepSeek-Flash" : sanitizeModelName(m)
            }
            
            if type == "assistant" {
                let msg = json["message"] as? [String: Any]
                if let m = msg?["model"] as? String, m != "dfmodel" && !m.isEmpty {
                    instance.modelName = sanitizeModelName(m)
                }
                
                var chars = 0
                if let contents = msg?["content"] as? [[String: Any]] {
                    for c in contents {
                        let text = (c["text"] as? String) ?? (c["thinking"] as? String) ?? ""
                        chars += text.count
                    }
                }
                let tokens = max(1, Int(Double(chars) / 2.2))
                instance.totalSessionTokens += tokens
            }
        }
        
        // Qoder only flushes assistant messages after a response completes,
        // so a trailing user/tool_result event means a request is in flight.
        if let lastEventType = lastEventType {
            instance.isGenerating = (lastEventType == "user")
        }
    }
    
    func parseLatestSpeed(url: URL, fileModDate: Date, type: InstanceType) -> Double {
        switch type {
        case .antigravity:
            return parseAntigravityLatestSpeed(url: url, fileModDate: fileModDate)
        case .qoder:
            return parseQoderLatestSpeed(url: url, fileModDate: fileModDate)
        }
    }
    
    func parseAntigravityLatestSpeed(url: URL, fileModDate: Date) -> Double {
        guard let content = readTail(url: url) else { return 0.0 }
        
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
        
        var latestSpeed: Double = 0.0
        for i in 0..<steps.count {
            let step = steps[i]
            guard (step["source"] as? String) == "MODEL",
                  (step["type"] as? String) == "PLANNER_RESPONSE" else { continue }
            
            let outTokens = (step["output_tokens"] as? Int) ?? 0
            guard let createdAtStr = step["created_at"] as? String,
                  let tStart = isoFormatter.date(from: createdAtStr) else { continue }
            
            if i + 1 < steps.count {
                let nextStep = steps[i + 1]
                let nextType = (nextStep["type"] as? String) ?? ""
                if ["GENERIC", "MODEL", "TOOL"].contains(nextType),
                   let nextAtStr = nextStep["created_at"] as? String,
                   let tEnd = isoFormatter.date(from: nextAtStr) {
                    let dur = max(0.5, tEnd.timeIntervalSince(tStart))
                    latestSpeed = Double(outTokens) / dur
                }
            } else {
                let dur = max(0.5, fileModDate.timeIntervalSince(tStart))
                if outTokens > 0 {
                    latestSpeed = Double(outTokens) / dur
                }
            }
        }
        
        return latestSpeed
    }
    
    func parseQoderLatestSpeed(url: URL, fileModDate: Date) -> Double {
        guard let content = readTail(url: url) else { return 0.0 }
        
        let rawLines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let lines: [String]
        if rawLines.count > 1 && !rawLines[0].hasPrefix("{") {
            lines = Array(rawLines.dropFirst())
        } else {
            lines = rawLines
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let backupFormatter = ISO8601DateFormatter()
        backupFormatter.formatOptions = [.withInternetDateTime]
        
        func parseDate(_ s: String?) -> Date? {
            guard let s = s else { return nil }
            return isoFormatter.date(from: s) ?? backupFormatter.date(from: s)
        }
        
        var turnTokens = 0
        var turnStartDate: Date? = nil
        var latestSpeed: Double = 0.0
        
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            
            let type = (json["type"] as? String) ?? ""
            let tsStr = json["timestamp"] as? String
            let date = parseDate(tsStr)
            
            if type == "user" {
                turnStartDate = date
                turnTokens = 0
            } else if type == "assistant" {
                let msg = json["message"] as? [String: Any]
                var chars = 0
                if let contents = msg?["content"] as? [[String: Any]] {
                    for c in contents {
                        let text = (c["text"] as? String) ?? (c["thinking"] as? String) ?? ""
                        chars += text.count
                    }
                }
                let tokens = max(1, Int(Double(chars) / 2.2))
                turnTokens += tokens
                
                if let tEnd = date, let tStart = turnStartDate {
                    let dur = max(0.5, tEnd.timeIntervalSince(tStart))
                    if turnTokens > 30 {
                        latestSpeed = Double(turnTokens) / dur
                    }
                }
            }
        }
        
        return latestSpeed
    }
    
    func triggerBackgroundUpdate() {
        if isChecking { return }
        isChecking = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            var updatedInstances = self.instances
            var hasChanges = false
            
            for i in 0..<updatedInstances.count {
                if let latest = self.fastFindLatestTranscript(for: updatedInstances[i]) {
                    // Check if new session
                    if updatedInstances[i].latestURL != latest.url {
                        updatedInstances[i].latestURL = latest.url
                        updatedInstances[i].lastParsedModDate = .distantPast
                        updatedInstances[i].totalSessionTokens = 0
                        updatedInstances[i].lastTrackedFileSize = 0
                        updatedInstances[i].isGenerating = false
                        updatedInstances[i].currentSpeed = 0
                        hasChanges = true
                    }
                    
                    updatedInstances[i].latestModDate = latest.modDate
                    
                    // Qoder's generating state comes from its appended events
                    // during the token scan below, not from file freshness.
                    if updatedInstances[i].type == .antigravity {
                        let generating = now.timeIntervalSince(latest.modDate) < 2.5
                        if generating != updatedInstances[i].isGenerating {
                            updatedInstances[i].isGenerating = generating
                            hasChanges = true
                        }
                    }
                    
                    if latest.modDate != updatedInstances[i].lastParsedModDate {
                        updatedInstances[i].lastParsedModDate = latest.modDate
                        
                        // 1. Incrementally calculate session tokens and track model
                        self.updateSessionTokens(url: latest.url, instance: &updatedInstances[i])
                        
                        // 2. Parse latest speed
                        let spd = self.parseLatestSpeed(url: latest.url, fileModDate: latest.modDate, type: updatedInstances[i].type)
                        if spd > 0 {
                            updatedInstances[i].currentSpeed = spd
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
    
    func updateDashboardState() {
        let visibleInstances = instances.filter { $0.latestURL != nil }
        let generating = visibleInstances.filter { $0.isGenerating }
        let isConcurrent = generating.count > 1
        
        if isConcurrent {
            let displaySpeed = generating.reduce(0.0) { $0 + $1.currentSpeed }
            let countTag = generating.count == 2 ? "双路并发" : "\(generating.count)路并发"
            statusItem.button?.title = String(format: "%.1f t/s · %@", displaySpeed, countTag)
        } else if let gen = generating.first {
            statusItem.button?.title = String(format: "%.1f t/s · 生成中", gen.currentSpeed)
        } else {
            let mostRecent = visibleInstances.max(by: { $0.latestModDate < $1.latestModDate })
            let speed = mostRecent?.currentSpeed ?? 0.0
            statusItem.button?.title = speed > 0 ? String(format: "%.1f tok/s", speed) : "-- tok/s"
        }
        
        let sortedInstances = visibleInstances
            .enumerated()
            .sorted { lhs, rhs in
                let l = lhs.element, r = rhs.element
                if l.isGenerating != r.isGenerating { return l.isGenerating }
                if l.isGenerating && l.currentSpeed != r.currentSpeed {
                    return l.currentSpeed > r.currentSpeed
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
        
        dashboardView.update(with: sortedInstances)
    }
    
    @objc func refreshAction() {
        for i in 0..<instances.count {
            instances[i].lastParsedModDate = .distantPast
            instances[i].totalSessionTokens = 0
            instances[i].lastTrackedFileSize = 0
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
