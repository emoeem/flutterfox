# 缺陷矩阵（04-defect-matrix，2026-11-10 第二轮全量复审）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §5/§6/§7/§8/§12.7，以当前工作区（feat/ui-redesign @ 5725231 + Phase 1 未提交改动）为准逐条验证。
- 更新（2026-11-11 复验轮）：P1-08/P1-09 关闭（QA 修复批次入树，代码 diff + 回归测试 + 实机目检三重核实）、P1-10 复拍全部完成（激活态实机截图补齐）；P1-11「同类残余」已于 QA 第 2 轮修复时改判已修复。本轮门禁（报告员实跑）：analyze 0 / flutter-test 246 / cargo-test 72+40 / dart-format 0 / cargo-fmt 0；Rust 零改动（git diff 为空）。
- 实机环境（本轮）：**Xvfb :2（1920x1080x24，无 WM）**，release 构建（`flutter build linux --release` exit 0），XTest 注入交互；另在 :1（niri 26.04 + xwayland-satellite）做窗口行为观察。第一轮会话（niri 全屏 1656x817）的证据仅标注引用，不冒充本轮复现。
- 评级口径（§12.7）：P0 数据错乱/播放不可用/崩溃；P1 核心操作无法完成/封面普遍缺失/关键页面不可用；P2 视觉与次要功能缺口；P3 可选增强/文档债。
- 基线事实与门禁数据：`docs/redesign/00-baseline.md`（§3 门禁、§9 播放链、§10 封面链）。

---

## P0（阻断级）

### P0-01 主 isolate 概率性卡死（搜索结果/播放后 UI 全死）——【开放；本轮未复现】

- **状态**：开放。第一轮会话 5 实例 3 复现（搜索结果到达后或播放启动后输入全失效、帧差=0）；**本轮 Xvfb 会话约 8 分钟全流程交互（搜索 259 结果渲染、双击播放、走带 3 分钟、队列/全屏播放页/五个页面导航/主题切换）未复现一次**。概率性缺陷的「未复现」不构成修复证据，根因仍未定位（Phase 1 加的事件速率观测 `voicefox events: N/5 s` 本轮持续输出正常，无洪泛/静默异常）。
- **第一轮复现步骤（存档，非本轮复现）**：release 构建 + `VOICEFOX_START_PAGE=search VOICEFOX_START_SEARCH=love` 启动 → 等待结果渲染 → XTest 点击任意行/侧栏 → 无响应；`x11tool key Tab` 两次后 `magick compare -metric AE f1.png f2.png` = 0。
- **影响**：用户视角=应用随机整体无响应；截图回归/交互验收在此缺陷未定位前对「长时间会话」不可信。
- **嫌疑方向（未定罪）**：AppModel 事件泵热路径（搜索结果 setState）、progress 4Hz 泵、library 事件 `_reloadCustomPlaylistDetails/_reloadAccountBrowse` 重取循环；需 profiler/devtools 定位。
- **2026-11-11 QA 复拍会话新增观察（同域，变体症状）**：Xvfb :5 多轮 boot 实测，ButtonPress 点击对 PlayerBar IconButton 间歇性完全失效（repeat/shuffle/pause 均复现），同期 hover 高亮与 tooltip 正常、进度渲染走带正常（AE 帧 diff ≠ 0）、事件流正常（19-24/5s），与第一轮「输入全失效 + 帧差=0」症状不同：渲染存活、仅按压失效；且同会话内行双击/next 按钮偶发有效，行为非确定性。两个实例并存、增量构建陈旧等环境变量已逐一排除（清理后仍复现）。定位优先级维持：长时间会话验收前必须定位。

### P0-02 播放中 position/duration 恒 0——【已关闭，Phase 1；本轮实机复核通过】

- **根因与修复**（Phase 1）：FRB 同步引导路径无 ambient tokio → `start_playback_pump` 的 `Handle::try_current()` guard 静默 return → 泵从未启动。修复 = `runtime/src/lib.rs:22-32` `enter_sync_bootstrap_runtime()`（进程级 `OnceLock<Arc<Runtime>>`，enter 作用域覆盖 `from_parts` 全函数体）。
- **本轮实机复核（Xvfb :2，release）**：
  1. 启动日志 `voicefox: 同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime` + `voicefox: playback pump started`（app-run3.log）。
  2. 双击搜索行播放 L-O-V-E（汽水）：PlayerBar `00:02 / 00:30`（docs/redesign/screenshots/baseline/linux-search-1440x900-playing-00-02-progress.png）。
  3. 曲目结束**自动切换下一首**：LOVE/Aki阿杰·5sing `00:00 / 02:34`（…ended-auto-next-00-00.png）——Ended 自动下一首同时复核通过（旧 P0-03 行为）。
  4. 26 秒后 `00:26 / 02:34` 走带（…00-26-progress.png）；stderr `voicefox events: 19-22/5 s, last=progress`（≈4Hz）。
- **回归测试**：runtime `sync_bootstrap_path_provides_tokio_context` / `ambient_runtime_path_is_untouched`；application `playback_pump_broadcasts_progress_for_watch_changes`（cargo-test 816 全绿内）。

## P1（功能缺口）

### P1-03 封面三元反写（有 URL 显示渐变占位）——【已关闭，Phase 1；本轮实机复核通过】

- **关闭证据（本轮）**：反写模式（`? null : CoverImage`）全仓 grep 为零；home/discover/search(专辑歌手网格)/playlist_detail 共 7 处走 `VxArtwork` + `ArtworkResolver`（负缓存/退避/TTL/单飞/限尺寸解码，13 项 artwork_widget_test 全绿）。
- **实机复核**：发现页酷我/酷狗热门歌单卡 12+ 张真实封面全部渲染（linux-discover-1440x900-default.png）；队列面板 2 行真实封面；首页最近播放本地曲「晴天」真实照片封面（linux-home-1440x900-playing.png）。
- **范围声明（维持）**：§8.2 解析优先级第 3 级（音源补全接口）与第 5 级（可靠实体匹配补全）未实现（后端补全链路依赖，phase-1-report 登记）；渲染级两项（本地封面真实解码/非图片字节真实解码）由 TestWidgetsFlutterBinding 环境所限，锁定在 resolver/回调契约层。

### P1-04 搜索「加载更多」丢失音源过滤——【已关闭，Phase 1；本轮代码+测试复核通过】

- **修复**：`FfiCommand::SearchMore` 带 `source: Option<String>`（ffi/src/lib.rs:1339-1345）；search_page `_loadMoreIfNeeded` 传 `_dispatchSource`；Rust `start_search` append 且 source=None 时**先读后写**沿用 `state.search.source`（application/src/service.rs:1462-1484）。
- **回归**：flutter/test/search_pagination_test.dart 4 项（本轮 flutter-test 229 全绿内）。
- **诚实标注**：本轮实机未做触底多页交互观察；正确性由代码链路核对 + 测试锁定。

### P1-05 进程静默退出（无崩溃日志）——【开放；本轮新增 1 例观察】

- **本轮观察（新增）**：:1 会话实例（run1）在经 xwayland-satellite 转发的 X 客户端 configure resize（1212x1274→1600x950→1920x1080，间隔数分钟）并出现 `Timed out waiting for OpenGL frame of size 948x1010 (have 1440x900)`（app-run1.log 23:35:38）后，数分钟内进程消失（pgrep 空、X 窗口消失）；日志无 panic、无 core dump（/var/lib/systemd/coredump 仅 vinput-daemon 旧核）、journal 无条目。
- **复现步骤（本轮实际操作）**：niri :1 会话启动 release 应用 → 对 X toplevel 连续 `XResizeWindow`（python-xlib configure）→ 等待 GL frame timeout → 数分钟内 `pgrep -f voicefox_flutter` 为空。
- **诚实声明**：触发链含非用户常规操作（X 客户端直发 configure 经 satellite 转发）；niri IPC 全屏路径（第一轮）与本轮 Xvfb 会话均未复现进程消失。与 P0-01 同域疑云（同属静默死亡），Phase 1 后续需一起定位；正常运行路径下的第一轮复现步骤（搜索+播放后停留，进程消失）保留。

### P1-06 Android 全链不可构建/未验证（环境阻断，非代码缺陷）——【维持】

- 无 JDK、SDK 无 emulator/system-images、adb 无设备 → `flutter build apk` 与真机/模拟器验证均无法执行；用户已明确搁置 Android 验证（禁止 APK/Gradle 构建与 AVD 创建）。指南 §5/§10/§12.6 真机 13 项全部未验证；MobileShell/TabletShell/AndroidInsets 仅有 widget 测试层覆盖（android_insets_layout_test 7 项）。

### P1-07 错误 toast 无高度上限且原始异常直出 UI——【已关闭，Phase 1；维持关闭声明】

- 修复两层（AppModel `sanitizeUserFacingMessage` 源头净化 + vendored toast maxLines 4/maxHeight 160）本轮代码复核在位（app_model.dart:1184-1208、toast_notification_widget.dart:69,104）；error_toast_test 9 项全绿。
- 运行时复现声明（维持）：离线失败状态未在运行时强造（隔离代理配置未生效，QA 环境失败条件不可复现），正确性由测试锁定。

### P1-08 搜索结果歌曲行封面普遍缺失（VxTrackRow 调用点漏传 cover）【已关闭，QA 修复批次 2026-11-11；代码+回归+实机三重复核】

- **现象**：搜索结果列表全部 259 行封面均为「渐变 + 首字母」占位，即使 DTO 带真实 cover_url。
- **根因**：`search_page.dart:550-568` 的 `VxTrackRow(...)` 未传 `cover:` 参数 → 组件缺省渲染 `VxCoverFallback`（vx_track_row.dart:166 `cover ?? VxCoverFallback(title)`，渐变首字母是 Phase 0 设计占位）。对照正确写法：`song_tile.dart:233` 同组件传了 `cover: CoverImage(url: song.coverUrl, size: 40, radius: 6)`。
- **实机对照证据（同一首歌、同一数据源）**：Love/Cloudy Skies（千千音乐）在搜索列表为渐变「L」占位（linux-search-1440x900-results.png），在队列面板显示真实封面（linux-queue-1440x900-playing.png 第 8 行，queue_panel.dart:208 CoverImage）。
- **复现步骤**：启动应用 → 搜索任意关键词 → 观察结果行封面：无一显示真实图片；播放其中一首 → 打开队列面板 → 同曲显示真实封面。
- **影响**：§12.7「封面普遍缺失」在搜索这一核心路径成立；§8.2「页面散落不同 fallback 决策」的活证据（同一 VxTrackRow，封面行为由调用点各自决定）。
- **修复（QA 修复批次 2026-11-11 入树，复验轮补录）**：search_page.dart 结果行 `VxTrackRow` 补传 `cover: VxArtwork(url: song.coverUrl, ...)`，行封面统一走 VxArtwork 路径（负缓存/失败占位/重试与全仓封面策略一致）。
- **回归**：`search_page_test.dart`「P1-08 回归：结果行封面走 VxArtwork，song.coverUrl 不再被渐变占位吞掉」（全套 flutter test 246 项内通过，2026-11-11 报告员实跑）。
- **实机复核（复验轮）**：`linux-search-1440x900-repeat-singleloop-active.png` 第 1 行（LOVE/3B LAB.☆）真实封面渲染（报告员目检），不再整列渐变/首字母占位。

### P1-09 浅色主题下 Shell Chrome 对比度破坏（导航/播放栏文字不可读）【已关闭，QA 修复批次 2026-11-11；代码+回归复核；P2-01 并入本行一并关闭】

- **现象**：设置 → 外观 → 明暗模式切「浅色」后：内容区（页面/卡片）正确变浅，但 **AppHeader、Sidebar、PlayerBar 背景仍是硬编码深色（VxColors.surface1 等）**，而其内部文字/图标颜色切为浅色主题的 onSurface（深色）→ 深底深字，左侧导航文字、左上角品牌字标、PlayerBar 歌名几乎不可读。
- **根因**：shell 组件无条件引用 `VxColors`/`VxDarkSurface` 硬编码深色常量（app_header.dart 4 处、app_shell.dart:481/571、app_sidebar.dart、context_panel.dart、player_bar.dart:76 等；唯 theme-aware 的是 player_bar.dart:177 seekTrack 三元）；MaterialApp 真源是 myune ThemeProvider `ColorScheme.fromSeed`（main.dart:384-386），Chrome 背景不走 ColorScheme。违反 §3.2「不使用硬编码页面颜色，全部从 Theme/ColorScheme token 获取」与「浅色主题必须完整支持」、§11.2 对比度 ≥4.5:1。
- **复现步骤**：启动应用 → 设置 → 外观 → 明暗模式点「浅色」→ 观察 Header/Sidebar/PlayerBar（截图 docs/redesign/screenshots/baseline/linux-settings-1440x900-light-theme.png）。
- **影响**：浅色主题下全局 Chrome 可读性破坏 → 「浅色主题完整支持」验收不成立。评级 P1（关键页面不可用级别的主题形态）。
- **修复（QA 修复批次 2026-11-11 入树，复验轮补录）**：`design_tokens.dart:148-157` 新增 `VxChrome`（`surface1(brightness)`/`divider(brightness)` 亮度双源：深色侧仍返回原 VxColors 常量、浅色侧返回 VxLightColors，深色像素零变化）；app_header/app_shell/app_sidebar/context_panel/player_bar 全部 Chrome 底色/分隔线改经 VxChrome。
- **回归**：`chrome_theme_test.dart` 5 项（VxChrome 纯函数双侧取值 + AppHeader/PlayerBar/ContextPanel/AppSidebar/VoicefoxShell 真实组件浅/深渲染色断言；全套 flutter test 246 项内通过，2026-11-11 报告员实跑）。
- **诚实标注**：浅色主题整页实机走查与对照截图本轮未重采（归 Phase 2/7 视觉批次）；收口由代码链路 + 真实组件渲染色测试锁定。

### P1-10 repeat 模式第 2 档（单曲循环）视觉不可区分 + QA 截图证据失实（QA 2026-11-11 复拍轮）【已关闭，复拍全部完成】

- **现象（QA 复拍轮登记）**：`repeat-mode-2.png` 原采集实际渲染非激活态（图标灰 rgb(167,168,177)）而非预期单曲循环激活态；根因有二：(a) 代码层两档循环共用 `Icons.repeat` 且同为 primary 色，激活态归属不可判定；(b) 采集点击硬编码坐标，实测 PlayerBar 控制列随歌名宽度位移 ±45px，点击可落旧位置。
- **修复**：`VxPlayerControls` 新增 `repeatSingle` 参数（vx_player_controls.dart），single-loop 档渲染 `Icons.repeat_one` + tooltip「单曲循环」，list-loop 档 tooltip「列表循环」，none 档灰色「循环播放」；`player_bar.dart`/`now_playing_page.dart` 接线。回归 `repeat_mode_test.dart` 4 项（三档视觉 + 循环点击顺序经真实 PlayerBar 代码）。
- **复拍状态（全部完成，2026-11-11 复验轮）**：`repeat-mode-1.png`（list-loop 激活：播放中 + config.toml 地面真值 + primary 蓝采样 + tooltip）；`repeat-mode-2.png`/`-glyph.png`（single-loop：config 地面真值 + repeat_one 字形 + tooltip「单曲循环」）；**激活态已补齐**：`linux-search-1440x900-repeat-singleloop-active.png`（03:57，真实播放中 repeat_one 字形 primary 蓝激活，报告员目检确认；复验轮记录 config.toml `play_mode="single-loop"` 落盘核对），激活态不再仅由测试锁定。
- **环境勘误**：增量 release 构建的 MaterialIcons 字体子集陈旧导致新字形（repeat_one）不渲染，`flutter clean` 重建恢复（详见 phase-1-mobile/README.md）。

### P1-11 搜索页错误框直出原始 URL/异常（P1-07 同类新表面，QA 2026-11-11）【已修复】

- **现象**：`linux-search-1440x900-error-retry.png` 错误框 detail 直出 migu 原始 URL；`state.search.error` 为 Rust 快照字段，不经 `lastError/lastNotification` 净化链路（app_model.dart:265-270 search 事件仅 `_refreshState`）。
- **修复**：`AppModel.sanitizeUserFacingMessage` 公开化（app_model.dart），`search_page.dart` 错误框渲染前净化（URL 打码/空白折叠/截断 140，与 P1-07 toast 同口径）；原始异常仍在命令/事件层写 stderr。
- **回归**：`search_page_test.dart`「P1-07 同类缺口回归」（原始 URL 不得直出、[URL] 占位呈现）。
- **同类残余（QA 第 2 轮 2026-11-11 确认后已修复）**：发现页/歌单页 `BrowseResult.error` 直出（`_applyBrowseEvent` page=0 分支原样落槽）已在本轮修复：错误与 notice 均在 `_applyBrowseEvent` 源头净化（app_model.dart，单点收口覆盖 discover/playlist/leaderboard/library/custom_playlists 全部消费面），错误走 `_logAndSanitize`（原始异常写 stderr）；回归 `playlist_detail_isolation_test.dart`「P1-11 回归」；实机复拍 `linux-discover-1440x900-error-retry.png`（离线 netns 实例，错误框显示 `([URL]`，原始 URL 仅在 stderr 日志）。

## P2（登记）

| ID | 问题 | 证据 | 指南条款 |
|---|---|---|---|
| P2-01 | 【已关闭，随 P1-09 关闭（2026-11-11 复验轮）】VxColors/VxDarkSurface 硬编码深色常量被 shell 组件无条件引用；已收口为 VxChrome 亮度双源 token（design_tokens.dart:148-157，浅色侧 VxLightColors，深色像素零变化） | chrome_theme_test 5 项 + 代码 diff | §3.2 |
| P2-02 | 双 ThemeData 产源：运行时真源 = myune ThemeProvider；`design_system/voicefox_theme.dart` buildDark/LightTheme 仅 Gallery 页与测试使用（当前只有一套运行时真源，风险受控） | grep buildDarkTheme 调用点 | §1.2-4 |
| P2-03 | 发现页/首页横向书架最右卡被窗口右缘裁切（实机 1440 视口复现：「伤悲：眼泪的心!」「DJ歌曲抖音…」右缘截断） | linux-discover-1440x900-default.png | §12.5 |
| P2-04 | 窗口尺寸契约在 niri 下不可靠：请求 1440x900 实得 tile 1212x1274（surface 948x1010，<960 触发降级布局）；Xvfb 下请求即所得。验收截图须在受控显示器采集 | 第一轮 + 本轮 :1 观察；本轮 Xvfb 对照 | §12.4 |
| P2-05 | 桌面系统集成（MPRIS/托盘/系统通知）GUI 未接；Rust 侧 app/src/mpris.rs 存在 | 代码 | §12.6-8 |
| P2-06 | 移动全屏播放页只有竖向手势（下滑关闭），无 §5.7 横向滑动切歌；未实机验证（无设备） | mobile_now_playing_page.dart 代码 | §5.7 |
| P2-07 | 【已修复】设置页左侧分类导航 9 组（播放与音效/音源/下载/歌词/外观/网络/账号与集成/快捷键/关于） | linux-settings-1440x900-default.png | §7.3 |
| P2-08 | xwayland-satellite 转发的 X 客户端 resize 触发 `Timed out waiting for OpenGL frame`，随后进程静默消失（关联 P1-05 观察）；niri IPC 与 Xvfb 路径未见 | app-run1.log + pgrep/coredump 取证 | §11 |
| P2-09 | 队列拖动排序 / 队列内跳播：后端无对应 FfiCommand，UI 禁用并说明（不伪造）；§7.4「拖拽排序」目标待后端命令落地 | queue_panel.dart:8-10 | §7.4 |

## P3（可选增强 / 文档债）

| ID | 问题 | 证据 |
|---|---|---|
| P3-01 | 【已修复】cover_loader.dart 头注释更正为「没有磁盘缓存」 | 代码 |
| P3-02 | readAudioInfo 悬空桥（7 处调用、so 无导出），调用点均有 try/catch 降级（「未知歌手 (解析失败)」），维持 P3 | 第一轮 nm 取证 + 本轮代码抽查 |
| P3-03 | 【Phase 1 已落地→长期验证记录】PlaylistKey(kind,source,id) 类型化键 + appendArmed 过期 append 丢弃；playlist_detail_isolation_test 7 项覆盖 §8.1 八步序列的 widget 层映射；实机八步序列未走查 | app_model.dart:23-42,470-516 |
| P3-04 | PlaylistDto 无 creator/play_count/link（into_playlist 全丢），歌单详情 Hero 元数据受限 | ffi/src/lib.rs:448-461 |
| P3-05 | ATK `atk_socket_embed` 断言失败与 OpenGL frame timeout 告警（运行日志非致命；后者与 P2-08 关联观察） | 运行日志 |
| P3-06 | CONTRIBUTING.md 基线数字过时（「53 tests」实为 229）；KEYBINDINGS.md 为 TUI 文档，GUI 键位无独立文档 | 文档对照 |
| P3-07 | 全屏播放页歌词仅空态文案（「本版本暂无手动重新获取入口」自认）；5sing 等源未取到歌词时无手动重取 | linux-nowplaying-1440x900-playing.png |

## 已验证正常（本轮实机/门禁证据，避免重复修复）

- 播放链路端到端：走带三连证据 + Ended 自动切歌 ×2 + 4Hz 事件泵（§9/矩阵 P0-02）。
- 封面链路：发现页多源真实封面、队列真实封面、首页本地封面（P1-03 关闭证据）。
- 队列：当前曲高亮（行内均衡器图标）、单曲移除按钮、清空确认、随机开关、共 259 首/接下来播放 256 计数（linux-queue-1440x900-playing.png）。
- 全屏播放页：渐变占位封面（非黑块）、进度走带、音量条真实值（80 与配置一致）、诚实歌词空态（linux-nowplaying-1440x900-playing.png）。
- 设置：左侧分类导航 9 组、明暗三态切换即时生效（深→浅→深往返）、主题矩阵渲染（linux-settings-1440x900-*.png）。
- 曲库：快捷卡真实计数（最近播放 7/本地 0/喜欢 0）、分类 chips 计数（专辑 6/歌手 5 来自真实聚合）、来源分段（linux-library-1440x900-songs.png）。
- 下载页四分段 + 表头 + 空态引导（linux-downloads-1440x900-empty.png）。
- 静态门禁全绿：dart-format/analyze/cargo-fmt exit 0；flutter-test 229、cargo-test 816 全通过（00-baseline §3）。
- 事件流 lag 自愈、SetVolume 真实通路、搜索防抖/in-flight 锁、reduce-motion、错误净化（代码复核 + 测试维持第一轮结论）。

## Phase 1 退出条件核对（§13）——【本轮复审后更新】

| 条件 | 状态 |
|---|---|
| P0 清零 | P0-02 已关闭；P0-01 开放但本轮未复现（根因未定位，不能宣称修复） |
| 歌单隔离测试 | ✅ widget 层 9 项（新增 §8.1 序列 7：A 触底分页在途切 B 迟到页 2 只落 A 槽；实机八步未逐项走查，隔离对照三连实机通过，见 P3-03） |
| 封面错误态 | ✅ 13 项；P1-08 搜索结果行封面已关闭（cover: VxArtwork + 回归 + 实机目检） |
| 手机系统栏无重叠 | widget 层 ✅；真机未验证（P1-06 环境阻断维持） |
| 本地音乐真实导入并播放 | 未达成（无媒体文件，Phase 5） |
| 播放状态/进度/duration/seek/Ended（§8.3） | ✅ 实机走带三连 + 自动切歌 ×2 |

**下一阶段进入条件**：P1 全部关闭（P1-03/04/07/08/09/10/11），Phase 2 可进入；P0-01 继续以「概率性未复现」状态跟进，长时间会话验收前必须定位（ButtonPress 间歇失效同域观察在案）；浅色主题实机整页走查归 Phase 2/7。
