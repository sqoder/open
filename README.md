# 🌊 momi · AI 实时测速仪 (v1.5.6)

<p align="center">
  <img src="resources/icon.jpg" width="160" height="160" style="border-radius: 24px;" alt="momi Icon" />
</p>

<p align="center">
  <strong>专为 macOS 设计的轻量级 AI 实时输出速率 (Tokens Per Second) 测速仪</strong><br>
  常驻 Mac 顶部系统菜单栏 · 支持 Antigravity / Qoder / DeepSeek Harness / Pi / Claude Code / Codex · 零依赖原生架构
</p>

---

## ✨ 核心特性

- ⚡ **实时 TPS 测速**：在 Mac 菜单栏常驻显示模型生成速率（如 `⚡ 85.2 tok/s`），生成中动态提示 `⚡ 正在生成...`。
- 📱 **多工具/多实例联合监听**：自动同时监听 **Antigravity Desktop / CLI**、**Qoder**、**DeepSeek Harness**、**Pi**、**Claude Code**、**Codex App** 与 **Codex CLI**，无缝自动切换当前活动会话。
- 📊 **毫秒级真实数据**：直接读取底层官方服务端的分词计数（`output_tokens`）与真实物理时钟耗时，**拒绝粗略字数估算，100% 真实吞吐量**。
- 📜 **用量统计窗口**：查看全部历史的输入 / 输出 / 缓存总量，并按模型或 Agent 排行。
- 🧠 **模型与会话自动识别**：自动展示当前模型（如 `Gemini 3.8 Flash (High)`）与当前对话 ID。
- 🪶 **原生极简，零额外负担**：
  - 基于 Swift + AppKit 原生编写，已编译为单一独立二进制。
  - 不占用 Dock 栏，不占用 `Cmd + Tab` 切换栏。
  - 物理内存仅 ~15MB，自身私有占用仅 1.1MB，CPU 占用日常 0%。

---

## 🚀 快速开始

### 1. 运行应用
本项目编译出的应用已安装至系统 `/Applications/momi.app`：
- **启动台 (Launchpad)**：直接点击带有海边插画图标的 **momi** 即可启动。
- **快捷键**：`Command + 空格` 搜索 `momi` 回车。
- **开机自启**：在 Mac **系统设置 → 通用 → 登录项** 中添加 `momi.app`。

### 2. 源码构建与安装
如果你需要对源码进行修改：
```bash
git clone ...
cd momi
chmod +x build.sh scripts/*.sh
./build.sh
```
`build.sh` 会调用系统原生 `swiftc` 编译器进行最高等级优化（`-O`），并自动打包安装到 `/Applications/momi.app`。

---

## 📁 目录结构

```text
momi/
├── src/
│   ├── main.swift             # momi 原生 AppKit 核心逻辑
│   └── Info.plist             # 声明 macOS Menu Bar Accessory App
├── resources/
│   ├── AppIcon.icns           # 生成的原生高清 macOS 图标
│   └── icon.jpg               # 原生图标原始图片
├── scripts/
│   ├── build.sh               # 一键编译并安装到 /Applications
│   ├── start.sh               # 启动应用
│   └── stop.sh                # 退出应用
├── plugins/
│   └── swiftbar/              # 备用 SwiftBar/xbar 脚本
│       └── momi_tps.2s.py
└── README.md
```

---

## 🛠 技术原理

1. **会话日志抓取**：定时监听 Agent 活动日志与投影缓存（如 `~/.gemini/antigravity/brain/*/transcript.jsonl`、`~/.dsh/storages/session_projcache/sessions/*.json`）。
2. **端到端 TPS 测算**：
   $$\text{TPS} = \frac{\text{真实 Output Tokens}}{\text{真实生成时间戳差值 (秒)}}$$
3. **Menu Bar 渲染**：利用 `NSStatusBar.system.statusItem` 构建原生菜单项，配合定时器进行低功耗异步刷新。
