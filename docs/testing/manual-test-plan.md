# siqi 全功能手工测试手册

> 文档地址：`/Users/wangxinglin/Desktop/glint/siqi/docs/testing/manual-test-plan.md`
> 用途：交给 Codex 或人工，**逐项**点测，确认每个功能正常。每一步都给「操作 / 期望 / 失败判据」。
> 原则：只报**可复现**的问题；每条问题都要能按步骤重现。

---

## 0. 环境与准备

| 项 | 值 / 命令 |
|---|---|
| 系统 | macOS 26.x（开发机 26.5） |
| 安装位置 | `/Applications/siqi.app` |
| 配置目录 | `~/.config/siqi/config`（回落 `~/.config/suqi/config` 或 `~/.config/ghostty/config`） |
| 工作目录缓存 | `~/Library/Caches` 实为 `~/.cache/siqi/last_working_directory` 与 `~/.cache/siqi/pastes/` |
| 崩溃报告 | `~/Library/Logs/DiagnosticReports/siqi-*.ips` |
| 运行日志 | `log stream --predicate 'process == "siqi"' --level debug` |
| 版本 | `defaults read /Applications/siqi.app/Contents/Info.plist CFBundleShortVersionString` |

**开始每个测试轮次前**
1. 备份配置：`cp ~/.config/siqi/config ~/.config/siqi/config.bak`（不存在跳过）。
2. 完全退出旧版本：`⌘Q`（不是关窗口）。
3. 改代码后重新安装：
   ```bash
   cd /Users/wangxinglin/Desktop/glint/siqi
   ./scripts/install.sh
   ```
4. 重启 App。

**每轮必跑自动化测试**
```bash
cd /Users/wangxinglin/Desktop/glint/siqi
xcodebuild test -project siqi.xcodeproj -scheme siqi -destination 'platform=macOS' 2>&1 | tail -20
```
期望：`** TEST SUCCEEDED **`，5 个用例全过。出现 `error:` 或失败即 bug。

---

## 1. 启动与外框

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| S-01 | 双击 `/Applications/siqi.app` 启动 | 主窗口出现，光标闪烁，可输入 | 无窗口 / 闪退 |
| S-02 | 点 Dock 图标右键 → New Window | 新窗口 | 无反应 |
| S-03 | 点 Dock 图标右键 → New Tab | 当前窗口新标签 | 无反应 |
| S-04 | 点 Dock 图标右键 → Toggle Quick Terminal | 快速终端滑出 | 无反应 |
| S-05 | 关闭所有窗口后点 Dock 图标 | 应用重新打开窗口（见 `AppDelegate.applicationShouldHandleReopen`） | 应用已退出无反应 |
| S-06 | 在 Finder 选中一个文件夹 → 右键 → 服务 → 用 siqi 打开 | 在该目录开新窗口（见 `AppDelegate.openInSiqi`） | 开错目录 / 无反应 |
| S-07 | 全屏按钮进入/退出全屏 | 标题灯位置自适应，终端正常 | 灯被遮 / 闪退 |
| S-08 | 把窗口缩到极小（拖到 < 140×60） | 变成 80×32 小药丸（capsule），显示展开按钮 | 崩溃 / 卡住 |
| S-09 | 小药丸点展开按钮 / 双击 | 平滑恢复成正常窗口 | 不恢复 / 跳变 |

---

## 2. 菜单栏 — File（文件）

*菜单定义在 `SiqiApp.swift` 的 `.newItem` 替换组。*

| 编号 | 菜单项 | 快捷键 | 操作 | 期望 |
|---|---|---|---|---|
| M-F1 | New Window | `⌘N` | 按 `⌘N` | 独立新窗口，输入互不干扰 |
| M-F2 | New Tab | `⌘T` | 按 `⌘T` | 当前窗口新标签，工作目录继承当前 session 目录 |
| M-F3 | Split Right | `⌘D` | 按 `⌘D` | 当前 pane 右侧分出垂直分屏 |
| M-F4 | Split Down | `⌘⇧D` | 按 `⌘⇧D` | 当前 pane 下方分出水平分屏 |
| M-F5 | Toggle Split Zoom | `⌘⇧↩` | 在分屏里按 | 该 pane 放大占满；再按还原 |
| M-F6 | Equalize Splits | `⌃⌘=` | 在多个 pane 里按 | 所有分隔线变 50/50 |
| M-F7 | Close Split / Tab | `⌘W` | 在分屏里按 | 只关当前 pane；最后一个 pane 关则关标签 |
| M-F8 | Close Window | `⌘⇧W` | 按 | 关整个窗口 |

---

## 3. 菜单栏 — Edit（编辑）

| 编号 | 菜单项 | 快捷键 | 操作 | 期望 |
|---|---|---|---|---|
| M-E1 | Cut | `⌘X` | 选中文本按 | 剪切（终端场景多为透传） |
| M-E2 | Copy | `⌘C` | 选中终端文本按 | 复制选中内容到系统剪贴板 |
| M-E3 | Paste | `⌘V` | 见 §6 粘贴专题 | 智能粘贴（文本/图片/文件） |
| M-E4 | Paste Image as File Path | `⌥⌘V` | 复制一张图片后按 | 图片存盘并把路径贴入（见 `TerminalActionBridge.handlePaste(saveImageAsPath:)`） |
| M-E5 | Select All | `⌘A` | 按 | 全选终端内容 |
| M-E6 | Find... | `⌘F` | 按 | 顶部出现搜索条，输入高亮匹配 |

**注意**：在 `⌘F` 搜索框聚焦时，`⌘C/⌘V/⌘A/⌘X` 应作用于搜索框文本，不触发终端动作（`TerminalActionBridge.dispatchKeyEvent` 内 `isTextInputFocused` 分支）。

---

## 4. 菜单栏 — Terminal（终端）

| 编号 | 菜单项 | 快捷键 | 操作 | 期望 |
|---|---|---|---|---|
| M-T1 | Toggle Quick Terminal | `⌃\`` | 见 §9 | 滑出/收起下拉终端 |
| M-T2 | Clear Scrollback | `⌘K` | 按 | 清屏 + 清滚动回滚 |
| M-T3 | Restart Active Session | `⌘R` | 在跑 `sleep 1000` 时按 | 会话重建；当前标签不消失，其他标签不受影响（修过的 bug） |
| M-T4 | Reload Configuration | `⌘⇧,` | 改配置后按 | 热重载全部窗口配置 |
| M-T5 | Enable/Disable Secure Keyboard Entry | （无默认） | 点 | 系统安全输入状态切换，菜单文案同步 |
| M-T6 | Previous Tab | `⌘⇧[` | 按 | 切到上一标签 |
| M-T7 | Next Tab | `⌘⇧]` | 按 | 切到下一标签 |
| M-T8 | Select Tab 1..9 | `⌘1`..`⌘9` | 按 | 直接跳到第 N 个标签（标签数 ≥ N 时） |

---

## 5. 菜单栏 — View（视图）

| 编号 | 菜单项 | 快捷键 | 操作 | 期望 |
|---|---|---|---|---|
| M-V1 | Increase Font Size | `⌘+` / `⌘=` | 按 | 字号 +1 |
| M-V2 | Decrease Font Size | `⌘-` | 按 | 字号 -1 |
| M-V3 | Reset Font Size | `⌘0` | 按 | 回到配置文件字号 |
| M-V4 | Settings... | `⌘,` | 按 | 打开设置窗口（见 §10） |
| M-V5 | Open Configuration File | `⌥⌘,` | 按 | 用默认编辑器打开 `~/.config/siqi/config` |

---

## 6. 粘贴专题（重点回归）

| 编号 | 场景 | 操作 | 期望 | 失败判据 |
|---|---|---|---|---|
| P-01 | 纯文本 | 复制一段文字，`⌘V` | 原样贴入 shell | 乱码 / 不贴 |
| P-02 | 单个文件 | Finder 复制一个 `.py`，`⌘V` | 贴转义后路径带空格 | 路径缺引号导致空格断词 |
| P-03 | 多个文件 | Finder 多选复制，`⌘V` | 多个路径空格分隔 | 只贴一个 |
| P-04 | 图片（标准 shell） | 从 Safari 复制一张图，`⌘V` | 图片存 `~/.cache/siqi/pastes/paste_*.png` 并贴路径 | 出现 `^V` 乱码 |
| P-05 | 图片（AI CLI） | 跑 `claude` 后，复制图片 `⌘V` | 合成 `⌃V` 把图片喂给 CLI（见 `AppTerminalView.triggerImagePasteShortcut`） | CLI 收到路径而非图片 |
| P-06 | 图片+文本混选 | Finder 同时选 `.png` 和 `.txt`，`⌘V` | 走图片分支（AI CLI 收图） | 被当成纯文本贴两路径 |
| P-07 | 浏览器空图 | 从网页复制图片 `⌘V` | 图片正常送达；`pastes/` 目录**无 0 字节文件**（修过的 bug） | 产生空文件 |
| P-08 | ⌥⌘V 图片 | 复制图片，按 `⌥⌘V` | 图片存盘并贴路径（非 AI 分支也贴路径） | 不贴 / 崩 |
| P-09 | 拖入文件 | 从 Finder 拖文件到终端 | 贴转义路径 | 不贴 |
| P-10 | 拖入纯文本 | 从别处拖文本到终端 | 文本输入 | 不贴 |

---

## 7. 右键菜单与 TUI（重点回归）

siqi 的右键菜单（`TerminalContextMenuBridge`）只在**裸 shell** 弹出；前台跑非 shell 程序（如 `herdr`、`vim`、`htop`、`top`）时右键应**转发给程序自身**（`AppTerminalView+ContextMenu.swift` 的 `session.hasActiveProcess` 判定）。

| 编号 | 场景 | 操作 | 期望 | 失败判据 |
|---|---|---|---|---|
| R-01 | 裸 shell 右键 | 退出到 zsh 后右键 | 弹 siqi 菜单（Copy/Paste/Split/Clear/New Tab…） | 不弹 / 弹错 |
| R-02 | TUI 右键归程序 | 跑 `herdr`（或 `vim`）右键 | **只**出现程序自己的弹层，siqi 菜单不出现 | siqi 菜单压住 herdr |
| R-03 | Ctrl+click 裸 shell | 按住 `⌃` 点终端 | 不弹 siqi 菜单 | 误弹 |
| R-04 | 多窗口右键作用范围 | 开两窗口各一 pane，窗口 A 右键 Close Pane | 只关 A 的 pane，B 不动 | 误关 B |
| R-05 | 标签拖拽中右键 | 拖动标签时右键 | 不弹菜单 / 不误作用别的窗口 | 误弹 |
| R-06 | 分屏右键 | 在分屏某 pane 右键 → Close Pane | 只关该 pane | 关错 |
| R-07 | 右键菜单项—Split Right/Down | 点对应项 | 正确分屏 | 不生效 |
| R-08 | 右键菜单项—Equalize / Toggle Split Zoom | 点对应项 | 生效 | 不生效 |
| R-09 | 右键菜单项—Find / Clear Screen / New Tab / New Window | 逐项点 | 生效 | 不生效 |
| R-10 | 右键菜单项—Close Pane（多 pane → Close Pane；单 pane → Close Tab） | 点 | 文案与行为匹配 | 文案错 |

---

## 8. 标签（Tab）

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| T-01 | `⌘T` 新标签 | 新标签，目录继承当前 session | 目录错 |
| T-02 | 点标签切换 | 切换激活 | 不切 |
| T-03 | `⌘1..9` 跳标签 | 跳到对应标签 | 不跳 |
| T-04 | `⌘⇧[` / `⌘⇧]` 前后切 | 循环切换 | 不切 |
| T-05 | 拖标签重排 | 顺序改变并持久 | 跳回原位 |
| T-06 | 把标签拖到**自己**标签栏上松手 | 不变成新窗口 | 误变新窗口 |
| T-07 | 把标签拖到窗口**外** | 变成独立新窗口（见 `detachTabToNewWindow`） | 不分离 / 崩 |
| T-08 | 标签右键 → New Tab / Split Right / Split Down | 生效 | 不生效 |
| T-09 | 标签右键 → Move Tab to New Window | 该标签去新窗口 | 不生效 |
| T-10 | 标签右键 → Close Other Tabs | 仅留当前标签 | 误关 |
| T-11 | 标签右键 → Close Tab | 关该标签 | 不关 |
| T-12 | 标签标题随前台进程变 | 跑 `vim` 标题变 vim，退出回路径；有前台进程时标签左侧显示橙色点 | 标题不变 / 点不显示 |
| T-13 | hover 标签出现关闭 ✕；非 hover 显示 `⌘N` 角标 | 视觉正确 | 显示错 |

---

## 9. 快速终端（Quick Terminal）

配置键：`quick-terminal-position`(top/bottom/left/right/center)、`quick-terminal-screen`(main/mouse)、`quick-terminal-size`(如 `50%` 或 `1200x600`)、`quick-terminal-autohide`(bool)、`quick-terminal-animation-duration`(秒)。

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| Q-01 | `⌃\`` 唤出 | 从配置的位置滑出 | 不出现 |
| Q-02 | 再按 `⌃\`` | 收起 | 不收 |
| Q-03 | 动画中（`duration=0.2`）连按两次 | 先收；再按能正常唤出；**不出现「按了没反应」或「刚出又消失」**（修过的 bug） | 卡死 |
| Q-04 | 隐藏动画中按 `⌘W` | 快速终端的 pane 不被关；隐藏完成后 `⌘W` 才作用于主窗口（修过的 bug） | 误关 pane |
| Q-05 | 切到别的 App 再按 `⌃\`` | 能唤出（需辅助功能权限） | 不唤出 |
| Q-06 | 设置 `quick-terminal-autohide=true`，唤出后点别处 | 自动收起 | 不收 |
| Q-07 | 改 `quick-terminal-position` / `size` 后重载 | 位置尺寸生效 | 不生效 |
| Q-08 | 设置里 Request Permission（辅助功能） | 跳转系统设置；授予后 `Q-05` 正常 | 授权后仍未生效 |
| Q-09 | 全局热键权限被撤（`tccutil reset` 辅助功能） | `⌃\`` 在别的 App 下静默失效（已知问题，不报） | — |

---

## 10. 设置窗口（Settings）

打开：`⌘,`。每项改动即时写 `~/.config/siqi/config` 并热重载。

| 编号 | 控件 | 操作 | 期望 | 失败判据 |
|---|---|---|---|---|
| C-01 | Theme 下拉 | 切换主题 | 立即生效，无需重启 | 不生效 |
| C-02 | Browse 300+ 主题 | 搜索并选主题 | 生效 | 搜不到 / 不生效 |
| C-03 | Background Opacity 滑杆 | 拖动 | 背景透明度实时变 | 不生效 |
| C-04 | Background Blur 滑杆 | 拖动 | 背景模糊实时变 | 不生效 |
| C-05 | Font Family 下拉 | 切换字体 | 生效 | 不生效 |
| C-06 | Font Size stepper | +/− | 字号变 | 不生效 |
| C-07 | Adjust Cell Height stepper | 调值 | 行高变 | 不生效 |
| C-08 | Padding X / Y stepper | 调值 | 内边距变 | 不生效 |
| C-09 | Cursor Style（Bar/Block/Underline） | 切换 | 光标样式变 | 不生效 |
| C-10 | Cursor Blink 开关 | 切换 | 光标闪烁变 | 不生效 |
| C-11 | Restore Last Working Directory 开关 | 开 → 关所有窗口重开 | 新窗口回到上次目录（见 `SiqiDirectoryManager`） | 不恢复 |
| C-12 | 配置只读时改任意项 | `chmod 444 ~/.config/siqi/config` 后改主题 | 不崩不卡；`log stream` 见 `Failed to write config to ...`（修过的 bug） | 崩溃 |
| C-13 | 重复键全更新 | 配置文件写两行 `font-size = 12` 和 `font-size = 14`，设置里调成 18 | **两行都变 18**（修过的 bug） | 只改一行 |
| C-14 | Full Disk Access 配置按钮 | 点 | 跳系统隐私设置 | 不跳 |

---

## 11. 配置热重载（手动改文件）

配置文件格式：`key = value`（行内 `#` 注释）。支持键见下表。**每改一项后 1 秒内应生效，应用不重启。**

| 配置键 | 作用 | 验证 |
|---|---|---|
| `theme` | 主题名 | 终端配色变 |
| `font-family` / `font-size` | 字体 / 字号 | 渲染变 |
| `font-thicken` | 字体加粗 | 字重变 |
| `adjust-cell-height` | 行高微调 | 行高变 |
| `background-opacity` | 背景不透明度 | 透明变 |
| `background-opacity-cells` | 逐格透明 | 透明变 |
| `background-blur` | 模糊 | 模糊变 |
| `background` | 背景色（hex，去 `#`） | 底色变 |
| `foreground` | 前景色 | 字色变 |
| `window-padding-x` / `window-padding-y` | 内边距 | 边距变 |
| `window-width` / `window-height` | 新窗口默认尺寸 | 新窗口尺寸变 |
| `macos-titlebar-style` | `native` 显示系统标题栏，其他用自定义 | 标题栏变 |
| `window-save-state` | `never` 不保存/恢复几何 | 窗口位置记忆变 |
| `cursor-style` / `cursor-style-blink` | 光标 | 见 C-09/10 |
| `copy-on-select` | 选中即复制 | 选词自动进剪贴板 |
| `shell-integration` | shell 集成 | zsh/bash 集成 |
| `working-directory` | 新窗口起始目录 | 新窗口目录变 |
| `restore-last-working-directory` | 恢复上次目录 | 见 C-11 |
| `unfocused-split-opacity` | 失焦 pane 变暗 | 非激活 pane 变暗 |
| `mouse-scroll-multiplier` | 滚动倍率 | 滚动速度变 |
| `command` | 启动命令 | 新 session 跑该命令 |
| `font-feature` | OpenType 特性 | 字形变 |
| `confirm-close-surface` | 有关进程时关窗确认 | 见 §14 |
| `quick-terminal-*` | 见 §9 | 见 §9 |
| `keybind` | 自定义快捷键（Ghostty 风格 `cmd+shift+e=new_tab`） | 见 §12 |

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| H-01 | 改 `theme` 保存 | 1 秒内配色变 | 不生效 |
| H-02 | 改 `background` 保存 | 底色变 | 不生效 |
| H-03 | 改 `font-size` 保存 | 字号变 | 不生效 |
| H-04 | 改 `macos-titlebar-style=native` 保存 | 出现系统标题栏 | 不变 |
| H-05 | 连续改 20 次任意键 | 无崩溃、无卡死 | 崩 |
| H-06 | 用 vim 改配置（原子保存/重命名） | watcher 重新监听，仍热重载（见 `SiqiConfigFileWatcher`） | 改后失效 |
| H-07 | fd 泄漏检查 | 改配置 20 次前后 `lsof -p $(pgrep -x siqi) | wc -l` 稳定（修过的 bug） | 持续增长 |

---

## 12. 自定义快捷键（keybind）

配置示例：`keybind = super+shift+e=new_tab`。解析见 `SiqiUserConfig.parseKeybinding`。用户配置优先级高于内置快捷键（`dispatchKeyEvent` 内先匹配 `keybindings`）。

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| K-01 | 加 `keybind = cmd+shift+n=new_window`，重载，按 `⌘⇧N` | 开新窗口 | 不生效 |
| K-02 | 加 `keybind = cmd+k=clear_screen`，按 | 清屏 | 不生效 |
| K-03 | 重复键 `keybind` 多行 | 全部加载 | 只认一条 |
| K-04 | 非法值（无 `=`） | 忽略不崩 | 崩 |

---

## 13. 分屏与 pane 导航

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| SP-01 | `⌘D` / `⌘⇧D` | 分屏 | 不屏 |
| SP-02 | 拖分隔线 | 比例变 | 不动 |
| SP-03 | 双击分隔线 | 变 50/50（见 `SplitDividerNSView.mouseDown` `clickCount==2`） | 不变 |
| SP-04 | `⌃⌘H/J/K/L` 或 `⌃⌘←/↓/↑/→` | 按方向聚焦 pane | 不切 |
| SP-05 | `⌥⌘←/→/↑/↓` | 同方向聚焦 | 不切 |
| SP-06 | `⌥⌘[` / `⌥⌘]` | 上一个/下一个 pane | 不切 |
| SP-07 | `⌘⇧↩` 放大某 pane，再按 | 放大/还原（ZOOMED 角标显示） | 不切 |
| SP-08 | 关其中一个 pane | 另一个占满 | 留空 |
| SP-09 | `⌃⌘=` 均衡 | 全 50/50 | 不均衡 |
| SP-10 | 快速开关分屏 50 次 | 无崩溃、无残留 | 崩 |

---

## 14. 关闭确认与退出

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| X-01 | `confirm-close-surface=true`，标签跑 `sleep` 时 `⌘W` | 弹确认框，确认才关 | 不弹 / 直接关 |
| X-02 | 同上，Cancel | 不关 | 仍关 |
| X-03 | `confirm-close-surface=true`，窗口跑进程时关窗口（红灯） | 弹窗确认 | 不弹 |
| X-04 | 无前台进程时关窗口 | 直接关 | 误弹 |
| X-05 | 有前台进程时 ⌘Q 退出 | 按配置确认后退出 | 不退出 / 崩 |
| X-06 | 退出后 `pgrep -x siqi` | 无输出（进程结束） | 进程残留 |

---

## 15. 搜索（⌘F）

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| SE-01 | `⌘F` 输入关键字 | 高亮匹配，可翻页（↑/↓ 按钮或 Enter/Shift+Enter） | 不高亮 |
| SE-02 | Esc / 点 ✕ | 搜索条关闭，焦点回终端 | 不关 |
| SE-03 | 搜索时 `⌘C` | 复制搜索框文本，不触发终端复制 | 误触发 |

---

## 16. 链接与拖放

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| L-01 | `⌘` 点击终端里的 URL | 浏览器打开 | 不打开 |
| L-02 | `⌘` 点击终端里的文件路径（绝对/相对） | 在 Finder 打开/定位（见 `TerminalLinkResolver`） | 不打开 |
| L-03 | 从 Finder 拖文件到终端 | 插入转义路径 | 不插 |
| L-04 | 从别处拖纯文本到终端 | 文本输入 | 不输 |
| L-05 | 拖图片文件到跑着 AI CLI 的标签 | 走图片分支 | 走路径 |

---

## 17. 主题 / 字体 / 光标（综合）

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| TH-01 | 切换内置主题（Catppuccin / TokyoNight / Dracula / Nord 等） | 配色正确 | 错色 |
| TH-02 | 搜索并选 300+ 中冷门主题 | 生效 | 不生效 |
| TH-03 | 设 `background-opacity < 1` 或 `background-blur > 0` | 窗口半透明 + 毛玻璃 | 不透明 |
| TH-04 | 设 `background` 为自定义 hex | 底色变 | 不变 |
| FO-01 | 设非常用等宽字体 | 渲染正确无重叠 | 乱排 |
| FO-02 | `⌘+/⌘-/⌘0` 调字号 | 生效并可复位 | 不生效 |
| CU-01 | 切 Bar/Block/Underline 光标 | 样式对 | 错 |
| CU-02 | 开关光标闪烁 | 行为对 | 错 |

---

## 18. IME 中文输入

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| I-01 | 切拼音输入法，打「你好」上屏 | 正常上屏无乱码 | 乱码 / 不显候选 |
| I-02 | 输入法候选窗位置 | 候选浮在终端上方（见 `AppTerminalView+IME.windowLevel`） | 被遮挡 |
| I-03 | 中文显示（不含糊字、不重叠） | 正常 | 缺字 |

---

## 19. 通知

siqi 通过 OSC 9 / 777 发系统通知（`TerminalNotificationService`）。

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| N-01 | 全新配置（或 `tccutil reset Notifications com.siqi.terminal` 后重启），触发一次通知 | 弹系统授权；允许后通知出现 | 不弹授权 |
| N-02 | 拒绝授权后触发 | 应用不崩，后续无通知 | 崩 |
| N-03 | 已授权后触发 | 通知正常出现 | 不出 |

---

## 20. 窗口置顶（Pin）

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| PN-01 | hover 左上角出现 pin 按钮，点击 | 窗口置顶（level=floating，可跨空间） | 不置顶 |
| PN-02 | 再点 pin | 取消置顶 | 不取消 |
| PN-03 | pin 按钮平时隐藏，hover 才显 | 视觉对 | 常显 / 不显 |

---

## 21. 窗口状态恢复

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| W-01 | 开两个窗口、几个标签、分屏，退出 | 重启后结构恢复（见 `window-save-state`） | 不恢复 |
| W-02 | `restore-last-working-directory=true`，在目录 A 工作后退出 | 重开窗口回到 A | 不回 |
| W-03 | `window-save-state=never` | 不记忆几何，每次默认位置 | 仍记忆 |

---

## 22. 稳定性 / 资源

| 编号 | 操作 | 期望 | 失败判据 |
|---|---|---|---|
| ST-01 | 开一个标签跑 `yes > /dev/null` 挂 10 分钟 | CPU 稳定、内存不持续涨、输入不卡 | 涨内存 / 卡 |
| ST-02 | 快速开关窗口/标签 50 次 | 无崩溃、无窗口残留、菜单正常 | 崩 |
| ST-03 | 开第二个窗口红灯关闭，反复 5 次 | 主窗口仍可用；活动监视器看 siqi 内存不持续涨（修过的 bug：残留 observer） | 涨内存 |
| ST-04 | 多窗口下切来切去，点不同窗口的 pane | 焦点/右键都正确作用本窗口（修过的 bug） | 串窗口 |
| ST-05 | fd 泄漏（见 H-07） | 稳定 | 增长 |

---

## 23. 已知问题（**不要重复报**）

1. `⌘R` 重启会话时旧 ghostty surface 不释放（库无公开 API），频繁重启会累积。
2. 未支持的 Ghostty 配置键（如 `font-variation`、`background-image`）静默忽略，无提示。
3. Accessibility 权限被撤销后，全局 `⌃\`` 热键静默失效。
4. 输入法激活时，AI CLI 图片粘贴的合成 `⌃V` 可能被吞（未稳定复现）。
5. 自定义 `keybind` 只能覆盖内置行为，不能绑定到无对应 action 的组合（静默忽略）。

---

## 24. 覆盖率清单（测试后打勾）

```
启动外框    S-01..S-09
File 菜单   M-F1..M-F8
Edit 菜单   M-E1..M-E6
Terminal    M-T1..M-T8
View 菜单   M-V1..M-V5
粘贴        P-01..P-10
右键/TUI    R-01..R-10
标签        T-01..T-13
快速终端    Q-01..Q-09
设置        C-01..C-14
配置热重载  H-01..H-07 + 全键表
自定义键    K-01..K-04
分屏导航    SP-01..SP-10
关闭确认    X-01..X-06
搜索        SE-01..SE-03
链接拖放    L-01..L-05
主题字体光标 TH-01..TH-04, FO-01..FO-02, CU-01..CU-02
IME         I-01..I-03
通知        N-01..N-03
置顶        PN-01..PN-03
状态恢复    W-01..W-03
稳定性      ST-01..ST-05
```

---

## 25. 报 bug 模板

每条问题按格式写，缺项视为无效：

```
编号：<对应上面编号 或 新>
标题：一句话
严重度：blocker / high / medium / low
环境：macOS 版本、siqi 版本（defaults read 结果）、是否外接显示器、输入法
前置条件：
步骤：
  1.
  2.
期望：
实际：
复现率：n/5
证据：截图路径、`log stream` 片段、崩溃报告文件名
备注：是否与「已知问题」重复
```

**结果交付**：把发现的问题按上面格式追加到 `docs/testing/findings.md`（新建），每条间空一行。没问题的用例也写一行 `S-01 PASS`，方便判断覆盖率。

---

## 26. 快速冒烟（10 分钟版）

```
S-01 启动 → M-F2 新标签/切换 → M-E2 复制粘贴 →
R-01 裸 shell 右键 → R-02 herdr 右键 → P-04/P-06 图片粘贴 →
Q-03 快速终端连按 → M-T3 ⌘R 重启 → C-13 重复键 →
自动化 xcodebuild test
```
