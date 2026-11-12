# Phase 6 Report: DesktopShell 三栏重构（2026-11-13 收口轮 + Phase6-QA1 修复轮 + QA 复查轮收口）

## 范围

§7 桌面三栏（Sidebar / Main Content / ContextPanel / Global PlayerBar）规格对齐与交互补齐（六工作流 W1-W6：常量对齐、侧栏拖调/折叠/持久化、Esc 链、歌单表六入口核验、全屏回归、平板 840-1199 end panel、触点分档、MPRIS 核验）；Phase6-QA1 修复轮 P1-18（推入式详情页整页覆盖壳层）根因修复；QA 复查轮运行时实拍复核收口。不重建骨架：三栏骨架、断点纯函数、IndexedStack 常驻 Phase 2 已在位。

## 修改文件

`git diff --stat` 实测 12 文件 +770/-192，全部 Flutter 壳系，**Rust 零改动**（无 app/src、ffi/src）：

- `flutter/lib/src/nav_bus.dart`（+14：`contentNavigatorKey` 内容区内嵌 Navigator key，nav_bus.dart:22）
- `flutter/lib/src/shell/app_shell.dart`（内嵌 Navigator :642-662、seed 下钻落内嵌 :223-236、PlayerBar 全屏摘除 :566、Esc 链内容区档、焦点回落 `_shellShortcutsFocus`）
- `flutter/lib/src/shell/app_sidebar.dart`（拖调把手 240-300、折叠/展开钮、SharedPreferences 持久化、歌单推入落内嵌）
- `flutter/lib/src/player/player_bar.dart`（P1-14 左区非 flex、高度 84、空态去假控件）
- `flutter/lib/src/shell/responsive_shell.dart`（断点/常量对齐 §7.1/§7.4/§7.5）
- `flutter/lib/src/shell/context_panel.dart`、`mobile_shell.dart`、`design_system/components/vx_player_controls.dart`（触点分档 touchTargets）
- `flutter/test/`：shell_test.dart（+138，含「推入式详情页播放器跨页面保持」group 3 条 :275）、desktop_three_column_layout_test.dart（新）、desktop_queue_interaction_test.dart（新）、tablet_shell_test.dart、mobile_now_playing_layout_test.dart

## 关键设计决策

- **内容区内嵌 Navigator（P1-18 根因修复）**：桌面壳中央内容区 `Navigator(pages:[MaterialPage(IndexedStack…)])`（app_shell.dart:642-662，key=nav_bus.dart:22 `contentNavigatorKey`）承接推入式详情页；内容区内 `Navigator.of(context)` 就近解析自动落内嵌（library_page.dart 等推入点零改动即被机制性覆盖），壳层兄弟子树（app_sidebar.dart 歌单项、app_shell.dart `_openSeedDetail` 四分支，:223 注释「不推根路由（根路由整页覆盖壳层）」、:236 pushDetail(LocalMusicPage)）经同 key 显式落内嵌；pages API 让壳层 setState 重建传导进基页；Esc 链补内容区档（§4.3 先关最上层）。不推根路由：根路由整页覆盖壳层正是 P1-18 缺陷形态。
- **焦点回落修复（内嵌 Navigator 伴生缺陷）**：`Focus(autofocus)` 改显式 FocusNode，`_setNowPlayingOpen` 统一出口在转场帧后收回 primary；全屏播放页切换拆 shell-main 后焦点不再落 home ModalScope（§9 快捷键全链失灵已修复，Esc 链用例 A/B 实跑确认被波及后恢复）。
- **P1-14**：PlayerBar 左区改非 flex 子项（ConstrainedBox 钳宽 + mainAxisSize.min），中区 Expanded 独占剩余空间，右簇贴右缘（修复前 1920 宽尾距 547px）。
- **P2-11**：PlayerBar 恒挂载维持（app_shell.dart:566 仅全屏时摘除，§5.1 防双重控制），空态传输/进度假控件不进树，空态提示与右区真实控件保留。
- **常量对齐**：侧栏拖调带 240-300（§7.1）、右栏 300-420 默认 340（§7.4）、playerBarHeight 84（§7.5 上沿）；用户记忆值仅 ≥1200 展开档生效（G1：1024 展开态 Header 实测溢出 21px，widget 层实证）。
- **平板 840-1199 右栏 end panel 内嵌**（§6.2:546 取 end panel，G4）；D1/D2 维持现状，tablet_shell_test 1199/1200 边界断言为裁决证据。
- **偏差 G1-G9 登记 04 矩阵 Phase 6 节**（规格数值冲突口径、密度 50/58/66、golden harness 缺席、平板运行时不可达、W2 评审修正、MPRIS、拖调实机）。

## 数据流/交互变化

播放真源恒在 AppModel 不变；推入路由目标从根 Navigator 改落内容区内嵌 Navigator，行为变化三条如实登记（04 矩阵 P1-18）：①行右键菜单等浮层挂载点从窗口底移到内容区底（desktop_queue_interaction 7 项仍绿）；②全屏播放页打开后推入详情栈随 AnimatedSwitcher 进出树（此前推入根路由时代该场景不可达，非回归）；③移动/平板壳零变化。侧栏宽度/折叠经 SharedPreferences（`shell.sidebar.width`/`shell.sidebar.collapsed`）持久化重启恢复；Esc 链四档：全屏 > <960 降级侧栏浮层 > 右栏 ContextPanel > 内容区内嵌 > 根路由。队列/右键操作走真实 FfiCommand；缺命令项（队内移动/跳播）维持如实禁用（P2-09）。

## 执行命令与退出码

**报告员本轮实跑（QA 复查轮佐证，2026-11-13）**：

- `flutter test test/tablet_shell_test.dart --reporter compact` → `00:05 +8: All tests passed!` exit 0（shell 大改回归护栏，独立复跑）
- `stat` build/linux/x64/debug/bundle/：kernel_blob.bin **2026-11-13 05:06:57**（126646776B）+ libvoicefox_ffi.so 05:06:53（286283424B）在位，早于 05:11/05:12 重截
- `git diff --stat`：12 文件，无 app/src、ffi/src（Rust 零改动佐证）
- 重截 2 张 PNG Read 逐张目检（见「视觉 QA 结果」）
- 代码行核对：nav_bus.dart:22、app_shell.dart:223/:236/:566/:642-662、responsive_shell.dart:95-100、app/src/main.rs:1646、shell_test.dart:275

**QA 复查轮实跑（ask 已知事实转述，报告员未复跑）**：重建 `flutter build linux --debug` exit 0 → Xvfb :61 + GDK_BACKEND=x11 重跑修复版 bundle（窗口内容=外框减 264px 阴影边精确裁切）→ 1280×800 表格页双击第 3 行实跑 **0 次 Unhandled Exception**（修复前会话 1 双击 12 次 + 会话 2 播放全部 1 次）→ 日志 `last=progress` 事件流动 → `busctl --user list` grep voicefox→none。

**QA1 修复轮实跑（04 矩阵登记在案，报告员本轮未复跑）**：定向 7 文件 **81 项全绿**（`00:13 +81` exit 0，78 基线 + shell_test 新增 3）+ 壳系 3 文件 22 项 + **全量 flutter test 375 项全绿**（`00:33 +375` exit 0）+ `flutter analyze` 0 issue + dart format 5 文件。

**收口轮实跑（04 矩阵登记在案，报告员本轮未复跑）**：定向 7 文件 78 项全绿（`+78` exit 0）+ analyze 0 + debug 重建 + Xvfb 5 视口实拍逐张目检 + MPRIS `busctl --user list` 零命中。

## 测试结果（通过/失败/跳过）

- **通过**：QA 复查定向 4 文件 **49 项全绿** exit 0（shell_test 含新 group「推入式详情页播放器跨页面保持」3 条：1024x640 推入后 PlayerBar/侧栏在树、1440 推入页不挡右栏 + Esc 先关右栏、详情页返回钮经内嵌 Navigator 壳层保持）；tablet_shell_test 8/8（报告员本轮独立复跑）；QA1 轮 81 + 22 + 375；收口轮 78。
- **失败**：无。
- **跳过/未跑（如实）**：报告员本轮未复跑 7 文件 81 项、全量 375 项、analyze 0（修复轮登记在案，未独立复核）；全量 flutter test / cargo test 由外部门禁统一执行。

## 构建结果

`flutter build linux --debug` exit 0（QA 复查轮，bundle kernel_blob.bin 05:06:57 新鲜 + libvoicefox_ffi.so 286283424B，报告员 stat 佐证；RUSTUP_TOOLCHAIN=1.99.0，Rust 零改动）。release bundle 本轮未重建（维持 Phase 3 03:52:19 结论，桌面运行验证均基于 debug 产物）。

## 设备和视口

Linux 桌面（本机，cachyos）；Xvfb :61 私有显示 + GDK_BACKEND=x11，debug bundle，VOICEFOX_START_SIZE 种子视口。受影响视口 2（≤3）：1024×640 最小窗、1280×800 播放态；1024x640 窗口内容=外框减 264px 阴影边精确裁切。未受影响视口（1280 threecolumn/panelhidden、1920 threecolumn，均我的音乐页非推入详情页）维持原截图不重截。Android 真机与平板触屏运行时不可达（P1-06 环境阻断；responsive_shell.dart:95-100 isTouch=false 恒 desktop，平板两档 rail 仅 widget 层证据）。

## 截图路径

- `docs/redesign/screenshots/phase-6-desktop/`（5 张）：本轮重截 **desktop-library-1024x640-minwindow.png**（05:11:38，68497B，替换）与 **desktop-library-1280x800-playing.png**（05:12:17，107523B）；desktop-library-1280x800-threecolumn / panelhidden / 1920x1080-threecolumn 三张 04:07 原截维持。
- `docs/redesign/screenshots/phase-6/`（收口轮 5 视口 desktop-{1024x640,1150x720,1280x800,1440x900,1920x1080}.png，04:07 批次）。

## 视觉 QA 结果

- **报告员逐张目检（本轮实看 2 张重截）**：①1024x640：本地音乐详情页在壳内渲染：折叠 72 侧栏（V 标 + 图标列）+ AppHeader（搜索框 Ctrl K/窗口钮）+ 中央内容列（返回钮/标题/添加目录/播放全部/音乐目录 /home/emo/Music/voicefox-phase1/共 30012 首/5 行 P5测试曲1）+ PlayerBar 空态（未在播放/选择一首歌曲开始播放 + 音量/歌词/队列钮）全部在位，行贴底缘缺陷消失。②1280x800：详情页 PlayerBar 真实播放态：P5测试曲1/P5艺术家·local、⏸ 主钮、进度 00:00/00:01 前进中（与列表时长吻合）、行 3 当前播放均衡器高亮、歌词加载失败 toast 为本地曲预期真实错误态（非致命）。两图无 overflow/遮挡/白黑屏。
- **§12.5 复查（QA 复查轮）**：无白/黑屏、无 overflow、遮挡仅 DEBUG 横幅（debug 构建固有）、封面无异常、本地音乐计数/曲目/时长三方一致真实数据、深色对比度可读；浅色主题仍归 Phase 7 未验证。
- **残留 minor 4 条非阻塞**：计数头滚动态碰撞（维持 open）、DEBUG 横幅、30012 陈旧条目（建议立矩阵项）、30013±1 未归因。

## 新增/关闭缺陷

- **关闭（Phase 6 三项）**：P1-14（播放栏右簇不贴右缘，根因修复 + widget 位置断言 + 运行时实拍）、P2-11（空态假控件，PlayerBar 恒挂载语义落地）、**P1-18（推入式详情页整页覆盖壳层：本轮复查轮三重证据齐，实拍 2 张运行时复核 + 代码 nav_bus.dart:22/app_shell.dart:642-662 + 测试 shell_test group 3 条；上轮登记的「运行时实拍待复核」缺口已闭）**。
- **开放维持**：P2-05 MPRIS（GUI 无服务，busctl 实跑零命中；见未解决节）；P1-16/P1-17/P2-13/P2-14/P3-09（Phase 5 遗留，本阶段未动）；P0-01/P1-05/P1-06 既有开放。
- 行为变化三条登记于 04 矩阵 P1-18（浮层挂载点移内容区底/全屏进出拆内嵌栈/移动平板零变化）。

## 未解决问题和原因

1. **MPRIS 仍未修复**：`busctl --user list` 无 org.mpris.MediaPlayer2.voicefox.*（grep voicefox→none，QA 复查轮实跑）；本轮修复未触碰 app/src 与 ffi/src（git diff --stat 仅 shell 侧 12 文件，报告员实测）；MPRIS 仍只在 TUI run_app（app/src/main.rs:1646 start_media_controls）接线，Flutter 桌面 FFI 路径无 media_controls。P2-05 维持开放，Rust 实装留独立批次（桌面零回归铁律）。
2. **键盘焦点移动未通过**：点击选行可用，但 ArrowDown×3 后无焦点指示移动（仅 mouse hover 跟随）；本次修复未涉及，未立矩阵项（无障碍全量审计归 Phase 7）。
3. **真实出声无法验证**：无头环境 pipewire client.conf 加载失败，仅见引擎 progress 事件；音频输出链维持未验证。
4. **平板两档 rail 桌面运行时不可达**：responsive_shell.dart:95-100 isTouch=false 恒 desktop，无强制触屏入口；仅定向 widget 测试 8/8 绿作证据（G6）。
5. **1 秒测试曲时长限制**：播放推进/自动切歌长程行为无法演示（测试曲 00:01）。
6. **报告员侧未复跑项**：7 文件 81 项 + 全量 375 项 + analyze 0 为修复轮登记在案数据，本轮未独立复核；全量门禁外执行。
7. **Android/浅色主题/golden harness**：维持既有口径（P1-06 环境阻断；浅色走查、G5 golden 基础设施裁决归 Phase 7）。

## 下一阶段进入条件

§13 Phase 6 退出条件（1024/1150/1280/1440/1920 视口无布局缺陷；三栏可折叠；播放器跨页面保持）+ QA 补充项（右面板 overlay 不挤压，上轮已核）**全部成立，Phase 7 可进入**。建议 Phase 7 承接：浅色主题整页走查、Android 真机项（P1-06）、无障碍全量审计（含键盘焦点移动）、golden harness 裁决（G5）、P1-16/P1-17 修复批次、残留 minor 4 条与 30012 陈旧条目矩阵化。
