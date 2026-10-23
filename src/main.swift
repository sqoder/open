import AppKit
import Foundation

// MARK: - Monitored Instance Model

struct MonitoredInstance {
    let name: String
    let shortTag: String
    let brainDir: URL
    var latestURL: URL?
    var latestModDate: Date = .distantPast
    var lastParsedModDate: Date = .distantPast
    var isGenerating: Bool = false
    var currentSpeed: Double = 0.0
    var totalSessionTokens: Int = 0
    var lastTrackedFileSize: UInt64 = 0
    var modelName: String = "Gemini 3.8 Flash"
}

// MARK: - Minimalist Dual-Core Dashboard View (Style B)

class MomiDashboardView: NSView {
    private let statusDot = NSTextField(labelWithString: "●")
    private let instanceLabel = NSTextField(labelWithString: "Antigravity")
    private let modelLabel = NSTextField(labelWithString: "Gemini 3.8 Flash")
    
    private let speedNumber = NSTextField(labelWithString: "--")
    private let speedUnit = NSTextField(labelWithString: "tok/s")
    private let speedCaption = NSTextField(labelWithString: "瞬时吞吐速率")
    
    private let tokenNumber = NSTextField(labelWithString: "--")
    private let tokenCaption = NSTextField(labelWithString: "累计使用 Token")
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 96))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        // --- Header Row ---
        statusDot.font = .systemFont(ofSize: 8, weight: .bold)
        statusDot.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusDot)
        
        instanceLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        instanceLabel.textColor = .labelColor
        instanceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instanceLabel)
        
        modelLabel.font = .systemFont(ofSize: 11, weight: .regular)
        modelLabel.textColor = .secondaryLabelColor
        modelLabel.lineBreakMode = .byTruncatingTail
        modelLabel.alignment = .right
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelLabel)
        
        // --- Left Metric: Instant Speed ---
        speedNumber.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        speedNumber.textColor = .labelColor
        speedNumber.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedNumber)
        
        speedUnit.font = .systemFont(ofSize: 12.5, weight: .medium)
        speedUnit.textColor = .secondaryLabelColor
        speedUnit.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedUnit)
        
        speedCaption.font = .systemFont(ofSize: 10, weight: .regular)
        speedCaption.textColor = .tertiaryLabelColor
        speedCaption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedCaption)
        
        // --- Right Metric: Total Tokens ---
        tokenNumber.font = .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        tokenNumber.textColor = .labelColor
        tokenNumber.alignment = .right
        tokenNumber.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenNumber)
        
        tokenCaption.font = .systemFont(ofSize: 10, weight: .regular)
        tokenCaption.textColor = .tertiaryLabelColor
        tokenCaption.alignment = .right
        tokenCaption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tokenCaption)
        
        NSLayoutConstraint.activate([
            // Header Row
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            statusDot.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            
            instanceLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 4),
            instanceLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            
            modelLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            modelLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            modelLabel.leadingAnchor.constraint(greaterThanOrEqualTo: instanceLabel.trailingAnchor, constant: 8),
            
            // Left Metric: Speed
            speedNumber.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            speedNumber.topAnchor.constraint(equalTo: instanceLabel.bottomAnchor, constant: 4),
            
            speedUnit.leadingAnchor.constraint(equalTo: speedNumber.trailingAnchor, constant: 5),
            speedUnit.firstBaselineAnchor.constraint(equalTo: speedNumber.firstBaselineAnchor),
            
            speedCaption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            speedCaption.topAnchor.constraint(equalTo: speedNumber.bottomAnchor, constant: 2),
            speedCaption.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            
            // Right Metric: Total Tokens
            tokenNumber.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            tokenNumber.firstBaselineAnchor.constraint(equalTo: speedNumber.firstBaselineAnchor),
            
            tokenCaption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            tokenCaption.topAnchor.constraint(equalTo: tokenNumber.bottomAnchor, constant: 2),
        ])
    }
    
    func update(
        speed: Double,
        totalTokens: Int,
        isConcurrent: Bool,
        isGenerating: Bool,
        instanceName: String,
        modelName: String
    ) {
        // Status & Colors
        if isConcurrent {
            statusDot.textColor = .systemOrange
            instanceLabel.stringValue = "Antigravity · 双路并发"
            speedNumber.textColor = .systemOrange
        } else if isGenerating {
            statusDot.textColor = .systemOrange
            instanceLabel.stringValue = instanceName + " · 生成中"
            speedNumber.textColor = .systemOrange
        } else {
            statusDot.textColor = NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0)
            instanceLabel.stringValue = instanceName
            speedNumber.textColor = speed >= 80.0 ? NSColor(red: 0.22, green: 0.85, blue: 0.52, alpha: 1.0) : .labelColor
        }
        
        // Instant Speed
        if speed > 0 {
            speedNumber.stringValue = String(format: "%.1f", speed)
        } else {
            speedNumber.stringValue = "--"
            speedNumber.textColor = .secondaryLabelColor
        }
        
        // Total Tokens with Decimal Formatter
        if totalTokens > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            tokenNumber.stringValue = formatter.string(from: NSNumber(value: totalTokens)) ?? "\(totalTokens)"
        } else {
            tokenNumber.stringValue = "--"
        }
        
        // Model Name
        modelLabel.stringValue = modelName
        modelLabel.toolTip = modelName
        
        needsDisplay = true
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
        
        // 1. Minimalist Dual-Core Dashboard View (Instant Speed + Total Tokens)
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
        let pattern = #"Model Selection[`']?\s+from\s+.+?\s+to\s+(.+?)(?:\.\s+No need|\.\n|\n|</USER_SETTINGS_CHANGE>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        if let lastMatch = matches.last,
           let modelRange = Range(lastMatch.range(at: 1), in: content) {
            let model = String(content[modelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty && !model.contains("{") && !model.contains("let ") {
                return model
            }
        }
        return nil
    }
    
    /// Incrementally scans new bytes from transcript file to accurately compute total session tokens in O(1) time
    func updateSessionTokens(url: URL, instance: inout MonitoredInstance) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        
        if fileSize < instance.lastTrackedFileSize {
            instance.totalSessionTokens = 0
            instance.lastTrackedFileSize = 0
        }
        
        handle.seek(toFileOffset: instance.lastTrackedFileSize)
        let newData = handle.readDataToEndOfFile()
        instance.lastTrackedFileSize = fileSize
        
        if let str = String(data: newData, encoding: .utf8) {
            // Track model changes in newly appended text
            if str.contains("<USER_SETTINGS_CHANGE>"), let m = extractModelName(from: str) {
                instance.modelName = m
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
    
    func parseLatestSpeed(url: URL, fileModDate: Date) -> (speed: Double, model: String?) {
        var detectedModel: String? = nil
        
        if let head = readHead(url: url), let m = extractModelName(from: head) {
            detectedModel = m
        }
        
        guard let content = readTail(url: url) else { return (0.0, detectedModel) }
        
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
                
                if (json["source"] as? String) == "USER_EXPLICIT",
                   let userContent = json["content"] as? String,
                   let m = extractModelName(from: userContent) {
                    detectedModel = m
                }
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
        
        return (latestSpeed, detectedModel)
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
                if let latest = self.fastFindLatestTranscript(in: updatedInstances[i].brainDir) {
                    // Check if new session
                    if updatedInstances[i].latestURL != latest.url {
                        updatedInstances[i].latestURL = latest.url
                        updatedInstances[i].totalSessionTokens = 0
                        updatedInstances[i].lastTrackedFileSize = 0
                        hasChanges = true
                    }
                    
                    updatedInstances[i].latestModDate = latest.modDate
                    
                    let generating = now.timeIntervalSince(latest.modDate) < 2.5
                    if generating != updatedInstances[i].isGenerating {
                        updatedInstances[i].isGenerating = generating
                        hasChanges = true
                    }
                    
                    if latest.modDate != updatedInstances[i].lastParsedModDate {
                        updatedInstances[i].lastParsedModDate = latest.modDate
                        
                        // 1. Incrementally calculate session tokens
                        self.updateSessionTokens(url: latest.url, instance: &updatedInstances[i])
                        
                        // 2. Parse latest speed and active model
                        let (spd, model) = self.parseLatestSpeed(url: latest.url, fileModDate: latest.modDate)
                        if let model = model {
                            updatedInstances[i].modelName = model
                        }
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
        let generating = instances.filter { $0.isGenerating }
        let isConcurrent = generating.count > 1
        
        let displaySpeed: Double
        if isConcurrent {
            // Sum speeds across all active generating instances
            displaySpeed = generating.reduce(0.0) { $0 + $1.currentSpeed }
            statusItem.button?.title = String(format: "%.1f t/s · 双路并发", displaySpeed)
        } else if let gen = generating.first {
            displaySpeed = gen.currentSpeed
            statusItem.button?.title = String(format: "%.1f t/s · 生成中", displaySpeed)
        } else {
            let mostRecent = instances.max(by: { $0.latestModDate < $1.latestModDate })
            displaySpeed = mostRecent?.currentSpeed ?? 0.0
            statusItem.button?.title = displaySpeed > 0 ? String(format: "%.1f tok/s", displaySpeed) : "-- tok/s"
        }
        
        let totalTokens = instances.reduce(0) { $0 + $1.totalSessionTokens }
        
        let activeName: String
        let activeModel: String
        if isConcurrent {
            activeName = "Antigravity"
            activeModel = instances.map { $0.modelName }.joined(separator: " + ")
        } else if let gen = generating.first {
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
            speed: displaySpeed,
            totalTokens: totalTokens,
            isConcurrent: isConcurrent,
            isGenerating: !generating.isEmpty,
            instanceName: activeName,
            modelName: activeModel
        )
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
