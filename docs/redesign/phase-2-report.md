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
