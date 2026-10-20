# momi 更新日志 (Changelog)

## [1.1.0] - 2026-10-20

### 🚀 新增功能 (Features)
- **多实例联合监听 (Multi-Instance Monitoring)**：
  - 同时支持并监听 **Antigravity Desktop**（桌面端应用）、**Antigravity CLI**（终端 `agy` 命令行版）以及 **Antigravity IDE**。
- **智能焦点切换 (Smart Focus Switching)**：
  - 当关闭 Desktop 切换至 CLI 时，自动感知并无缝切换至 CLI 会话测速。
  - 当多个实例同时生成时，优先在菜单栏高亮正在生成的实例（标示来源如 `[CLI]` 或 `[Desktop]`）。
- **多实例状态面板**：
  - 下拉菜单新增 **“📱 监听中的实例”** 列表，各工具的在线/活跃状态、最后测速与更新时间一目了然，并支持手动点击切换。

### ⚡ 性能优化 (Performance)
- **零浪费修改守卫 (`mtime guard`)**：未触发生成时完全跳过重复解析，实现 0% CPU 与 0 磁盘 I/O。
- **末尾偏移读取 (`readTail`)**：采用 `FileHandle` 仅读取文件末尾 64KB，彻底解决超长会话（数万行）内存暴涨隐患。
- **极限内存占用**：物理 Footprint 稳定在 15MB，自身私有 Dirty Memory 仅 1.1MB。

---

## [1.0.0] - 2026-10-20
- 初始版本发布：支持 Mac 顶部菜单栏常驻显示 Antigravity 实时 Tokens/s 速率。
- 支持历史 5 次生成耗时与分词详情查看。
- 原生 Retina 高清海边少女图标集成。
