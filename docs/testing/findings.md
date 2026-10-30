# siqi 手工测试结果

测试时间：2026-10-30 15:14–15:53（Asia/Shanghai）  
测试版本：siqi 0.0.27 (27)，`/Applications/siqi.app`  
源码基线：`dc2a726`  
测试方式：Xcode 单元测试 + Computer Use 实际操作 + `CGWindowList`/进程/文件检查

## 0. 自动化基线

| 项目 | 结果 | 证据 |
|---|---|---|
| `xcodebuild test -project siqi.xcodeproj -scheme siqi -destination 'platform=macOS'` | PASS | 5 tests, 0 failures |
| Release 构建、签名、安装 | PASS | `./scripts/install.sh` 成功 |

## 1. 已通过的用例

| 编号 | 结果 | 实测 |
|---|---|---|
| S-01 | PASS | 启动后主窗口出现，终端可输入 |
| M-F1 | PASS | `⌘N` 新建独立窗口 |
| M-F2 / T-01 | PASS | `⌘T` 新建标签并加载 shell |
| M-F3 / SP-01 | PASS | `⌘D` 右侧分屏 |
| M-F5 / SP-07 | PASS | `⌘⇧↩` 放大/还原分屏，ZOOMED 标记出现 |
| M-V1 / M-V2 / M-V3 | PASS | 字号增大、减小、重置均生效 |
| M-T1 / Q-01 / Q-02 | PASS | 快速终端可唤出、可再次收起 |
| M-T3 | PASS | `sleep 1000` 时 `⌘R` 重建当前会话，其他标签保留 |
| M-T6 / M-T7 / M-T8 | PASS | 前后标签切换、`⌘1`/`⌘2` 跳转生效 |
| P-01 | PASS | 纯文本粘贴正常 |
| P-02 | PASS | 单文件路径按 shell 规则转义空格 |
| P-03 | PASS | 多文件路径同时粘贴，两个路径都保留 |
| P-04 | PASS | 剪贴板图片保存到 `~/.cache/siqi/pastes/` 并粘贴非空 PNG 路径 |
| P-08 | PASS | `⌥⌘V` 图片按文件路径粘贴 |
| R-01 | PASS | 裸 shell 右键出现 siqi 菜单 |
| R-09（Find） | PASS | 右键菜单 `Find...` 能打开搜索条 |
| SE-01 / SE-02 / SE-03 | PASS | 搜索高亮、Esc 关闭、搜索框内 `⌘C` 不误触终端复制 |
| SP-04 | PASS | `⌃⌘H` 从右侧分屏切到左侧分屏 |
| H-02 | PASS | 运行中修改 `background` 后 2 秒内热重载 |
| H-03 | PASS | 运行中修改 `font-size` 后热重载 |
| K-01 | PASS | 配置 `cmd+shift+n=new_window` 后新窗口被创建 |
| X-06 | PASS | `⌘Q` 后 siqi 进程退出 |

## 2. 失败项

### F-01 `⌘W` / File > Close Split / Tab 不关闭标签

- 严重度：high
- 复现：
  1. 冷启动 siqi。
  2. `⌘T` 创建第二个标签，确认标签栏有 `⌘1`、`⌘2`。
  3. 聚焦终端后按 `⌘W`。
  4. 再通过 `File > Close Split / Tab` 重复一次。
- 期望：当前标签关闭，剩下另一个标签。
- 实际：两次操作后标签数量仍为 2，界面和活动标签都没有变化。
- 备注：`siqi/App/SiqiApp.swift:58-60` 调用 `closeCurrentTabOrWindow()`；需要继续排查 `SiqiWindowModel.closeActiveSession()` 或当前活动标签状态。

### F-02 Settings 打开为空白窗口

- 严重度：high
- 复现：
  1. 点击第二个 `View` 菜单。
  2. 点击 `Settings...`（也测试过 `⌘,`）。
- 期望：打开包含主题、字体、透明度、光标、权限等控件的设置窗口。
- 实际：`CGWindowList` 出现一个 500×500 的 siqi 窗口，位置为 `X=0, Y=669`；窗口内容为空白白色，主窗口没有可用设置界面。
- 证据：`docs/testing/evidence/2026-10-30-settings-blank.png`
- 影响：C-01..C-14 无法执行；设置相关功能整体不可用。

### F-03 TUI 程序右键被 siqi 菜单截获

- 严重度：high
- 复现：
  1. 在裸 shell 运行 `top`。
  2. 等 `top` 正常刷新后，在终端区域右键。
- 期望：右键交给 `top`/TUI 程序处理，siqi 菜单不出现。
- 实际：出现 siqi 的 Copy/Paste/Split/Clear/New Tab 菜单，`top` 没有获得右键。
- 备注：在 `top` 运行期间重复一次，结果一致；与 `R-02` 的预期相反。

### F-04 裸 shell 的 Ctrl+click 仍弹 siqi 菜单

- 严重度：medium
- 复现：
  1. 退出 `top`，回到裸 zsh。
  2. 关闭已有菜单后，按住 `⌃` 点击终端区域。
- 期望：不出现 siqi 右键菜单。
- 实际：出现同一套 siqi 菜单。
- 备注：与 `R-03` 的失败判据一致；需要区分 macOS 原生 control-click 与右键事件路径。

### F-05 `⌘K` 只输入 `clear`，不会立即清屏

- 严重度：medium
- 复现：
  1. 在 shell 运行 `echo BEFORE_CLEAR`。
  2. 按 `⌘K`，不按 Return。
- 期望：立即清空屏幕和 scrollback。
- 实际：当前提示符只出现文字 `clear`，屏幕仍保留旧内容；再按一次 Return 才真正清屏。
- 备注：`SiqiTerminalSession.clearScreen()` 当前发送 `"clear\n"`，可能是换行符与终端输入约定不一致。

### F-06 菜单栏出现两个 `Edit` 和两个 `View`

- 严重度：low
- 实际菜单栏顺序：`siqi, File, Edit, View, Edit, Terminal, View, Window, Help`
- 期望：每个标准菜单只出现一次，或明确使用自定义菜单替换标准菜单。
- 证据：菜单栏 AX 树及实际截图均显示重复项。

### F-07 前台进程没有更新标签标题和橙色状态点

- 严重度：medium
- 复现：
  1. 打开两个标签。
  2. 在标签内运行 `top` 或 `sleep 1000`。
  3. 观察标签栏。
- 期望：标签标题变为 `top`/`sleep`，并显示橙色前台进程圆点。
- 实际：标签标题仍为 `~`，没有橙色圆点。
- 备注：可能与当前构建日志中的 shell integration 不可用有关，但该行为仍与测试文档的期望不一致。

### F-08 重启后不恢复标签和分屏结构

- 严重度：medium
- 复现：
  1. 在一个窗口内创建两个标签，并在当前标签中执行 `⌘D` 分屏。
  2. 记录窗口结构：两个标签、左右两个 pane。
  3. 通过应用菜单 `Quit siqi` 退出，再重新启动。
- 期望：按 W-01 恢复两个标签和分屏结构。
- 实际：只恢复一个窗口和一个标签，分屏结构丢失。
- 证据：
  - `docs/testing/evidence/2026-10-30-window-restore-before.jpg`
  - `docs/testing/evidence/2026-10-30-window-restore-after.jpg`
- 备注：当前实现只恢复窗口几何，`SiqiWindowManager.swift:42-95` 和 `TerminalWindowController.swift:223-224` 没有保存/恢复 tab 或 pane 树的逻辑。

## 3. 未验证项

以下项目本轮没有足够可靠证据，不能标为 PASS：

- Dock 图标菜单 S-02..S-05、Finder 服务 S-06。
- 全屏、极小窗口胶囊 S-07..S-09（Computer Use 坐标缩放导致拖动结果不可靠）。
- 关闭确认 X-01..X-05；其中 X-01..X-03 还受 F-01 阻塞。窗口状态恢复 W-02..W-03（W-01 已确认失败）。
- 通知 N-01..N-03、Pin PN-01..PN-03、IME I-01..I-03。
- AI CLI 图片粘贴 P-05/P-06、空图 P-07、拖放 P-09/P-10、链接 L-01..L-05。
- 主题目录、设置控件、完整 30 个配置键、稳定性 ST-01..ST-05。

这些项需要在干净配置、单窗口、无其他 siqi 进程干扰的条件下继续跑。

## 4. 测试环境备注

- 本轮开始时没有 `~/.config/siqi/config`，应用回落到 `~/.config/suqi/config` 或 Ghostty 配置。
- 为验证热重载创建了临时 siqi 配置；测试结束后已删除，`~/.config/siqi/config` 已恢复为不存在。
- `~/.cache/siqi/pastes/` 中新增了两张测试图片，均为 10,130 bytes，非 0 字节：
  - `paste_20261030_152420.png`
  - `paste_20261030_152435.png`

## 5. 修复验证（2026-10-30 第二轮）

修复提交：`c396051` F-01，`a603702` F-06，`afb365a` F-02/F-03/F-04，`8a88a8f` F-07，`db7ce07` F-08，`35c1e98`/`95a6998` F-02 键盘路径。
安装版本：`./scripts/install.sh` Release 构建（全部修复后重装并实测）。

| 编号 | 状态 | 实测 | 证据 |
|---|---|---|---|
| F-01 | 已修复 | 3 个标签时 `⌘W` → 剩 2 个，活动标签切到相邻标签 | `evidence/2026-10-30-fix-f01-before-close.png`、`...-f01-after-close.png` |
| F-02 | 已修复 | 菜单 `Settings…` 与 `⌘,` 均打开 460×592 的完整设置窗口（主题/透明度/字体/间距/光标） | `evidence/2026-10-30-fix-f02-settings.png`、`...-f06-menubar.png` |
| F-03 | 已修复 | `top` 运行中右键：不出现 siqi 菜单，事件交给 TUI | `evidence/2026-10-30-fix-f03-tui-rightclick.png` |
| F-04 | 已修复 | 裸 shell `⌃`+点击：不出现 siqi 菜单 | `evidence/2026-10-30-fix-f04-ctrl-click.png` |
| F-05 | 已修复 | `echo BEFORE_CLEAR` 后 `⌘K`：立即清屏，不再输入字面 `clear` | `evidence/2026-10-30-fix-f05-before.png`、`...-f05-after.png` |
| F-06 | 已修复 | 菜单栏为 `siqi, File, Edit, View, Terminal, Window, Help`，Edit/View 各一个 | `evidence/2026-10-30-fix-f06-menubar.png` |
| F-07 | 已修复 | 运行 `top` 后标签标题变为 `top` 并出现橙色圆点；退出后恢复 `~` | `evidence/2026-10-30-fix-f07-top-running.png` |
| F-08 | 已修复 | 2 标签 + 右侧分屏 → 菜单 Quit → 重启后标签与分屏结构、窗口位置均恢复 | `evidence/2026-10-30-fix-f08-before-quit.png`、`...-f08-after-relaunch.png` |

单元测试：12 项全部通过（`xcodebuild test -project siqi.xcodeproj -scheme siqi -destination 'platform=macOS'`）。

备注：
- F-02 的 `⌘,` 在中文输入法下报 `，`（U+FF0C），libghostty 的 keybind 表会先截获该键；修复后按物理键位匹配，两种输入法都能打开设置。
- F-07 的进程名轮询每秒一次，仅作用于活动标签；若 shell integration 可用，标题仍以终端上报为准。

补充（复核后）：
- F-05 在 `top` 运行中按 `⌘K`：`top` 画面保持完整、无花屏（`evidence/2026-10-30-fix-f05-cmdk-in-top.png`），清屏只作用于普通屏幕。
- F-04 复核后 `⌃`+点击改为交给 libghostty 处理（保留其选中复制菜单），裸 shell 右键仍显示 siqi 菜单（`evidence/2026-10-30-fix-r01-bare-rightclick.png`）。
- F-02 设置窗口关闭/最小化后复用同一个 NSWindow，不再每次新建。
- F-08 恢复时若保存的目录已不存在（删除的项目、卸载的卷），该 pane 回落到 `~`。
