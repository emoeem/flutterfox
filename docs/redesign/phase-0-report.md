# Phase 0 Report

> 日期：2026-11-10　分支：`feat/ui-redesign` @ d9ee22fa66dee29fe86159643ca67df0591aa346
> 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §2 / §13 / §14 模板
> 审计方式与全部原始证据见 `docs/redesign/00-baseline.md`；缺陷明细见 `docs/redesign/04-defect-matrix.md`。
> 说明：文中门禁命令与退出码为 Phase 0 审计会话期间实跑所得（证据记录于 00-baseline §3 与 /tmp 日志），
> 本报告员负责汇总核对（截图张数、缺陷条目数、矩阵条目已逐一复核），未重跑门禁。

## 范围

Phase 0 = 基线审计 + 参考研究（指南 §13 Phase 0 交付：`00-baseline.md` ~ `04-defect-matrix.md`）：

1. 全量读代码重审当前实现（Shell/断点/AppModel/FFI/DTO/播放链/封面链/导入链/音源面），不照抄旧审计（00-baseline §1–§13、§16）。
2. 门禁基线实跑（scripts/redesign-gate.sh 各子命令 + clippy 降级变体）。
3. Linux 桌面实机运行 + X11 注入式交互审计，产出真实数据基线截图。
4. 6 个参考项目源码级研究（clone → pin SHA → LICENSE 实读 → 依赖许可证逐查 → 组件逐文件阅读），产出 01/02/03 三份报告。
5. 建立缺陷矩阵（每条 P0/P1 本会话真实复现，附复现步骤与证据）。

## 修改文件

仅新增文档与截图，**零源码改动**（git status：`?? docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md`、`?? docs/redesign/`）：

- `docs/redesign/00-baseline.md`（基线审计）
- `docs/redesign/01-reference-projects.md`（参考项目研究）
- `docs/redesign/02-license-and-reuse-audit.md`（许可证与复用审计）
- `docs/redesign/03-component-reuse-map.md`（组件级复用映射）
- `docs/redesign/04-defect-matrix.md`（缺陷矩阵）
- `docs/redesign/screenshots/baseline/` 8 张 PNG（见「截图路径」）
- 环境修复（非仓库内容）：删除含旧环境失效路径的 CMake 缓存目录 `flutter/build/linux/`（可再生构建产物，gitignore 内）后重建成功——详见「未解决问题和原因」#6。

## 关键设计决策

Phase 0 无代码设计决策，以下为研究与审计层面的判定（依据 01/02/03/04 四份报告）：

1. **复用判定矩阵**（01-reference-projects §8）：代码级移植仅限 myune（Apache-2.0，已 vendored，优先级 1）与 aethertune（0BSD，零耦合组件如 artwork_palette.dart）；finamp（MPL-2.0）仅个别 UI 文件小幅改造且须保留 MPL 头；feishin（GPL-3.0）/nuclear（AGPL-3.0-only）/harmonoid（PolyForm Strict 1.0.0）一律**仅参考交互、禁止任何代码复制（含改写式移植与资产）**。
2. **最高法律风险已两次独立证实**：harmonoid 根许可证为 PolyForm Strict 1.0.0（02 报告 §0）；其 ≤2022-02 旧快照为 GPL-3.0，从旧 tag 摘代码会造成整体传染——禁入清单。
3. **缺陷先行**：P0-01（主 isolate 卡死）使一切交互验收/截图回归不可信，登记为 Phase 1 第一阻断（04 矩阵 P0-01、00-baseline §17）。
4. **截图命名与视口语义**：按指南 §12.5 命名 `<platform>-<page>-<viewport>-<state>.png`；niri+xwayland 下窗口尺寸契约不可靠（P2-04），视口按实际渲染 1656x817 命名，不虚标 1440x900。
5. **旧审计逐条复核后才引用**：9 条旧 P0/P1 确认已修（00-baseline §16），未修复/未复核项如实转登新矩阵（P1-04、P3-02 等），防止重复修复或漏修。

## 数据流/交互变化

无。Phase 0 为只读审计与研究，未改动任何代码、FFI、状态或交互行为。
唯一运行时影响：重建 `flutter/build/linux` 构建产物（产物内容与源码无差异）。

## 执行命令与退出码

命令均于 Phase 0 审计会话实跑（记录：00-baseline §3；构建日志 /tmp/build-linux*.log；交互审计现场 /tmp/vx-audit/）。
门禁命令定义见 `scripts/redesign-gate.sh`（clippy 子命令原文：`cargo clippy --workspace --all-targets --all-features -- -D warnings`，scripts/redesign-gate.sh:59）。

| 命令 | 退出码 | 结果 |
|---|---|---|
| `dart format --output=none --set-exit-if-changed lib test`（经 gate dart-format） | **0** | `Formatted 229 files (0 changed)` |
| `flutter analyze --fatal-infos`（经 gate flutter-analyze） | **0** | `No issues found! (ran in 11.9s)` |
| `flutter test`（经 gate flutter-test） | **0** | `00:18 +189: All tests passed!` |
| `cargo fmt --all -- --check`（经 gate cargo-fmt） | **0** | 全绿 |
| `cargo test --workspace`（经 gate cargo-test） | **101** | lx-source 已知 flaky `cover_cache::tests::sweep_evicts_down_to_the_limit_by_oldest_access` 失败中止（该测试单独复跑通过；FLUTTER_MIGRATION_PROGRESS.md 在案）；中止前 lx-core 47 + lx-lyric 19 + lx-player 12 通过 |
| 补跑 `cargo test --workspace --exclude lx-core --exclude lx-lyric --exclude lx-player --exclude lx-source` | **0** | 513 passed（voicefox-app 333 / application 71 / download 65 / ffi 6 / runtime 38 / lx_test 0，另 2 ignored） |
| **gate cargo-clippy 原样命令**（`--all-features -D warnings`） | **101（构建失败）** | `--all-features` 激活 voicefox-player 的 `build_libmpv` → libmpv2 6.0.0 build.rs panic：`env var MPV_SOURCE not set`。**本环境无法按原样执行——属「环境不可执行」，不是「0 告警」** |
| clippy 去 `--all-features`（保留 `-D warnings`） | **101** | lx-core 28 个 `must_use/double_must_use` 错误后中止 |
| clippy `--workspace --all-targets`（不带 `-D warnings`，降级基线） | **0** | **30 条 unique 告警**，全部 `#[must_use]/double_must_use`（`#[async_trait]` 展开触发）：lx-core 28（core/src/traits/source.rs 19、core/src/sync/mod.rs 8、core/src/traits/lyric_fetcher.rs 1）+ voicefox-application 2（application/src/services/playback.rs） |
| `flutter build linux --release` | **0** | 先因 CMake 缓存含旧环境路径（`/usr/sbin/ninja` 等）连环失败，修补 3 次无效；删除 `flutter/build/linux/` 后重建成功 |
| 参考项目核验：`git rev-parse HEAD` / `head LICENSE`（6 仓库） | 0 | 记录 SHA 逐一一致；根许可证复核一致（01 报告头部） |

**Phase 7 对比基线（00-baseline §3）：clippy 告警 30 条（不得更差）；flutter-test 189；analyze 0 issues；clippy 原样命令在本环境为「无法执行」，Phase 7 不得误记为已通过。**

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过/说明 |
|---|---|---|---|
| Flutter（unit/widget/golden） | **189** | 0 | 0 skipped |
| Rust 全仓合计 | **≈808** | 1（known-flaky，单独复跑通过） | `cargo test --workspace` 原命令在 lx-source 处中止（exit 101），剩余 crate 已补跑（exit 0，513 passed）；合计口径详见 00-baseline §3 |
| 歌单隔离 8 步序列（指南 §8.1） | 0 | — | **未执行**：交互被 P0-01 阻断；代码层 key 隔离成立（`'$kind|$source|$id'`，app_model.dart:293），类型化 PlaylistKey 登记为 P3-03 |
| Ended 自动切歌 | 0 | — | **未观察**：代码链路在（service.rs:240-247），实机观察被 P0-01 阻断 |
| MPRIS | 0 | — | **未验证**：Rust 侧 app/src/mpris.rs 350 行存在，GUI 未接（P2-05，Phase 6 计划项） |
| 本地音乐真实导入播放 | 0 | — | **未走通**：桌面链路代码在（local_music_page.dart），实机被 P0-01 阻断且本机无媒体文件；Android SAF 未验证（无设备） |
| Android 设备测试（§12.6 13 项） | 0 | — | **全部未验证**（无 JDK/无设备/无模拟器，见「设备和视口」） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux 桌面 release | ✅ exit 0（清理失效 CMake 缓存后；产物 bundle 已用于实机审计） |
| Android APK | ❌ 无法构建：无 JDK（`java` 不存在）→ Gradle 不可用；P1-06 |
| Android 交叉 FFI（NDK） | 未执行（同上环境阻断） |
| Windows / macOS | 未尝试（本机无对应构建链；CI 有对应 job，未在本会话触发） |

## 设备和视口

- **Android**：无真机、无模拟器（`adb devices` 空；SDK 无 emulator/system-images；无 JDK）→ 指南 §5（手机 UI）、§10（系统集成）、§12.6 真机 13 项**全部未验证**；MobileShell/TabletShell 仅 widget 测试覆盖。
- **桌面实机**：Linux（niri + xwayland-satellite，DISPLAY=:1，GDK_BACKEND=x11），release bundle，XTest 注入交互；`VOICEFOX_START_SIZE=1440x900` 在该合成器下未按预期生效（P2-04），实际渲染 **1656x817**，截图按实际值命名。
- 平板三态断点（600/900/1200）：无触屏设备，仅 resolveShellMetrics/resolveDeviceFormFactor 纯函数单测覆盖。

## 截图路径

`docs/redesign/screenshots/baseline/`（8 张，真实数据、实机交互取得）：

| 文件 | 内容 |
|---|---|
| linux-home-1656x817-empty.png | 空库 Hero + 真实酷我热门榜单 |
| linux-home-1656x817-history.png | 继续收听 Hero + 最近播放（重启后历史仍在=持久化证据） |
| linux-discover-1656x817-default.png | 发现页：多源真实歌单卡/榜单/分类 chips（右缘裁切=P2-03 证据） |
| linux-library-1656x817-empty.png | 曲库四类 chips + 本地/网易云/QQ 分段 + 空态 |
| linux-downloads-1656x817-empty.png | 下载页三分段 + 表头 + 空态 |
| linux-settings-1656x817-default.png | 设置页 9 分组 |
| linux-search-1656x817-results.png | love → 257 结果、8 音源徽标 |
| linux-search-1656x817-playing.png | 播放中：行内均衡器 + PlayerBar；**同时是 P0-02 证据（00:00 / --:--）** |

**未取得（被 P0-01 阻断，已在 00-baseline §15 与 04 矩阵 P0-01 如实记录）**：全屏播放页（NowPlaying）、队列面板（ContextPanel queue tab）。旧壳截图（docs/shots/ 等）与本分支现役壳已完全不同，仅作历史证据，不作为当前基线。

## 视觉 QA 结果

- 已完成（8 张基线截图，对照 §12.5 检查项）：发现页横向书架右缘裁切（P2-03）；设置页无分类导航（P2-07）；有真实封面 URL 的卡片普遍显示渐变占位（P1-03，截图+代码双证据）；播放进度 00:00/--:--（P0-02 截图证据）；窗口尺寸契约失效（P2-04）。
- 未完成：
  - 全屏播放页与队列面板走查——P0-01 阻断（5 实例中 3 例卡死：帧差=0、输入全失效）。
  - 浅色主题实机走查——主题切换交互被 P0-01 阻断；P2-01（Vx* 深色常量无条件引用）目前**仅代码层证据，未实机确认**。
  - 手机/平板视口矩阵（360/390/430/600/840/1200 等）——无设备，未验证。

## 新增/关闭缺陷

**新增（缺陷矩阵 04-defect-matrix.md 建立，共 6 条 P0/P1 + 7 条 P2 + 6 条 P3）**

> 注：本次任务简报写「7 条 P0/P1」，与矩阵实际不符——矩阵 P0/P1 为 **6 条**（P0×2、P1×4），「7」对应的是 P2 条数（P2-01~07）。以下按矩阵实数记录。

| 级别 | ID | 摘要 |
|---|---|---|
| P0 | P0-01 | 主 isolate 概率性卡死：搜索结果/播放后 UI 全死（5 实例 3 例，帧差=0、输入全失效） |
| P0 | P0-02 | 播放中 position/duration 恒 0（进度不走、总时长 --:--；比 11-06 旧审计更严重） |
| P1 | P1-03 | 封面三元反写 4 处：有真实封面 URL 反而显示渐变占位（封面普遍缺失） |
| P1 | P1-04 | 搜索「加载更多」硬编码丢 source（ffi/src/lib.rs:1516-1520），第 2 页起回落聚合 |
| P1 | P1-05 | 进程静默退出（1 例，无崩溃日志/core；与 P0-01 疑同根因） |
| P1 | P1-06 | Android 全链不可构建/未验证（环境阻断，非代码缺陷） |
| P2×7 | P2-01~07 | 浅色主题硬编码深色 Chrome（未实机确认）/双 ThemeData 产源/横向书架右缘裁切/窗口尺寸契约/MPRIS 未接/移动端无横向滑动切歌/设置页无分类导航 |
| P3×6 | P3-01~06 | cover_loader 注释与实现不符/readAudioInfo 悬空桥（有降级，旧 P0-A1 降级登记）/类型化 PlaylistKey 未建立/PlaylistDto 元数据丢失/ATK+OpenGL 非致命告警/CONTRIBUTING 基线数字过时 |

**关闭**：0（修复自 Phase 1 起）。
**旧审计复核后确认已修（防重复修复清单，00-baseline §16）**：播放泵、Toggle 回写、SetVolume、错误静默、seed alpha、lag 重拉、reduce-motion、主题预览 rebuild、窄窗降级等 9 条。

## 未解决问题和原因

1. **P0-01 主 isolate 概率性卡死**——未定位。嫌疑方向已列（04 矩阵：事件泵×UI 重建热路径、progress 4Hz 泵、library 事件重取循环），需 Phase 1 profiler/日志定位；该缺陷使一切交互类验收（含 NowPlaying/队列截图、浅色主题走查、8 步歌单隔离序列、Ended 观察、本地导入实机走通）不可信。
2. **P0-02 进度/时长恒 0**——代码链路各环存在（engine watcher → 4Hz 泵 → FFI progress → AppModel → PlayerBar），断点在下游哪一环未定，Phase 1 按 §8.3 逐环排查。
3. **Android 全链未验证**——环境缺 JDK（`java` 不存在）、adb 无设备、SDK 无 emulator/system-images，APK 无法构建；§5/§10/§12.6 真机 13 项全部未验证。需用户提供 JDK + 设备/模拟器后补验（P1-06）。
4. **clippy 门禁原样命令在本环境不可执行**——`--all-features` 激活 voicefox-player 的 build_libmpv → libmpv2 build.rs 因缺 `MPV_SOURCE` panic（exit 101）。这是**环境不可执行**，不是「0 告警」；已用降级命令（`--workspace --all-targets`，不带 `-D warnings`）取得 **30 条告警**基线供 Phase 7 对比。Phase 7 需在有 mpv 源码树的环境跑原样命令，或按指南 §12.1「按 crate/feature 拆分并给出原因」的方式记录。
5. **cargo test --workspace 在 lx-source 已知 flaky 测试处中止**（exit 101）——该测试单独复跑通过；剩余 crate 补跑 exit 0（513 passed），全仓合计 ≈808 passed / 1 known-flaky。flaky 根因未修（在案记录，Phase 7 复测时注意）。
6. **flutter/build/linux CMake 缓存失效**——缓存含旧环境路径（`/usr/sbin/ninja`、`/usr/sbin/clang++` 等，2026-11-07 环境遗留），逐行修补 3 次仍连环失败；删除该可再生构建产物后重建成功（exit 0）。**Phase 7 构建前需清理该缓存目录**（00-baseline §2）。
7. **参考研究报告的诚实声明**（01 §0 / 02 §5-6）：参考项目结论来自静态源码级核验（clone+pin SHA+LICENSE 实读），未运行参考项目截图；mpv_audio_kit pin 精确版本许可证未读到（fetch 网络失败，风险低已声明）；vendored myune 文件头引用的外部 LICENSE 路径已失效，应改仓库内 NOTICE（待办已登记）。

## 下一阶段进入条件

Phase 1（数据链路和 P0 修复）**可以进入**，但以下为进入后的强制顺序（00-baseline §17 / 04 矩阵 Phase 1 进入条件核对）：

1. **先修 P0-01**（卡死）：修复并复测前，任何交互验收/截图回归结果均不可信。
2. **P0-02**：按 §8.3 逐环定位 position/duration 断点，恢复进度/时长/seek 真实数据。
3. **P1-03**：4 处封面三元反写对齐 library_page 写法（约 4 行），再进 §8.2 ArtworkResolver 统一改造。
4. P1-04 SearchMore 补 source 透传；P1-05 与 P0-01 同域排查。
5. 歌单隔离 8 步序列、Ended 自动切歌、本地导入真实走通：待 P0-01 修复后实机执行。
6. Android 全链（含 §12.6 13 项）：继续**未验证**状态直至环境补齐，不得在任何报告中写成已验证。

Phase 0 退出条件核对（指南 §13）：每个参考项目有精确 commit/许可证 ✅（01 报告 pinned SHA + LICENSE 实读）；P0/P1 缺陷有复现步骤 ✅（04 矩阵）；「每个核心页面有现状截图」**部分达成**——8 页已取得，NowPlaying/队列 2 页被 P0-01 阻断未取得，如实披露。
