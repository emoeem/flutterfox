# 缺陷矩阵（04-defect-matrix，2026-11-10）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §5/§6/§7/§8/§12.7，以当前代码（feat/ui-redesign @ d9ee22f）为准逐条验证。
- 每条 P0/P1 均在本会话真实复现（实机交互或命令输出），附复现步骤与证据；未验证项明确标注。
- 实机环境：Linux 桌面（niri + xwayland-satellite，DISPLAY=:1），release 构建（`flutter build linux --release` exit 0）。
- 基线事实与门禁数据见 `docs/redesign/00-baseline.md`。

评级口径（§12.7）：P0 数据错乱/播放不可用/崩溃；P1 核心操作无法完成/封面普遍缺失/关键页面不可用；P2 视觉与次要功能缺口；P3 可选增强/文档债。

---

## P0（阻断级，进入 Phase 1 前必须关闭）

### P0-01 主 isolate 概率性卡死（搜索结果加载 / 开始播放后 UI 全死）

- **现象**：UI 渲染完全停止（连播放行动画在内 4 秒两帧逐像素 diff = 0），指针点击、键盘输入全部无响应；进程通常仍存活，1 例最终进程消失（见 P1-05）。
- **发生率**：本会话 5 个独立实例中 **3 例卡死**（#2/#3/#5），时点分别在搜索结果到达后数秒（#2/#3，未播放）或开始播放后数秒（#5：悬停/行内播放按钮尚可响应，播放启动后全部输入失效）；实例 #1 存活较久（完成搜索+播放）但播放后 position 同样冻结（见 P0-02），最终进程消失（P1-05）；实例 #4 另有「进程存在但窗口从未出现」的启动异常（未诊断，被手动终止）。
- **复现步骤**（本会话实际操作，桌面 release 构建）：
  1. `cd flutter/build/linux/x64/release/bundle && setsid env DISPLAY=:1 GDK_BACKEND=x11 VOICEFOX_START_SIZE=1440x900 VOICEFOX_START_PAGE=search VOICEFOX_START_SEARCH=love ./voicefox_flutter`
  2. 通过 niri IPC FocusWindow + FullscreenWindow 置于前台。
  3. 等待搜索结果渲染（257 个结果，约 10–15s）。
  4. 用 XTest（`/tmp/vx-audit/x11tool`，经 :1 X server 注入）点击任意行/侧栏/头部按钮 → 无响应。
  5. 验证冻结：`x11tool key Tab` 两次后 `magick compare -metric AE f1.png f2.png` → **0**（无焦点环、无任何像素变化）。
- **证据**：基线截图 linux-search-1656x817-results.png（冻结前最后状态）；4 秒帧差 = 0（实例 #5，正在播放状态下连均衡器动画都停止）；实例 #2/#3 各自 `x11tool key Tab` 两次后帧差 = 0（无焦点环出现）；实例 #2 点击侧栏「首页」两次均不导航。
- **影响**：任何交互验收/截图回归在此缺陷修复前不可信；用户视角=应用随机整体无响应。
- **嫌疑方向**（供 Phase 1 排查，未定罪）：AppModel 事件泵与 UI 重建的热路径（搜索结果 257 行 setState）、progress 4Hz 泵、`_reloadCustomPlaylistDetails/_reloadAccountBrowse` 的 library 事件重取循环；需要 profiler/日志定位（RUST_LOG=debug 已开但日志无异常输出——isolate 卡死通常无声）。

### P0-02 播放中 position/duration 恒 0（进度条不走、总时长 --:--）

- **现象**：真实播放已启动（PlayerBar 显示歌曲 L-O-V-E/Aimer·soda、暂停键=播放中、行内均衡器图标），但进度恒 `00:00`、总时长恒 `--:--`，等待 20s、40s、60s 后三张截图均无变化。
- **与旧审计的关系**：UI_AUDIT_DESKTOP 的 P0-A2 当时只记录「duration 恒 0（position 已实时 00:21 走动）」；本次实测 **position 也不走**——比 11-06 更严重，或与 P0-01 卡死耦合（第一张播放截图拍摄于播放开始后 ~5s，position 已应 >0 仍为 00:00）。
- **复现步骤**：
  1. 按搜索页流程得到结果列表（实例 #1：header 搜索框输入 love 回车；实例 #5：VOICEFOX_START_SEARCH=love 种子）。
  2. 双击或点击行内「播放」按钮（悬停行尾出现 ▶）启动 L-O-V-E（汽水音乐）。
  3. 观察 PlayerBar：`00:00 / --:--`；sleep 20/40/60 后重截——不变。
- **证据**：docs/redesign/screenshots/baseline/linux-search-1656x817-playing.png（00:00 / --:--）。
- **代码层链路完整性**（泵存在、断点在下游）：engine duration observer（engine.rs:453-455）→ application 泵（service.rs:163-247）→ FFI progress 事件 → AppModel `_applyPlaybackProgress`（app_model.dart:255-279）→ PlayerBar。需按 §8.3 逐环断点定位（engine watcher 是否对汽水流吐数、4Hz 泵是否被 P0-01 卡死拖死）。
- **影响**：§8.3 核心数据正确性破坏：seek 不可用、LivePlayback 插值被 duration>0 挡住、歌词推进失效。

## P1（功能缺口）

### P1-03 封面三元反写：有真实封面 URL 时显示渐变占位（封面普遍缺失）

- **代码证据**（4 处同一反写模式）：
  - `flutter/lib/src/pages/discover_page.dart:571-578`：`cover: (playlist.coverUrl?.isNotEmpty ?? false) ? null : CoverImage(url: ...)`——URL 非空 → 传 null → `VxCardShell`（vx_card_shell.dart:35-36「null 用渐变首字母占位」）渲染渐变；URL 空 → 才建 CoverImage。
  - `flutter/lib/src/pages/home_page.dart:147-149`（Continue Hero）、`:207-209`（最近播放书架）、`:260-265`（我的歌单卡）——同样反写。
  - 对照正确写法：`library_page.dart:595-601`（空 → VxCoverFallback，非空 → CoverImage.expand）。
- **实机证据**：基线截图中发现页酷我热门歌单卡（古风戏腔/短视频DJ/爱的故事随笔…8+ 张）与首页继续收听/最近播放封面全部为渐变首字母占位；按数据面 kw 歌单通常带 cover_url（被反写丢弃）。
- **复现步骤**：启动应用 → 发现页 → 观察热门歌单卡：无一显示真实封面。
- **影响**：§12.7「封面普遍缺失」= P1；§5.3/§7.3 页面视觉围绕封面组织的目标落空。
- **修复**：4 处条件对齐 library_page 写法（约 4 行改动），随后再进 §8.2 ArtworkResolver 统一改造。

### P1-04 搜索「加载更多」丢失音源过滤（第 2 页起回落聚合）

- **代码证据**：`ffi/src/lib.rs:1516-1520`——`FfiCommand::SearchMore { keyword, page } => ApplicationCommand::SearchMore { keyword, page, source: None }` 硬编码 None；而 Search 首页支持 `source: Option<String>`（搜索页单源筛选时下发，search_page.dart:129-132）。
- **复现步骤**：搜索页音源筛选选 1 个源（如酷狗）→ 搜索 → 触底加载第 2 页 → 第 2 页请求无 source 过滤，混入其他音源结果。
- **状态**：与 UI_AUDIT_DESKTOP P1-C3 一致（本次代码复核确认未修）。
- **影响**：违反指南 §5.4「分页响应只能合并到同一 PlaylistKey/同一查询上下文」与 §8.1 过期/异源响应不得覆盖当前页面语义。

### P1-05 进程静默退出（无崩溃日志）

- **现象**：实例 #1 在成功播放一首（汽水源）并停留约 1 分钟后、第二次双击另一音源（酷狗）曲目时，进程直接消失（`pgrep` 空、niri Windows 列表无窗口）；`app-run3.log` 无任何错误/panic（末行为 PipeWire client.conf 告警）；`/var/lib/systemd/coredump` 无 voicefox core；journalctl 无相关条目。
- **复现步骤**：实例 #1 流程——搜索 love → 双击行 1（汽水 L-O-V-E）播放 → 停留 ~60s → 双击行 5（酷狗 Love/BEYOND）→ 进程消失（`pgrep -f voicefox_flutter` 为空）。
- **证据**：/tmp/vx-audit/app-run3.log（无异常）；崩溃时点前后 journal/dmesg 无记录。
- **影响**：用户丢会话；与 P0-01 同域（疑同根因的不同表现），Phase 1 需一起定位。
- **诚实声明**：仅 1 例，未稳定复现；不排除外部因素，但同会话内其余进程均存活。

### P1-06 Android 全链不可构建/未验证（环境阻断，非代码缺陷）

- **事实**：无 JDK（`java` 不存在）、SDK 无 emulator/system-images、adb 无设备 → `flutter build apk` 与任何真机/模拟器验证均无法执行；Rust Android FFI 交叉链（NDK 存在）也未在本会话执行。
- **影响**：指南 §5（手机 UI）、§10（Android 系统集成）、§12.6 真机 13 项全部 **未验证**；MobileShell/TabletShell 仅 widget 测试覆盖。
- **处置**：需要用户环境补 JDK（+ emulator 或真机）后按 §12.6 清单补验；在此之前任何「移动端可用」的说法都不成立。

## P2（登记，不影响主流程修复优先级排序）

| ID | 问题 | 证据 | 指南条款 |
|---|---|---|---|
| P2-01 | `VxColors`/`VxDarkSurface` 硬编码深色常量被 shell 组件**无条件**引用（AppHeader :74-75、Sidebar app_shell.dart:481/571、ContextPanel :61、PlayerBar :76-77 等 11 个文件）；MaterialApp 真源是 myune ThemeProvider 的 `ColorScheme.fromSeed`（main.dart:384-386）。浅色主题下 Chrome（头部/侧栏/右栏/播放栏）预期仍是深色。**未实机验证**（浅色切换被 P0-01 阻断） | 代码 grep；§3.2「不使用硬编码页面颜色」「浅色主题必须完整支持」 | §1.2-4 / §3.2 |
| P2-02 | 双 ThemeData 产源：运行时真源 = myune ThemeProvider；`design_system/voicefox_theme.dart` buildDark/LightTheme 仅 Gallery 页与测试使用——与 §1.2-4「不得两套 ThemeData 并存为真源」相悖（当前只有一套运行时真源，另一套是画廊预览，风险中等） | grep buildDarkTheme 调用点 | §1.2-4 |
| P2-03 | 发现页/首页在线歌单卡为横向书架，最右卡被窗口右缘裁切（实机截图 linux-discover-1656x817-default.png 右缘「听」字半截）；与旧 U-07/P2-V2 同类问题在新壳上重现 | 截图 | §12.5 |
| P2-04 | 窗口尺寸契约在 niri+xwayland-satellite 下不可靠：VOICEFOX_START_SIZE=1440x900 未生效（tile 1212x1274）、FullscreenWindow 后 niri 报 window_size 1920x1080 而 GL frame 报 1440x900（渲染 ~1656x817 居中留黑边）；桌面截图视口命名按实际 1656x817 | 实机日志 + 截图 | §12.4 |
| P2-05 | 桌面系统集成（MPRIS/托盘/系统通知）GUI 未接；Rust 侧 app/src/mpris.rs（350 行）与 11-06 实机「系统面板显示暂无播放内容」均在。Phase 6 计划项 | 代码 + 旧实机记录 | §12.6-8 |
| P2-06 | 移动全屏播放页只有竖向手势（下滑关闭，mobile_now_playing_page.dart:160/282），无 §5.7 要求的横向滑动切歌（有视觉反馈且不与系统返回冲突）；未实机验证（无设备） | 代码 | §5.7 |
| P2-07 | 设置页为单列长页（9 分组），无左侧分类导航（实机截图 linux-settings-1656x817-default.png；9 组内容本身齐备） | 截图 | §7.3 |

## P3（可选增强 / 文档债）

| ID | 问题 | 证据 |
|---|---|---|
| P3-01 | `myune_seam/cover_loader.dart:1-5` 注释宣称「磁盘缓存（系统临时目录）」，实现只有内存 LRU——注释与代码不符 | 代码 |
| P3-02 | readAudioInfo 悬空桥仍存在（7 处调用、so 无导出），但各调用点均有 try/catch 降级（playlist_content_notifier.dart:1073-1076 等）→ 旧 P0-A1 降级；触发时表现为「未知歌手 (解析失败)」而非崩溃 | grep + nm（导出 0） |
| P3-03 | 指南 §8.1 建议的显式 PlaylistKey(source,id,type) 抽象未建立；现状以 browseKind 字符串进 key 实现语义隔离（`'$kind|$source|$id'`，app_model.dart:293）——隔离成立但类型化键（含过期响应校验的 request token 化）待 Phase 1 落地 | 代码 |
| P3-04 | PlaylistDto 无 creator/play_count/link/extra（into_playlist 全丢，ffi/src/lib.rs:448-461），歌单详情 Hero 无法显示创建者等元数据 | 代码 |
| P3-05 | ATK `atk_socket_embed` 断言失败与 OpenGL frame timeout 告警（运行日志持续出现；Impeller 已禁用仍报）——非致命 | 运行日志 |
| P3-06 | CONTRIBUTING.md 基线数字过时（「53 tests」实为 189）；KEYBINDINGS.md 为 TUI 文档，GUI 仅 5 键且无键位文档（旧 P2-V6 延续） | 文档对照 |

## 已验证正常（旧问题确认已修，避免重复修复）

- 事件流 lag 自愈：1s 退避重订阅 + 整份重拉快照（app_model.dart:164-186）。
- SetVolume 真实通路（FFI 命令 → application service → mpv；PlayerBar 滑条下发）。
- 搜索防抖 300ms + 分页 in-flight 锁 + requestId 失效释放（search_page.dart:74-77/110-125/151-167）。
- 队列当前曲高亮/单曲移除/清空确认（queue_panel.dart:33-60/114/130）。
- reduce-motion：`MediaQuery.disableAnimationsOf` 已用于全屏转场等 5 处。
- 图标按钮 tooltip 覆盖面广（实机悬停可见「播放」tooltip）。
- 播放历史/继续收听持久化：重启应用后首页 Hero 与最近播放仍在（实机证据 linux-home-1656x817-history.png）。
- 错误/通知统一出口（lastError/lastNotification → ToastOverlay；空时 SizedBox.shrink 不挡交互）。
- 静态门禁：dart format / flutter analyze / flutter test 189 / cargo fmt 全绿（见 00-baseline §3）。

## Phase 1 进入条件核对（§13）

| 条件 | 状态 |
|---|---|
| P0 清零 | **未达成**（P0-01 卡死、P0-02 进度/时长） |
| 歌单隔离测试 | 代码层 key 隔离成立（kind+source+id）；8 步测试序列未执行（被 P0-01 阻断交互） |
| 封面错误态 | 组件层占位/重试在；真实封面渲染被 P1-03 反写阻断 |
| 手机系统栏无重叠 | 未验证（无设备） |
| 本地音乐真实导入并播放 | 桌面链路代码在；实机未走通（P0-01 阻断交互；本地目录为空也无媒体文件） |
