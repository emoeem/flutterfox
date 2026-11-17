# FFI 契约与调用链清单（Batch A · Task A0）

> 状态：生效中 · 日期：2026-11-14 · 审计 HEAD：`4e40ee7`（feat/ui-redesign）· 上游计划：《Flutterfox 跨平台工程演进计划书》Batch A / Task A0 · 风险判定与修复方案见 [ffi-reliability-design.md](ffi-reliability-design.md)

## 一、Rust API 函数表（ffi/src/api.rs，24 个暴露函数）

| 函数（api.rs:行） | 职责 | 返回 | 异步性 |
|---|---|---|---|
| command_pause/resume/toggle/stop/next/previous（14-31） | 6 个播放控制命令构造器 | FfiCommand | 同步 |
| command_search（32）/ command_search_more（35） | 搜索/翻页命令构造 | FfiCommand | 同步 |
| command_play（42）/ command_queue_add（45）/ command_queue_remove（48）/ command_queue_clear（51） | 播放与队列命令构造 | FfiCommand | 同步 |
| command_load_lyrics（56） | P2-17 歌词重取命令构造 | FfiCommand | 同步 |
| new_desktop（62） | mpv 桌面引导（LC_NUMERIC=C 修正）；非 mpv 构建返回 Err | Result\<VoicefoxController,String\> | 同步 |
| new_host（88） | 移动端转发型后端引导（无 mpv） | Result\<VoicefoxController,String\> | 同步 |
| host_player_stream（95） | Rust→Dart 播放指令流；非宿主控制器时 `.expect` panic（:99） | HostPlayerStream | 同步 |
| host_player_report（107） | Dart→Rust 回流 state/position/duration | Result<(),String> | 同步 |
| host_player_report_event（127） | Dart→Rust 回流 ended/error/buffering/playing | Result<(),String> | 同步 |
| host_player_next（177） | 取一条宿主播放指令 | Result\<HostPlayerCommandDto,String\> | 异步 |
| set_data_dir（183） | 进程级数据目录覆盖（移动端私有目录） | () | 同步 |
| state（187） | 全量状态快照（含 local_songs 全量克隆，见 R09） | VoicefoxState | 同步 |
| dispatch（191） | 命令下发（into_application 映射后入 ApplicationService） | Result<(),String> | 异步 |
| subscribe（195） | 订阅应用事件广播 | VoicefoxEventStream | 同步 |
| event_next（199） | 取一条应用事件 | Result\<VoicefoxEvent,String\> | 异步 |

异步 3 个（dispatch/event_next/host_player_next），FRB 全部包装为 Future。

## 二、DTO / 枚举 / Opaque / Stream（ffi/src/lib.rs）

- **DTO 24 个**（lib.dart 同数对应）：组合根 `VoicefoxState`（:101，15 字段）及组成 PlaybackDto(:472)/SearchDto(:287)/LyricsDto(:307)/LyricLineDto(:300)/PlaylistDto(:316)/PlaylistCategoryDto(:326)/LeaderboardDto(:349)/ArtistDto(:368)/AlbumDto(:388)/SourceCapabilitiesDto(:423)/CustomPlaylistSummaryDto(:120)/DownloadTaskDto(:128)/SongDto(:24)/ScanStatsDto(:656)；事件附属 QrLoginSessionDto(:277)/SyncRowDto(:585)/SyncFailureDto(:596)/SyncPreviewDto(:602)/SyncReportDto(:614)/PushTargetDto(:625)/PushPreviewDto(:634)/PushReportDto(:646)/ConfigDto(:148)；宿主镜像 HostHeaderDto(:1266)。
- **命令**：`FfiCommand` 60 变体（:1354-1545，经 into_application 映射到 ApplicationCommand :1547）；`HostPlayerCommandDto` 8 变体（:1274，Play/Pause/Resume/Stop/Toggle/Seek/SetVolume/SetSpeed）。
- **事件**：`VoicefoxEvent` 单一扁平结构体（:672-712），`kind:String` + 约 30 个 Option/Vec 字段，非 tagged enum（疑点见 §五.1）。
- **Opaque 3 个**：`VoicefoxController`（:1142，Clone，10 个 pub 方法 :1154-1257）、`VoicefoxEventStream`（:1259，包 ApplicationEventStream）、`HostPlayerStream`（:1327，tokio broadcast Receiver）。
- **Stream 容量**：应用事件 `EVENT_CAPACITY=256`（application/src/service.rs:63,103）；宿主指令 `channel(64)`（application/src/services/host_player.rs:88）；两者 Lagged 均转 Err(String)（lib.rs:1335,1343-1350），由 Dart 重订阅。

## 三、Dart 侧对应与 AppModel 结构

- **codegen**：flutter_rust_bridge@2.13.0 双侧一致（api.dart:2 / lib.dart:2 / frb_generated.dart:2；pubspec.yaml:37 `^2.13.0`；bridge_smoke_test.dart:7 断言 codegenVersion=="2.13.0"；Cargo 侧 `=2.13.0` 精确锁）。flutter_rust_bridge.yaml：rust_input=crate::api，rust_root=./ffi，dart_output=./flutter/lib/src/bridge。
- **api.dart**（139 行）：24 函数一一对应，全部 Future 包装；私有 parse_host_state 不入 codegen（:10）。
- **lib.dart**（1442 行）：24 个 Dto class + VoicefoxEvent(:1210)/VoicefoxState(:1373) + 3 个 opaque abstract class；FfiCommand/HostPlayerCommandDto 为 freezed sealed class（:286/:476，实现在 lib.freezed.dart）。
- **AppModel**（app_model.dart，1454 行）：
  - 派发：`dispatch` :1260 → `_sendCommand` :1275（测试拦截钩子 :1277-1281；无控制器返回「控制器尚未连接」:1283；catch-all → _logAndSanitize + lastError/lastNotification + notifyListeners :1287-1292）；`dispatchWithError` :1271。
  - 事件泵 `_eventLoop` :232-256：while(true) await eventNext(:237) → 异常时 stderr 日志(:242) + 1s 退避(:243) + 重订阅(:247) + 全量 _refreshState(:250) + 重订阅失败退出循环(:251-252)；`_pumping` 幂等守卫 :220-223。
  - `_handleEvent` :258-325：kind 字符串 switch（:272）；'progress' 只换 playback 快照（:273-276）；search/playback/queue/playlist/lyrics/downloads/library/local_music 触发 _refreshState；**无 state_changed 分支**（Rust 尾随快照被整体丢弃，见 R08）。
  - `_refreshState` :339，调用点 5 处（250/282/287/289/320），unawaited 并发无合并。
  - 初始化：ensureRustLib :198-201（memoized RustLib.init）；bootstrapDesktop :204-208；attach :211-214；_attach :216-228（先 state() :218 → 后 subscribe :219 → 泵 + libraryRefresh/configGet :225-226，顺序窗口见 R09）。
  - main.dart 分支：uiOnly :199-210；触屏 :215-228 → `_bootstrapTouch` :282-296（ensureRustLib :284 → setDataDir :286 → newHost :287 → attach :288 → audio_service :290 → hostPlayerStream :293 → HostPlayerBridge start）；桌面 :253-266（attachVoicefoxAudioBackend :255，后台 bootstrapDesktop :265）。

## 四、测试覆盖矩阵

| 接口 | Rust 侧 | Dart 侧 |
|---|---|---|
| FfiCommand 序列化/映射 | 有：lib.rs:1808 command_mapping_does_not_expose_application_types（仅 SeekMs 一例） | 无直接（host_player_bridge_test.dart:202 控制指令语义对齐属桥层） |
| VoicefoxEvent 形状 | 有：lib.rs:1791 playback_event_maps_to_stable_ffi_shape | 无直接（经 widget 测试间接） |
| state() 快照 | 无 | 无 |
| 事件流 event_next/重订阅 | 无 | 无（bridge_smoke_test.dart:5 只查 codegen 版本） |
| dispatch 全链 | 无端到端 | 间接：页面测试经 _commandInterceptor（app_model.dart:1277） |
| host_player 链 | 有：host_player.rs:261+ 共 5 测（forwards_play_with_headers_and_generation / controls_forward_and_reports_backfill_watchers / play_sets_loading_and_stop_resets_position / play_without_subscriber_still_accepts / report_event_reaches_consumer） | 有：host_player_bridge_test.dart 6 测（:175/:202/:241/:270/:325/:342，含 lagged 容错） |
| 事件广播容量行为 | 有：service.rs:2006(64)/2123(256) | 无 |

## 五、契约边界疑点（审计结论，编号供设计文档引用）

1. **VoicefoxEvent 是「上帝结构体」**：kind:String + 约 30 扁平字段（lib.rs:672-712），Dart 裸字符串 switch（app_model.dart:272-325）；新增 kind 无编译期保护，每个事件携带全部字段。
2. **错误全为 `Result<_, String>`**（api.rs 六处 + 两流 next），无类型化错误枚举；Dart 侧仅可读文本，可匹配性弱（R10）。
3. **host_player_stream 非宿主控制器时 `.expect` panic**（api.rs:99）：契约上是进程崩溃而非 Result，桌面控制器误用即 abort。
4. **FfiCommand 映射含静默窄化**：SetVolume `.min(100)`（lib.rs:1555）、SeekMs/QueueRemove 强转（:1561/:1567）、未知 source id 转 Err；策略对 Dart 不可见。
5. **state() 全量克隆含 local_songs 整份快照**（lib.rs:101-118,1217-1232）；app_model.dart:274-275 注释自认 4Hz progress 特意绕开 state()；曲库增大后每次调用 O(n) FFI 序列化（R09 详算）。

## 六、后续动作

- 风险判定与最小修复方案：见 [ffi-reliability-design.md](ffi-reliability-design.md)（R01-R12）。
- 已证实风险登记入缺陷矩阵：FFI-R01/02/03/04/06/07/08/09/10/12（R05/R11 维持观察态）。
- 修复实施在审计报告获用户确认后按设计文档优先级分小批进行，不在审计批次内动生产代码。
