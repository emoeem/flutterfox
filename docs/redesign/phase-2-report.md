# Phase 2 Report（MobileShell 和手机首页）：已完成（2026-11-11 缺陷复验轮收口）

> 分支：`feat/ui-redesign`　模板：指南 §14
> 覆盖批次：①手机壳重建批次（MobileShell/手机首页/Mini Player/底部导航重建，2026-11-11 入树；规格偏差登记见 04 矩阵「Phase 2 偏差登记」D1-D6）；②**缺陷复验轮（本报告重点）**：QA 轮登记的两条 P1 修复后的复验收口，本轮唯一新增代码改动为 `library_page.dart`。
> 状态口径：指南 §13 Phase 2 退出条件在 widget/golden 层全部满足；**Android 真机运行时项（P1-06 环境阻断）与浅色主题实机走查维持「未验证」**，如实披露，不因测试全绿改判。

## 范围

1. **手机壳重建批次（前批次，已入树）**：MobileShell 重建（底部导航 + 抽屉 + 平台隔离 + AndroidInsets 契约）、手机首页（Hero/最近播放横滑书架/快捷入口/空库 CTA）、Mini Player 固定布局、首页两视口 golden（360×800 nonempty、390×844 emptyhero/nonempty）。偏差与裁决点以 04 矩阵 D1-D6 为准，本报告不重复。
2. **缺陷复验轮（本轮）**：QA 轮发现的两条 P1（①曲库页 430 视口「我的音乐」h1 标题折行；②首页空库 Hero 两 CTA 横排折行）修复后按「定向测试 → 重建 → 受影响视口 golden 重截 → 目检」复验收口。本轮唯一新增改动为库页 header 断点分支；受影响视口仅 library 430×932，home 两视口不含库页、不受影响（沿用 06:04 批次截图）。

## 修改文件

本轮（缺陷复验轮）：

- `flutter/lib/src/pages/library_page.dart`（唯一新增代码改动）：`_header` 改 `LayoutBuilder`（:81），`maxWidth < 512` 走标题独占一行 + compact 工具行（:88），title 加 `maxLines: 1` + ellipsis（:91）；`_tools` 增加 `compact` 参数（:301），compact 时搜索框改 `Expanded` 弹性宽度、非 compact 保持 200 定宽；**≥512 保持原 Row 桌面渲染零变化**。diff 实读：hunk `@@ -78,18 +78,39 @@`（新文件 78-117 行）与 `@@ -277,32 +298,33 @@`。
- `flutter/test/mobile_home_page_test.dart`：新增「窄视口 390：两 CTA 竖排全宽，按钮文字单行不折行（Phase 2 QA P1 回归）」（:176-208，断言两按钮宽 >280、纵向排列、label 高 <30 单行）。
- `flutter/test/mobile_shell_test.dart`：新增「窄视口曲库布局：标题单行不折行、各档工具条无横向溢出（Phase 2 QA P1 回归）」（:173，遍历 430×932 / 390×844 / 360×800 三视口进曲库页断言），上一轮「窄视口曲库布局无测试覆盖」缺口已同步补上。
- 截图：`docs/redesign/screenshots/phase-1-mobile/fluttertest-library-430x932-dark-default.png`（覆盖重截）。
- 文档：`04-defect-matrix.md`（P1-12/P1-13 登记并关闭；minor 两条 P2-10/P3-08 登记）、指南 §17、本报告。

前批次（已入树未提交，前一轮登记）：`mobile_shell.dart`、`mobile_home_page.dart`（新）、`home_shared.dart`（新）、`app_shell.dart`、`responsive_shell.dart`、`home_page.dart`、`local_music_page.dart` + 测试 6 文件 + fluttertest-home 截图 3 张。

## 关键设计决策

1. **512 分界由最宽工具档反推**（library_page.dart:84-88 注释）：同 Row 时定宽 200 搜索条 + 三图标占 308-360px，h1 需 ≥113.6px，430 视口剩余 90px 必折行；最宽工具档（专辑/歌手 360px）需 ≥505.6 才放得下，分界取 512，手机档 360-599 全覆盖。
2. **title `maxLines: 1` 结构上不可能再折行**：compact 分支标题独占整行，回归测试在三视口断言单行；≥512 桌面分支保持原 Row，零变化。
3. **空库 CTA 竖排全宽**（mobile_home_page.dart:152-167）：`width: double.infinity` + 纵向 Column，FilledButton「搜索音乐」在上、OutlinedButton「导入本地音乐」在下，各 ~280-310px 单行容纳；横排等分在 390 视口每按钮仅 ~149px 的成因已消除，触控目标同时增大（§5.9）。
4. **golden 重截用临时测试、用后即删**：pump 真实 MobileShell，底栏第四入口切库页，430×932 dpr=1.0 渲染，断言标题 `maxLines==1` 通过；文件已删除，报告员 `ls` 核实仓库零残留。
5. **fluttertest- 平台前缀沿用首轮诚实口径**：桌面窗口平台隔离使 MobileShell 不进桌面运行时树（mobile_shell.dart:110-122，desktop → `SizedBox.shrink()`），fluttertest-\* 为 widget 层 golden 渲染证据，不冒充实机截图。字体口径不变：注入 Noto Sans CJK + bundle MaterialIcons。

## 数据流/交互变化

本轮为纯视觉布局改动，无数据流变化：库页窄视口标题/工具条两行布局、首页空库 CTA 竖排；各视口无横向溢出；桌面库页渲染零变化。

## 执行命令与退出码

| 命令 | 退出码 | 结果 | 执行者 |
|---|---|---|---|
| `flutter test test/mobile_shell_test.dart test/mobile_home_page_test.dart test/mini_player_interaction_test.dart test/mobile_now_playing_layout_test.dart test/viewport_matrix_test.dart test/phase5_library_test.dart test/local_music_page_test.dart`（flutter/） | **0** | **`00:05 +51: All tests passed!`** | 报告员本轮实跑 |
| `flutter test`（5 文件定向，--reporter compact） | **0** | **All tests passed! 共 38 项**，含两条新增 P1 回归 | 复验轮记录（ask 提供） |
| `flutter test test/tmp_golden_recapture_test.dart --update-goldens` | **0** | **+1: All tests passed!**；临时测试已删除，报告员 `ls` 核实零仓库残留 | 复验轮记录（ask 提供） |
| `flutter build linux --release`（RUSTUP_TOOLCHAIN=1.99.0 固定） | **0** | 报告员佐证：`build/linux/x64/release/bundle/`（flutter_assets 06:33）与 `lib/libvoicefox_ffi.so` 在位 | 复验轮记录（ask 提供） |
| `identify fluttertest-library-430x932-dark-default.png` | 0 | **PNG 430x932**，48831B，mtime 06:34（重截批次） | 报告员本轮实跑 |
| `git diff flutter/lib/src/pages/library_page.dart` | n/a | hunk 实读（见「修改文件」） | 报告员本轮实跑 |
| 全量 `flutter test` / `cargo test` / analyze / dart format / clippy | n/a | **未跑**（外部门禁统一执行，遵守 ask 纪律；本轮已知事实「门禁全绿」） | 未执行 |

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过 | 说明 |
|---|---|---|---|---|
| 定向 7 文件 | **51** | 0 | 0 | 报告员本轮实跑（上表第一条命令） |
| 其中新增 P1 回归 | **2** | 0 | 0 | mobile_home_page_test.dart:176-208（CTA 竖排全宽）+ mobile_shell_test.dart:173（曲库三视口单行/无溢出） |
| 临时 golden 重截 | 1 | 0 | 0 | tmp_golden_recapture_test.dart（已删除，不在仓库） |
| 全量 flutter test / cargo test | n/a | n/a | n/a | 未跑（外部门禁统一执行） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux release（`flutter build linux --release`，RUSTUP_TOOLCHAIN=1.99.0 固定） | exit 0（复验轮记录）；报告员佐证 bundle 与 `libvoicefox_ffi.so` 在位（06:33） |
| Android APK | 未构建：无 JDK、无设备/模拟器（P1-06 环境阻断维持，用户明确搁置） |

## 设备和视口

- golden 渲染：430×932 dpr=1.0（真实 MobileShell widget 树，底栏第四入口切库页）；受影响视口仅 library 430×932，home 两视口（360×800 / 390×844）不含库页不受影响。
- Android 真机/模拟器（§12.6 真机 13 项）：**未验证**（P1-06 环境阻断维持）。
- 桌面实机：本轮无新增桌面改动，未重拍桌面壳（平台隔离使 MobileShell 不进桌面运行时树，mobile_shell.dart:110-122）。

## 截图路径

`docs/redesign/screenshots/phase-1-mobile/`：

- `fluttertest-library-430x932-dark-default.png`（**覆盖重截**，06:34）：标题折行修复后「我的音乐」单行 + 工具条换行布局。
- `fluttertest-home-360x800-dark-nonempty.png`、`fluttertest-home-390x844-dark-emptyhero.png`、`fluttertest-home-390x844-dark-nonempty.png`（06:04 批次，本轮无改动，沿用）。
- `linux-*` 桌面证据沿用 Phase 0/1 批次（目录 README 有命名勘误说明）。

## 视觉 QA 结果

**QA 复查通过：两条 P1 均确认关闭，当前无 P0/P1。** 报告员在重截 PNG 上目检（Read 工具实际查看图像）：

1. **曲库标题折行（P1-12）**：`fluttertest-library-430x932-dark-default.png` 中「我的音乐」单行显示、搜索条 + 筛选/刷新图标整行移至第二行，与代码修复一致（git diff 实读 + maxLines:1）。
2. **空库 CTA 折行（P1-13）**：代码改竖排 Column 两全宽按钮（mobile_home_page.dart:152-167），成因已消除；该文件为未跟踪新文件无 git diff，以当前源码 + 回归测试（:176-208）为准。
3. **其余项复核无回归**：筛选行（歌曲/专辑/歌手/歌单）、本地/网易云/QQ 源选择、空态文案、我的音乐底栏第四项高亮均与上一轮一致；无新增溢出/遮挡/折行。
4. **遗留 minor**：入口卡标签截断（截图中「最近…/本地…/喜欢…」可见，P2-10）；旧 golden 截图未更新/数据种子不一致（P3-08）。

## 新增/关闭缺陷

- **关闭（本轮）**：P1-12（曲库 430 视口标题折行）、P1-13（空库 Hero CTA 折行），登记与关闭证据见 04 矩阵。
- **新登记（minor）**：P2-10（入口卡标签截断）、P3-08（旧 golden 截图未更新/数据种子不一致）。
- **仍开放**：P0-01（概率性卡死未复现未定位）、P1-05（进程静默退出）、P1-06（Android 环境阻断）、P2-02/03/04/05/06/08/09、P3-02/04/05/06/07。
- Rust 侧：本轮零改动。

## 未解决问题和原因

1. **Android 真机运行时行为**（MobileShell/首页/Mini Player、系统栏、edge-to-edge）：无 JDK/模拟器/设备，notVerified（P1-06，用户明确搁置）。
2. **Mini Player 60-68dp 与底栏叠序**：仅 widget/golden 层证据。
3. **桌面窗口内 MobileShell 运行时呈现**：被平台隔离设计阻止（desktop → `SizedBox.shrink()`），本轮未实拍桌面壳（无新增桌面改动）。
4. **浅色主题实机整页走查**：不在本轮材料内，维持未验证（P1-09 收口仍为代码 + 测试锁定，归 Phase 7）。
5. **全量测试未由报告员复跑**：外部门禁统一执行（本轮已知事实「门禁全绿」）；上轮工作报告登记的 cargo test exit 101 门禁阻塞据此解除，报告员未独立复核 cargo test。
6. **minor 两条**：P2-10 / P3-08（见 04 矩阵）。

## 下一阶段进入条件

§13 Phase 2 退出条件逐条核对：

| 条件 | 状态 |
|---|---|
| 360/390/430 三种视口无溢出 | ✅ widget 层（mobile_shell_test.dart:173 三视口断言 + viewport_matrix + mobile_home_page_test）+ golden（430 库页、360/390 首页） |
| 状态栏、导航栏不重叠 | ✅ widget 契约层（android_insets_layout_test 7 项，Phase 1 批次）；**真机未验证（P1-06）** |
| 导入入口可用 | ✅ widget 层回调（空库 CTA + 本地音乐页 + 曲库入口卡，D6）；导入→扫描→播放端到端归 Phase 5 |
| Mini Player 不遮挡导航 | ✅ widget/golden 层（mini_player_interaction_test 等） |

- **Phase 3（手机 Library、搜索、发现和详情）可进入。**
- 跨阶段遗留不阻塞：P0-01 定位（长时间会话验收前必须）、P1-05 同域跟进、P1-06 环境补齐、浅色主题走查归 Phase 7。

## 勘误（2026-11-12 Phase 2 QA 修复轮，历史正文不动，仅以下事实更新）

1. **截图路径节所记 fluttertest-library-430x932-dark-default.png（06:34，48831B）已被 610d6d8（phase 3 提交）无声替换**为页面级 pump LibraryPage + 未注入 CJK 字体的版本（18496B，mtime 11-11 07:29）：该版本全部文字空心方框、底栏与「我的音乐」高亮不在画面内，本报告「视觉 QA 结果」与 04 矩阵对该文件的目检结论对替换版不成立（Phase 2 QA 轮 2026-11-12 判 P0）。已按本报告「关键设计决策 4」口径复截：真实 MobileShell 进树、底栏第四入口切库页（断言 selectedIndex==3）、430×932 dpr=1.0、规格要素断言通过后才捕获、临时测试用后即删零残留；现文件 61983B（mtime 11-12 01:53），逐项目检通过（详见 04 矩阵 P1-12「证据勘误与复截」）。
2. **字体口径实测更正（决策 5「注入 Noto Sans CJK」）**：NotoSansCJK .ttc 在 flutter_tester `loadFontFromList` 下静默加载失败（实测 advance 为 .notdef）；且 golden 家族混入 Roboto 时 w400/w700 的 CJK 字符落回测试字体方框（家族内 per-glyph 兜底不跨 face）。2026-11-12 复截改用本机 MiSans 单源全覆盖 face（Regular/Medium/Semibold/Bold OTF，每个 face 均含 Latin+CJK，任意字重查询都落在有字形 face 上）+ JetBrainsMono（pubspec 资产）+ MaterialIcons（SDK 缓存）。
3. **fluttertest-home-390x844-dark-emptyhero.png（06:04 批次，「沿用」）已随当前代码复截**：06:04 版停留 P1-13 修复前横排形态（「导入本地音/乐」词中断行），「空库 CTA 竖排全宽」修复在证据层当时未闭环（Phase 2 QA 轮 2026-11-12 判 P1）。复截同上述口径（390×844，空库模型，两 CTA 宽 >280/竖排/单行断言通过后捕获）；现文件 100843B（mtime 11-12 01:53），目检竖排全宽单行与 mobile_home_page.dart:152-167 一致（详见 04 矩阵 P1-13「golden 证据闭环」）。

---

# 追加批次（2026-11-12 全屏播放页封面带修复轮；§14 模板小节逐项对应，历史正文不动）

**缺陷定位**：全屏播放页封面 280-340dp 自适应带（§5.7:446-447，Phase 4 项，04 矩阵登记 **P2-12**）：原实现 `(height-330).clamp(160,320)` 恒 320 封顶，390/430 视口未达带上限 340 且无带语义测试；受影响面仅三移动视口的全屏播放页（非壳层页面），故证据重截仅 nowplaying 三张（≤3 合规）。同批入树的 §5.7 同域收口：封面横滑切歌（**P2-06 关闭**）、队列改底部 sheet（§5.7:452）、歌词点击门槛（§5.7:461）、音频焦点中断 + 通知 artUri 守卫（`voicefox_audio_handler.dart`）。

## 修改文件（git diff 实读；± 为 diffstat 变更行数）

- `flutter/lib/src/player/mobile_now_playing_page.dart`（±243）：封面带公式（:337-348 `max(min(min(height-330, width-40), 340), min(160, widthCap))`；<560 极矮回退 240 + 滚动）；`_SwipeableCover` 横滑切歌（速度阈值 500px/s，左滑 next/右滑 previous，方向提示层随拖动生命周期整体移除；只绑封面区，避开 LiveSeekRow 横拖与屏幕缘返回手势，§5.7:459）；队列层改底部 sheet（showModalBottomSheet 75% 高 + 独立 DragHandle 下滑/点遮罩关闭，enableDrag=false，因 DraggableScrollableSheet 与 QueuePanel 的 Column+Expanded 定高依赖不兼容；拖拽排序维持如实禁用）；`MobileNowPlayingLayer` 删 queue 层。
- `flutter/lib/src/player/lyrics_panel.dart`（±29）：歌词全部行无有效时间戳时点击不挂 seek 手势并如实说明「本曲歌词无时间戳，不支持点击跳转」（:161-164/:205-213/:229-231）。
- `flutter/lib/src/playback/voicefox_audio_handler.dart`（±34）：audio_session 中断事件（begin 快照在播并暂停让焦；end 且抢占前在播才恢复；audio_session 0.2.4 无 shouldResume 信号如实收敛）+ MediaItem artUri null/空串守卫（不伪造无图封面 URL）。
- `flutter/test/mobile_now_playing_layout_test.dart`（±100）：新增 group「全屏封面 280-340dp 自适应带（§5.7:446-447，Phase 4）」（:202）三用例（三视口 [280,340]／极矮 430×560 回退 240／矮 430×680 收缩分支）。
- `flutter/test/mobile_now_playing_test.dart`（±284）：group「封面横滑切歌（P2-06）」（:193）四用例 + group「歌词点击门槛（§5.7:461）」（:326）两用例。
- `flutter/test/mini_player_interaction_test.dart`（±101）：group「MiniPlayerBar 几何与进度契约（§5.8，Phase 4）」（:173）三用例（高 64∈[60,68]、封面 44×44、顶部进度线 fraction、图标随播放态翻转）。
- `flutter/test/queue_interaction_test.dart`（**新文件**，319 行 8 用例）：顶栏队列按钮→sheet 打开且按钮激活、DragHandle 下滑关闭、点遮罩关闭、清空二次确认（取消不派发 queueClear）、移出队列 queueRemove(index)、随机切换 configUpdate、空队列空态、拖拽排序如实禁用说明。
- 截图（新）：`fluttertest-nowplaying-{360x800,390x844,430x932}-dark-playing.png`；文档：04 矩阵（P2-12 登记并关闭、P2-06 关闭、P2-09 补记）、指南 §17、本节。

## 关键设计决策

1. **封面带公式**：340 上限 + `min(160, widthCap)` 下界守卫，高度充足时让位歌名/控制行，封面绝不宽于可用宽（外层水平 padding 两侧共 40）；极矮视口 <560 回退 240 + 滚动，控制行不挤出可视区（§5.7:447）。
2. **横滑手势只绑封面区**：§5.7:459「不与系统返回手势冲突」的可测收敛；速度阈值 500 滤误触，方向提示层 Cancel/End 整体移除不残留 hit-test 区。
3. **队列 sheet 定高容器 + 独立 DragHandle**（enableDrag=false）：关闭入口收敛为「DragHandle 下滑 + 点遮罩」，与列表滚动手势解耦、语义可测。
4. **golden 重截口径沿袭 04 矩阵已登记更正版**：MiSans 单源 face（Latin+CJK 同 face）+ MaterialIcons（SDK 缓存）+ JetBrainsMono（pubspec 资产）+ 深色主题 + debugShowCheckedModeBanner=false + dpr=1.0 + MediaQuery insets(top:24,bottom:16)（对齐 mobile_now_playing_layout_test.dart:35-53/:114 harness）；临时测试 pump 真实 MobileShell → debugSetPlaybackSong（paused 42s/244s）→ nowPlayingRequest 开全屏，**封面带断言通过后才捕获**，用后即删零残留（报告员 `git status --porcelain` + `ls flutter/test | grep -i tmp` 实查，唯一新文件为常驻 queue_interaction_test.dart）。

## 数据流/交互变化

横滑切歌/队列 sheet/歌词门槛/音频中断均走真实通路（AppModel next/previous/seekMs/queueRemove/queueClear/configUpdate；audio_session 平台通道），无新增假数据；桌面数据流零变化（全屏页不进桌面窗口）。

## 执行命令与退出码（报告员本轮实跑）

| 命令（flutter/ 下） | 退出码 | 结果 |
|---|---|---|
| `flutter test test/mobile_now_playing_layout_test.dart test/mobile_now_playing_test.dart test/mini_player_interaction_test.dart test/queue_interaction_test.dart --reporter compact` | **0** | **`00:08 +39: All tests passed!`** |
| `flutter test test/mobile_now_playing_test.dart test/mobile_now_playing_layout_test.dart test/queue_interaction_test.dart --no-pub --reporter compact` | **0** | **`00:08 +32: All tests passed!`** |
| `identify` + 像素行扫描 3 张 nowplaying PNG | 0 | 封面实测 **320/340/340**（见视觉 QA） |
| `git status --porcelain`；`ls flutter/test \| grep -i tmp` | 0；1 | 临时测试零残留（唯一新文件为常驻 queue_interaction_test.dart） |
| flutter analyze / dart format / 全量 flutter test / cargo test / `flutter build linux --release` / Android 构建 | n/a | **未由报告员复跑**（全量门禁由外部门禁统一执行，本轮已知事实「门禁全绿」；Android 为 P1-06 环境阻断） |

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过 | 说明 |
|---|---|---|---|---|
| 定向 4 文件 | **39** | 0 | 0 | 报告员实跑；含封面带 3 用例 + P2-06 横滑 4 用例 + 歌词门槛 2 用例 + queue sheet 8 用例 + MiniPlayer 契约用例 |
| 定向 3 文件（--no-pub） | **32** | 0 | 0 | 报告员实跑（4 文件去掉 mini_player_interaction_test.dart） |
| `voicefox_audio_handler.dart` ±34 | n/a | n/a | n/a | **无专项单测**（flutter/test 全目录 grep `VoicefoxAudioHandler|configureAudioService|interruption|artUri` 0 命中），仅随包编译；真机音频输出未验证 |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux release | **本轮未重建**：golden/测试路径直接编译当前源码；桌面运行时证据面未变（平台隔离 mobile_shell.dart:107-119 desktop→`SizedBox.shrink()` 仍使移动壳/全屏页不进桌面窗口），phase 3 收口轮 bundle（07:54）结论不失效 |
| Android APK | 未构建：无 JDK、无设备/模拟器（P1-06 环境阻断维持） |

## 设备和视口

- golden 渲染：360×800 / 390×844 / 430×932 dpr=1.0（真实 MobileShell widget 树 + insets(top:24,bottom:16)）。
- Android 真机/模拟器（§12.6 真机 13 项）：**未验证**（P1-06 维持）。
- 桌面窗口内全屏页运行时呈现：被平台隔离设计阻止（mobile_shell.dart:107-119），仅 widget 契约 + golden 层证据。

## 截图路径

`docs/redesign/screenshots/phase-1-mobile/`（新，mtime 11-12 02:05）：

- `fluttertest-nowplaying-360x800-dark-playing.png`（47550B）：封面 **320** = min(340, 360-40) 宽度封顶分支。
- `fluttertest-nowplaying-390x844-dark-playing.png`（57777B）：封面 **340** ∈ [280,340] 带。
- `fluttertest-nowplaying-430x932-dark-playing.png`（59708B）：封面 **340** 带上限 + 宽裕布局。

## 视觉 QA 结果（报告员实看三张图像 + ImageMagick 像素测量）

1. 三张均含 NOW PLAYING 顶栏（返回 + 歌词/队列入口）、封面带内自适应（360 实测 320 < 390/430 的 340）、歌名「夜航」与「测试歌手 · netease」单行（metaParts 专辑空→回退 source，mobile_now_playing_page.dart:368-371，与 fixture 吻合）、操作行、EQ 走带进度条 + 控制行；无溢出条纹、无 tofu、无 debug banner；全屏独占（无底栏/迷你栏）符合 §5.1。
2. 封面宽度像素实测（magick 单行扫描）：360 视口亮区 x=[20..339]（宽 320=widthCap 封顶）、390 视口 x=[25..364]（宽 340）、430 视口 x=[45..384]（宽 340），与公式（:337-348）及测试「三视口封面落在目标带 [280,340]（360 宽受限取上限-40）」逐视口一致。
3. 背景取色驱动（:152/:161-163）：三张背景色相与封面渐变一致。
4. 上轮勘误两条复核**维持关闭**（报告员本轮实看图像）：`fluttertest-library-430x932-dark-default.png`（61983B，01:53）库页全要素在位（标题单行/入口卡两行/chips/源分段/底栏第四入口高亮）；`fluttertest-home-390x844-dark-emptyhero.png`（100843B，01:53）两 CTA 竖排全宽单行。

## 新增/关闭缺陷

- **关闭（本轮）**：**P2-12**（新登记：全屏播放页封面恒 320 封顶、未落 §5.7:446-447 280-340dp 自适应带；闭环证据 = 公式 + 三视口测试 + golden 像素实测）；**P2-06**（封面横滑切歌落地：4 用例锁定；真机手势冲突验证维持未验证，如实披露）。
- **补记**：P2-09 队列挂载形态已落 §5.7:452 底部 sheet；拖拽排序/队内跳播维持开放（后端无 FfiCommand，如实禁用）。
- **仍开放**：P0-01、P1-05、P1-06、P2-02/04/05/08/09、P3-02/04/05/06/07/08。
- Rust 侧：本轮零改动（diff 仅 flutter/ 与 docs/）。

## 未解决问题和原因

1. Android 真机/模拟器运行时（全屏页真实播放走带、横滑边缘手势冲突 §5.7:463、音频焦点中断、通知 artUri）：无 JDK/SDK emulator/system-images，notVerified（P1-06 维持）。
2. `voicefox_audio_handler.dart` ±34：无专项单测（见测试结果表），真机音频输出/通知验证缺失。
3. 全屏页桌面窗口运行时呈现：平台隔离阻止，仅 widget 契约 + golden 层证据。
4. release bundle 未本轮重建（见构建结果节）。
5. 浅色主题：本轮三张全深色，浅色走查归 Phase 7。

## 下一阶段进入条件

Phase 2 退出条件状态不变（见上文核对表，widget/golden 层全部满足）。本轮为 §5.7 全屏播放页证据补齐与缺陷修复：Phase 4 主体中的封面带/横滑切歌/队列 sheet/歌词门槛已提前落地并由测试锁定；Phase 4 进入时剩余项为后台服务、通知、锁屏、耳机/蓝牙与真机验证（P1-06 阻断面）。
