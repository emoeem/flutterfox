# Phase 0 Report

> 日期：2026-11-11（修订版；首版 2026-11-10 见提交 `5725231`）
> 分支：`feat/ui-redesign` @ `5725231634f32436455b89ffda7a0f3215777f00`；工作区含 Phase 1 未提交改动（29 个源码/文档修改 + 9 个新增文件，归 phase-1-report.md）
> 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §2 / §13 / §14 模板
> 审计证据：`docs/redesign/00-baseline.md`（第二轮全量复审，审计对象 = Phase 1 实施后的当前工作区）；缺陷明细 `docs/redesign/04-defect-matrix.md`（第二轮重写）
> 核验口径：与首版不同，本版**全部硬门禁命令（clippy gate 原样命令除外，见下）由报告员于 2026-11-11 当日实跑复验**（B 表）；审计会话完成、本报告员未复跑的项（Linux release 构建、Xvfb 交互与截图采集）在 A 表单列并注明出处。

## 范围

Phase 0 = 基线审计 + 参考研究（指南 §13 Phase 0 交付：`00-baseline.md` ~ `04-defect-matrix.md`），分两轮执行：

1. **第一轮（2026-11-10，提交 5725231）**：全量读代码重审（不照抄旧审计）+ 6 参考项目源码级研究（clone → pin SHA → LICENSE 实读 → 依赖许可证逐查）+ niri 实机交互审计与首轮 8 张截图 + 缺陷矩阵建立。
2. **第二轮（2026-11-11 修订轮，本版）**：针对「Phase 1 实施后的当前工作区」全量复审：00-baseline 与 04 矩阵按本轮新证据重写；01/02/03 研究文档改为「三轮核验」诚实口径（研究记录第一手 → 2026-11-10 汇总轮 `/tmp/voicefox-ref/` 克隆在场复核 SHA×6、LICENSE×6 一致 → 本轮克隆已清理、该复核**无法复跑**，如实登记）；Xvfb 受控显示器补齐第一轮被 P0-01 阻断的实机交互走查与新基线截图 13 张（含 NowPlaying、队列、浅色主题、走带三连）。

## 修改文件

Phase 0 范围内**零源码改动**（工作区 29 个源码/测试修改 + 9 个新增 = Phase 1 实施，见 phase-1-report.md）：

- `docs/redesign/00-baseline.md`（重写为第二轮全量复审，2026-11-10）
- `docs/redesign/04-defect-matrix.md`（第二轮重写：本轮新证据后）
- `docs/redesign/01-reference-projects.md`（2026-11-11 修订轮：三轮核验口径）
- `docs/redesign/02-license-and-reuse-audit.md`（2026-11-11 修订轮：核验基础区分）
- `docs/redesign/03-component-reuse-map.md`（2026-11-11 修订轮：本仓行号逐一实测更新）
- `docs/redesign/phase-0-report.md`（本文件，修订版）
- `docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §17（Phase 0 行验收证据更新；Phase 1 行由 phase-1 报告员更新）
- `docs/redesign/screenshots/baseline/` 新增 13 张 PNG（见「截图路径」）
- 仓库状态：git status 29 modified + 9 untracked，与 00-baseline §1 清点一致（报告员本轮复核：flutter 侧未跟踪 dart 文件恰 8 个 + phase-1-report.md = 9）

## 关键设计决策

Phase 0 无代码设计决策，研究与审计层面判定（依据 01/02/03/04 四份报告）：

1. **复用判定矩阵（维持第一轮结论）**：代码级移植仅限 myune（Apache-2.0，已 vendored，pin `5188867b…`）与 aethertune（0BSD）；finamp（MPL-2.0）仅个别 UI 文件小幅改造且保留 MPL 头；feishin（GPL-3.0）/nuclear（AGPL-3.0-only）/harmonoid（PolyForm Strict 1.0.0）一律**仅参考交互、禁止任何代码复制**。
2. **harmonoid 双许可证陷阱（维持）**：根许可证 PolyForm Strict 1.0.0；≤2022-02 旧快照为 GPL-3.0，从旧 tag 摘代码会整体传染，禁入清单。
3. **三轮核验口径（01/02 修订轮新增）**：外部仓库 SHA/许可证结论的证据链 = 研究记录（第一手）+ 2026-11-10 汇总轮复核（当时一致）；本轮 `/tmp` 克隆已清理，复核不可复跑，已如实登记而非冒充本轮复现；仓库内可复验项（vendored 文件头、license_service 等）本轮实测。
4. **截图命名与视口语义（本轮修正）**：验收截图必须在受控显示器采集：Xvfb :2 下 `VOICEFOX_START_SIZE=1440x900` 请求即所得；niri 平铺下同一请求实得 tile 1212x1274（P2-04）。本轮 13 张按实际 1440x900 命名；第一轮 1656x817 ×8 保留作历史对照，不混用。
5. **缺陷先行与「未复现≠修复」**：P0-01 本轮 8 分钟实机全流程未复现，但概率性缺陷的未复现不构成修复证据，根因未定位前长时间会话验收不可信（04 矩阵 P0-01 状态栏）。
6. **旧审计逐条复核后才引用（维持）**：UI_AUDIT 旧条目 14 条已修逐条核对（00-baseline §16），防重复修复或漏修。

## 数据流/交互变化

无。Phase 0 为只读审计与研究，未改动任何代码、FFI、状态或交互行为。
（Phase 1 的源码改动，如 `runtime/src/lib.rs:22-32` `enter_sync_bootstrap_runtime()` 泵启动修复，归 phase-1-report.md，本报告仅作为审计对象复核其行为。）

## 执行命令与退出码

### A. 审计会话实跑（本报告员未复跑，出处注明）

| 命令 | 退出码 | 结果 | 出处 |
|---|---|---|---|
| `flutter build linux --release` | **0** | bundle 用于 Xvfb 实机审计；产物 mtime 晚于最后 Rust 源码编辑（00-baseline §2） | 审计会话构建日志 /tmp/vx-baseline2/build-linux.log |
| Xvfb :2（1920x1080x24，无 WM）XTest 注入交互 + 截图采集 | n/a | 全流程：搜索 259 结果、双击播放、走带、队列/全屏播放页/五页导航/主题切换；13 张截图入库（文件在场已核） | 00-baseline §7/§15、04 矩阵 |

### B. 报告员 2026-11-11 实跑复验（本会话，命令原文与退出码）

| 命令 | 退出码 | 结果 |
|---|---|---|
| `scripts/redesign-gate.sh dart-format` | **0** | `Formatted 237 files (0 changed) in 1.32 seconds.`（00-baseline §3 记 229 系第一轮数字：229 + Phase 1 新增 8 个 dart 文件 = 237，已按未跟踪文件清单核对） |
| `scripts/redesign-gate.sh flutter-analyze` | **0** | `No issues found! (ran in 16.4s)` |
| `scripts/redesign-gate.sh flutter-test` | **0** | `00:27 +229: All tests passed!`（229 项，与 00-baseline §3 一致） |
| `scripts/redesign-gate.sh cargo-fmt` | **0** | 无输出（全绿） |
| `scripts/redesign-gate.sh cargo-test` | **0** | 21 个 `test result: ok`，合计 **816 passed / 0 failed**（与 00-baseline §3 一致；第一轮 lx-source flaky 本轮亦未复现） |
| **gate cargo-clippy 原样命令**：`cargo clippy --workspace --all-targets --all-features -- -D warnings`（原文见 scripts/redesign-gate.sh:59） | **101（构建失败）** | `MPV_SOURCE=<unset>`（printenv 确认）→ libmpv2 6.0.0 build.rs panic：log 第 10 行 `env var MPV_SOURCE not set: NotPresent`；同轮另有 lx-core 28 个 `must_use` 错误中止。**本环境无法按原样执行：属「环境不可执行」，不是「0 告警」** |
| `cargo clippy --workspace --all-targets`（去 `-D warnings` 降级基线） | **0** | **30 条 unique 告警**，全部 `#[must_use]`（lx-core 28 + voicefox-application 2；日志 34 行 warning 输出中 4 行为 cargo crate 汇总行，不计入） |
| `flutter test test/search_pagination_test.dart test/playlist_detail_isolation_test.dart`（flutter/ 下） | **0** | `00:07 +11: All tests passed!`（分页 4 + 隔离 7） |
| 清点核对：baseline 截图、矩阵条目 | n/a | 13 张 `*1440x900*` 在场（未跟踪）；矩阵 P0×2、P1×7、P2×9、P3×7 与文件实读一致 |

**Phase 7 对比基线（锁定）**：clippy unique 告警 30 条（不得更差）；flutter-test 229；analyze 0；cargo-test 816 / 0 failed；两套格式化 0。clippy gate 原样命令在本环境为「无法执行」（MPV_SOURCE），Phase 7 复验沿用「去 `--all-features` + 统计告警」口径并保持该事实披露（00-baseline §3）。

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过/说明 |
|---|---|---|---|
| Flutter（unit/widget/golden，37 文件） | **229** | 0 | 0 skipped（报告员本会话复跑） |
| Rust 全仓 | **816** | 0 | 0 failed（报告员本会话复跑；第一轮 lx-source flaky 未复现） |
| search_pagination_test（分页 in-flight 锁 + source 透传） | **4** | 0 | 报告员本会话定向复跑 |
| playlist_detail_isolation_test（§8.1 八步序列 widget 层映射） | **7** | 0 | 报告员本会话定向复跑 |
| 歌单隔离 §8.1 八步序列**实机**走查 | 0 | n/a | **未执行**：实机多歌单切换观察未做；widget 层 7 项已锁定 AppModel 语义（P3-03） |
| 搜索分页**实机**多页触底交互 | 0 | n/a | **本轮会话未做**；in-flight 锁与 source 透传由上述 4 项测试锁定 |
| 本地音乐真实导入端到端 | 0 | n/a | **未走通**：本机无媒体文件（Phase 5 计划项）；导入 UI/扫描链路仅代码层 + widget 测试证据（00-baseline §11） |
| MPRIS/托盘/系统集成 | 0 | n/a | **未实现**：Rust 侧 app/src/mpris.rs 存在、GUI 未接（P2-05，Phase 6 计划项） |
| Android（§12.6 真机 13 项） | 0 | n/a | **全部未验证**：无 JDK、SDK 无 emulator/system-images、adb 无设备（见「设备和视口」） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux 桌面 release | ✅ exit 0（审计会话实跑，A 表；bundle 已用于 Xvfb 实机审计） |
| Android APK | ❌ 不可构建：无 JDK → Gradle 不可用；**用户已明确搁置 Android 验证（禁止 APK/Gradle 构建与 AVD 创建）**（P1-06） |
| Android 交叉 FFI（NDK） | 未执行（同上环境阻断） |
| Windows / macOS | 未尝试（本机无对应构建链；CI 有对应 job，本会话未触发） |

## 设备和视口

- **桌面实机（本轮采集环境）**：Xvfb :2（1920x1080x24，无 WM），release bundle，XTest 注入交互；应用按请求呈现 1440x900（受控显示器下请求即所得）。:1（niri 26.04 + xwayland-satellite）仅用于窗口行为观察（P2-04：请求 1440x900 实得 tile 1212x1274；P2-08：satellite 转发 resize 后 OpenGL frame timeout + 进程静默消失观察）。
- **Android**：无真机、无模拟器（`adb devices` 空；SDK 无 emulator/system-images）、无 JDK（`java` 不存在）→ 指南 §5（手机 UI）、§10（系统集成）、§12.6 真机 13 项**全部未验证**；MobileShell/TabletShell/AndroidInsets 仅 widget 测试层覆盖（android_insets_layout_test 7 项在 229 内）。
- **平板三态断点（600/900/1200）**：无触屏设备，仅 resolveShellMetrics/resolveDeviceFormFactor/resolveTabletLayout 纯函数单测与 widget 测试覆盖。

## 截图路径

`docs/redesign/screenshots/baseline/` 本轮新基线 **13 张**（Xvfb :2，1440x900，真实数据、播放中状态，命名 `<platform>-<page>-<viewport>-<state>.png`）：

| 文件 | 内容 |
|---|---|
| linux-home-1440x900-playing.png | 问候 + Continue Listening Hero 播放中 + 最近播放真实封面 + 我的歌单 |
| linux-search-1440x900-results.png | love → 259 结果、8 音源徽标、类型 Tab（**同时是 P1-08 证据：行封面渐变占位**） |
| linux-search-1440x900-playing.png | 搜索页 + PlayerBar 播放中 |
| linux-search-1440x900-playing-00-02-progress.png | PlayerBar `00:02 / 00:30`（P0-02 关闭证据 1/3） |
| linux-search-1440x900-playing-ended-auto-next-00-00.png | 曲目结束自动切下一首 `00:00 / 02:34`（P0-02 关闭证据 2/3 + Ended 自动切歌复核） |
| linux-search-1440x900-playing-00-26-progress.png | 26 秒后 `00:26 / 02:34` 走带（P0-02 关闭证据 3/3） |
| linux-library-1440x900-songs.png | 曲库：快捷卡真实计数 + 分类 chips + 来源分段 + 空态 |
| linux-discover-1440x900-default.png | 发现页：酷我/酷狗热门歌单真实封面分组（P1-03 关闭证据；右缘裁切 = P2-03） |
| linux-downloads-1440x900-empty.png | 下载页四分段 + 表头 + 空态 |
| linux-settings-1440x900-default.png | 设置页左侧分类导航 9 组 |
| linux-settings-1440x900-light-theme.png | **浅色主题实机：P1-09 Chrome 对比度破坏证据**（Header/Sidebar/PlayerBar 深底深字） |
| linux-nowplaying-1440x900-playing.png | 全屏播放页：渐变占位封面（非黑块）、01:11/02:34 走带、音量 80 真实值、歌词诚实空态 |
| linux-queue-1440x900-playing.png | 队列面板：当前曲高亮、256 待播、真实封面（**同时是 P1-08 对照证据：同曲队列显示真实封面**） |

第一轮 8 张 `*-1656x817-*`（niri 全屏、P0-02 修复前）保留作历史对照；第一轮因 P0-01 阻断缺失的 NowPlaying/队列截图**本轮已补齐**。旧壳截图（docs/shots/ 等）不作为当前基线。

## 视觉 QA 结果

- **本轮已完成**（对照 §12.5 检查项）：全屏播放页与队列面板走查（第一轮被 P0-01 阻断，本轮通过：渐变占位非黑块/走带/音量真实值/诚实歌词空态/队列高亮+单曲移除+清空确认+计数）；设置页分类导航 9 组（P2-07 关闭）；**浅色主题实机切换（深→浅→深往返即时生效）发现 P1-09**（Chrome 深底深字，截图为证）；发现页多源真实封面 12+ 张（P1-03 关闭证据）；搜索结果行封面普遍占位 → **新开 P1-08**；1440 视口横向书架右缘裁切维持（P2-03）。
- **维持/新登记（代码+实机证据）**：P2-08（satellite resize → GL timeout → 进程静默消失观察，关联 P1-05）；P2-09（队列拖动排序后端无命令，UI 禁用并说明，不伪造）；P3-07（全屏播放页歌词无手动重取入口）。
- **未完成**：Android 手机视口矩阵（360/390/430 等）与平板三态实机走查，无设备；搜索分页实机多页触底交互，本轮会话未做（见「未解决问题」）。

## 新增/关闭缺陷

**缺陷矩阵现状（04-defect-matrix.md，第二轮重写）**：P0×2 + P1×7 = **9 条 P0/P1 级条目** + P2×9 + P3×7。
（口径说明：本任务简报写「缺陷矩阵 7 条 P0/P1」，与矩阵实数对照：「7」对应 **P1 条数**；P0 级 2 条（P0-01 开放、P0-02 已关闭）另计，合计 9 条。以下按矩阵实数记录。）

| 级别 | ID | 摘要 | 状态 |
|---|---|---|---|
| P0 | P0-01 | 主 isolate 概率性卡死（第一轮 5 实例 3 复现） | **开放**；本轮 Xvfb 约 8 分钟全流程交互未复现，根因未定位，不构成修复证据 |
| P0 | P0-02 | 播放中 position/duration 恒 0 | **已关闭（Phase 1）**：runtime 同步引导修复 + 本轮实机走带三连复核 |
| P1 | P1-03 | 封面三元反写 4 处 | **已关闭（Phase 1）**：反写 grep 归零 + 发现/首页/队列实机真实封面 |
| P1 | P1-04 | 搜索「加载更多」丢 source | **已关闭（Phase 1）**：FFI+Rust+Dart 三层修复；实机多页触底未做（诚实标注） |
| P1 | P1-05 | 进程静默退出（无崩溃日志） | **开放**；本轮新增 1 例观察（satellite resize 链，含非用户常规触发；与 P0-01 同域疑云） |
| P1 | P1-06 | Android 全链不可构建/未验证（环境阻断） | **维持**；用户明确搁置 |
| P1 | P1-07 | 错误 toast 无高度上限 + 原始异常直出 | **已关闭（Phase 1）**：源头净化 + vendored 兜底；error_toast_test 9 项 |
| P1 | P1-08 | 搜索结果歌曲行封面普遍缺失（VxTrackRow 漏传 cover） | **本轮新发现并复现**（修复方向：search_page.dart:550 补传 cover） |
| P1 | P1-09 | 浅色主题 Shell Chrome 对比度破坏（VxColors 硬编码深色） | **本轮新发现并复现**（由 P2-01 升级） |
| P2×9 | P2-01~09 | 01 并入 P1-09；02 双 ThemeData 产源；03 书架右缘裁切；04 窗口尺寸契约；05 MPRIS 未接；06 移动端无横滑切歌；07 设置分类导航已修；08 satellite resize→静默退出观察；09 队列拖动排序无后端命令 | 本轮实数 |
| P3×7 | P3-01~07 | 01 注释已修；02 readAudioInfo 悬空桥（有降级）；03 PlaylistKey 已落地（实机八步未走查）；04 PlaylistDto 元数据丢失；05 ATK/OpenGL 非致命告警；06 文档基线数字过时；07 歌词无手动重取 | 本轮实数 |

**关闭**：6 条（P0-02、P1-03、P1-04、P1-07、P2-07、P3-01；P3-03 落地转长期验证记录）。**新开**：5 条（P1-08、P1-09、P2-08、P2-09、P3-07）。每条 P0/P1 有复现步骤（04 矩阵）。

## 未解决问题和原因

1. **P0-01 主 isolate 概率性卡死**：**根因未定位**。本轮 Xvfb 会话约 8 分钟全流程交互（搜索 259 结果、双击播放、走带、队列/全屏播放页/五页导航/主题切换）未复现一次；**第一轮 5 实例 3 复现记录保留**。概率性缺陷的「未复现」不构成修复证据；Phase 1 事件速率观测（`voicefox events: N/5 s`）本轮输出正常。长时间会话的截图回归/交互验收在该缺陷定位前不可信（04 矩阵 P0-01）。
2. **P1-05 进程静默退出**：本轮新增 1 例观察（xwayland-satellite 转发 X configure resize → GL frame timeout → 数分钟内进程消失，无 panic/core/journal）。触发链含非用户常规操作，未定罪根因；与 P0-01 同域，Phase 1 后续一起定位。
3. **Android 全链未验证**：环境缺 JDK（`java` 不存在）、adb 无设备、SDK 无 emulator/system-images；**用户已明确搁置（禁止 APK/Gradle 构建与 AVD 创建）**。指南 §5/§10/§12.6 真机 13 项全部未验证，在环境补齐前不得在任何报告中写成已验证（P1-06）。
4. **本地音乐真实导入端到端未走通**：本机无媒体文件；导入 UI/扫描链路仅代码层 + widget 测试证据（00-baseline §11）；**Phase 5 计划项**。Android SAF URI 亦未验证（无设备）。
5. **搜索分页实机多页触底交互未做**：本轮实机会话未执行触底翻页观察；正确性由代码链路核对 + `search_pagination_test` 4 项（in-flight 锁 `_moreInFlight`、requestId 失效释放、source 透传）锁定，如实标注。
6. **歌单隔离 §8.1 八步序列实机走查未做**：`playlist_detail_isolation_test` 7 项覆盖 widget 层映射（PlaylistKey 隔离 + appendArmed 过期丢弃），实机多歌单切换观察未做（P3-03）。
7. **clippy gate 原样命令在本环境不可执行**：`--all-features` 激活 libmpv2 build.rs，`MPV_SOURCE` 环境变量未设 → panic（exit 101；**报告员本轮实测复现**，log 含 `env var MPV_SOURCE not set: NotPresent`）。这是**环境不可执行**，不是「0 告警」；降级命令（`--workspace --all-targets`，无 `-D warnings`）取得 **30 条告警**基线锁定供 Phase 7 对比。Phase 7 需在有 mpv 源码树的环境跑原样命令，或按 §12.1 拆分记录。
8. **平板三态断点实机未验证**：无触屏设备，仅纯函数单测 + widget 测试覆盖。
9. **参考项目 `/tmp` 克隆已清理**：01/02 的「汇总轮复核（SHA×6、LICENSE×6 一致）」发生在 2026-11-10 且当时在场；本轮修订轮**无法复跑**该复核，已按三轮核验口径如实登记（01 §0 / 02 §0），仓库内可复验项本轮实测。
10. **00-baseline §3 dart-format 数字过时（本轮发现并修正口径）**：该节记「Formatted 229 files」沿用第一轮数字；报告员本轮实测 `Formatted 237 files (0 changed)`（229 + Phase 1 新增 8 个 dart 文件），退出码 0 不受影响。

## 下一阶段进入条件

Phase 0 退出条件核对（指南 §13）：每个参考项目有精确 commit/许可证 ✅（01 报告 pinned SHA，三轮核验口径下诚实登记本轮不可复跑部分）；P0/P1 缺陷有复现步骤 ✅（04 矩阵）；「每个核心页面有现状截图」✅（本轮 13 张补齐第一轮缺失的 NowPlaying/队列；8 个页面 + 浅色主题变体全部在场）。

进入后续 Phase 前的强制项（04 矩阵「下一阶段进入条件」）：

1. **先修 P1-08**（search_page.dart:550 补传 cover，单行）与 **P1-09**（Chrome 背景改读 ColorScheme token，对齐 seekTrack 既有三元做法）。
2. **P0-01 继续以「概率性未复现」状态跟进**：长时间会话验收（含后续各 Phase 的截图回归）前必须定位根因；不得因本轮未复现而改状态为已修。
3. P1-05 与 P0-01 同域排查；P2-08 观察项随附。
4. 歌单隔离八步实机走查、搜索分页实机多页触底：可在后续 Phase 的实机会话补做，补做前维持「未验证（测试锁定）」标注。
5. 本地音乐真实导入端到端：Phase 5 计划项（需真实媒体文件）。
6. Android 全链（含 §12.6 真机 13 项）：继续**未验证**状态直至环境补齐且用户解除搁置；在此之前禁止 APK/Gradle 构建与 AVD 创建，不得写成已验证。
7. 门禁基线保持：clippy 30 条 / flutter-test 229 / cargo-test 816 / analyze 0；Phase 7 复验沿用「去 `--all-features` + 统计告警」口径并披露 MPV_SOURCE 缺失事实。
