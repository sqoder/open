# Glint · Next-Gen Native macOS Productivity Workstation

<p align="center">
  <img src="assets/logo.png" width="128" height="128" alt="Glint Logo" />
</p>

<p align="center">
  <b>A unified, ultra-fast macOS workstation blending hardware notch integration, screenshot & recording tools, AI voice dictation, clipboard manager, and instant notes.</b><br>
  Built natively with Swift and Metal for macOS 14.0+.
</p>

<p align="center">
  <a href="#-download">Download DMG</a> •
  <a href="#-installation--first-run">Quick Start</a> •
  <a href="#-key-features">Features</a> •
  <a href="#-keyboard-shortcuts">Shortcuts</a> •
  <a href="#-privacy--security">Privacy</a>
</p>

---

## 📥 Download

Pre-built DMG installer (`v0.0.614`, ultra-slim `16.2 MB`) for macOS 14.0 (Sonoma) and newer:

| Platform | Version | System | Package |
|---|---|---|---|
| **macOS** | `v0.0.614` | macOS 14.0+ | [**Download Glint.dmg**](./Glint.dmg) |

---

## 🚀 Installation & First Run

1. Download [**`Glint.dmg`**](./Glint.dmg) and drag **Glint** into your **`Applications`** folder.
2. **First-launch Gatekeeper bypass** (if prompted with "unverified developer"):
   - Right-click **Glint** in `Applications` → choose **Open** → click **Open**.
   - Or run in Terminal:
     ```bash
     xattr -cr /Applications/Glint.app
     ```
3. **Grant Essential Permissions**:
   - **Screen Recording**: For screenshot capture, area OCR, and video recording.
   - **Accessibility**: For global hotkeys and seamless text paste injection.
   - **Microphone**: For voice dictation and screen recording audio.

---

## ✨ Key Features

### 🏝️ Dynamic Island & Hardware Notch Hub
- Seamlessly fuses with MacBook Pro hardware notches and external displays with 120 FPS Metal liquid glass shaders and zero-pause spring physics.
- **Universal Media & Video Controller**: Real-time artwork, synchronized lyrics, dynamic audio waveforms, playback controls, and one-click window/tab jump across Apple Music, NetEase Music, QQ Music, Spotify, Kugou, Kuwo, YouTube, Bilibili, Youku, Tencent Video, iQIYI, Instagram, Safari, Chrome, Arc, and Edge.
- **Integrated App Library & Tool Dock**: Quick access to 3D Flip Clock & Daily Quotes, Ghostty/Suqi GPU Terminal, Clean Desktop toggle, Native Color Picker, File Shelf, Calendar, Weather, Caffeine sleep prevention, Health Reminder, and Instant Notes.

### 📸 Smart Capture & Professional Annotation
- **Sub-Pixel Snapping & Magnifier**: Instant window and element snapping with precise RGB / HEX color picker.
- **12+ Annotation Tools**: Rectangles, callout arrows, highlighter, step counters, pixelate mosaic, gaussian blur, spotlight, and text.
- **Scrolling Screenshot (Long Capture)**: Sub-pixel image stitching for full-length webpages, long code files, and chats.
- **Smart Privacy Redaction**: Vision-powered automatic detection and blurring of phone numbers, emails, cards, and API keys.
- **Pin to Screen**: Float screenshots on top across multiple desktops with opacity and scale adjustment.

### 🎥 High-Performance Screen Recording
- Crisp 60 FPS recording with system audio loopback + microphone input.
- Live canvas brush annotations during recording.
- Instant high-quality GIF or MP4 export.

### 🎙️ AI Voice Dictation & Smart Style Tuning
- Multi-engine support: Offline low-latency SenseVoice, Apple Speech, and cloud Whisper.
- Context-aware formatting: Automatically cleans filler words and adapts tone (code style for IDEs, formal for mail, colloquial for chat).
- Seamless cursor injection: Directly inserts transcribed text into active apps.

### 📋 Clipboard History & Instant Notes
- Multi-category indexing: Rich text, images, code snippets, color codes, and links.
- Lightweight markdown notepad with live word count, formatting toolbar, and instant local persistence.

### 🌐 In-Place Screen Translation
- Area selection OCR with direct overlay translation rendering (supporting DeepL, OpenAI-compatible APIs, Google, and Baidu).

---

## ⌨️ Keyboard Shortcuts

| Action | Default Shortcut | Description |
|---|---|---|
| **Area Capture** | `⌘ ⇧ A` | Interactive capture and annotation overlay |
| **Fullscreen Capture** | `⌘ ⇧ 1` | Instantly captures entire screen to clipboard |
| **Window Capture** | `⌘ ⇧ 2` | Snaps and captures the hovered active window |
| **Screen Recording** | `⌘ ⇧ R` | Starts area or full-screen video/GIF recording |
| **Scrolling Capture** | `⌘ ⇧ L` | Smooth auto-scrolling long capture |
| **Screen OCR Translate** | `⌘ ⇧ T` | Select area for in-place text translation |
| **Voice Dictation** | `⌘ ⇧ D` | Hold or tap to open live voice dictation pill |
| **Toggle Notch Island** | `⌘ ⇧ N` | Expands or collapses the notch workspace |
| **Clipboard History** | `⌘ ⇧ V` | Opens floating clipboard manager |
| **Preferences** | `⌘ ,` | Opens Glint Settings |

*All keyboard shortcuts are fully customizable in Settings → Shortcuts.*

---

## 🔒 Privacy & Security

- **Zero Telemetry**: Glint collects no user data, analytics, or screen captures.
- **Offline-First**: OCR, stitching algorithms, clipboard history, and image processing run 100% locally on your machine.
- **Encrypted Credentials**: Custom API keys (e.g. translation providers) are securely stored inside the macOS system Keychain.

---

## 📄 License

Copyright © 2026 Glint. All rights reserved.
