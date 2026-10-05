# Suqi · GPU-Accelerated macOS Terminal

<p align="center">
  <img src="suqi/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Suqi Icon" />
</p>

<p align="center">
  <b>A minimalist, ultra-fast macOS terminal powered by Metal GPU hardware acceleration.</b><br>
  Designed for modern developers and AI CLI workflows with seamless <code>⌘V</code> multimodal image pasting and drag-and-drop.
</p>

---

## ⚡ Highlights

- **Metal GPU Engine**: 120 FPS rendering, sub-millisecond input latency, and full 24-bit TrueColor/kitty graphics support.
- **Multimodal AI CLI Pasting (`⌘V`)**: Bridges screenshots and image files directly into terminal input streams for tools like **`agy`**, **`codex`**, and **`claude`**.
- **Native Drag & Drop**: Drag files, folders, or plain text directly into any terminal surface with automatic path escaping.
- **Floating Pin & Clean Chrome**: Integrated pin-on-top toggle and distraction-free, borderless window frame.
- **Multi-Tab & Split Panes**: Vertical (`⌘D`), horizontal (`⇧⌘D`), spatial navigation (`⌃⌘H/J/K/L`), zoom (`⇧⌘↩`), and equal distribution (`⌃⌘=`).
- **Quick Dropdown Scratchpad (`⌃\``)**: Global hotkey toggle for instant terminal access from any screen.
- **Declarative Config & Hot-Reload (`⇧⌘,`)**: Native support for `~/.config/suqi/config` with live hot reload.

---

## ⌨️ Essential Shortcuts

| Shortcut | Action | Description |
|---|---|---|
| `⌘ V` | **Smart Paste** | Pastes text, file paths, or clipboard images directly |
| `⌥ ⌘ V` | **Paste Path** | Saves clipboard image to cache and pastes the escaped file path |
| `⌘ D` / `⇧ ⌘ D` | **Split Right / Down** | Splits the active pane vertically or horizontally |
| `⇧ ⌘ ↩` | **Toggle Zoom** | Maximizes the focused pane / restores layout |
| `⌃ ⌘ =` | **Equalize Splits** | Rebalances all split pane dimensions evenly |
| `⌃ ⌘ H/J/K/L` | **Focus Direction** | Spatial focus navigation across split panes |
| `⌘ T` / `⌘ W` | **New / Close Tab** | Opens a new tab or closes the current pane/tab |
| `⌃ \`` | **Quick Terminal** | Toggles global dropdown scratchpad |
| `⌘ F` | **Find** | Search scrollback buffer with match highlighting |
| `⇧ ⌘ ,` | **Reload Config** | Live hot-reloads configuration without restarting |

---

## ⚙️ Configuration

Suqi uses a declarative configuration format. Create `~/.config/suqi/config`:

```ini
theme = Catppuccin Mocha
background-opacity = 0.92
background-blur = 20

font-family = Maple Mono NF
font-size = 14
cursor-style = bar
cursor-style-blink = true

window-width = 110
window-height = 32
window-padding-x = 12
window-padding-y = 10
window-save-state = always
copy-on-select = clipboard
```

---

## 🛠 Building & Installation

### Requirements
- macOS 14.0 (Sonoma) or newer
- Xcode 15.0+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
# Clone repository
git clone https://github.com/sqoder/glint.git suqi
cd suqi
git checkout suqi

# Build, sign with local developer certificate, and install to /Applications
./scripts/install.sh
```

Or manually:
```bash
xcodegen generate
xcodebuild -project suqi.xcodeproj -scheme suqi -configuration Release -destination 'platform=macOS' build
cp -R ~/Library/Developer/Xcode/DerivedData/suqi-*/Build/Products/Release/suqi.app /Applications/
codesign -s - --force --deep /Applications/suqi.app
```

> **Tip**: Like iTerm2 or Terminal.app, grant **Full Disk Access** (System Settings → Privacy & Security → Full Disk Access → `suqi`) to execute shell commands across Desktop, Downloads, and Documents without repeated macOS permission prompts.
---

## 📄 License

Licensed under the [MIT License](LICENSE).
