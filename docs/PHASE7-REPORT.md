# Phase 7 报告：平板与移动端 UI（桌面冻结后）

日期：2026-11-07　执行：工作流自动实施（提交 c2c72fa，未推送）

计划书依据：`flutterfox-ui-redesign-plan-v2.md` Phase 7 节。前置条件（桌面 UI 冻结并通过验收后才开始）经批次 0 门禁落实：先于 HEAD 3446162 重建冻结态 release bundle 并实机复核，再动 `lib/` 代码。

## 实施前架构勘察（冻结态 HEAD 3446162）

- 现有 Flutter 端是桌面单壳架构：`main.dart` 无条件走桌面引导（windowManager.ensureInitialized + AppModel.bootstrapDesktop，经 FRB newDesktop 的 libmpv 后端）；唯一外壳 VoicefoxShell（AppHeader + AppSidebar + IndexedStack 页面区 + ContextPanel + PlayerBar）；断点由纯函数 resolveShellMetrics 驱动（1440 三栏 / 1200 右栏浮层 / 960 侧栏折叠，勘察时点 `responsive_shell.dart:74-97`），<960 仅降级隐藏侧栏，尚无手机壳与移动断点。
- 播放域：PlayerBar 92px 常驻且 <760 已有逐级收缩路径（`player_bar.dart:65-74`）；全屏 NowPlayingPage 是桌面式封面 46% + 歌词 54% 并置（勘察时点 `now_playing_page.dart:349-373`）；队列经 _QueueSheet 侧板复用 QueuePanel；LyricsPanel 自带 compact 参数可直接复用；全页无手势交互。
- 设计系统独立于壳（design_tokens.dart 静态 Token 深浅两套 + 15 个 Vx 组件 + gallery_page），共享给移动端零成本。
- 状态面：AppModel 是单 ChangeNotifier + Rust 事件泵，页面只依赖 AppModel；导航经 nav_bus.dart 两个 ValueNotifier 弱耦合。换壳成本低，页面/组件可原样被 MobileShell 复用。
- Rust 侧已为移动预留边界：lx-player 的 mpv 引擎锁在 desktop-mpv feature；PlayerBackend trait + ApplicationRuntime::from_parts 支持注入任意播放后端；ffi 已有 from_application/setDataDir 宿主引导；非 mpv Android ABI 本轮实跑 cargo check 通过。

## 已完成任务表（实测）

| 项 | 状态 | 说明 |
|---|---|---|
| 批次 0 门禁：桌面冻结基线 | ✅ | 动 `lib/` 前于 HEAD 3446162 重建冻结态 release bundle，niri 空工作区实机运行，set-column-width（1920 档 fullscreen）+ screenshot-window 补拍 1920/1280/1024 暗色与浅色 2 张（浅色经真实配置链路 config.toml [theme] name=catppuccin-latte mode=light，设置页明暗分段控件实拍显示「✓ 浅色」；环境无指针注入，未在运行中点击切换控件，方法已记入 PHASE6-REPORT.md 附录）。5 张截图入库 docs/shots/，完成度矩阵两处 ⚠ 改 ✅；顺带记录浅色下壳 chrome 仍为 VxColors 暗面常量（冻结前既有状态） |
| 任务 2/3：平台门控 + UI-only 无 Rust 引导 | ✅ | `main.dart` 增 _isDesktopWindowPlatform = !isTouchPlatform（responsive_shell.dart 新增 dart:io 版 isTouchPlatform，全仓禁用 defaultTargetPlatform），门控 windowManager/窗口尺寸/VOICEFOX_START 窗口钩子与 AppHeader 窗控+DragToMoveArea（桌面树零变化）；新增 kUiOnly = bool.fromEnvironment('VOICEFOX_UI_ONLY') && kDebugMode 无 Rust 引导分支（跳过 window_manager 与 bootstrapDesktop，VoicefoxApp.uiOnly 以测试同款最小 Provider 集渲染壳，页面真实空/错误态如 SettingsPage「配置加载中…」） |
| 任务 4：触屏形态路由 | ✅ | `responsive_shell.dart` 仅新增（git diff 零删除行）：resolveDeviceFormFactor/resolveTabletLayout/MobileBreakpoints 纯函数；桌面平台恒 desktop，宽度不参与；VoicefoxApp home 触屏才路由 TouchShell |
| 任务 5：MobileShell | ✅ | 新建 `mobile_shell.dart`（TouchShell/MobileShell：底部 NavigationBar 五主入口、MiniPlayerBar 无歌不进树、顶栏「更多」抽屉复用完整 AppSidebar 承载设置/帮助、navRequest/nowPlayingRequest 同语义消费复位、PopScope 先退全屏、全屏打开时导航/迷你栏随壳隐藏防双控）；从 `app_shell.dart` 提取共享 kShellDestinationOrder/kShellPrimaryDestinations/mapLegacyNavIndex/buildShellPage（原 _pageFor）；`app_sidebar.dart` 公开 shellDestinationIcon |
| 任务 6：MiniPlayerBar | ✅ | 新建 `mini_player_bar.dart`：封面+歌名+播放暂停/下一首接 model.toggle/next 真实命令，顶部 2px 进度线复用 LivePlayback，点击经 nowPlayingRequest 总线开全屏 |
| 任务 7：TabletShell 三态 | ✅ | 600-899 图标 Rail / 900-1199 展开 Rail 双栏 / ≥1200 三栏 ContextPanel 内嵌无 Positioned（其下浮层）；自持顶栏含面板开关；底部迷你播放栏 |
| 任务 8：触屏长按菜单 | ✅ | VxHoverBuilder/VxTrackRow 增 onLongPressStart，SongTrackRow/SongTile 长按弹 showSongMenu 同一菜单（真实命令，_RecordingModel 断言）；桌面右键行为回归不变，hover 操作由长按菜单全量替代；song_table_view 行经 SongTrackRow 无需直改；nav_bus.dart 无需改动 |
| MobileNowPlayingPage 分层全屏 | ✅ | `now_playing_page.dart` 提取 4 个可复用件公开化（NowPlayingBackdrop/NowPlayingAutoPalette/CrossfadeCover/NowPlayingActionRow，LiveSeekRow 本就公开），桌面内部引用同步改名行为零变化；新建 `mobile_now_playing_page.dart`：封面/歌词/队列三态分层（AnimatedSwitcher），手势 = 封面层点击或上滑进歌词层、下滑退出整页（速度阈值 120px/s）；歌词层复用 LyricsPanel compact、队列层复用 QueuePanel；封面层按可用高度自适应不接滚动容器保证手势命中，极矮视口（<560 高）退化为滚动布局并停用手势；两壳全屏页换用 MobileNowPlayingPage |
| TouchShellSession 跨档状态 | ✅ | 跨档共享目的地/Rail 高亮/全屏开关，旋转拖窗跨 600 档导航与全屏状态不丢；TouchShell 增 touchPlatformOverride 显式注入（测试用），桌面 factor 兜底渲染空 |
| 桌面冻结复验（第二批） | ✅ | 重构建 release bundle 实拍 1440/1150/800 三档（docs/shots/20261107-p7b2-*.png：侧栏展开/折叠 72/降级隐藏+菜单钮+播放栏常驻全部与基线行为一致）；同视口逐像素对照：当前代码 1280 截图对批次 0 冻结基线（20261107-vp-1280-home.png）RMSE=0，提取共享组件后桌面渲染逐字节不变 |
| 移动专项测试 | ✅ | viewport_matrix_test.dart 10 例（平台隔离 + 视口×数据状态抽样 360×800/600×900/768 图标 Rail 档+右栏浮层/1024 展开 Rail 档 + 断点穿越 390→900、600×900→900×600 旋转、900→390：导航 selectedIndex 保持、AppModel 播放位置不重置、全屏页跨档保持打开）；mobile_now_playing_test.dart 8 例（三态切换/点击/上滑/下滑退出/歌词数据/队列禁用/空队列/空态） |

### 计划外必要修复（实施中发现，非计划书 Phase 7 项）

| 修复 | 说明 |
|---|---|
| 三处窄宽溢出 | vx_hero/vx_player_controls/now_playing_page：Row 改 Wrap+Flexible，桌面内容放得下时渲染逐字节一致 |
| VxHero 纵排堆叠档 | 窄内容区（<320，360 宽手机）封面 178px 把文字列压到 76px 导致按钮逐字换行溢出；增纵排档后桌面全部档位（含 <960 降级档最小约 480 内容宽）不受影响 |
| LibraryPage 标签行 | Row 改 Wrap（放得下时视觉一致）；此前 360 宽 Home 页 8px 溢出同源修复 |
| Android 构建对齐 | 模板 compileSdk 31 被 dynamic_color 传递依赖卡死，`app/build.gradle.kts` 定 36 + 根 `build.gradle.kts` 子工程对齐；仅构建期，applicationId/签名/权限仍留 Phase 8 |

## 验收状态

- 门禁记录（实施时实测）：
  - analyze 第 1 轮：exitCode 0，输出 "No issues found! (ran in 2.9s)"
  - test 第 1 轮：exitCode 0，输出 "00:14 +183: All tests passed!"
- 报告撰写时复核（2026-11-07，HEAD c2c72fa，工作区干净）：实跑 `flutter analyze --fatal-infos` 得 "No issues found! (ran in 2.9s)"（exit 0）；实跑 `flutter test` 得 "00:14 +183: All tests passed!"（exit 0），与门禁记录一致
- 测试构成：flutter test 全量 183 例 = 基线 145 + 本阶段新增 38（第一批靶向回归 12 个既有测试文件 80 例全过 + 新增 4 文件 20 例：mobile 7/tablet 7/长按 4/uiOnly 2；第二批新增 viewport_matrix 10 例 + mobile_now_playing 8 例）
- 构建：`flutter build apk --debug --dart-define=VOICEFOX_UI_ONLY=1` 成功产出 app-debug.apk
- 桌面实机截图：9 张入库 docs/shots/（批次 0 五张 20261107-vp-1920/1280/1024-home、20261107-light-1440-home、20261107-light-1150-settings-appearance；第二批四张 20261107-p7b2-1440/1150/800/1280-home）
- 像素级冻结验证：1280 视口当前代码截图对批次 0 冻结基线 RMSE=0

## 待补项（未完成，不得视为已完成）

- 模拟器/真机截图与运行验证：未跑。本机为 Linux 宿主，无 emulator 二进制/AVD/adb 设备（adb devices 确认），插件 GUI 模拟器流程不支持 Linux
- MissingPluginException 的运行时表现与 MobileShell 实机呈现：未经实跑，仅有 APK 编译通过 + widget 测试佐证
- UI-only 门控路径的模拟器截图：未拍，以 ui_only_boot_test 与 touchPlatformOverride 注入的 widget 测试佐证
- release 树摇剔除 kUiOnly：为编译期常量语义推断，未做 release 构建实测
- 有 Rust 链路的实机播放验证：明确顺延 Phase 8
- Android applicationId/签名/权限：留 Phase 8

## 剩余问题与已知发现（未修）

1. 极矮视口（如 844×390 平板横屏，高 390）下桌面页存在纵向 43px 溢出。属桌面页逐页移动适配范畴，不在本批视口验收档内（360/600/768/1024 全过）。
2. 队列拖拽排序如实禁用：后端暂无队列排序命令，tooltip「后端暂无队列排序命令，暂不支持拖动排序」即 `queue_panel.dart:194` 现状（与 Phase 6 登记的后端任务一致）。
3. 浅色主题下壳 chrome 仍为 VxColors 暗面常量：冻结前既有状态（批次 0 顺带记录），留待后续批次统一。
4. compileSdk 31 升至 36：仅构建期对齐，非运行时改动。

## 与计划书 Phase 7 要求对照

| 计划书要求 | 状态 |
|---|---|
| 手机单独使用 MobileShell：底部导航、迷你播放栏、手势式全屏播放 | ✅ 代码与 widget 测试完成；实机验证待补（见待补项） |
| 平板根据宽度在 NavigationRail / 双栏 / 三栏布局之间切换 | ✅（600-899 图标 Rail / 900-1199 双栏 / ≥1200 三栏） |
| 播放器、TrackRow、专辑卡、主题 Token 与桌面共享；导航和布局不强行共用 | ✅（共享 buildShellPage/kShellDestinationOrder、LyricsPanel compact/QueuePanel 复用、设计系统零成本共享；MobileShell 独立布局） |
| 手机全屏播放器采用封面、歌词和队列分层切换；桌面仍使用封面/歌词并置 | ✅（MobileNowPlayingPage 三态分层；桌面并置不变，RMSE=0 佐证） |

## 附录：证据清单

- 新增源码：`flutter/lib/src/shell/mobile_shell.dart`、`flutter/lib/src/player/mini_player_bar.dart`、`flutter/lib/src/player/mobile_now_playing_page.dart`
- 新增测试：`flutter/test/mobile_shell_test.dart`、`flutter/test/tablet_shell_test.dart`、`flutter/test/touch_longpress_test.dart`、`flutter/test/ui_only_boot_test.dart`、`flutter/test/viewport_matrix_test.dart`、`flutter/test/mobile_now_playing_test.dart`
- 修改要点：`flutter/lib/main.dart`（平台门控 + kUiOnly）、`flutter/lib/src/shell/responsive_shell.dart`（形态/平板纯函数 + isTouchPlatform）、`flutter/lib/src/shell/app_shell.dart`（共享目的地提取）、`flutter/lib/src/shell/app_header.dart`、`flutter/lib/src/shell/app_sidebar.dart`、`flutter/lib/src/player/now_playing_page.dart`（组件公开化）、`flutter/lib/src/design_system/components/`（vx_hover/vx_track_row/vx_hero/vx_player_controls）、`flutter/lib/src/pages/song_tile.dart`、`flutter/lib/src/pages/library_page.dart`、`flutter/android/app/build.gradle.kts`、`flutter/android/build.gradle.kts`
- 截图：docs/shots/ 下 20261107-vp-1920-home.png、20261107-vp-1280-home.png、20261107-vp-1024-home.png、20261107-light-1440-home.png、20261107-light-1150-settings-appearance.png、20261107-p7b2-1440-home.png、20261107-p7b2-1150-home.png、20261107-p7b2-800-home.png、20261107-p7b2-1280-home.png
- 提交：c2c72fa（feat: Phase 7(UI) MobileShell 底部导航/迷你播放栏/手势全屏播放 + 平板断点，工作流自动实施，未推送；33 文件，+2818/-195）
- 报告撰写时复核命令：`flutter analyze --fatal-infos` 与 `flutter test`（均于 /home/emo/code/voicefox-gui/flutter 实跑，结果见验收状态节）
