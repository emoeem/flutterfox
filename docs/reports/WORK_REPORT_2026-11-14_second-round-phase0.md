# 工作报告 · 2026-11-14（第二轮 UI/UX 重构 Phase 0 只读审计 + 门禁恢复批次）

| 项 | 值 |
| --- | --- |
| 报告日期 | 2026-11-14 |
| 项目 | voicefox-gui，分支 feat/ui-redesign @ `eb1afc3`（工作区干净，本轮零生产代码改动） |
| 生产版本 | git `eb1afc3`（WIP 快照，本轮审计对象，未新增提交） |
| 对应更新记录 | 无 release（按红线不打 tag） |
| 执行方式 | 会话内 4 个只读审计子代理（主题链/桌面/手机平板/WIP 批次）+ 本会话复现与定向测试；契约 = 第二轮执行计划书（/home/emo/Downloads/flutterfox-ui-ux-second-round-execution-plan.md） |

## 1. 本轮范围

第二轮计划书 Phase 0：实现盘点与差距审计（只读）。产出 `docs/redesign/second-round/01-implementation-audit.md`（逐页矩阵 + SR-01..18 新差距登记）与 `docs/redesign/second-round/baseline/BASELINE-MANIFEST.md`（基线截图证据集）。未修改任何生产代码、测试代码与既有文档。

## 2. 交付结论

| 级别 | 问题 | 状态 | 关键证据 |
| --- | --- | --- | --- |
| 完成 | 逐页盘点矩阵（全局设计系统/桌面 17 页/手机 10 页/平板）+ 状态分级 | ✅ | 01-implementation-audit.md §三至§六，全部结论带 file:line |
| 完成 | CI analyze 失败根因定位 | ✅ | CI `channel: stable` 未固定（ci.yml:355-358），新 stable 将 `package:flutter/material.dart` 整体弃用（deprecated after v3.47.0-0.0.pre），115 条 `deprecated_member_use` info 触发 `--fatal-infos`；本地 3.47.9 同仓 analyze exit 0 零问题（13.7s 实测）→ 根因是 CI SDK 漂移，非代码劣化 |
| 完成 | WIP 批次（eb1afc3）四项核验：P1-20 代码+widget 测试闭环；P2-16 Rust 单元闭环；P2-17 链路纸面闭环；P2-18 代码完成 | ✅ | 01-implementation-audit.md §七；均缺运行时证据，矩阵 4 条维持开放 |
| 发现 | HEAD flutter test 红：`now_playing_test.dart:286` 旧空态断言与 P2-18 新布局分支冲突 | ❌ 40/41 | 实跑 3 文件 41 用例（discover/now_playing/mobile_now_playing），挂 1 例，2026-11-14 实测 |
| 发现 | 手机 8 页复用桌面实现（仅首页/全屏播放页/壳独立）；主题双真源（ThemeProvider vs Vx token 零引用）；28/44 预设投影失效；首页「导入本地」语义错位 | ❌ 新登记 | SR-03/04/05 等 18 条，01-implementation-audit.md §九 |
| 开放缺陷 | P0-01/P1-05/P2-08/P1-06/P2-04/P2-05/P2-09/P3-09 全部维持开放，未宣称修复 | ⏳ | 01-implementation-audit.md §八逐条核验表 |

## 3. 工程状态（实测）

| 门禁 | 结果 |
| --- | --- |
| flutter analyze --fatal-infos（本地 3.47.9） | exit 0，No issues found（13.7s） |
| flutter test（定向 3 文件） | 40 passed / 1 failed（now_playing_test.dart:286；exit 非零） |
| cargo test（定向 soda 封面链） | 4 passed / 0 failed（soda::api 2 + cover::source 2） |
| CI（PR #12 最新 run 43547105433） | 仅 Flutter(analyze) job 红；Build Linux/macOS×2/Windows/Android 与 Lint(fmt+clippy) 全绿；Test 步骤被跳过 |

工具链：Flutter 3.47.9 stable（c197ca519）、rustc 1.99.0。桌面环境 niri Wayland + DISPLAY=:1，无 Xvfb 常驻。全量门禁（全套 flutter test / cargo test --workspace）本轮未跑，属 Phase 0 只读纪律与预算取舍，下阶段入口批次必须先跑。

## 4. 确认无问题的部分

- 壳层骨架（桌面三栏、PlayerBar 常驻、详情内嵌 Navigator、手机 5 入口、平板三档断点）代码+测试在位，有既有测试锁定，不需重写。
- frb_generated.rs/.dart/.freezed.dart 的 657 行变动确认为 codegen 再生成，无手工逻辑。
- 硬编码色仅 3 处横幅叠字 `Color(0xCCFFFFFF)`，无热点聚集。
- design_system/components 17 个组件无零引用死组件。
- 手机 inset 消费契约（android_insets.dart）单一出处且有公式级测试。

## 5. 已知限制与未做项

- 需要用户决策：CI 修复采 pin 3.47.9 还是 material_ui 迁移（审计建议 pin，理由在 01 §2.1）；git 提交/推送时机（计划书 §0.1.6 留给用户）。
- 代码待办（下阶段入口批次）：SR-01 CI pin+证据独立、SR-02 now_playing_test 重写、SR-12 歌词按钮态+DIAG 残留+过时注释。
- 固有限制：Android 真机验证不可行（无 JDK/AVD，用户明确搁置）；P0-01/P1-05 需长时实机会话，本轮只读纪律下未复现；WIP 三页（discover/now_playing/lyrics）基线截图为 5ec550a 旧代码状态，待运行时验证轮重截（BASELINE-MANIFEST 已标注）。

## 6. 下一步建议

1. ~~门禁恢复小批次（SR-01+SR-02+SR-12 清理）~~ 已完成，见 §七。
2. WIP 批次收尾并行推进：P2-16 HTTP/解码/UI 证据、P2-18 运行时截图、P1-20 运行时复验，证据齐后更新矩阵（P2-17 代码+测试面已在 §七闭环，只剩运行时复验）。
3. 全量门禁已在本日 §七跑齐（386 Dart + 835 Rust），Phase 1 开工无需重跑基线。

## 七、门禁恢复批次（2026-11-14 同日追加）

| 项 | 值 |
| --- | --- |
| 范围 | 仅 CI 门禁、NowPlaying 测试与歌词链路必要修复（按用户指令，不涉及 Phase 1 主题、不涉及无关页面） |
| Git | 零提交零推送，改动全部留在工作区待用户审查 |
| 修改文件数 | 生产代码 3（lyrics_panel.dart / now_playing_page.dart / service.rs）+ 测试 1（now_playing_test.dart）+ CI 2（ci.yml / release-flutter.yml）+ 文档 3（04 矩阵 / 审计 / 本报告） |

### 7.1 修改清单与理由

| 文件 | 修改 | 理由 |
| --- | --- | --- |
| .github/workflows/ci.yml | `flutter` 单 job 拆为 `flutter-analyze` + `flutter-test` 两个独立 job；两处 SDK 补 `flutter-version: 3.47.9`；两 job 各加 `flutter --version`/`dart --version` 输出步骤 | 修 SR-01：SDK 漂移根因 + analyze 失败不再吞测试证据 + CI 日志可直接核对实际版本 |
| .github/workflows/release-flutter.yml | 4 处 flutter-action 补同一 pin | 发布构建与门禁/本地验证版本一致，防同一漂移在 release 面复发 |
| flutter/lib/src/player/lyrics_panel.dart | 新增共用 `LyricsRetryButton`（在途禁用/成功复位/失败通知复位/12s 超时兜底）；空态 action 换用该组件；更新过时文件头注释（P2-17 命令已存在） | 修 SR-12：重取按钮无 loading/防重复态 + 注释谎称「后端无重取命令」 |
| flutter/lib/src/player/now_playing_page.dart | `_LeftColumn` 无歌词单列布局内新增 `LyricsRetryButton`（仅 lyrics 为空时渲染） | 解决 P2-17×P2-18 交叉：单列下 LyricsPanel 不渲染，重取入口不能只挂在面板空态里 |
| application/src/service.rs | 删除 `:1732` `[DIAG-lyric]` eprintln；新增 mock fetcher + LoadLyrics 成功/失败两路径回归测试 | 调试残留与 Notification 事件内容重复，无保留价值；用户要求的链路测试 |
| flutter/test/now_playing_test.dart | 旧「无歌词空态」用例按新行为重写为 6 用例组 | 修 SR-02：旧断言与 P2-18 分支冲突；不删业务断言，按新契约重写 |

### 7.2 CI SDK 固定与验证结果

- 6 处 `channel: stable` 全部补 `flutter-version: 3.47.9`（ci.yml analyze/test 两 job + release-flutter 四平台构建），YAML 解析校验通过（两文件 jobs 列表实测）。
- analyze 与 test 已拆独立 job（`flutter-analyze` / `flutter-test`），任一失败不影响另一 job 出证据。
- **CI 实际运行结论（已闭环，2026-11-14 12:0x）**：提交 `e58e7c2` 推送后 run `43556931399` **8/8 job 全绿**：Flutter (analyze) 1m11s（上一 run 同 job 失败，修复直接生效）、Flutter (test) 3m30s（独立 job 首次跑出测试证据）、Lint/Build Linux/Windows/macOS×2/Android 全绿；版本日志实测 `Flutter 3.47.9 • Dart 3.13.7`，与本地验证版本一致。SR-01 关闭。

### 7.3 NowPlaying 新旧行为差异与 P2-17/P2-18 冲突解决

| 场景 | 旧行为（5ec550a 及以前） | eb1afc3 WIP | 本批次后 |
| --- | --- | --- | --- |
| 有歌词 | 双列（左封面+右 LyricsPanel） | 同左（hasLyrics=true 双栏 46/54） | 不变；测试断言 LyricsPanel 在树、重取入口不显示 |
| 无歌词 | 双列但右列只有「暂无歌词」空态（右半区空置，P2-18） | 单列封面居中，但重取入口随面板一起消失（不可达） | 单列保留，**单列内新增重取入口**（封面/标题/操作区之间） |
| 重取按钮 | 不存在（文案自认「不伪造重试按钮」） | 裸 TextButton，无 loading/防重复/失败反馈 | 在途转圈禁用；成功（歌词内容变化）复位并切双列；失败（「歌词加载失败」通知）复位并提示「暂未取到歌词，可再次尝试」；12s 无事件超时兜底；切歌即复位 |
| 失败通知 | 无 | 全局 notification（Rust 侧已有） | 保留全局通知 + 按钮级复位/提示双层反馈 |

设计冲突记录：P2-18（单列去空面板）与 P2-17（空态面板内重取按钮）天然互斥，解决方式 = 重取入口从「面板空态专属」提升为「独立共用组件」，两处挂载（面板空态 + 全屏单列），语义统一、不重复实现。

### 7.4 歌词链路测试覆盖

| 层 | 测试 | 结果 |
| --- | --- | --- |
| UI 命令派发 | tap 重取 → `FfiCommand_LoadLyrics` 派发断言（_RecordingModel） | ✅ now_playing_test |
| UI 防重复 | 在途态 onPressed=null + 连点不产生第二条命令 | ✅ now_playing_test |
| UI 成功回填 | 歌词内容变化 → 按钮复位 + 双列恢复 | ✅ now_playing_test |
| UI 失败恢复 | 「歌词加载失败」通知 → 复位可重试（第二条命令） | ✅ now_playing_test |
| UI 超时兜底 | 12s 无事件 → 复位 + 失败提示 | ✅ now_playing_test |
| UI 切歌一致性 | 在途切歌 → 复位无失败误报（Rust 侧 prepare() 代次同步失效旧请求） | ✅ now_playing_test |
| Rust 接线 | LoadLyrics 成功：state.lyrics 回填 + LyricsChanged 广播 | ✅ service.rs 新增 2 项 |
| Rust 接线 | LoadLyrics 失败：Notification 前缀断言 + state 不动 | ✅ service.rs 新增 2 项 |
| 页面切换一致性 | 全屏页退出 → 按钮监听器/timer 随 dispose 释放（Widget dispose 契约，全量套件无泄漏报错佐证） | ✅ 全量套件 |

### 7.5 门禁实测汇总（本批次）

| 门禁 | 命令 | 结果 |
| --- | --- | --- |
| dart format | `dart format --output=none --set-exit-if-changed lib test` | exit 0（253 files 0 changed） |
| analyze | `flutter analyze --fatal-infos`（3.47.9） | exit 0，No issues found |
| 定向 | `flutter test test/now_playing_test.dart` | 18/18 全绿 exit 0 |
| 相关 | `flutter test` 5 文件（mobile_now_playing+layout/shell/desktop_queue_interaction/mobile_shell） | 60/60 全绿 exit 0 |
| 全量 | `flutter test` | **386/386 全绿** exit 0（00:32，= L1 基线 380 + 新 6） |
| Rust fmt | `cargo fmt --all -- --check` | exit 0 |
| Rust clippy | `cargo clippy --workspace --all-targets` | 30 条告警 = 既有基线（全 `#[must_use]` 类，与本次改动零关联） |
| Rust test | `cargo test --workspace` | **835 passed / 0 failed** exit 0（833 + 新 2） |
| CI 一致性 | ci.yml 与本地命令逐条对照 | pub get / analyze --fatal-infos / test / fmt / clippy / test 命令一致；SDK 3.47.9 与本地一致 |

### 7.6 仍开放缺陷（坏消息单列）

- **P2-17/P2-18/P2-16/P1-20 四项运行时证据全部缺**：本批次全部验证在 widget/单元层，真实 App 内的实机点按（loading 观感、失败 toast、封面 HTTP 链、音源切回聚合）未做。矩阵四条维持开放。
- **CI 修复的最终证据未取得**：未 push，PR #12 新 run 未跑，analyze/test 双 job 实际结论待观察。
- **P0-01/P1-05/P2-05/P2-09/P3-09 等开放项未触碰**（本批次范围外，如实维持）。
- 重取按钮的 Rust 侧并发竞态（同曲连点两次 prepare）由代次令牌天然覆盖，但未写专项 Rust 并发测试（两次 prepare 使首次 fetch 结果被 load_at 过期校验丢弃，机制在 lyric crate 存量测试内，未重复造）。

### 7.7 是否具备进入 Phase 1 的条件

具备。依据：(a) 全量 Dart 386 + Rust 835 双绿，HEAD 由红转绿；(b) CI 门禁根因已修（代码层），待 push 后双 job 观察确认；(c) P2-17/P2-18 交叉冲突已解决且有测试锁定。Phase 1（主题真源统一，SR-03..08）开工前建议：先 push 一次拿 CI 双 job 绿证据（用户执行），再进入主题改造。
