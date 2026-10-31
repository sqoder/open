import AppKit
import Foundation

// MARK: - Shared Model Name Helpers

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

let maxPlausibleSpeed: Double = 5_000

func clampSpeed(_ speed: Double) -> Double {
    guard speed.isFinite, speed > 0 else { return 0 }
    return min(speed, maxPlausibleSpeed)
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

func piModelDisplayName(for raw: String) -> String {
    let id = raw.hasPrefix("magpie/") ? String(raw.dropFirst("magpie/".count)) : raw
    let modelsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".pi/agent/models.json")

    if let data = try? Data(contentsOf: modelsURL),
       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       let providers = json["providers"] as? [String: Any] {
        for value in providers.values {
            guard let provider = value as? [String: Any],
                  let models = provider["models"] as? [[String: Any]] else { continue }
            for model in models where (model["id"] as? String) == id {
                if let name = model["name"] as? String, !name.isEmpty {
                    let shortName = name.components(separatedBy: " · ").first ?? name
                    return sanitizeModelName(shortName)
                }
            }
        }
    }

    switch id {
    case "qoder/dfmodel", "dfmodel":
        return "DeepSeek-Flash"
    case "qoder/qfmodel", "qfmodel":
        return "Qwen3.8-Flash"
    default:
        return sanitizeModelName(id)
    }
}

func claudeModelDisplayName(for raw: String) -> String {
    let clean = sanitizeModelName(raw)
    let lower = clean.lowercased()
    if lower == "dfmodel" || lower.hasSuffix("/dfmodel") { return "DeepSeek-Flash" }
    if lower == "qfmodel" || lower.hasSuffix("/qfmodel") { return "Qwen3.8-Flash" }
    guard lower.contains("claude") else { return clean }

    var tokens = lower.split(separator: "-").map(String.init)
    tokens.removeAll { token in
        token == "claude" || (token.count == 8 && Int(token) != nil)
    }

    guard let familyIndex = tokens.firstIndex(where: { ["opus", "sonnet", "haiku"].contains($0) }) else {
        return clean
    }
    let family = tokens[familyIndex].capitalized
    let numbers = tokens.enumerated()
        .filter { $0.offset != familyIndex && Int($0.element) != nil }
        .map { $0.element }
    return numbers.isEmpty ? "Claude \(family)" : "Claude \(family) \(numbers.joined(separator: "."))"
}

func qoderModelDisplayName(for raw: String) -> String {
    let clean = sanitizeModelName(raw)
    guard !clean.isEmpty else { return "未知模型" }

    let id = clean.hasPrefix("magpie/") ? String(clean.dropFirst("magpie/".count)) : clean
    let dynamicTextsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".qoder/.auth/dynamic-texts.json")

    if let data = try? Data(contentsOf: dynamicTextsURL),
       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       let locales = json["locales"] as? [String: Any] {
        let localeDict = (locales["zh"] as? [String: Any]) ?? (locales["en"] as? [String: Any]) ?? [:]
        if let name = localeDict["modelSelector.item.\(id)"] as? String, !name.isEmpty {
            return sanitizeModelName(name)
        }
    }

    switch id {
    case "dfmodel": return "DeepSeek-Flash"
    case "dmodel": return "DeepSeek-V4-Pro"
    case "kmodel": return "Kimi-K2.8-Preview"
    case "kmodel_latest": return "Kimi-K3.1-Pro"
    case "qfmodel": return "Qwen3.8-Flash"
    case "qmodel": return "Qwen3.7-Plus"
    case "qmodel_latest": return "Qwen3.7-Max"
    case "qmodel_preview": return "Qwen3.8-Max-Preview"
    case "qmodel_38max": return "Qwen3.8-Max"
    case "q35model": return "Qwen3.5-Plus"
    case "gfmodel": return "GLM-5.3-Flash"
    case "gmodel": return "GLM-5.3"
    case "gm51model": return "GLM-5.2"
    case "mmodel": return "MiniMax-M3.1-Flash"
    case "cmodel": return "Cantus"
    case "smodel": return "Sonus"
    case "kimi-work/k3d1-agent", "k3d1-agent": return "Kimi-K3.1-Agent"
    case "qwenwork/qwen3.8-max-preview": return "Qwen3.8-Max-Preview"
    default:
        let tail = clean.split(separator: "/").last.map(String.init) ?? clean
        return sanitizeModelName(tail)
    }
}

func codexModelDisplayName(for raw: String) -> String {
    let clean = sanitizeModelName(raw)
    guard !clean.isEmpty else { return "Codex" }
    let id = clean.split(separator: "/").last.map(String.init) ?? clean
    guard id.lowercased().hasPrefix("gpt-") else { return id }

    let tail = id.dropFirst(4).split(separator: "-").map { part -> String in
        if part.first?.isNumber == true { return String(part) }
        return part.prefix(1).uppercased() + part.dropFirst()
    }.joined(separator: "-")
    return "GPT-" + tail
}

func deepseekModelDisplayName(for raw: String) -> String {
    let clean = sanitizeModelName(raw)
    guard !clean.isEmpty else { return "DeepSeek" }
    let id = clean.split(separator: "/").last.map(String.init) ?? clean
    var parts = id.split(separator: "-").map { part -> String in
        guard let first = part.first else { return "" }
        return first.uppercased() + part.dropFirst()
    }
    if let first = parts.first, first.lowercased() == "deepseek" {
        parts[0] = "DeepSeek"
    }
    return parts.joined(separator: "-")
}

enum CodexFlavor: String {
    case desktop
    case cli

    var agentKey: String { self == .desktop ? "codex-desktop" : "codex-cli" }
}

func codexFlavor(forOriginator raw: String?) -> CodexFlavor {
    let value = (raw ?? "").lowercased()
    return value.contains("desktop") || value.contains("vscode") ? .desktop : .cli
}

let usageAgentOrder = ["antigravity-desktop", "antigravity-cli", "qoder", "deepseek", "pi", "claude", "codex-desktop", "codex-cli"]

func agentDisplayName(for key: String) -> String {
    switch key {
    case "antigravity-desktop": return "Antigravity Desktop"
    case "antigravity-cli": return "Antigravity CLI"
    case "qoder": return "Qoder"
    case "deepseek": return "DeepSeek Harness"
    case "pi": return "Pi"
    case "claude": return "Claude Code"
    case "codex-desktop": return "Codex App"
    case "codex-cli": return "Codex CLI"
    default: return key
    }
}

func agentIconName(for key: String) -> String? {
    switch key {
    case "antigravity-desktop": return "agent_antigravity"
    case "antigravity-cli": return "agent_antigravity_cli"
    case "qoder": return "agent_qoder"
    case "deepseek": return "agent_deepseek"
    case "pi": return "agent_pi"
    case "claude": return "agent_claude"
    case "codex-desktop": return "agent_codex"
    case "codex-cli": return "agent_codex_cli"
    default: return nil
    }
}

let refreshIntervalDefaultsKey = "momi.refreshInterval"

// MARK: - Monitored Instance Model

enum InstanceType {
    case antigravity
    case qoder
    case deepseek
    case pi
    case claude
    case codex
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
    var claudeMessageLedger: [String: Int] = [:]
    var claudeRequestStartedAt: Date?
    var claudeToolInFlight: Bool = false
    var antigravityStepInFlight: Bool = false
    var codexFlavor: CodexFlavor = .cli
    var codexTaskStartedAt: Date?
    var codexLastTokenAt: Date?
    var qoderTurnStartedAt: Date?
    var qoderTurnTokens: Int = 0
    var deepseekLastActivity: Date?
}

// MARK: - Usage Statistics Model

enum UsagePeriod: Int, CaseIterable, Hashable {
    case all = 0
    case week = 1
    case today = 2
}

struct TokenUsage: Codable {
    var input: Int64 = 0
    var output: Int64 = 0
    var cache: Int64 = 0
    var requests: Int = 0
    var estimatedOutput: Int64 = 0

    var total: Int64 { input + output }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case input, output, cache, requests, estimatedOutput
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        input = try c.decodeIfPresent(Int64.self, forKey: .input) ?? 0
        output = try c.decodeIfPresent(Int64.self, forKey: .output) ?? 0
        cache = try c.decodeIfPresent(Int64.self, forKey: .cache) ?? 0
        requests = try c.decodeIfPresent(Int.self, forKey: .requests) ?? 0
        estimatedOutput = try c.decodeIfPresent(Int64.self, forKey: .estimatedOutput) ?? 0
    }

    mutating func add(input: Int64, output: Int64, cache: Int64, requests: Int, estimated: Bool) {
        self.input += input
        self.output += output
        self.cache += cache
        self.requests += requests
        if estimated { estimatedOutput += output }
    }

    mutating func add(_ other: TokenUsage) {
        input += other.input
        output += other.output
        cache += other.cache
        requests += other.requests
        estimatedOutput += other.estimatedOutput
    }

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        var result = lhs
        result.add(rhs)
        return result
    }
}

struct UsageRow {
    let name: String
    let usage: TokenUsage
    let isEstimated: Bool
    let iconName: String?
}

struct UsagePeriodSnapshot {
    let total: TokenUsage
    let modelRows: [UsageRow]
    let agentRows: [UsageRow]
}

struct UsageSnapshotBundle {
    let periods: [UsagePeriod: UsagePeriodSnapshot]
    let indexedAt: Date?
    let isIndexing: Bool
    let progress: Double
    let fileCount: Int
}

struct UsageFileCheckpoint: Codable {
    var size: UInt64 = 0
    var mtime: Double = 0
    var offset: UInt64 = 0
    var antigravityModel: String?
    var antigravityLastStep: Int?
    var claudeMessageId: String?
    var claudeInput: Int64 = 0
    var claudeOutput: Int64 = 0
    var claudeCache: Int64 = 0
    var codexAgent: String?
    var codexModel: String?
    var codexInput: Int64 = 0
    var codexOutput: Int64 = 0
    var codexCache: Int64 = 0
    var deepseekInput: Int64 = 0
    var deepseekOutput: Int64 = 0
    var deepseekCache: Int64 = 0
    var deepseekSteps: Int64 = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case size, mtime, offset, antigravityModel, antigravityLastStep
        case claudeMessageId, claudeInput, claudeOutput, claudeCache
        case codexAgent, codexModel, codexInput, codexOutput, codexCache
        case deepseekInput, deepseekOutput, deepseekCache, deepseekSteps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decodeIfPresent(UInt64.self, forKey: .size) ?? 0
        mtime = try c.decodeIfPresent(Double.self, forKey: .mtime) ?? 0
        offset = try c.decodeIfPresent(UInt64.self, forKey: .offset) ?? 0
        antigravityModel = try c.decodeIfPresent(String.self, forKey: .antigravityModel)
        antigravityLastStep = try c.decodeIfPresent(Int.self, forKey: .antigravityLastStep)
        claudeMessageId = try c.decodeIfPresent(String.self, forKey: .claudeMessageId)
        claudeInput = try c.decodeIfPresent(Int64.self, forKey: .claudeInput) ?? 0
        claudeOutput = try c.decodeIfPresent(Int64.self, forKey: .claudeOutput) ?? 0
        claudeCache = try c.decodeIfPresent(Int64.self, forKey: .claudeCache) ?? 0
        codexAgent = try c.decodeIfPresent(String.self, forKey: .codexAgent)
        codexModel = try c.decodeIfPresent(String.self, forKey: .codexModel)
        codexInput = try c.decodeIfPresent(Int64.self, forKey: .codexInput) ?? 0
        codexOutput = try c.decodeIfPresent(Int64.self, forKey: .codexOutput) ?? 0
        codexCache = try c.decodeIfPresent(Int64.self, forKey: .codexCache) ?? 0
        deepseekInput = try c.decodeIfPresent(Int64.self, forKey: .deepseekInput) ?? 0
        deepseekOutput = try c.decodeIfPresent(Int64.self, forKey: .deepseekOutput) ?? 0
        deepseekCache = try c.decodeIfPresent(Int64.self, forKey: .deepseekCache) ?? 0
        deepseekSteps = try c.decodeIfPresent(Int64.self, forKey: .deepseekSteps) ?? 0
    }
}

struct UsageStore: Codable {
    var version: Int = 1
    var total = TokenUsage()
    var daily: [String: TokenUsage] = [:]
    var modelTotal: [String: TokenUsage] = [:]
    var modelDaily: [String: [String: TokenUsage]] = [:]
    var agentDaily: [String: [String: TokenUsage]] = [:]
    var files: [String: UsageFileCheckpoint] = [:]
    var indexedAt: Double = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, total, daily, modelTotal, modelDaily, agentDaily, files, indexedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        total = try c.decodeIfPresent(TokenUsage.self, forKey: .total) ?? TokenUsage()
        daily = try c.decodeIfPresent([String: TokenUsage].self, forKey: .daily) ?? [:]
        modelTotal = try c.decodeIfPresent([String: TokenUsage].self, forKey: .modelTotal) ?? [:]
        modelDaily = try c.decodeIfPresent([String: [String: TokenUsage]].self, forKey: .modelDaily) ?? [:]
        agentDaily = try c.decodeIfPresent([String: [String: TokenUsage]].self, forKey: .agentDaily) ?? [:]
        files = try c.decodeIfPresent([String: UsageFileCheckpoint].self, forKey: .files) ?? [:]
        indexedAt = try c.decodeIfPresent(Double.self, forKey: .indexedAt) ?? 0
    }
}

// MARK: - Usage Index

final class UsageIndex {
    static let shared = UsageIndex()

    private struct SourceFile {
        let url: URL
        let path: String
        let agent: String
        let kind: InstanceType
        let size: UInt64
        let mtime: Date
    }

    private struct SourceSpec {
        let root: URL
        let agent: String
        let kind: InstanceType
        let matches: (URL) -> Bool
    }

    private let queue = DispatchQueue(label: "com.glint.momi.usage", qos: .utility)
    private var store = UsageStore()
    private var scanInFlight = false
    private var pendingRescan = false
    private var isIndexing = false
    private var progress: Double = 1
    private var lastSnapshotPost = Date.distantPast
    private var modelLookup: [String: String] = [:]
    private var piNameCache: [String: String] = [:]
    private var timer: DispatchSourceTimer?

    var onUpdate: ((UsageSnapshotBundle) -> Void)?

    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private lazy var storeURL: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("momi", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.json")
    }()

    private init() {}

    func start() {
        queue.async {
            self.loadStore()
            self.postSnapshot(force: true)
            self.scanAll(rebuild: false)
            self.startAutoScan()
        }
    }

    func scanNow() {
        queue.async { self.scanAll(rebuild: false) }
    }

    func rebuild() {
        queue.async { self.scanAll(rebuild: true) }
    }

    private func startAutoScan() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(5))
        t.setEventHandler { [weak self] in self?.scanAll(rebuild: false) }
        t.resume()
        timer = t
    }

    private func loadStore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode(UsageStore.self, from: data),
              decoded.version == 1 else {
            store = UsageStore()
            modelLookup.removeAll()
            return
        }
        store = decoded
        modelLookup.removeAll()
        for key in store.modelTotal.keys {
            modelLookup[key.lowercased()] = key
        }
    }

    private func saveStore() {
        store.indexedAt = Date().timeIntervalSince1970
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func collectSourceFiles() -> [SourceFile] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let specs: [SourceSpec] = [
            SourceSpec(
                root: home.appendingPathComponent(".gemini/antigravity/brain"),
                agent: "antigravity-desktop",
                kind: .antigravity,
                matches: { $0.lastPathComponent == "transcript.jsonl" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".gemini/antigravity-cli/brain"),
                agent: "antigravity-cli",
                kind: .antigravity,
                matches: { $0.lastPathComponent == "transcript.jsonl" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".qoder/projects"),
                agent: "qoder",
                kind: .qoder,
                matches: { $0.pathExtension == "jsonl" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".dsh/storages/session_projcache/sessions"),
                agent: "deepseek",
                kind: .deepseek,
                matches: { $0.pathExtension == "json" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".pi/agent/sessions"),
                agent: "pi",
                kind: .pi,
                matches: { $0.pathExtension == "jsonl" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".claude/projects"),
                agent: "claude",
                kind: .claude,
                matches: { $0.pathExtension == "jsonl" }
            ),
            SourceSpec(
                root: home.appendingPathComponent(".codex/sessions"),
                agent: "codex-cli",
                kind: .codex,
                matches: {
                    $0.pathExtension == "jsonl" && $0.lastPathComponent.hasPrefix("rollout-")
                }
            )
        ]

        var result: [SourceFile] = []
        for spec in specs {
            guard let enumerator = FileManager.default.enumerator(
                at: spec.root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [],
                errorHandler: nil
            ) else { continue }

            for case let url as URL in enumerator {
                guard spec.matches(url),
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize,
                      let mtime = values.contentModificationDate else { continue }
                result.append(SourceFile(
                    url: url,
                    path: url.path,
                    agent: spec.agent,
                    kind: spec.kind,
                    size: UInt64(size),
                    mtime: mtime
                ))
            }
        }
        result.sort { $0.path < $1.path }
        return result
    }

    private func scanAll(rebuild: Bool) {
        if scanInFlight {
            pendingRescan = true
            return
        }
        scanInFlight = true

        var rebuildNeeded = rebuild
        if rebuildNeeded {
            store = UsageStore()
            modelLookup.removeAll()
        }

        let files = collectSourceFiles()
        if !rebuildNeeded {
            for file in files {
                // Projection caches are rewritten wholesale and may legitimately
                // shrink; only append-only transcripts signal a rebuild this way.
                if file.kind == .deepseek { continue }
                if let checkpoint = store.files[file.path], checkpoint.offset > 0, file.size < checkpoint.offset {
                    rebuildNeeded = true
                    break
                }
            }
        }
        if rebuildNeeded {
            store = UsageStore()
            modelLookup.removeAll()
        }

        var pending: [(SourceFile, UInt64)] = []
        for file in files {
            let checkpoint = store.files[file.path]
            if file.kind == .deepseek {
                let changed = checkpoint.map {
                    $0.size != file.size
                        || abs($0.mtime - file.mtime.timeIntervalSince1970) >= 0.001
                } ?? true
                if changed {
                    pending.append((file, file.size))
                }
                continue
            }
            let offset = checkpoint?.offset ?? 0
            if let checkpoint = checkpoint,
               checkpoint.size == file.size,
               abs(checkpoint.mtime - file.mtime.timeIntervalSince1970) < 0.001,
               checkpoint.offset >= file.size {
                continue
            }
            if offset < file.size {
                pending.append((file, file.size - offset))
            }
        }

        let bytesToScan = pending.reduce(UInt64(0)) { $0 + $1.1 }
        if rebuildNeeded || bytesToScan > 1_000_000 {
            isIndexing = true
            progress = 0
            postSnapshot(force: true)
        } else {
            progress = 1
        }

        var processed: UInt64 = 0
        var lastSave = Date()
        var needsRebuild = false

        for (file, fileBytes) in pending {
            if !scanFile(file) {
                needsRebuild = true
                break
            }
            processed += fileBytes
            progress = bytesToScan > 0 ? min(0.99, Double(processed) / Double(bytesToScan)) : 1
            postSnapshot()
            if Date().timeIntervalSince(lastSave) > 2.0 {
                saveStore()
                lastSave = Date()
            }
        }

        if needsRebuild {
            scanInFlight = false
            scanAll(rebuild: true)
            return
        }

        isIndexing = false
        progress = 1
        saveStore()
        postSnapshot(force: true)
        scanInFlight = false

        if pendingRescan {
            pendingRescan = false
            scanAll(rebuild: false)
        }
    }

    /// Returns false when the file shrank after enumeration and a full rebuild is required.
    private func scanFile(_ file: SourceFile) -> Bool {
        var checkpoint = store.files[file.path] ?? UsageFileCheckpoint()
        if file.kind == .deepseek {
            let ok = scanDeepseekProjection(file, checkpoint: &checkpoint)
            store.files[file.path] = checkpoint
            return ok
        }
        guard let handle = try? FileHandle(forReadingFrom: file.url) else { return true }
        defer { try? handle.close() }

        let actualSize = handle.seekToEndOfFile()
        if actualSize < checkpoint.offset {
            return false
        }
        handle.seek(toFileOffset: checkpoint.offset)
        let newData = handle.readDataToEndOfFile()

        guard !newData.isEmpty, let lastNewline = newData.lastIndex(of: 0x0A) else {
            checkpoint.size = actualSize
            checkpoint.mtime = file.mtime.timeIntervalSince1970
            store.files[file.path] = checkpoint
            return true
        }

        let processData = newData.subdata(in: 0..<(lastNewline + 1))
        let text = String(decoding: processData, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        switch file.kind {
        case .antigravity:
            scanAntigravity(lines: lines, file: file, checkpoint: &checkpoint)
        case .qoder:
            scanQoder(lines: lines, file: file, checkpoint: &checkpoint)
        case .deepseek:
            break
        case .pi:
            scanPi(lines: lines, file: file, checkpoint: &checkpoint)
        case .claude:
            scanClaude(lines: lines, file: file, checkpoint: &checkpoint)
        case .codex:
            scanCodex(lines: lines, file: file, checkpoint: &checkpoint)
        }

        checkpoint.offset += UInt64(processData.count)
        checkpoint.size = actualSize
        checkpoint.mtime = file.mtime.timeIntervalSince1970
        store.files[file.path] = checkpoint
        return true
    }

    private func scanDeepseekProjection(_ file: SourceFile, checkpoint: inout UsageFileCheckpoint) -> Bool {
        guard let data = try? Data(contentsOf: file.url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let recordObject = root["record"] as? [String: Any],
              let rows = recordObject["rows"] as? [String: Any] else { return true }

        func row(_ key: String) -> [String: Any]? {
            guard let entry = rows[key] as? [String: Any],
                  let value = entry["val"] as? [String: Any] else { return nil }
            return value
        }

        checkpoint.offset = UInt64(data.count)
        checkpoint.size = UInt64(data.count)
        checkpoint.mtime = file.mtime.timeIntervalSince1970

        guard let usage = row("tokenUsage"),
              let totals = usage["totals"] as? [String: Any] else { return true }

        let input = Int64((totals["uncachedInputTokens"] as? NSNumber)?.int64Value ?? 0)
        let output = Int64((totals["outputTokens"] as? NSNumber)?.int64Value ?? 0)
        let cache = Int64((totals["cacheReadTokens"] as? NSNumber)?.int64Value ?? 0)
            + Int64((totals["cacheWriteTokens"] as? NSNumber)?.int64Value ?? 0)
        let steps = Int64((row("sessionStats")?["steps"] as? NSNumber)?.int64Value ?? 0)

        if input < checkpoint.deepseekInput
            || output < checkpoint.deepseekOutput
            || cache < checkpoint.deepseekCache
            || steps < checkpoint.deepseekSteps {
            checkpoint.deepseekInput = input
            checkpoint.deepseekOutput = output
            checkpoint.deepseekCache = cache
            checkpoint.deepseekSteps = steps
            return true
        }

        let deltaInput = input - checkpoint.deepseekInput
        let deltaOutput = output - checkpoint.deepseekOutput
        let deltaCache = cache - checkpoint.deepseekCache
        let deltaSteps = max(0, steps - checkpoint.deepseekSteps)
        checkpoint.deepseekInput = input
        checkpoint.deepseekOutput = output
        checkpoint.deepseekCache = cache
        checkpoint.deepseekSteps = steps

        guard deltaInput > 0 || deltaOutput > 0 || deltaCache > 0 else { return true }

        var rawModel = "DeepSeek"
        if let selection = row("modelSelection"),
           let lastUsed = selection["lastUsed"] as? [String: Any],
           let model = lastUsed["model"] as? String, !model.isEmpty {
            rawModel = model
        }

        let day: String
        if let ms = (row("sessionListMetadata")?["lastPromptAt"] as? NSNumber)?.doubleValue, ms > 0 {
            day = dayKey(for: Date(timeIntervalSince1970: ms / 1000))
        } else {
            day = dayKey(for: file.mtime)
        }

        record(
            agent: file.agent,
            model: deepseekModelDisplayName(for: rawModel),
            day: day,
            input: deltaInput,
            output: deltaOutput,
            cache: deltaCache,
            requests: Int(deltaSteps),
            estimated: false
        )
        return true
    }

    private func scanAntigravity(lines: [Substring], file: SourceFile, checkpoint: inout UsageFileCheckpoint) {
        for line in lines {
            if !line.contains("\"output_tokens\"") && !line.contains("<USER_SETTINGS_CHANGE>") { continue }
            autoreleasepool {
                guard let data = line.data(using: .utf8),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }

                if (json["source"] as? String) == "USER_EXPLICIT",
                   let content = json["content"] as? String,
                   content.contains("<USER_SETTINGS_CHANGE>"),
                   let model = extractModelName(from: content) {
                    checkpoint.antigravityModel = model
                }

                guard (json["source"] as? String) == "MODEL",
                      (json["type"] as? String) == "PLANNER_RESPONSE" else { return }

                let step = (json["step_index"] as? NSNumber)?.intValue
                if let step = step, let last = checkpoint.antigravityLastStep, step <= last {
                    return
                }

                let input = (json["input_tokens"] as? NSNumber)?.int64Value ?? 0
                let output = (json["output_tokens"] as? NSNumber)?.int64Value ?? 0
                let cache = (json["cache_read_tokens"] as? NSNumber)?.int64Value ?? 0
                if let step = step {
                    checkpoint.antigravityLastStep = step
                }
                guard input > 0 || output > 0 || cache > 0 else { return }

                let model = checkpoint.antigravityModel ?? "Gemini (未标注)"
                let day = dayKey(fromISO: json["created_at"] as? String) ?? dayKey(for: file.mtime)
                record(agent: file.agent, model: model, day: day, input: input, output: output, cache: cache, requests: 1, estimated: false)
            }
        }
    }

    private func scanQoder(lines: [Substring], file: SourceFile, checkpoint: inout UsageFileCheckpoint) {
        var seenRequests = Set<String>()
        for line in lines {
            if !line.contains("\"assistant\"") { continue }
            autoreleasepool {
                guard let data = line.data(using: .utf8),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      (json["type"] as? String) == "assistant",
                      let message = json["message"] as? [String: Any],
                      let messageId = message["id"] as? String else { return }

                let rawModel = (message["model"] as? String) ?? ""
                if rawModel == "<synthetic>" { return }

                var chars = 0
                if let contents = message["content"] as? [[String: Any]] {
                    for content in contents {
                        chars += ((content["text"] as? String) ?? (content["thinking"] as? String) ?? "").count
                    }
                }
                guard chars > 0 else { return }

                let output = Int64(max(1, Int(Double(chars) / 2.2)))
                let day = dayKey(fromISO: json["timestamp"] as? String) ?? dayKey(for: file.mtime)
                let isNewRequest = seenRequests.insert(messageId).inserted
                record(
                    agent: file.agent,
                    model: qoderModelDisplayName(for: rawModel),
                    day: day,
                    input: 0,
                    output: output,
                    cache: 0,
                    requests: isNewRequest ? 1 : 0,
                    estimated: true
                )
            }
        }
    }

    private func scanPi(lines: [Substring], file: SourceFile, checkpoint: inout UsageFileCheckpoint) {
        for line in lines {
            if !line.contains("\"usage\"") { continue }
            autoreleasepool {
                guard let data = line.data(using: .utf8),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      (json["type"] as? String) == "message",
                      let message = json["message"] as? [String: Any],
                      (message["role"] as? String) == "assistant",
                      let usage = message["usage"] as? [String: Any] else { return }

                let input = (usage["input"] as? NSNumber)?.int64Value ?? 0
                let output = (usage["output"] as? NSNumber)?.int64Value ?? 0
                let cache = ((usage["cacheRead"] as? NSNumber)?.int64Value ?? 0)
                    + ((usage["cacheWrite"] as? NSNumber)?.int64Value ?? 0)
                guard input > 0 || output > 0 || cache > 0 else { return }

                let rawModel = (message["model"] as? String) ?? ""
                let day = dayKey(fromISO: json["timestamp"] as? String) ?? dayKey(for: file.mtime)
                record(
                    agent: file.agent,
                    model: piDisplayName(rawModel),
                    day: day,
                    input: input,
                    output: output,
                    cache: cache,
                    requests: 1,
                    estimated: false
                )
            }
        }
    }

    private func scanClaude(lines: [Substring], file: SourceFile, checkpoint: inout UsageFileCheckpoint) {
        for line in lines {
            if !line.contains("\"usage\"") { continue }
            autoreleasepool {
                guard let data = line.data(using: .utf8),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      (json["type"] as? String) == "assistant",
                      (json["isSidechain"] as? Bool) != true,
                      let message = json["message"] as? [String: Any],
                      let messageId = message["id"] as? String, !messageId.isEmpty,
                      let usage = message["usage"] as? [String: Any] else { return }

                let rawModel = (message["model"] as? String) ?? ""
                if rawModel == "<synthetic>" { return }

                let input = (usage["input_tokens"] as? NSNumber)?.int64Value ?? 0
                let output = (usage["output_tokens"] as? NSNumber)?.int64Value ?? 0
                let cache = ((usage["cache_read_input_tokens"] as? NSNumber)?.int64Value ?? 0)
                    + ((usage["cache_creation_input_tokens"] as? NSNumber)?.int64Value ?? 0)
                let day = dayKey(fromISO: json["timestamp"] as? String) ?? dayKey(for: file.mtime)
                let model = claudeModelDisplayName(for: rawModel)

                if messageId == checkpoint.claudeMessageId {
                    let deltaInput = max(0, input - checkpoint.claudeInput)
                    let deltaOutput = max(0, output - checkpoint.claudeOutput)
                    let deltaCache = max(0, cache - checkpoint.claudeCache)
                    checkpoint.claudeInput = max(checkpoint.claudeInput, input)
                    checkpoint.claudeOutput = max(checkpoint.claudeOutput, output)
                    checkpoint.claudeCache = max(checkpoint.claudeCache, cache)
                    if deltaInput > 0 || deltaOutput > 0 || deltaCache > 0 {
                        record(agent: file.agent, model: model, day: day, input: deltaInput, output: deltaOutput, cache: deltaCache, requests: 0, estimated: false)
                    }
                } else {
                    checkpoint.claudeMessageId = messageId
                    checkpoint.claudeInput = input
                    checkpoint.claudeOutput = output
                    checkpoint.claudeCache = cache
                    guard input > 0 || output > 0 || cache > 0 else { return }
                    record(agent: file.agent, model: model, day: day, input: input, output: output, cache: cache, requests: 1, estimated: false)
                }
            }
        }
    }

    private func scanCodex(lines: [Substring], file: SourceFile, checkpoint: inout UsageFileCheckpoint) {
        for line in lines {
            if !line.contains("\"token_count\"")
                && !line.contains("\"session_meta\"")
                && !line.contains("\"turn_context\"")
                && !line.contains("\"thread_settings_applied\"") { continue }
            autoreleasepool {
                guard let data = line.data(using: .utf8),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let payload = json["payload"] as? [String: Any] else { return }

                let type = (json["type"] as? String) ?? ""
                if type == "session_meta" {
                    checkpoint.codexAgent = codexFlavor(forOriginator: payload["originator"] as? String).agentKey
                    checkpoint.codexModel = nil
                    checkpoint.codexInput = 0
                    checkpoint.codexOutput = 0
                    checkpoint.codexCache = 0
                    return
                }

                if type == "turn_context" {
                    if let model = payload["model"] as? String, !model.isEmpty {
                        checkpoint.codexModel = model
                    }
                    return
                }

                guard type == "event_msg" else { return }
                let event = (payload["type"] as? String) ?? ""

                if event == "thread_settings_applied" {
                    if let settings = payload["thread_settings"] as? [String: Any],
                       let model = settings["model"] as? String, !model.isEmpty {
                        checkpoint.codexModel = model
                    }
                    return
                }

                guard event == "token_count",
                      let info = payload["info"] as? [String: Any],
                      let totals = info["total_token_usage"] as? [String: Any] else { return }

                let input = (totals["input_tokens"] as? NSNumber)?.int64Value ?? 0
                let output = (totals["output_tokens"] as? NSNumber)?.int64Value ?? 0
                let cache = ((totals["cached_input_tokens"] as? NSNumber)?.int64Value ?? 0)
                    + ((totals["cache_write_input_tokens"] as? NSNumber)?.int64Value ?? 0)

                if input < checkpoint.codexInput || output < checkpoint.codexOutput || cache < checkpoint.codexCache {
                    checkpoint.codexInput = input
                    checkpoint.codexOutput = output
                    checkpoint.codexCache = cache
                    return
                }

                let deltaInput = input - checkpoint.codexInput
                let deltaOutput = output - checkpoint.codexOutput
                let deltaCache = cache - checkpoint.codexCache
                checkpoint.codexInput = input
                checkpoint.codexOutput = output
                checkpoint.codexCache = cache

                // Codex's input_tokens already include cached tokens; keep the
                // cache column separate from the fresh-input total.
                let freshInput = max(0, deltaInput - deltaCache)
                guard freshInput > 0 || deltaOutput > 0 || deltaCache > 0 else { return }

                let day = dayKey(fromISO: json["timestamp"] as? String) ?? dayKey(for: file.mtime)
                let model = codexModelDisplayName(for: checkpoint.codexModel ?? "Codex")
                record(
                    agent: checkpoint.codexAgent ?? CodexFlavor.cli.agentKey,
                    model: model,
                    day: day,
                    input: freshInput,
                    output: deltaOutput,
                    cache: deltaCache,
                    requests: 1,
                    estimated: false
                )
            }
        }
    }

    private func record(agent: String, model rawModel: String, day: String, input: Int64, output: Int64, cache: Int64, requests: Int, estimated: Bool) {
        let model = canonicalModel(rawModel)
        var usage = TokenUsage()
        usage.add(input: input, output: output, cache: cache, requests: requests, estimated: estimated)

        store.total.add(usage)
        store.daily[day, default: TokenUsage()].add(usage)

        store.modelTotal[model, default: TokenUsage()].add(usage)
        var modelDays = store.modelDaily[model] ?? [:]
        modelDays[day, default: TokenUsage()].add(usage)
        store.modelDaily[model] = modelDays

        var agentDays = store.agentDaily[agent] ?? [:]
        agentDays[day, default: TokenUsage()].add(usage)
        store.agentDaily[agent] = agentDays
    }

    private func canonicalModel(_ rawModel: String) -> String {
        let cleaned = sanitizeModelName(rawModel)
        let name = cleaned.isEmpty ? "未知模型" : cleaned
        let key = name.lowercased()
        if let existing = modelLookup[key] { return existing }
        modelLookup[key] = name
        return name
    }

    private func piDisplayName(_ rawModel: String) -> String {
        if let cached = piNameCache[rawModel] { return cached }
        let name = piModelDisplayName(for: rawModel)
        piNameCache[rawModel] = name
        return name
    }

    private func dayKey(fromISO raw: String?) -> String? {
        guard let raw = raw else { return nil }
        guard let date = isoFractional.date(from: raw) ?? isoPlain.date(from: raw) else { return nil }
        return dayFormatter.string(from: date)
    }

    private func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func makeSnapshot() -> UsageSnapshotBundle {
        let now = Date()
        let calendar = Calendar.current
        let todayKey = dayFormatter.string(from: now)
        let weekKeys = Set((0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.map { dayFormatter.string(from: $0) })

        func sum(_ days: [String: TokenUsage], period: UsagePeriod) -> TokenUsage {
            switch period {
            case .all:
                var bucket = TokenUsage()
                for value in days.values { bucket.add(value) }
                return bucket
            case .today:
                return days[todayKey] ?? TokenUsage()
            case .week:
                var bucket = TokenUsage()
                for (key, value) in days where weekKeys.contains(key) { bucket.add(value) }
                return bucket
            }
        }

        var periods: [UsagePeriod: UsagePeriodSnapshot] = [:]
        for period in UsagePeriod.allCases {
            let total = period == .all ? store.total : sum(store.daily, period: period)

            var modelRows: [UsageRow] = []
            for (name, days) in store.modelDaily {
                let usage = sum(days, period: period)
                guard usage.input > 0 || usage.output > 0 || usage.cache > 0 else { continue }
                modelRows.append(UsageRow(name: name, usage: usage, isEstimated: usage.estimatedOutput > 0, iconName: nil))
            }
            modelRows.sort { lhs, rhs in
                if lhs.usage.total != rhs.usage.total { return lhs.usage.total > rhs.usage.total }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            var agentRows: [UsageRow] = []
            for key in usageAgentOrder {
                guard let days = store.agentDaily[key] else { continue }
                let usage = sum(days, period: period)
                guard usage.input > 0 || usage.output > 0 || usage.cache > 0 else { continue }
                agentRows.append(UsageRow(
                    name: agentDisplayName(for: key),
                    usage: usage,
                    isEstimated: usage.estimatedOutput > 0,
                    iconName: agentIconName(for: key)
                ))
            }

            periods[period] = UsagePeriodSnapshot(total: total, modelRows: modelRows, agentRows: agentRows)
        }

        return UsageSnapshotBundle(
            periods: periods,
            indexedAt: store.indexedAt > 0 ? Date(timeIntervalSince1970: store.indexedAt) : nil,
            isIndexing: isIndexing,
            progress: progress,
            fileCount: store.files.count
        )
    }

    private func postSnapshot(force: Bool = false) {
        let now = Date()
        if !force && now.timeIntervalSince(lastSnapshotPost) < 0.4 { return }
        lastSnapshotPost = now
        let bundle = makeSnapshot()
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(bundle)
        }
    }
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
        
        modelLabel.font = .systemFont(ofSize: 11, weight: .medium)
        modelLabel.textColor = .labelColor
        modelLabel.lineBreakMode = .byTruncatingTail
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelLabel)
        
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        speedLabel.textColor = .secondaryLabelColor
        speedLabel.alignment = .right
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedLabel)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            modelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            modelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            modelLabel.trailingAnchor.constraint(lessThanOrEqualTo: speedLabel.leadingAnchor, constant: -10),
            
            speedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            speedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            speedLabel.widthAnchor.constraint(equalToConstant: 72),
        ])
    }
    
    func update(instance: MonitoredInstance, icon: NSImage?) {
        iconView.image = icon
        iconView.toolTip = instance.name
        modelLabel.stringValue = instance.modelName
        modelLabel.toolTip = instance.modelName
        
        let speed = clampSpeed(instance.currentSpeed)
        if instance.isGenerating {
            if speed > 0 {
                speedLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
                speedLabel.stringValue = String(format: "%.1f t/s", speed)
            } else {
                speedLabel.font = .systemFont(ofSize: 11, weight: .medium)
                speedLabel.stringValue = "运行中"
            }
            speedLabel.textColor = .systemOrange
        } else {
            speedLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
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

    private let totalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 206))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        
        for label in [headerAgent, headerModel, headerSpeed] {
            label.font = .systemFont(ofSize: 9.5, weight: .semibold)
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
        
        totalCaption.font = .systemFont(ofSize: 10, weight: .regular)
        totalCaption.textColor = .tertiaryLabelColor
        totalCaption.toolTip = "输入 + 输出，不含缓存读取"
        totalCaption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(totalCaption)
        
        totalValue.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        totalValue.textColor = .labelColor
        totalValue.alignment = .right
        totalValue.translatesAutoresizingMaskIntoConstraints = false
        addSubview(totalValue)
        
        NSLayoutConstraint.activate([
            headerAgent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerAgent.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerAgent.heightAnchor.constraint(equalToConstant: 14),
            
            headerModel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            headerModel.centerYAnchor.constraint(equalTo: headerAgent.centerYAnchor),
            
            headerSpeed.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            headerSpeed.centerYAnchor.constraint(equalTo: headerAgent.centerYAnchor),
            headerSpeed.widthAnchor.constraint(equalToConstant: 72),
            
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: headerAgent.bottomAnchor, constant: 2),
            
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            separator.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 4),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            totalCaption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            totalCaption.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 5),
            totalCaption.heightAnchor.constraint(equalToConstant: 16),
            totalCaption.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),
            
            totalValue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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
        
        setFrameSize(NSSize(width: 280, height: 56 + CGFloat(instances.count) * 30))
    }
    
    func update(with instances: [MonitoredInstance]) {
        configure(with: instances)
        
        for (row, instance) in zip(rowViews, instances) {
            row.update(instance: instance, icon: icon(for: instance))
        }
    }

    func updateTotal(_ total: Int64, indexing: Bool) {
        if total > 0 {
            totalValue.stringValue = totalFormatter.string(from: NSNumber(value: total)) ?? "\(total)"
            totalValue.textColor = .labelColor
            totalValue.toolTip = indexing ? "输入 + 输出，正在更新索引…" : "输入 + 输出，不含缓存读取"
        } else {
            totalValue.stringValue = indexing ? "索引中…" : "--"
            totalValue.textColor = indexing ? .tertiaryLabelColor : .labelColor
            totalValue.toolTip = nil
        }
    }
    
    private func icon(for instance: MonitoredInstance) -> NSImage? {
        let name: String
        switch instance.type {
        case .qoder:
            name = "agent_qoder"
        case .deepseek:
            name = "agent_deepseek"
        case .pi:
            name = "agent_pi"
        case .claude:
            name = "agent_claude"
        case .codex:
            name = instance.codexFlavor == .desktop ? "agent_codex" : "agent_codex_cli"
        case .antigravity:
            name = instance.shortTag == "CLI" ? "agent_antigravity_cli" : "agent_antigravity"
        }
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        return image
    }
}

// MARK: - Usage Stats Window

// MARK: - Usage Stats Window

private struct UsageColumnLayout {
    static let rowHeight: CGFloat = 30
    static let headerHeight: CGFloat = 26

    let name: NSRect
    let input: NSRect
    let output: NSRect
    let total: NSRect
    let cache: NSRect
    let share: NSRect

    static func make(width: CGFloat, height: CGFloat) -> UsageColumnLayout {
        let gap: CGFloat = 12
        let nameGap: CGFloat = 18
        var x = width

        func take(_ width: CGFloat) -> NSRect {
            x -= width
            let rect = NSRect(x: x, y: 0, width: width, height: height)
            x -= gap
            return rect
        }

        let share = take(60)
        let cache = take(96)
        let total = take(90)
        let output = take(76)
        let input = take(82)
        let name = NSRect(x: 0, y: 0, width: max(0, input.minX - nameGap), height: height)
        return UsageColumnLayout(name: name, input: input, output: output, total: total, cache: cache, share: share)
    }
}

private func usageFontHeight(_ font: NSFont) -> CGFloat {
    ceil(font.ascender - font.descender)
}

private func drawUsageString(_ string: String, in rect: NSRect, alignment: NSTextAlignment, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let height = usageFontHeight(font)
    (string as NSString).draw(
        in: NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height + 1),
        withAttributes: attributes
    )
}

private func drawUsageAttributedString(_ string: NSAttributedString, in rect: NSRect, alignment: NSTextAlignment, font: NSFont) {
    let mutable = NSMutableAttributedString(attributedString: string)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
    let height = usageFontHeight(font)
    mutable.draw(in: NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height + 1))
}

private final class UsageHairlineView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let scale = max(1, window?.backingScaleFactor ?? 2)
        NSColor.separatorColor.withAlphaComponent(0.5).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1 / scale).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private final class UsageStatsHeaderView: NSView {
    var groupByAgent = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let layout = UsageColumnLayout.make(width: bounds.width, height: bounds.height)
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        let color = NSColor.tertiaryLabelColor

        drawUsageString(groupByAgent ? "Agent" : "模型", in: layout.name, alignment: .left, font: font, color: color)
        drawUsageString("输入", in: layout.input, alignment: .right, font: font, color: color)
        drawUsageString("输出", in: layout.output, alignment: .right, font: font, color: color)
        drawUsageString("合计", in: layout.total, alignment: .right, font: font, color: color)
        drawUsageString("缓存", in: layout.cache, alignment: .right, font: font, color: color)
        drawUsageString("占比", in: layout.share, alignment: .right, font: font, color: color)

        let scale = max(1, window?.backingScaleFactor ?? 2)
        NSColor.separatorColor.withAlphaComponent(0.55).setFill()
        NSRect(x: 0, y: bounds.height - 1 / scale, width: bounds.width, height: 1 / scale).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private final class UsageStatsRowsView: NSView, NSViewToolTipOwner {
    var rows: [UsageRow] = [] {
        didSet {
            refreshToolTips()
            needsDisplay = true
        }
    }

    var groupByAgent = false {
        didSet { needsDisplay = true }
    }

    var periodTotal: Int64 = 0 {
        didSet { needsDisplay = true }
    }

    var emptyText = "" {
        didSet { needsDisplay = true }
    }

    private var tintedIcons: [String: NSImage] = [:]
    private var hoveredRow: Int?
    private var trackingArea: NSTrackingArea?

    private let intFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard !rows.isEmpty else {
            drawUsageString(
                emptyText.isEmpty ? "暂无用量记录" : emptyText,
                in: NSRect(x: 0, y: 48, width: bounds.width, height: 20),
                alignment: .center,
                font: .systemFont(ofSize: 11.5, weight: .regular),
                color: .tertiaryLabelColor
            )
            return
        }

        let layout = UsageColumnLayout.make(width: bounds.width, height: UsageColumnLayout.rowHeight)
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        let totalFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let shareFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        let nameFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let scale = max(1, window?.backingScaleFactor ?? 2)

        for (index, item) in rows.enumerated() {
            let rowRect = NSRect(
                x: 0,
                y: CGFloat(index) * UsageColumnLayout.rowHeight,
                width: bounds.width,
                height: UsageColumnLayout.rowHeight
            )

            if hoveredRow == index {
                let highlight = NSBezierPath(
                    roundedRect: rowRect.insetBy(dx: 0, dy: 3),
                    xRadius: 6,
                    yRadius: 6
                )
                NSColor.labelColor.withAlphaComponent(0.045).setFill()
                highlight.fill()
            }

            var nameX = layout.name.minX
            if let iconName = item.iconName, let icon = tintedIcon(named: iconName) {
                icon.draw(
                    in: NSRect(x: nameX, y: rowRect.midY - 8, width: 16, height: 16),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
                nameX += 24
            }

            let nameRect = NSRect(
                x: nameX,
                y: rowRect.minY,
                width: max(0, layout.name.maxX - nameX),
                height: rowRect.height
            )
            let name = NSMutableAttributedString(
                string: item.name,
                attributes: [
                    .font: nameFont,
                    .foregroundColor: NSColor.labelColor
                ]
            )
            if item.isEstimated {
                name.append(NSAttributedString(
                    string: groupByAgent ? "  估算" : "  含估算",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 9.5, weight: .medium),
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                ))
            }
            drawUsageAttributedString(name, in: nameRect, alignment: .left, font: nameFont)

            func numberRect(_ rect: NSRect) -> NSRect {
                NSRect(x: rect.minX, y: rowRect.minY, width: rect.width, height: rowRect.height)
            }

            drawUsageString(
                format(item.usage.input),
                in: numberRect(layout.input),
                alignment: .right,
                font: numberFont,
                color: .secondaryLabelColor
            )
            drawUsageString(
                format(item.usage.output),
                in: numberRect(layout.output),
                alignment: .right,
                font: numberFont,
                color: .secondaryLabelColor
            )
            drawUsageString(
                format(item.usage.total),
                in: numberRect(layout.total),
                alignment: .right,
                font: totalFont,
                color: .labelColor
            )
            drawUsageString(
                format(item.usage.cache),
                in: numberRect(layout.cache),
                alignment: .right,
                font: numberFont,
                color: .secondaryLabelColor
            )

            let share: String
            if periodTotal > 0 {
                let percent = Double(item.usage.total) / Double(periodTotal) * 100
                if percent > 0 && percent < 0.1 {
                    share = "<0.1%"
                } else {
                    share = String(format: "%.1f%%", percent)
                }
            } else {
                share = "—"
            }
            drawUsageString(
                share,
                in: numberRect(layout.share),
                alignment: .right,
                font: shareFont,
                color: .secondaryLabelColor
            )

            if index < rows.count - 1 {
                NSColor.separatorColor.withAlphaComponent(0.3).setFill()
                NSRect(
                    x: 0,
                    y: rowRect.maxY - 1 / scale,
                    width: bounds.width,
                    height: 1 / scale
                ).fill()
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = Int(point.y / UsageColumnLayout.rowHeight)
        let next = rows.indices.contains(index) ? index : nil
        if next != hoveredRow {
            hoveredRow = next
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredRow != nil {
            hoveredRow = nil
            needsDisplay = true
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshToolTips()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        tintedIcons.removeAll()
        needsDisplay = true
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        let layout = UsageColumnLayout.make(width: bounds.width, height: UsageColumnLayout.rowHeight)
        let index = Int(point.y / UsageColumnLayout.rowHeight)
        guard rows.indices.contains(index) else { return "" }
        let item = rows[index]

        if layout.cache.contains(point) {
            return "缓存读取单独统计，不计入合计"
        }
        if layout.total.contains(point) {
            return "合计 = 输入 + 输出"
        }
        if layout.share.contains(point) {
            return "占当前筛选总量的比例"
        }
        if layout.name.contains(point), item.isEstimated {
            return "该行包含 Qoder 字符估算输出：Qoder 日志没有真实 token 字段，输出按字符数估算，输入未计入。"
        }
        return item.name
    }

    private func refreshToolTips() {
        removeAllToolTips()
        guard !rows.isEmpty, bounds.width > 0, bounds.height > 0 else { return }
        addToolTip(bounds, owner: self, userData: nil)
    }

    private func tintedIcon(named name: String) -> NSImage? {
        if let cached = tintedIcons[name] { return cached }
        guard let base = NSImage(named: name) else { return nil }
        base.isTemplate = true
        let size = NSSize(width: 16, height: 16)
        let tinted = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.secondaryLabelColor.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        tintedIcons[name] = tinted
        return tinted
    }

    private func format(_ value: Int64) -> String {
        intFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private final class UsageTabsView: NSView {
    var items: [String] = [] {
        didSet { needsDisplay = true }
    }

    var selectedIndex = 0 {
        didSet { needsDisplay = true }
    }

    var fontSize: CGFloat = 11.5 {
        didSet { needsDisplay = true }
    }

    var spacing: CGFloat = 20 {
        didSet { needsDisplay = true }
    }

    var showsUnderline = true {
        didSet { needsDisplay = true }
    }

    var onSelect: ((Int) -> Void)?

    private var hoveredIndex: Int?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let frames = tabFrames()
        for (index, item) in items.enumerated() where frames.indices.contains(index) {
            let frame = frames[index]
            let selected = index == selectedIndex
            let font = NSFont.systemFont(
                ofSize: fontSize,
                weight: selected ? .semibold : .regular
            )
            let color: NSColor
            if selected {
                color = .labelColor
            } else if hoveredIndex == index {
                color = .secondaryLabelColor
            } else {
                color = .tertiaryLabelColor
            }
            drawUsageString(item, in: frame, alignment: .center, font: font, color: color)

            if selected && showsUnderline {
                NSColor.labelColor.setFill()
                let underline = NSRect(
                    x: frame.minX + 1,
                    y: frame.maxY - 2.5,
                    width: max(0, frame.width - 2),
                    height: 1.5
                )
                NSBezierPath(roundedRect: underline, xRadius: 0.75, yRadius: 0.75).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, frame) in tabFrames().enumerated() where frame.contains(point) {
            guard index != selectedIndex else { return }
            selectedIndex = index
            onSelect?(index)
            return
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        var next: Int?
        for (index, frame) in tabFrames().enumerated() where frame.contains(point) {
            next = index
            break
        }
        if next != hoveredIndex {
            hoveredIndex = next
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredIndex != nil {
            hoveredIndex = nil
            needsDisplay = true
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for frame in tabFrames() {
            addCursorRect(frame, cursor: .pointingHand)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private func tabFrames() -> [NSRect] {
        guard !items.isEmpty else { return [] }
        let measureFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let widths = items.map { item -> CGFloat in
            ceil((item as NSString).size(withAttributes: [.font: measureFont]).width) + 4
        }
        let totalWidth = widths.reduce(0, +) + spacing * CGFloat(max(0, items.count - 1))
        var x = max(0, bounds.width - totalWidth)
        return widths.map { width in
            let frame = NSRect(x: x, y: 0, width: width, height: bounds.height)
            x += width + spacing
            return frame
        }
    }
}

private final class UsageScrollView: NSScrollView {
    var contentHeight: CGFloat = 0
    var onViewportWidthChange: ((CGFloat) -> Void)?

    private var lastViewportWidth: CGFloat = 0

    override func layout() {
        super.layout()
        guard let documentView = documentView else { return }
        let viewport = contentView.bounds.size
        let height = max(contentHeight, viewport.height)
        if abs(documentView.frame.width - viewport.width) > 0.5
            || abs(documentView.frame.height - height) > 0.5 {
            documentView.frame = NSRect(x: 0, y: 0, width: viewport.width, height: height)
        }
        if abs(viewport.width - lastViewportWidth) > 0.5 {
            lastViewportWidth = viewport.width
            onViewportWidthChange?(viewport.width)
        }
    }
}

final class UsageStatsWindowController: NSWindowController {
    private var bundle: UsageSnapshotBundle?
    private var period: UsagePeriod = .all
    private var groupByAgent = false
    private var rows: [UsageRow] = []
    private var headerWidthConstraint: NSLayoutConstraint?

    private let captionLabel = NSTextField(labelWithString: "累计用量 · 输入 + 输出")
    private let totalLabel = NSTextField(labelWithString: "—")
    private let breakdownLabel = NSTextField(labelWithString: "")
    private let periodTabs = UsageTabsView()
    private let groupTabs = UsageTabsView()
    private let headerView = UsageStatsHeaderView()
    private let rowsView = UsageStatsRowsView()
    private let scrollView = UsageScrollView()
    private let headerSeparator = UsageHairlineView()
    private let footerSeparator = UsageHairlineView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let rebuildButton = NSButton()
    private let refreshButton = NSButton()

    private let intFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var onRefreshIntervalChange: ((Double) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "用量统计"
        window.minSize = NSSize(width: 700, height: 360)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        captionLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        captionLabel.textColor = .tertiaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(captionLabel)

        totalLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        totalLabel.textColor = .labelColor
        totalLabel.toolTip = "输入 + 输出，不含缓存读取"
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(totalLabel)

        breakdownLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        breakdownLabel.textColor = .secondaryLabelColor
        breakdownLabel.lineBreakMode = .byTruncatingTail
        breakdownLabel.maximumNumberOfLines = 1
        breakdownLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        breakdownLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(breakdownLabel)

        periodTabs.items = ["全部", "近 7 天", "今天"]
        periodTabs.selectedIndex = UsagePeriod.all.rawValue
        periodTabs.fontSize = 11.5
        periodTabs.spacing = 20
        periodTabs.showsUnderline = true
        periodTabs.onSelect = { [weak self] index in
            guard let self = self, let next = UsagePeriod(rawValue: index) else { return }
            self.period = next
            self.updateDisplay()
            self.scrollToTop()
            self.fitWindowHeightToRows()
        }
        periodTabs.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(periodTabs)

        groupTabs.items = ["模型", "Agent"]
        groupTabs.selectedIndex = 0
        groupTabs.fontSize = 10.5
        groupTabs.spacing = 16
        groupTabs.showsUnderline = false
        groupTabs.onSelect = { [weak self] index in
            guard let self = self else { return }
            self.groupByAgent = index == 1
            self.updateDisplay()
            self.scrollToTop()
            self.fitWindowHeightToRows()
        }
        groupTabs.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(groupTabs)

        headerView.groupByAgent = groupByAgent
        headerView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(headerView)
        headerWidthConstraint = headerView.widthAnchor.constraint(equalToConstant: 640)

        rowsView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = rowsView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentHeight = 160
        scrollView.onViewportWidthChange = { [weak self] width in
            guard let self = self, let constraint = self.headerWidthConstraint else { return }
            if abs(constraint.constant - width) > 0.5 {
                constraint.constant = width
            }
        }
        content.addSubview(scrollView)

        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(headerSeparator)

        footerSeparator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footerSeparator)

        statusLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        rebuildButton.isBordered = false
        rebuildButton.focusRingType = .none
        rebuildButton.target = self
        rebuildButton.action = #selector(rebuildAction)
        rebuildButton.attributedTitle = NSAttributedString(
            string: "重建索引",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        rebuildButton.setContentHuggingPriority(.required, for: .horizontal)
        rebuildButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(rebuildButton)

        refreshButton.isBordered = false
        refreshButton.focusRingType = .none
        refreshButton.imagePosition = .imageTrailing
        refreshButton.imageHugsTitle = true
        refreshButton.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold))
        refreshButton.contentTintColor = .tertiaryLabelColor
        refreshButton.toolTip = "刷新间隔"
        refreshButton.target = self
        refreshButton.action = #selector(showRefreshMenu)
        refreshButton.setContentHuggingPriority(.required, for: .horizontal)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(refreshButton)
        updateRefreshButtonTitle()

        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            captionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),

            totalLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 1),
            totalLabel.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),

            breakdownLabel.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 4),
            breakdownLabel.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),
            breakdownLabel.trailingAnchor.constraint(lessThanOrEqualTo: groupTabs.leadingAnchor, constant: -20),

            periodTabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            periodTabs.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            periodTabs.widthAnchor.constraint(equalToConstant: 240),
            periodTabs.heightAnchor.constraint(equalToConstant: 22),

            groupTabs.topAnchor.constraint(equalTo: periodTabs.bottomAnchor, constant: 2),
            groupTabs.trailingAnchor.constraint(equalTo: periodTabs.trailingAnchor),
            groupTabs.widthAnchor.constraint(equalToConstant: 240),
            groupTabs.heightAnchor.constraint(equalToConstant: 18),

            headerSeparator.topAnchor.constraint(equalTo: breakdownLabel.bottomAnchor, constant: 16),
            headerSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            headerSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1),

            headerView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            headerView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            headerView.heightAnchor.constraint(equalToConstant: UsageColumnLayout.headerHeight),
            headerWidthConstraint!,

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor, constant: -2),

            footerSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            footerSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            footerSeparator.heightAnchor.constraint(equalToConstant: 1),
            footerSeparator.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),

            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            statusLabel.centerYAnchor.constraint(equalTo: footerSeparator.bottomAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: rebuildButton.leadingAnchor, constant: -16),

            rebuildButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            rebuildButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -20),

            refreshButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24)
        ])

        updateDisplay()
    }

    func apply(_ bundle: UsageSnapshotBundle) {
        self.bundle = bundle
        updateDisplay()
        if !bundle.isIndexing {
            fitWindowHeightToRows()
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        fitWindowHeightToRows()
    }

    private func fitWindowHeightToRows() {
        guard let window = window, window.isVisible, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let rowsHeight = rows.isEmpty
            ? 160
            : CGFloat(rows.count) * UsageColumnLayout.rowHeight + 6
        let topInset = content.bounds.height - scrollView.frame.maxY
        let desiredContent = topInset + max(rowsHeight, 160) + 43
        let clamped = min(max(desiredContent, 360), 660)
        guard abs(content.bounds.height - clamped) > 1 else { return }

        var frame = window.frame
        let top = frame.maxY
        frame.size.height = window.frameRect(
            forContentRect: NSRect(x: 0, y: 0, width: frame.width, height: clamped)
        ).height
        frame.origin.y = top - frame.size.height
        if let screen = window.screen {
            frame = window.constrainFrameRect(frame, to: screen)
        }
        window.setFrame(frame, display: true)
    }

    private var periodName: String {
        switch period {
        case .all: return "全部历史"
        case .week: return "近 7 天"
        case .today: return "今天"
        }
    }

    private var periodCaption: String {
        switch period {
        case .all: return "累计用量"
        case .week: return "近 7 天用量"
        case .today: return "今日用量"
        }
    }

    private var refreshInterval: Double {
        let stored = UserDefaults.standard.double(forKey: refreshIntervalDefaultsKey)
        return stored >= 1 ? min(stored, 60) : 1.5
    }

    private func updateDisplay() {
        periodTabs.selectedIndex = period.rawValue
        groupTabs.selectedIndex = groupByAgent ? 1 : 0
        headerView.groupByAgent = groupByAgent
        captionLabel.stringValue = "\(periodCaption) · 输入 + 输出"

        guard let bundle = bundle else {
            totalLabel.stringValue = "—"
            breakdownLabel.stringValue = ""
            rows = []
            rowsView.rows = []
            rowsView.emptyText = "正在载入用量数据…"
            scrollView.contentHeight = 160
            scrollView.needsLayout = true
            statusLabel.stringValue = ""
            return
        }

        let snapshot = bundle.periods[period]
        let total = snapshot?.total ?? TokenUsage()
        if total.total == 0 && bundle.isIndexing {
            totalLabel.stringValue = "—"
        } else {
            totalLabel.stringValue = format(total.total)
        }
        breakdownLabel.attributedStringValue = breakdownText(for: total)

        rows = snapshot.map { groupByAgent ? $0.agentRows : $0.modelRows } ?? []
        rowsView.groupByAgent = groupByAgent
        rowsView.periodTotal = total.total
        rowsView.emptyText = bundle.isIndexing
            ? "正在读取历史日志…"
            : (bundle.indexedAt == nil ? "尚未建立索引" : "当前筛选下没有用量记录")
        rowsView.rows = rows

        let rowHeight = CGFloat(rows.count) * UsageColumnLayout.rowHeight + 6
        scrollView.contentHeight = max(rowHeight, 160)
        scrollView.needsLayout = true

        var parts: [String] = []
        if bundle.isIndexing {
            let percent = Int((bundle.progress * 100).rounded())
            parts.append("正在建立历史索引 \(percent)%")
            parts.append(periodName)
            if bundle.fileCount > 0 {
                parts.append("\(bundle.fileCount) 个日志")
            }
        } else if let indexedAt = bundle.indexedAt {
            parts.append(periodName)
            parts.append("\(rows.count) 个\(groupByAgent ? "Agent" : "模型")")
            parts.append("\(bundle.fileCount) 个日志")
            parts.append("更新于 \(timeFormatter.string(from: indexedAt))")
        } else {
            parts.append(periodName)
            parts.append("尚未建立索引")
        }
        if rows.contains(where: { $0.isEstimated }) {
            parts.append("含 Qoder 估算")
        }
        statusLabel.stringValue = parts.joined(separator: " · ")
    }

    private func breakdownText(for total: TokenUsage) -> NSAttributedString {
        let labelFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let labelColor = NSColor.tertiaryLabelColor
        let valueColor = NSColor.secondaryLabelColor

        let result = NSMutableAttributedString()
        let items: [(String, Int64)] = [
            ("输入", total.input),
            ("输出", total.output),
            ("缓存", total.cache)
        ]
        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(
                    string: "    ",
                    attributes: [.font: labelFont, .foregroundColor: labelColor]
                ))
            }
            result.append(NSAttributedString(
                string: item.0 + " ",
                attributes: [.font: labelFont, .foregroundColor: labelColor]
            ))
            result.append(NSAttributedString(
                string: format(item.1),
                attributes: [.font: valueFont, .foregroundColor: valueColor]
            ))
        }
        return result
    }

    private func format(_ value: Int64) -> String {
        intFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func scrollToTop() {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func updateRefreshButtonTitle() {
        let interval = refreshInterval
        let title = interval == floor(interval)
            ? String(format: "%.0fs", interval)
            : String(format: "%.1fs", interval)
        refreshButton.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    @objc private func showRefreshMenu() {
        let menu = NSMenu()
        for interval in [1.5, 3.0, 5.0, 10.0] {
            let title = interval == floor(interval)
                ? String(format: "%.0f 秒", interval)
                : String(format: "%.1f 秒", interval)
            let item = NSMenuItem(title: title, action: #selector(selectRefreshInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = abs(refreshInterval - interval) < 0.01 ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: refreshButton.bounds.maxY + 4),
            in: refreshButton
        )
    }

    @objc private func selectRefreshInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(interval, forKey: refreshIntervalDefaultsKey)
        updateRefreshButtonTitle()
        onRefreshIntervalChange?(interval)
    }

    @objc private func rebuildAction() {
        let alert = NSAlert()
        alert.messageText = "重建用量索引？"
        alert.informativeText = "将重新扫描全部 Agent 的历史会话日志。首次全量扫描可能需要几秒到几十秒。"
        alert.addButton(withTitle: "重建")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            UsageIndex.shared.rebuild()
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var updateTimer: Timer?
    
    var instances: [MonitoredInstance] = []
    var isChecking: Bool = false
    private var instancesGeneration = 0
    private var codexOriginatorCache: [String: String] = [:]
    private var codexLatestCache: [CodexFlavor: (url: URL, modDate: Date)] = [:]
    private var codexDiscoveryAt = Date.distantPast
    
    // Persistent menu and dashboard view
    let mainMenu = NSMenu()
    let dashboardView = MomiDashboardView()
    let dashboardMenuItem = NSMenuItem()
    var statsWindowController: UsageStatsWindowController?
    var latestUsageBundle: UsageSnapshotBundle?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Versioned slot: a poisoned autosave position parks the item off-screen.
        statusItem.autosaveName = "momi.speedo.v2"
        statusItem.button?.image = nil
        statusItem.button?.title = "--"
        
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
            ),
            MonitoredInstance(
                name: "DeepSeek Harness",
                shortTag: "DeepSeek",
                type: .deepseek,
                baseDir: home.appendingPathComponent(".dsh/storages/session_projcache/sessions"),
                modelName: "DeepSeek Harness"
            ),
            MonitoredInstance(
                name: "Pi",
                shortTag: "Pi",
                type: .pi,
                baseDir: home.appendingPathComponent(".pi/agent/sessions"),
                modelName: "Pi"
            ),
            MonitoredInstance(
                name: "Claude Code",
                shortTag: "Claude",
                type: .claude,
                baseDir: home.appendingPathComponent(".claude/projects"),
                modelName: "Claude"
            ),
            MonitoredInstance(
                name: "Codex App",
                shortTag: "App",
                type: .codex,
                baseDir: home.appendingPathComponent(".codex/sessions"),
                codexFlavor: .desktop
            ),
            MonitoredInstance(
                name: "Codex CLI",
                shortTag: "CLI",
                type: .codex,
                baseDir: home.appendingPathComponent(".codex/sessions"),
                codexFlavor: .cli
            )
        ]
        
        setupMenu()
        triggerBackgroundUpdate()

        UsageIndex.shared.onUpdate = { [weak self] bundle in
            self?.applyUsageBundle(bundle)
        }
        UsageIndex.shared.start()
        scheduleUpdateTimer()
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
        let statsItem = NSMenuItem(title: "用量统计…", action: #selector(showStatsAction), keyEquivalent: "t")
        statsItem.target = self
        mainMenu.addItem(statsItem)
        
        let refreshItem = NSMenuItem(title: "刷新数据", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        mainMenu.addItem(refreshItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 momi", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        mainMenu.addItem(quitItem)
        
        statusItem.menu = mainMenu
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        updateDashboardState()
        UsageIndex.shared.scanNow()
    }

    func applyUsageBundle(_ bundle: UsageSnapshotBundle) {
        latestUsageBundle = bundle
        let total = bundle.periods[.all]?.total.total ?? 0
        dashboardView.updateTotal(total, indexing: bundle.isIndexing)
        statsWindowController?.apply(bundle)
    }

    func scheduleUpdateTimer() {
        updateTimer?.invalidate()
        let interval = currentRefreshInterval()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerBackgroundUpdate()
        }
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    func currentRefreshInterval() -> TimeInterval {
        let value = UserDefaults.standard.double(forKey: refreshIntervalDefaultsKey)
        return value >= 1 ? min(value, 60) : 1.5
    }
    
    func fastFindLatestTranscript(for instance: MonitoredInstance) -> (url: URL, modDate: Date)? {
        switch instance.type {
        case .antigravity:
            return fastFindLatestAntigravityTranscript(in: instance.baseDir)
        case .qoder:
            return fastFindLatestQoderTranscript(in: instance.baseDir)
        case .deepseek:
            return fastFindLatestDeepseekSession(in: instance.baseDir)
        case .pi:
            return fastFindLatestPiTranscript(in: instance.baseDir)
        case .claude:
            return fastFindLatestClaudeTranscript(in: instance.baseDir)
        case .codex:
            return fastFindLatestCodexTranscript(in: instance.baseDir, flavor: instance.codexFlavor)
        }
    }
    
    func fastFindLatestAntigravityTranscript(in brainDir: URL) -> (url: URL, modDate: Date)? {
        guard let sessionDirs = try? FileManager.default.contentsOfDirectory(
            at: brainDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        // Session directory mtimes only reflect creation; a resumed conversation
        // appends to an old directory. Rank the transcripts themselves instead.
        for dir in sessionDirs {
            let transcript = dir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if let attrs = try? transcript.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = attrs.contentModificationDate,
               date > latestDate {
                latestDate = date
                latestFile = transcript
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
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        // Project directory mtimes only change when a new session file appears,
        // so an active old conversation would be missed by a prefix heuristic.
        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }
            
            for f in files where f.pathExtension == "jsonl" {
                if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]),
                   let date = attrs.contentModificationDate,
                   date > latestDate {
                    latestDate = date
                    latestFile = f
                }
            }
        }
        
        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
    }
    
    func fastFindLatestPiTranscript(in sessionsDir: URL) -> (url: URL, modDate: Date)? {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }
            
            for f in files where f.pathExtension == "jsonl" {
                if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]),
                   let date = attrs.contentModificationDate,
                   date > latestDate {
                    latestDate = date
                    latestFile = f
                }
            }
        }
        
        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
    }
    
    func fastFindLatestClaudeTranscript(in projectsDir: URL) -> (url: URL, modDate: Date)? {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }
        
        var latestFile: URL?
        var latestDate: Date = .distantPast
        
        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }
            
            for f in files where f.pathExtension == "jsonl" {
                if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]),
                   let date = attrs.contentModificationDate,
                   date > latestDate {
                    latestDate = date
                    latestFile = f
                }
            }
        }
        
        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
    }
    
    func fastFindLatestDeepseekSession(in cacheDir: URL) -> (url: URL, modDate: Date)? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        var latestFile: URL?
        var latestDate: Date = .distantPast
        for f in files where f.pathExtension == "json" {
            if let attrs = try? f.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = attrs.contentModificationDate,
               date > latestDate {
                latestDate = date
                latestFile = f
            }
        }

        if let url = latestFile {
            return (url, latestDate)
        }
        return nil
    }

    func fastFindLatestCodexTranscript(in sessionsDir: URL, flavor wanted: CodexFlavor) -> (url: URL, modDate: Date)? {
        let now = Date()
        if now.timeIntervalSince(codexDiscoveryAt) > 5 || codexLatestCache.isEmpty {
            codexDiscoveryAt = now
            codexLatestCache.removeAll()

            var candidates: [(url: URL, modDate: Date)] = []
            if let enumerator = FileManager.default.enumerator(
                at: sessionsDir,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) {
                for case let url as URL in enumerator {
                    guard url.pathExtension == "jsonl",
                          url.lastPathComponent.hasPrefix("rollout-"),
                          let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                          values.isRegularFile == true,
                          let modDate = values.contentModificationDate else { continue }
                    candidates.append((url, modDate))
                }
            }

            candidates.sort { $0.modDate > $1.modDate }
            for candidate in candidates {
                let originator = codexSessionOriginator(for: candidate.url)
                let flavor = codexFlavor(forOriginator: originator)
                if codexLatestCache[flavor] == nil {
                    codexLatestCache[flavor] = (candidate.url, candidate.modDate)
                }
                if codexLatestCache.count == 2 { break }
            }
        }

        guard let latest = codexLatestCache[wanted] else { return nil }
        return (latest.url, latest.modDate)
    }

    private func codexSessionOriginator(for url: URL) -> String? {
        if let cached = codexOriginatorCache[url.path] { return cached.isEmpty ? nil : cached }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 65536)) ?? Data()
        let text = String(decoding: data, as: UTF8.self)

        var originator: String?
        if let regex = try? NSRegularExpression(pattern: "\"originator\"\\s*:\\s*\"([^\"]+)\""),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            originator = String(text[range])
        }
        codexOriginatorCache[url.path] = originator ?? ""
        return originator
    }

    func readTail(url: URL, maxBytes: UInt64 = 65536) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
    
    func updateSessionTokens(url: URL, modDate: Date, instance: inout MonitoredInstance) {
        switch instance.type {
        case .antigravity:
            updateAntigravitySessionTokens(url: url, instance: &instance)
        case .qoder:
            updateQoderSessionTokens(url: url, instance: &instance)
        case .deepseek:
            updateDeepseekSessionTokens(url: url, fileModDate: modDate, instance: &instance)
        case .pi:
            updatePiSessionTokens(url: url, instance: &instance)
        case .claude:
            updateClaudeSessionTokens(url: url, instance: &instance)
        case .codex:
            updateCodexSessionTokens(url: url, instance: &instance)
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
            instance.qoderTurnStartedAt = nil
            instance.qoderTurnTokens = 0
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
        
        let str = String(decoding: processData, as: UTF8.self)
        guard !str.isEmpty else { return }
        let lines = str.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ value: Any?) -> Date? {
            guard let s = value as? String else { return nil }
            return fractionalFormatter.date(from: s) ?? plainFormatter.date(from: s)
        }

        var generatingState: Bool?
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            
            let type = (json["type"] as? String) ?? ""
            if type == "user" {
                // Tool results are not new user turns; resetting the window here
                // makes a big thinking block look like a thousands-t/s burst.
                let content = (json["message"] as? [String: Any])?["content"] as? [[String: Any]]
                let isToolResult = content?.contains { ($0["type"] as? String) == "tool_result" } ?? false
                if !isToolResult {
                    instance.qoderTurnStartedAt = parseDate(json["timestamp"])
                    instance.qoderTurnTokens = 0
                }
                generatingState = true
            }
            
            if type == "runtime-config", let m = json["model"] as? String, !m.isEmpty {
                instance.modelName = qoderModelDisplayName(for: m)
            }
            
            if type == "assistant" {
                let msg = json["message"] as? [String: Any]
                if let m = msg?["model"] as? String, !m.isEmpty, m != "<synthetic>" {
                    instance.modelName = qoderModelDisplayName(for: m)
                }
                
                // Only a completed final answer ends the run; tool calls and
                // thinking blocks are followed by more work.
                generatingState = (msg?["stop_reason"] as? String) != "end_turn"
                
                var chars = 0
                if let contents = msg?["content"] as? [[String: Any]] {
                    for c in contents {
                        let text = (c["text"] as? String) ?? (c["thinking"] as? String) ?? ""
                        chars += text.count
                    }
                }
                let tokens = max(1, Int(Double(chars) / 2.2))
                instance.totalSessionTokens += tokens
                instance.qoderTurnTokens += tokens

                if let started = instance.qoderTurnStartedAt,
                   let ended = parseDate(json["timestamp"]),
                   instance.qoderTurnTokens > 30 {
                    let duration = max(0.5, ended.timeIntervalSince(started))
                    instance.currentSpeed = clampSpeed(Double(instance.qoderTurnTokens) / duration)
                }
            }
        }
        
        if let generating = generatingState {
            instance.isGenerating = generating
        }
    }
    
    /// The raw dsh transcript is zstd-compressed; its plain projection cache carries open-turn state, totals and decode timing.
    func updateDeepseekSessionTokens(url: URL, fileModDate: Date, instance: inout MonitoredInstance) {
        guard let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let record = root["record"] as? [String: Any],
              let rows = record["rows"] as? [String: Any] else { return }

        func row(_ key: String) -> [String: Any]? {
            guard let entry = rows[key] as? [String: Any],
                  let value = entry["val"] as? [String: Any] else { return nil }
            return value
        }

        if let selection = row("modelSelection"),
           let lastUsed = selection["lastUsed"] as? [String: Any],
           let model = lastUsed["model"] as? String, !model.isEmpty {
            instance.modelName = deepseekModelDisplayName(for: model)
        }

        var running = false
        var stats: [String: Any]?
        var realActivity: Date?
        if let sessionStats = row("sessionStats") {
            stats = sessionStats
            if let openStep = sessionStats["openStep"] as? [String: Any] {
                running = true
                if let ms = (openStep["startTime"] as? NSNumber)?.doubleValue, ms > 0 {
                    realActivity = Date(timeIntervalSince1970: ms / 1000)
                }
            }
        }
        if let boundary = row("turnBoundary"),
           (boundary["openTurnStartSeq"] as? NSNumber) != nil {
            // Tools run between steps; the turn stays open until turn/end.
            running = true
        }
        if let ms = (row("timeContext")?["lastMessageTime"] as? NSNumber)?.doubleValue, ms > 0 {
            let messageTime = Date(timeIntervalSince1970: ms / 1000)
            realActivity = max(realActivity ?? .distantPast, messageTime)
        }
        instance.deepseekLastActivity = realActivity ?? fileModDate
        instance.isGenerating = running

        guard let usage = row("tokenUsage"),
              let totals = usage["totals"] as? [String: Any],
              let output = (totals["outputTokens"] as? NSNumber)?.intValue else { return }
        instance.totalSessionTokens = output

        let decodeTokens = (stats?["decodeTokens"] as? NSNumber)?.doubleValue ?? 0
        let decodeMs = (stats?["decodeMs"] as? NSNumber)?.doubleValue ?? 0
        if running, decodeTokens > 0, decodeMs > 0 {
            // The projection cache can publish tokens and decode time a moment
            // apart; differencing them produces impossible bursts. The harness's
            // cumulative decode rate is stable and authoritative.
            instance.currentSpeed = clampSpeed(decodeTokens / (decodeMs / 1000))
        }
    }

    /// Incrementally scans new bytes from Pi's session JSONL
    func updatePiSessionTokens(url: URL, instance: inout MonitoredInstance) {
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
        
        let str = String(decoding: processData, as: UTF8.self)
        guard !str.isEmpty else { return }
        let lines = str.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        var lastRole: String?
        var lastStopReason: String?
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            
            let type = (json["type"] as? String) ?? ""
            if type == "model_change" {
                if let modelId = json["modelId"] as? String, !modelId.isEmpty {
                    instance.modelName = piModelDisplayName(for: modelId)
                }
                continue
            }
            
            guard type == "message",
                  let msg = json["message"] as? [String: Any] else { continue }
            
            let role = (msg["role"] as? String) ?? ""
            if role == "user" || role == "assistant" || role == "toolResult" {
                lastRole = role
                lastStopReason = (msg["stopReason"] as? String) ?? (json["stopReason"] as? String)
            }
            
            guard role == "assistant" else { continue }
            
            if let model = msg["model"] as? String, !model.isEmpty {
                instance.modelName = piModelDisplayName(for: model)
            }
            
            let output = (msg["usage"] as? [String: Any]).flatMap { ($0["output"] as? NSNumber)?.intValue } ?? 0
            let durationMs = (msg["durationMs"] as? NSNumber)?.doubleValue ?? 0
            instance.totalSessionTokens += output
            if output > 0 && durationMs >= 50 {
                instance.currentSpeed = clampSpeed(Double(output) / (durationMs / 1000.0))
            }
        }
        
        // Pi appends an assistant message with stopReason == "toolUse" when it invokes
        // tools; during tool execution the agent is still actively working.
        if let lastRole = lastRole {
            if lastRole == "user" || lastRole == "toolResult" {
                instance.isGenerating = true
            } else if lastRole == "assistant" {
                instance.isGenerating = (lastStopReason == "toolUse")
            } else {
                instance.isGenerating = false
            }
        }
    }
    
    /// Incrementally scans new bytes from Claude Code's session JSONL
    func updateClaudeSessionTokens(url: URL, instance: inout MonitoredInstance) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()
        
        if fileSize < instance.lastTrackedFileSize {
            instance.totalSessionTokens = 0
            instance.lastTrackedFileSize = 0
            instance.isGenerating = false
            instance.currentSpeed = 0
            instance.claudeMessageLedger.removeAll()
            instance.claudeRequestStartedAt = nil
            instance.claudeToolInFlight = false
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
        
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        
        func parseDate(_ value: Any?) -> Date? {
            guard let s = value as? String else { return nil }
            return fractionalFormatter.date(from: s) ?? plainFormatter.date(from: s)
        }
        
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            
            // Subagent traffic is stored in the same transcript; keep it out of the main session stats.
            if (json["isSidechain"] as? Bool) == true { continue }
            
            let type = (json["type"] as? String) ?? ""
            if type == "user" {
                if (json["isMeta"] as? Bool) == true { continue }
                if let content = (json["message"] as? [String: Any])?["content"] as? String,
                   content.hasPrefix("<command-") || content.hasPrefix("<local-command-") {
                    continue
                }
                instance.claudeToolInFlight = false
                instance.claudeRequestStartedAt = parseDate(json["timestamp"]) ?? instance.claudeRequestStartedAt
                instance.isGenerating = true
            } else if type == "assistant" {
                let msg = json["message"] as? [String: Any]
                if let model = msg?["model"] as? String, !model.isEmpty, model != "<synthetic>" {
                    instance.modelName = claudeModelDisplayName(for: model)
                }
                
                if let messageId = msg?["id"] as? String, !messageId.isEmpty,
                   let usage = msg?["usage"] as? [String: Any],
                   let output = (usage["output_tokens"] as? NSNumber)?.intValue,
                   output > 0 {
                    // Claude Code repeats the cumulative usage on every content-block
                    // line of one message, so only the delta may be counted.
                    let seen = instance.claudeMessageLedger[messageId] ?? 0
                    if output > seen {
                        let delta = output - seen
                        instance.claudeMessageLedger[messageId] = output
                        instance.totalSessionTokens += delta
                        if let started = instance.claudeRequestStartedAt,
                           let ended = parseDate(json["timestamp"]) {
                            let duration = max(0.5, ended.timeIntervalSince(started))
                            instance.currentSpeed = clampSpeed(Double(delta) / duration)
                        }
                    }
                }
                // A tool_use block is written before the tool actually runs;
                // treating every assistant line as the end marks long tools idle.
                let stopReason = msg?["stop_reason"] as? String
                instance.claudeToolInFlight = (stopReason == "tool_use")
                instance.isGenerating = instance.claudeToolInFlight
            }
        }
    }
    
    /// Incrementally scans new bytes from a Codex rollout JSONL.
    func updateCodexSessionTokens(url: URL, instance: inout MonitoredInstance) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let fileSize = handle.seekToEndOfFile()

        if fileSize < instance.lastTrackedFileSize {
            instance.totalSessionTokens = 0
            instance.lastTrackedFileSize = 0
            instance.isGenerating = false
            instance.currentSpeed = 0
            instance.codexTaskStartedAt = nil
            instance.codexLastTokenAt = nil
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

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ value: Any?) -> Date? {
            guard let s = value as? String else { return nil }
            return fractionalFormatter.date(from: s) ?? plainFormatter.date(from: s)
        }

        for line in lines {
            guard let d = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let payload = json["payload"] as? [String: Any] else { continue }

            let type = (json["type"] as? String) ?? ""
            if type == "turn_context" {
                if let model = payload["model"] as? String, !model.isEmpty {
                    instance.modelName = codexModelDisplayName(for: model)
                }
                continue
            }

            guard type == "event_msg" else { continue }
            let event = (payload["type"] as? String) ?? ""

            if event == "thread_settings_applied" {
                if let settings = payload["thread_settings"] as? [String: Any],
                   let model = settings["model"] as? String, !model.isEmpty {
                    instance.modelName = codexModelDisplayName(for: model)
                }
                continue
            }

            if event == "task_started" {
                instance.isGenerating = true
                instance.codexTaskStartedAt = parseDate(json["timestamp"])
                instance.codexLastTokenAt = nil
                continue
            }

            if event == "task_complete" || event == "turn_aborted" {
                instance.isGenerating = false
                instance.codexTaskStartedAt = nil
                continue
            }

            guard event == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let totals = info["total_token_usage"] as? [String: Any] else { continue }

            let output = Int((totals["output_tokens"] as? NSNumber)?.int64Value ?? 0)
            let previousTotal = instance.totalSessionTokens
            if output >= previousTotal {
                instance.totalSessionTokens = output
            } else {
                instance.totalSessionTokens = output
                instance.codexLastTokenAt = nil
            }

            if let ended = parseDate(json["timestamp"]) {
                let delta = max(0, output - previousTotal)
                let started = instance.codexLastTokenAt ?? instance.codexTaskStartedAt
                if delta > 0, let started = started {
                    let duration = ended.timeIntervalSince(started)
                    if duration >= 0.3 {
                        instance.currentSpeed = Double(delta) / duration
                    }
                }
                instance.codexLastTokenAt = ended
            }
        }
    }

    func parseLatestSpeed(url: URL, fileModDate: Date, type: InstanceType) -> (speed: Double, inFlight: Bool?) {
        switch type {
        case .antigravity:
            return parseAntigravityTail(url: url, fileModDate: fileModDate)
        case .qoder, .pi, .claude, .codex, .deepseek:
            return (0.0, nil) // speed is computed while incrementally scanning events
        }
    }
    
    func parseAntigravityTail(url: URL, fileModDate: Date) -> (speed: Double, inFlight: Bool) {
        guard let content = readTail(url: url) else { return (0.0, false) }
        
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
        
        let lastStep = steps.last
        let lastType = (lastStep?["type"] as? String) ?? ""
        let lastStatus = (lastStep?["status"] as? String) ?? ""
        let inFlight = lastStatus == "RUNNING"
            || lastType == "GENERIC"
            || lastType == "USER_INPUT"
        return (clampSpeed(latestSpeed), inFlight)
    }

    func triggerBackgroundUpdate() {
        if isChecking { return }
        isChecking = true

        // Keep array access on the main thread; the scan owns a value snapshot.
        let snapshot = instances
        let generation = instancesGeneration
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            var updatedInstances = snapshot
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
                        updatedInstances[i].antigravityStepInFlight = false
                        updatedInstances[i].claudeMessageLedger.removeAll()
                        updatedInstances[i].claudeRequestStartedAt = nil
                        updatedInstances[i].claudeToolInFlight = false
                        updatedInstances[i].codexTaskStartedAt = nil
                        updatedInstances[i].codexLastTokenAt = nil
                        updatedInstances[i].qoderTurnStartedAt = nil
                        updatedInstances[i].qoderTurnTokens = 0
                        updatedInstances[i].deepseekLastActivity = nil
                        if updatedInstances[i].type == .qoder {
                            updatedInstances[i].modelName = "Qoder"
                        } else if updatedInstances[i].type == .pi {
                            updatedInstances[i].modelName = "Pi"
                        } else if updatedInstances[i].type == .claude {
                            updatedInstances[i].modelName = "Claude"
                        } else if updatedInstances[i].type == .codex {
                            updatedInstances[i].modelName = "Codex"
                        } else if updatedInstances[i].type == .deepseek {
                            updatedInstances[i].modelName = "DeepSeek Harness"
                        }
                        hasChanges = true
                    }
                    
                    updatedInstances[i].latestModDate = latest.modDate
                    
                    if latest.modDate != updatedInstances[i].lastParsedModDate {
                        updatedInstances[i].lastParsedModDate = latest.modDate
                        
                        // 1. Incrementally calculate session tokens and track model
                        self.updateSessionTokens(url: latest.url, modDate: latest.modDate, instance: &updatedInstances[i])
                        
                        // 2. Parse latest speed
                        let probe = self.parseLatestSpeed(url: latest.url, fileModDate: latest.modDate, type: updatedInstances[i].type)
                        if probe.speed > 0 {
                            updatedInstances[i].currentSpeed = clampSpeed(probe.speed)
                        }
                        if let inFlight = probe.inFlight {
                            updatedInstances[i].antigravityStepInFlight = inFlight
                        }
                        hasChanges = true
                    }
                    
                    // Antigravity writes a step when it starts or finishes, so a
                    // trailing GENERIC/USER_INPUT step means the request is still
                    // in flight even while the transcript stays untouched.
                    if updatedInstances[i].type == .antigravity {
                        let fresh = now.timeIntervalSince(latest.modDate) < 2.5
                        let stale = now.timeIntervalSince(latest.modDate) > 900
                        let generating = !stale && (updatedInstances[i].antigravityStepInFlight || fresh)
                        if generating != updatedInstances[i].isGenerating {
                            updatedInstances[i].isGenerating = generating
                            hasChanges = true
                        }
                    }
                    
                    // Claude Code only appends when a content block completes, so a
                    // long-silent transcript means the request was abandoned. A
                    // pending tool may legitimately run much longer than a model turn.
                    let claudeSilence = updatedInstances[i].claudeToolInFlight ? 1800.0 : 600.0
                    if updatedInstances[i].type == .claude,
                       updatedInstances[i].isGenerating,
                       now.timeIntervalSince(latest.modDate) > claudeSilence {
                        updatedInstances[i].isGenerating = false
                        hasChanges = true
                    }
                    
                    // Same safety net for runs stopped mid-tool; otherwise a
                    // trailing tool_use event would keep the row "运行中".
                    // Projection caches can be rewritten by the UI, so DeepSeek
                    // staleness is measured from its last real event instead.
                    let silentSince = updatedInstances[i].type == .deepseek
                        ? (updatedInstances[i].deepseekLastActivity ?? latest.modDate)
                        : latest.modDate
                    if (updatedInstances[i].type == .qoder || updatedInstances[i].type == .pi || updatedInstances[i].type == .codex || updatedInstances[i].type == .deepseek),
                       updatedInstances[i].isGenerating,
                       now.timeIntervalSince(silentSince) > 900 {
                        updatedInstances[i].isGenerating = false
                        hasChanges = true
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isChecking = false
                guard generation == self.instancesGeneration else {
                    // refreshAction reset the state while this scan was running;
                    // drop the stale copy and rescan from the reset snapshot.
                    self.triggerBackgroundUpdate()
                    return
                }
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
            let displaySpeed = generating.map { clampSpeed($0.currentSpeed) }.max() ?? 0.0
            statusItem.button?.title = displaySpeed > 0
                ? String(format: "%.1f t/s", displaySpeed)
                : "生成中"
        } else if let gen = generating.first {
            let speed = clampSpeed(gen.currentSpeed)
            statusItem.button?.title = speed > 0
                ? String(format: "%.1f t/s", speed)
                : "生成中"
        } else {
            statusItem.button?.title = "--"
        }
        
        let sortedInstances = visibleInstances
            .enumerated()
            .sorted { lhs, rhs in
                let l = lhs.element, r = rhs.element
                if l.isGenerating != r.isGenerating { return l.isGenerating }
                let lSpeed = clampSpeed(l.currentSpeed)
                let rSpeed = clampSpeed(r.currentSpeed)
                if l.isGenerating && lSpeed != rSpeed {
                    return lSpeed > rSpeed
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
        
        dashboardView.update(with: sortedInstances)
    }
    
    @objc func showStatsAction() {
        if statsWindowController == nil {
            let controller = UsageStatsWindowController()
            controller.onRefreshIntervalChange = { [weak self] interval in
                UserDefaults.standard.set(interval, forKey: refreshIntervalDefaultsKey)
                self?.scheduleUpdateTimer()
            }
            statsWindowController = controller
        }
        if let bundle = latestUsageBundle {
            statsWindowController?.apply(bundle)
        }
        UsageIndex.shared.scanNow()
        statsWindowController?.showWindow(nil)
        statsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func refreshAction() {
        instancesGeneration += 1
        for i in 0..<instances.count {
            instances[i].lastParsedModDate = .distantPast
            instances[i].totalSessionTokens = 0
            instances[i].lastTrackedFileSize = 0
            instances[i].antigravityStepInFlight = false
            instances[i].claudeMessageLedger.removeAll()
            instances[i].claudeRequestStartedAt = nil
            instances[i].claudeToolInFlight = false
            instances[i].codexTaskStartedAt = nil
            instances[i].codexLastTokenAt = nil
            instances[i].qoderTurnStartedAt = nil
            instances[i].qoderTurnTokens = 0
            instances[i].deepseekLastActivity = nil
        }
        triggerBackgroundUpdate()
        UsageIndex.shared.scanNow()
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
