# 工作报告 · 2026-11-14（第三轮工程演进 Phase 0 基线复核 + Batch A 只读审计）

| 项 | 值 |
| --- | --- |
| 报告日期 | 2026-11-14 |
| 项目 | voicefox-gui，分支 feat/ui-redesign |
| 生产版本 | 审计 HEAD `4e40ee7`（晚于计划基线 `e58e7c2` 一个 docs 提交，满足基线要求）· 工作区仅本批次文档新增/修改，零生产代码改动 |
| 工具链 | Flutter 3.47.9 stable（c197ca519）· Dart 3.13.7 · rustc 1.99.0 · FRB 2.13.0（双侧一致，bridge_smoke_test.dart:7 断言） |
| CI | run `43556931399`（e58e7c2 触发）**8/8 job 全绿**：flutter-analyze 1m11s / flutter-test 3m30s（独立 job 首次出证据）/ Lint / Build Linux/Windows/macOS×2/Android；版本日志实测 Flutter 3.47.9 Dart 3.13.7 与本地一致（2026-11-14 12:0x 查询） |
| 对应更新记录 | 无 release（按红线不打 tag） |
| 执行依据 | 《Flutterfox 跨平台工程演进计划书》Phase 0 + Batch A 只读审计（§第三/四部分）· Git 零提交零推送（计划书 §0.4.9：计划不自动授权 Git 操作） |

## 1. 本轮范围

1. Phase 0 基线复核：HEAD/CI/工作区/版本与文档一致性核验，输出本报告。
2. Batch A 只读审计：FFI 接口与调用链清单（Task A0）+ R01-R12 风险逐条判定，产出 `docs/architecture/ffi-contract-inventory.md` 与 `docs/architecture/ffi-reliability-design.md`。
3. 文档冲突裁决与修正（最重要的 SR-11 右键菜单口径）。
4. 零生产代码修改、零测试修改；修复实施待用户确认后按设计文档分批进行。

## 2. 交付结论

| 级别 | 交付 | 状态 | 证据 |
| --- | --- | --- | --- |
| 完成 | FFI 接口清单：24 Rust API 函数 / 24 DTO / FfiCommand 60 变体 / HostPlayerCommandDto 8 变体 / 3 Opaque / 双流容量（256+64） | ✅ | docs/architecture/ffi-contract-inventory.md §一/§二 |
| 完成 | R01-R12 风险逐条判定（10 项已证实 / 1 项已排除 / R05 需设备验证）+ 18 项最小修复候选 + 三批次实施方案 | ✅ | docs/architecture/ffi-reliability-design.md §一/§四 |
| 完成 | 文档冲突裁决：SR-11「右键菜单整体缺失」口径修正 | ✅ | song_tile.dart:76,217,242,263,393（showSongMenu 4 触发面 + 长按）+ 7 个消费文件实测在用；审计文档 §四/§九已改写 |
| 完成 | 测试覆盖缺口矩阵：state()/事件流/dispatch 全链三类接口双侧无测试 | ✅ | ffi-contract-inventory.md §四 |
| 完成 | 本报告 + docs/README 登记 + 矩阵 FFI-R 登记 | ✅ | 见 §4 |
| 待办 | Batch A 修复实施（A-1 移动命令可靠性 / A-2 事件与快照 / A-3 协议与工程） | ⏳ 待用户确认 | ffi-reliability-design.md §四 |

## 3. 基线事实（计划书 §3.1 逐项）

| 检查项 | 实测结果 |
| --- | --- |
| git status | `feat/ui-redesign` 干净（仅本批次文档改动） |
| HEAD | `4e40ee7` ≥ 计划基线 `e58e7c2` ✓（`git show --stat` 核对基线提交为门禁恢复批次 11 文件） |
| CI 最终结论 | run 43556931399 全绿（非历史瞬间状态，2026-11-14 12:0x 实查 completed）；无更新的 run（e58e7c2 后最新推送即 4e40ee7 docs 提交，其 CI 由 pull_request 同步触发在跑属预期，结论以本轮实查为准） |
| SDK 版本（CI 日志实读） | Flutter 3.47.9 / Dart 3.13.7（Print toolchain versions 步骤输出） |
| FRB 版本 | 2.13.0 双侧一致（frb_generated.rs:2 / frb_generated.dart:2 / pubspec ^2.13.0 / ffi Cargo =2.13.0 精确锁） |
| 测试基线 | 本地全量 flutter test 386 项全绿（2026-11-14 00:32 实跑）+ cargo test --workspace 835 passed 0 failed；与门禁恢复批次记录一致，基线未漂移 |

## 4. 文档与代码冲突核验（计划书 §3.1.7-8）

| 冲突点 | 裁决 |
| --- | --- |
| **右键菜单：SR-11「整体缺失」vs G7「已存在」** | **G7 正确，本轮审计原口径有误。** 当前 HEAD 实测：showSongMenu 定义于 song_tile.dart:76，onSecondaryTapUp/长按触发面 4 处（:217,:242,:263,:393），song_tile.dart 未退役且被 playlist_detail/album_songs/artist_detail/library/browse_songs_view/song_table_view/widgets/custom_playlists/voicefox_queue_drawer 七类表面消费；myune playlist_content_widget.dart:255 另有 onSecondaryTap。残余缺口收窄为「网格卡面与个别视图覆盖」，登记待 Batch D 精查。审计文档 §四/§九已修正（本批次唯一文档改写）。 |
| 主题投影 28/44 失效（SR-05） | 与代码一致（projection.dart `_seedFor` 仅遍历 16 套 kSeedThemes），维持 |
| 手机 8 页复用桌面（SR-03） | 与代码一致（app_shell.dart:802-826 仅 home 槽按形态分叉），维持 |
| P2-17/P2-18 状态 | 代码+widget 测试已闭环（门禁恢复批次），运行时证据维持开放，矩阵口径一致 |
| CI 结论（计划书 §0.3 提示「不得把历史瞬间当最终结论」） | 已实查 completed 8/8 绿，非瞬态 |

## 5. Batch A 审计核心结论（细节见设计文档）

1. **移动播放命令链五项已证实风险（R01-R04、R06-R07）**：订阅前 Play 静默丢失且被既有测试固化为预期（host_player.rs:356）；>64 积压物理覆盖最旧命令且 Dart 无重同步（与 api.rs:93-94 注释宣称不符）；非 Play 命令零代次防护；单命令异常杀死整条命令泵；宿主断连状态永久冻结。R02 延迟幅度与 R05 真实交错、R07 真机断连表现需设备验证。
2. **事件/快照三项结构性发现（R08/R09）**：Rust 每事件尾随的全量 StateChanged 快照被 Dart 整体丢弃（无对应分支）；attach 先拉快照后订阅存在丢失窗口；活跃下载期间每 500ms 一次全量曲库克隆（30k 曲库单次约 30k SongInfo+30k SongDto 两轮分配）。
3. **协议层（R10/R11/R12）**：字符串协议多点重复定义、取消语义藏在 message 文本、错误全 String；codegen 双侧一致（R11 排除）；Runtime 无任务取消与优雅关停（有意设计，登记观察）。
4. 修复方向：18 项最小修复候选按 A-1（移动命令可靠性）/ A-2（事件与快照）/ A-3（协议与工程）三批推进，每批含 Rust+Dart 两侧测试；不重写业务层、不替换 FRB。

## 6. 未验证项（坏消息单列）

- **需设备验证**：R02 慢 Play 延迟幅度、R05 双 play 真实交错、R07 真机断连表现、R09 大曲库真实卡顿幅度（无 Android 授权，全部静态判定；压测/复现需 Linux 桌面或用户授权的设备环境）。
- **需压测验证**：R03 的 >64 积压实际触发（人缩小容量可测，未在本审计批次执行）。
- **Batch A 修复的任何实施**：本轮零代码改动，矩阵 FFI 条目全部标注「修复待批次」。
- Android APK/Gradle/AVD：遵循用户既有约束，全程未触碰。

## 7. 下一批次许可条件

- ~~Batch A-1 实施需用户确认~~ 已按计划书 §13 固定流程在工作区实施（零 commit），见 §8。
- Batch A-1b（#2 命令代次/ID，DTO+FRB 再生成）与 A-2（事件与快照）实施待用户审阅本批 diff 后决定。
- Batch B（主题统一）可在 A-1 系列收口后开工，与 A-2/A-3 可并行评审。

## 8. Batch A-1 实施记录（2026-11-14 同日，工作区改动，零 commit）

| 项 | 值 |
| --- | --- |
| 范围 | 设计文档 §四 #1/#3/#4/#5/#6 五项（R01/R03-Dart 半边/R06 两项/R07）；#2 命令代次需 DTO+FRB 再生成，独立 A-1b |
| 修改文件 | Rust 3（host_player.rs / ffi/src/lib.rs new_host / ffi/src/api.rs 注释）+ Dart 2（host_player_bridge.dart / host_player_bridge_test.dart） |
| Git | 零提交零推送，diff 留工作区待审查 |

### 8.1 修改与理由

| 文件 | 修改 | 对应风险 |
| --- | --- | --- |
| application/src/services/host_player.rs | `pending_play` 挂起槽（play 写入/stop 清除/补投后清空）+ `subscribe()` 首个订阅者补投 + `last_report` 回流时间戳 + `liveness_tick(max_silence)` + `start_liveness_watchdog`（std 线程） | R01 订阅前 Play 丢失；R07 宿主断连状态冻结 |
| ffi/src/lib.rs | `new_host` 启动看门狗（5s 检查/20s 静默阈值；new_host 无 tokio 上下文，故 std 线程而非 tokio 任务） | R07 |
| ffi/src/api.rs | `host_player_stream` 过时注释修正（原「由 Dart 侧重订阅并重拉状态」与实现不符） | 审计疑点 |
| flutter/lib/src/bridge/host_player_bridge.dart | 命令异常与源异常分捕获（命令失败不杀泵）+ lagged 后 `_resync()` 回灌当前快照 + `dispose()` 改 `Future<void>`（await 订阅取消/播放器释放/泵退出，`pumpExitTimeout` 兜底）+ `_disposed` 守卫 | R03 重同步；R06 两项 |
| flutter/test/host_player_bridge_test.dart | 新增 3 用例（lagged 重同步/命令失败不杀泵/dispose 可等待不派发）+ fake 增强（throwOnPause/disposed 标记） | 锁定新行为 |

### 8.2 测试与验证（实测）

| 门禁 | 结果 |
| --- | --- |
| cargo test -p voicefox-application --lib host_player | 7 passed / 0 failed（旧 4 项无削弱 + 新 3 项：补投/stop 清挂起/存活检查 4 场景） |
| flutter test test/host_player_bridge_test.dart | 9 passed / 0 failed（旧 6 项无削弱 + 新 3 项） |
| cargo fmt --all -- --check | exit 0 |
| dart format（2 改动文件） | 0 changed |
| 全量 cargo test --workspace + flutter analyze --fatal-infos + 全量 flutter test | 见 §8.3 实跑记录 |

### 8.3 全量门禁实测

| 门禁 | 命令 | 结果 |
| --- | --- | --- |
| Rust 全量 | `cargo test --workspace` | **837 passed / 0 failed** exit 0（基线 835 + A-1 净增 2：host_player 5→7 测试） |
| analyze | `flutter analyze --fatal-infos` | exit 0，No issues found（5.1s） |
| Flutter 全量 | `flutter test` | **389 passed / 0 failed**（00:31，基线 386 + A-1 新 3） |

### 8.4 行为变化（审查要点）

1. **无订阅者时的 Play 不再丢弃**：挂起并在首个订阅者接入时补投；`stop` 后不再补投。旧行为测试 `play_without_subscriber_still_accepts` 强化重写为 `pending_play_replayed_on_first_subscribe`（原断言保留 + 补投/不重复断言），非删除。
2. **宿主断连/回流断流自动回落 Stopped**：`liveness_tick` 经 watch send_replace 走观察者泵正常广播，UI 零特殊处理；有挂起 Play 时不回落（避免误报停止）。
3. **lagged 后回灌当前快照**：Rust watch 与宿主状态对齐，泵继续消费缓冲内剩余指令。
4. **单条命令失败不再杀死泵**：仅 debugPrint 记录；真实播放器错误仍走 eventStream → reportEvent 既有链路，无重复上报。
5. **dispose 语义变化**：`void` → `Future<void>`（无生产调用点，兼容性零影响）；dispose 后到达的指令被 `_disposed` 守卫拦下，不再触碰已释放播放器。

### 8.5 未实施与未验证（坏消息单列）

- **#2 全命令 commandId/generation**：需 HostPlayerCommandDto 扩展 + FRB 再生成 + 双侧测试，独立 A-1b（codegen 本地可用已核实）。R04（过期命令误执行）在 #2 落地前仅由重同步缓解。
- **R02 慢 Play 分流**：依赖 #2 元数据，A-1b。
- **per-command ack**：同属 A-1b 契约变更。
- **运行时/真机证据**：引导窗口补投、断连看门狗、lagged 重同步均为 widget/单元层验证；Android 真机与 Linux 实机断连复验维持「需设备验证」（用户既有约束，未触碰 APK/Gradle/AVD）。

## 9. Batch A-1b / A-2 / A-3（同日连续实施，均已推送，用户已授权全部后续内容）

| 批次 | commit | 内容 | 门禁 |
| --- | --- | --- | --- |
| A-1b | `5e6f066` | 命令契约升级：8 变体 command_id 打戳 + 歌曲域 generation（FFI-R04 过期过滤）；新 FFI hostPlayerAck + pending 表销账（FFI-R06 ack 回销）；FRB 再生成幂等校验 | Rust 838/0、Flutter 391/391、CI 同款 clippy 0 |
| A-2 | `9304b86` | emit() 停止尾随全量 StateChanged（旧实现克隆后 Dart 整体丢弃）；_refreshState 单飞+追尾；attach 先订阅后拉快照；_eventLoop 连续 5 败置 streamDead + restartEventLoop；state() 拆出 local_songs（新 FFI localSongs + 按需拉取，页面零改动）；downloads_bridge 500ms→1s | 同上口径全绿 |
| A-3 | `092fd92` | PlayerState::as_protocol_str() 播放状态串单源；pubspec FRB 精确锁；ci.yml 新增 codegen-check job；gate 脚本 clippy 与 CI 逐字对齐 | 同上口径全绿 |

关键教训（f56e08b Lint 失败复盘）：CI clippy 门禁为 `-D warnings -A clippy::double_must_use`（30 条基线告警即 double_must_use，async_trait 宏展开固有豁免）；A-1 曾用宽松口径对账漏掉 2 条新告警，A-1b 起以 CI 同款命令对账并修复 gate 脚本分叉。

遗留如实登记：一次性事件（Notification/二维码/Sync/Browse 应答）丢失即丢为既定语义；sync cancelled 字段化与结构化 FfiError 留 Sync/下载批次；AppModel 事件泵直测需真控制器留 Batch I；R02 慢 Play 分流依赖代次契约留 A-1c 评估；运行时/真机证据全部维持「需设备验证」。

## 10. Batch B 进入

Batch A 全部收口（审计 + A-1/A-1b/A-2/A-3）。下一批 Batch B 主题真源统一（SR-03..08：双真源收敛、44 预设投影修复、dynamicColor 单源、Typography 层级、guard 补洞）。
