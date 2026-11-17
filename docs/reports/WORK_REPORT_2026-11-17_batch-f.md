# 工作报告：Batch F（队列协议 §9.1 + media-session crate 提取 §9.2 + GUI MPRIS §9.3：P2-09 关闭）

> 日期：2026-11-17 · 执行环境：Windows 10（Git Bash）· 分支 feat/ui-redesign · 基线 HEAD `293be01`（Batch E 提交）
> 上游：计划书 §9（队列协议 + 桌面媒体会话）· 04 矩阵 P2-09 · 本批为**首个 Rust/FFI/Dart 三面联动批次**（FRB codegen 再生成）

## 基线

- 分支/HEAD：feat/ui-redesign @ `293be01`，工作区干净（仅本批改动）。
- Flutter 3.47.9 / Dart 3.13.7 / rustc 1.100.0（gnu）/ FRB 2.13.0（本机新装 + 本地路径补丁，见「工具链增量」）。

## 审计结论（Step 1-2，§9.1/§9.3 现状逐项）

| 项 | 审计判定 | 证据（HEAD 293be01） |
|---|---|---|
| Rust 队列命令面 | **只有 add/remove/clear/set_index，无 move/play_at**——P2-09「拖拽禁用」登记属实，不是呈现层偷懒 | application/src/services/queue.rs |
| TUI 媒体架构 | 分层清晰：`media_session.rs` 纯数据层 + `mpris.rs`/`smtc.rs` 协议翻译层——**完美可提取为共享 crate**，GUI 不必从零实现两套 D-Bus | app/src/{media_session,mpris}.rs |
| GUI 播放命令面 | `ApplicationCommand` 已有 PlayCurrent/Pause/Resume/Toggle/Stop/Seek/SetVolume/Next/Previous——与 MediaCommand 一一对应，无需新增命令 | application/src/event.rs |
| GUI 状态面 | `PlaybackSnapshot{state,song,position,duration,volume,generation}` + `QueueState.songs.len()`——快照数据源齐全；play_mode 为 config 字符串（`none`/`list-loop`/`single-loop`/`random`） | application/src/state.rs + service.rs |

## §9.1 队列协议（P2-09 三面收口）

| 面 | 修改 |
|---|---|
| Rust | `QueueService::move_item(from,to)`：越界/原地幂等返回 false；**当前播放条目身份保持**——移动跨越当前索引时同步修正索引（`from==current→to`；`from<current≤to→current-1`；`from>current≥to→current+1`），避免「拖完之后正在播的歌错位」+ `ApplicationCommand::QueueMove/QueuePlayAt` 变体 + dispatch 处理器（QueuePlayAt 复用 play，越界返回与 Play 同款错误文案） |
| FFI | `FfiCommand::queueMove/queuePlayAt` 变体 + `into_application` 映射 + FRB codegen 再生成（frb_generated{,.io,.web}.dart / frb_generated.rs） |
| Dart | `app_model` +`queueMove`/`queuePlayAt`；`queue_panel` 从「拖拽禁用」改为 `ReorderableListView.builder` + `onReorderItem`（Flutter 3.47 新 API：SDK 已抵消移除偏移，命令语义 = Rust move_item）+ 拖柄 `drag_indicator` + `ReorderableDragStartListener` + proxyDecorator 浮起视觉 |
| 测试 | Rust queue 模块 6→10（+4：move_item 正常/越界幂等/当前条目身份/跨索引修正）；Dart `queue_interaction_test` 按 Batch F 真实语义重写（disabled-drag 用例不再符合新行为，不削弱）10/10 全绿 |

## §9.2 media-session crate 提取（GUI/TUI 共用，不从零实现两套 D-Bus）

- 新 crate `media-session`：`media_session.rs`（平台无关纯数据：`MediaSnapshot`/`MediaCommand`/`MediaLoopStatus`/`MediaHandle`/`translate_event`）+ `mpris.rs`（zbus 协议翻译，cfg linux）+ souvlaki 依赖随迁。
- **`MediaLoopStatus` 解耦枚举**：与 TUI `PlayMode` / GUI play_mode 字符串互不依赖，两端各自映射（Batch F 计划书 §9.2 既定裁决）。
- TUI 经 `app/src/media_session.rs` shim re-export 消费（`crate::media_session::…` 引用路径零变化）；shim 清理无人消费的 `micros` re-export（clippy unused import）。

## §9.3 GUI MPRIS 桥（application crate，cfg linux）

- 新 `application/src/services/mpris_bridge.rs`：
  - **纯逻辑跨平台编译 + 19 单测全绿（Windows 实跑）**：`map_loop_status`（play_mode 四态映射）/ `build_snapshot`（ApplicationState→MediaSnapshot）/ `translate_command`（MediaCommand→ApplicationCommand，Play/Toggle 按当前态分派：Paused→Resume、Idle/Stopped→PlayCurrent、Playing/Loading→Pause/无动作）/ `BridgeEpoch`（跳转纪元推进器）。
  - **Linux 运行时接线（cfg target_os="linux"）**：`spawn_mpris_bridge`（配置开关 `config.integration.mpris` 内含；独立线程 + 专用 tokio 运行时，与 FFI-R07 看门狗同构的自足装配；D-Bus 不可用/启动失败只记日志不影响应用）+ 快照循环（订阅应用事件，相关事件全集触发重建，MPRIS 层逐字段差异比对去重信号）+ 命令循环（桌面控件→既有 dispatch 链，单条失败只记日志不中断）。
  - **跳转纪元汇流**：换曲/重放（`state.playback.generation`）+ seek 兜底（`observe_position` 位置不连续检测——MPRIS 发起与 GUI 滑杆 seek 同路；播放中漂移 >1.5s / 暂停中任何位移；Loading 期不判定）→ MPRIS 层据此发 seeked 信号。
- `service.rs`：`play_mode` 提升为 `pub(crate)` + 新增 `mpris_enabled`（cfg linux）。
- `ffi/src/lib.rs::new_desktop`：cfg linux 调 `spawn_mpris_bridge(application.clone())`（`ApplicationService` 本就是 `#[derive(Clone)]` 全 Arc 字段，clone 即共享所有权——原计划的「值→Arc 改造」不必要，如实消解）。

### 如实登记的语义裁决

| 项 | 裁决 | 理由 |
|---|---|---|
| `MediaCommand::Quit` | GUI 侧忽略（记日志） | GUI 窗口生命周期归宿主（Flutter/桌面环境），Rust 侧无从优雅关闭；TUI 退出语义不搬入 GUI。开放项：如需支持，走新增事件面通知 Dart |
| MPRIS SetVolume | 只 dispatch `SetVolume`（引擎即时生效），不持久化 config | config 写面归 Dart `ConfigUpdate` 流程；下次 Dart 配置写入自然收敛。TUI 侧 persist_volume 语义不照搬 |
| seeked 回声 | MPRIS 发起的 SetPosition 也会触发 seeked 信号 | 与 TUI 行为一致（同走 ctx.seek/位置不连续检测）；规范上客户端发起的 seek 不应收到回声，实测对客户端无害（重新同步到同位置） |
| cfg-linux 编译验证 | 本机不验证，留 Linux CI（PR #12） | 本机无 x86_64-linux-gnu gcc（cc-rs 依赖无法交叉 check）；Linux-only 代码已人工复核 API 面（分发签名/事件变体/re-export 链）。与 1920 截图等「Linux 运行时项」口径一致 |

## 工具链增量（交接文档 §二 增补候选）

1. **FRB 2.13 Windows 路径 bug**：`\\?\` 前缀 + 混合分隔符导致 `strip_prefix` 失配（codegen 读不到 lib.rs）。本机已给 codegen 工具源码打本地补丁（只修路径计算，输出与 Linux CI 一致）并重装。
2. **测试 exe 需要 libmpv-2.dll 在 PATH**：`--features lx-player/build_libmpv` 构建的测试二进制运行时 `STATUS_DLL_NOT_FOUND`（0xc0000135）——`mpv/libmpv-extract/libmpv-audio-x86_64-*/` 需加入 PATH（此前批次口径只登记了 MPV_SOURCE，本会话补全运行时半边）。
3. **单包 cargo 命令也要带 `--features lx-player/build_libmpv`**：`cargo test -p <pkg>` 不带该 flag 时 feature 统一与 workspace 不同，libmpv2 build.rs 不注入 `-L` 导致 `cannot find -lmpv`（链接期才暴露，且仅发生在 feature 指纹失效重链时——易误判为环境抖动）。

## 验证

| 门禁 | 结果 |
|---|---|
| `cargo fmt --all -- --check` | **0 changed** ✓ |
| `cargo clippy --workspace --all-targets --features lx-player/build_libmpv -- -D warnings` | **exit 0** ✓（3 条预存 manifest 级 unused-deps 警告：lx-source anyhow/cbc、application lx-player——本批之前即存在，如实登记不动） |
| `cargo test --workspace --no-fail-fast --features lx-player/build_libmpv` | **858 passed / 3 failed**：3 例 = 04 矩阵登记的 lx-source Windows 夹具限制（临时目录名含线程名 `::` 在 Windows 非法，Linux CI 为准）✓；**数字对账 835（C-C 基线）+ 23（queue 4 + bridge 19）= 858 精确吻合**。app visualizer 1 例（`silence_watch_does_not_publish_while_data_flows`）时序 flaky 单独复跑 3/5 挂（登记时代 332/332 过——本机时序特性漂移，夹具不改不削弱，代码零改动，Linux CI 为准） |
| `dart analyze --fatal-infos` | **0 issues** ✓ |
| `dart format lib test` | **274 files 0 changed** ✓（本批 FRB 产物与测试文件按 SDK 口径重排，语义零变化；vendored hotkey_manager 不在本批域内已回退） |
| `flutter test` 逐文件 sweep | **61 文件全绿 / 508 passed / 0 failed**（sweep 实跑 59 绿 + 2 文件实抓 Batch F 波及后复跑全绿：`desktop_queue_interaction_test` 7/7、`now_playing_test` 18/18——两者各有旧「拖拽禁用/后端缺失能力」断言组与队列面板分组表头断言，Batch F queue_panel 重写（平面 ReorderableListView + 真实命令菜单）后不再成立，按 Batch F 语义重写不削弱；数字对账：Batch E 基线 506 + queue_interaction 重写净增 2 = 508 ✓，文件数 61 = 实际 test/*_test.dart 数量） |
| Linux CI（cfg-linux 接线 + zbus 运行时 + lx-source 3 例） | 留 PR #12 CI（本机无 Linux 工具链，口径同前批） |

## 契约 / 行为变化

- **Rust API**：`ApplicationCommand` +2 变体（QueueMove/QueuePlayAt）；`QueueService` +`move_item`；application 新增 `spawn_mpris_bridge`（cfg linux）；FFI `FfiCommand` +2 变体（FRB 绑定再生成）。
- **Dart**：`FfiCommand` +2（codegen）；`app_model` +2 方法；`queue_panel` 拖拽语义启用。
- **平台行为**：桌面队列拖拽排序/队内跳播真实生效（P2-09 关闭）；Linux 桌面媒体键/Waybar 可控 GUI 播放（运行时验收留 Linux）。
- 兼容策略：新命令向后兼容（旧端不发即无影响）；media-session 提取对 TUI 消费面零变化（shim）。

## 后续（Queue → Batch G）

- MPRIS 运行时验收（Linux 会话）：媒体键 / Waybar / `playerctl` 全链走查。
- GUI Windows SMTC / macOS Now Playing：media-session crate 已就位（translate_event 共用），GUI 侧接入为后续批次。
- MPRIS Quit 支持（新增事件面通知 Dart）与 SetVolume 持久化收敛，按需排期。
