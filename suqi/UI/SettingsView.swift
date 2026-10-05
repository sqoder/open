//
//  SettingsView.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import GhosttyTheme

public struct SettingsView: View {
    @State private var themeName: String
    @State private var backgroundOpacity: Double
    @State private var backgroundBlur: Double
    @State private var fontFamily: String
    @State private var fontSize: Double
    @State private var adjustCellHeight: Int
    @State private var windowPaddingX: Int
    @State private var windowPaddingY: Int
    @State private var cursorStyle: String
    @State private var cursorBlink: Bool
    @State private var restoreLastWorkingDirectory: Bool
    @State private var isAccessibilityTrusted: Bool = QuickTerminalController.isAccessibilityTrusted

    @State private var showingThemePicker: Bool = false
    @State private var themeSearchQuery: String = ""

    private static let popularThemes = [
        "Catppuccin Mocha",
        "Catppuccin Macchiato",
        "Catppuccin Frappe",
        "Catppuccin Latte",
        "TokyoNight",
        "TokyoNight Storm",
        "Dracula",
        "Nord",
        "One Dark",
        "Solarized Dark",
        "Solarized Light",
        "Gruvbox Dark",
        "GitHub Dark",
        "Monokai Pro"
    ]

    private static func loadSystemMonospacedFonts() -> [String] {
        let fm = NSFontManager.shared
        var families = Set<String>()
        for family in fm.availableFontFamilies {
            let name = family.lowercased()
            if let font = fm.font(withFamily: family, traits: .unboldFontMask, weight: 5, size: 12),
               font.isFixedPitch || name.contains("mono") || name.contains("code") || name.contains("nf") || name.contains("nerd") || name.contains("courier") || name.contains("menlo") || name.contains("monaco") {
                families.insert(family)
            }
        }
        var sorted = Array(families).sorted()
        let priority = ["Maple Mono NF", "SF Mono", "JetBrains Mono", "Fira Code", "Menlo", "Monaco", "Courier New"]
        for p in priority.reversed() {
            if let idx = sorted.firstIndex(of: p) {
                sorted.remove(at: idx)
                sorted.insert(p, at: 0)
            } else if fm.availableFontFamilies.contains(p) {
                sorted.insert(p, at: 0)
            }
        }
        return sorted.isEmpty ? priority : sorted
    }

    public init() {
        let (cfg, _) = GhosttyUserConfig.load()
        _themeName = State(initialValue: cfg.themeName)
        _backgroundOpacity = State(initialValue: cfg.backgroundOpacity)
        _backgroundBlur = State(initialValue: Double(cfg.backgroundBlur))
        _fontFamily = State(initialValue: cfg.fontFamily)
        _fontSize = State(initialValue: cfg.fontSize)
        _adjustCellHeight = State(initialValue: cfg.adjustCellHeight)
        _windowPaddingX = State(initialValue: cfg.windowPaddingX)
        _windowPaddingY = State(initialValue: cfg.windowPaddingY)
        _cursorStyle = State(initialValue: cfg.cursorStyle)
        _cursorBlink = State(initialValue: cfg.cursorBlink)
        _restoreLastWorkingDirectory = State(initialValue: cfg.restoreLastWorkingDirectory)
    }

    private var allThemes: [String] {
        var list = Self.popularThemes
        if !list.contains(themeName) {
            list.insert(themeName, at: 0)
        }
        return list
    }

    private var allFonts: [String] {
        var list = Self.loadSystemMonospacedFonts()
        if !list.contains(fontFamily) {
            list.insert(fontFamily, at: 0)
        }
        return list
    }

    public var body: some View {
        Form {
            Section("Appearance & Theme") {
                HStack {
                    Picker("Theme", selection: $themeName) {
                        ForEach(allThemes, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onChange(of: themeName) { _, newTheme in
                        GhosttyUserConfig.saveValues(["theme": newTheme])
                        SuqiWindowManager.shared.reloadAllWindows()
                    }

                    Button("Browse 300+...") {
                        showingThemePicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .sheet(isPresented: $showingThemePicker) {
                    ThemeSearchSheet(
                        isPresented: $showingThemePicker,
                        selectedTheme: $themeName,
                        onSelect: { newTheme in
                            GhosttyUserConfig.saveValues(["theme": newTheme])
                            SuqiWindowManager.shared.reloadAllWindows()
                        }
                    )
                }

                Slider(value: $backgroundOpacity, in: 0.4...1.0, step: 0.02) {
                    Text("Background Opacity")
                } minimumValueLabel: {
                    Text("40%")
                } maximumValueLabel: {
                    Text("100%")
                }
                .onChange(of: backgroundOpacity) { _, newOpacity in
                    GhosttyUserConfig.saveValues(["background-opacity": String(format: "%.2f", newOpacity)])
                    SuqiWindowManager.shared.updateAllThemeBackgrounds()
                }

                Slider(value: $backgroundBlur, in: 0...50, step: 2) {
                    Text("Background Blur")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("50")
                }
                .onChange(of: backgroundBlur) { _, newBlur in
                    GhosttyUserConfig.saveValues(["background-blur": "\(Int(newBlur))"])
                    SuqiWindowManager.shared.updateAllThemeBackgrounds()
                }
            }

            Section("Font & Typography") {
                Picker("Font Family", selection: $fontFamily) {
                    ForEach(allFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .onChange(of: fontFamily) { _, newFont in
                    GhosttyUserConfig.saveValues(["font-family": newFont])
                    SuqiWindowManager.shared.reloadAllWindows()
                }

                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(fontSize)) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Stepper("", value: $fontSize, in: 9...28, step: 1)
                        .onChange(of: fontSize) { _, newSize in
                            GhosttyUserConfig.saveValues(["font-size": String(Int(newSize))])
                            SuqiWindowManager.shared.reloadAllWindows()
                        }
                }

                HStack {
                    Text("Adjust Cell Height")
                    Spacer()
                    Text("\(adjustCellHeight) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Stepper("", value: $adjustCellHeight, in: -4...12, step: 1)
                        .onChange(of: adjustCellHeight) { _, newAdj in
                            GhosttyUserConfig.saveValues(["adjust-cell-height": "\(newAdj)"])
                            SuqiWindowManager.shared.reloadAllWindows()
                        }
                }
            }

            Section("Window & Spacing") {
                HStack {
                    Text("Padding X")
                    Spacer()
                    Text("\(windowPaddingX) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Stepper("", value: $windowPaddingX, in: 0...36, step: 2)
                        .onChange(of: windowPaddingX) { _, newPad in
                            GhosttyUserConfig.saveValues(["window-padding-x": "\(newPad)"])
                            SuqiWindowManager.shared.reloadAllWindows()
                        }
                }

                HStack {
                    Text("Padding Y")
                    Spacer()
                    Text("\(windowPaddingY) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Stepper("", value: $windowPaddingY, in: 0...36, step: 2)
                        .onChange(of: windowPaddingY) { _, newPad in
                            GhosttyUserConfig.saveValues(["window-padding-y": "\(newPad)"])
                            SuqiWindowManager.shared.reloadAllWindows()
                        }
                }
            }

            Section("Cursor") {
                Picker("Cursor Style", selection: $cursorStyle) {
                    Text("Bar").tag("bar")
                    Text("Block").tag("block")
                    Text("Underline").tag("underline")
                }
                .onChange(of: cursorStyle) { _, newStyle in
                    GhosttyUserConfig.saveValues(["cursor-style": newStyle])
                    SuqiWindowManager.shared.reloadAllWindows()
                }

                Toggle("Cursor Blink", isOn: $cursorBlink)
                    .onChange(of: cursorBlink) { _, newBlink in
                        GhosttyUserConfig.saveValues(["cursor-style-blink": newBlink ? "true" : "false"])
                        SuqiWindowManager.shared.reloadAllWindows()
                    }
            }

            Section("Startup & Working Directory") {
                Toggle("Restore Last Working Directory", isOn: $restoreLastWorkingDirectory)
                    .onChange(of: restoreLastWorkingDirectory) { _, newValue in
                        GhosttyUserConfig.saveValues(["restore-last-working-directory": newValue ? "true" : "false"])
                    }
                Text("When disabled, new windows open in your home directory (~), avoiding unwanted folder authorization popups on launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Terminal & Global Hotkey (⌃`)") {
                HStack {
                    Text("Accessibility Permission")
                    Spacer()
                    if isAccessibilityTrusted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Granted")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Request Permission") {
                            QuickTerminalController.requestAccessibilityPermissions()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isAccessibilityTrusted = QuickTerminalController.isAccessibilityTrusted
                            }
                        }
                    }
                }
            }

            Section("Privacy & Permissions") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Full Disk Access")
                            .font(.body)
                        Text("Recommended for terminal emulators to access Desktop, Downloads & Documents without repeated macOS system permission prompts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 16)
                    Button("Configure...") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
        .navigationTitle("Settings")
    }
}

// MARK: - 300+ Theme Search Sheet

struct ThemeSearchSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedTheme: String
    var onSelect: (String) -> Void

    @State private var searchQuery: String = ""

    private var filteredThemes: [GhosttyThemeDefinition] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return GhosttyThemeCatalog.allThemes
        }
        return GhosttyThemeCatalog.search(searchQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search 300+ Ghostty themes...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Theme list
            List(filteredThemes, id: \.name) { theme in
                HStack {
                    Text(theme.name)
                        .font(.system(size: 12.5, weight: selectedTheme == theme.name ? .semibold : .regular))
                    Spacer()
                    if selectedTheme == theme.name {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTheme = theme.name
                    onSelect(theme.name)
                    isPresented = false
                }
            }
            .listStyle(.inset)

            Divider()

            // Footer
            HStack {
                Text("\(filteredThemes.count) themes available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
        .frame(width: 380, height: 440)
    }
}
