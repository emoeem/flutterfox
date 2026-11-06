# FFI 暴露面审计（voicefox-gui）

- 审计对象：`ffi/`（crate `voicefox-ffi`）实际暴露给 Flutter 的全部方法/命令/类型，以及 Dart 侧引用情况
- 审计方式：只读。逐一读取 Rust 暴露源、FRB 生成物与 Dart 调用方，并对每个条目做全库 grep
- 审计日期：2026-11-05；工作区 commit `b6df383`（master，clean）

## 0. 审计方法与证据来源

| 步骤 | 内容 | 证据 |
|---|---|---|
| 1 | FRB 扫描范围 | `flutter_rust_bridge.yaml`：`rust_input: crate::api`，`rust_root: ./ffi`，`dart_output: ./flutter/lib/src/bridge` —— 只有 `ffi/src/api.rs` 参与 Dart 代码生成 |
| 2 | Rust 暴露源 | `ffi/src/api.rs`（18 个顶层 pub fn）；`ffi/src/lib.rs`（`FfiCommand` 55 个变体、`VoicefoxController`/`VoicefoxEventStream`、全部 DTO） |
| 3 | 生成物核对 | `flutter/lib/src/bridge/api.dart`（18 个函数逐一对应）；`flutter/lib/src/bridge/lib.dart:283-427`（`FfiCommand` sealed class 55 个 factory，与 Rust 枚举一一对应）；`frb_generated.dart:70-76` dylib stem `voicefox_ffi` |
| 4 | Dart 引用 grep | 对每个函数/每个 `FfiCommand.*` 变体在 `flutter/lib`、`flutter/test`（含 vendored `src/myune`、`src/myune_seam`、`src/myune_shell`）执行 `grep -rn "FfiCommand\.<v>(\|FfiCommand_<v>("`，命令与逐条输出见 §2/§3 表格"调用点"列；零引用条目另用无括号宽松模式复核（tear-off 场景），结果为 0 |
| 5 | 二进制核对 | `nm -D target/release/libvoicefox_ffi.so`：dynsym 导出 4 个 `frbgen_voicefox_*_Voicefox{Controller,EventStream}` ARC 符号；`nm` 全表含 190 个 `wire__crate__api__*` 闭包（对应 api.rs 全部 18 函数），无任何 `audio_info` 符号（0） |

结论口径：**"引用"指非生成物（`lib/src/bridge/` 之外）的 Dart 代码中存在实际调用/构造点**；`flutter/test` 与 vendored myune 代码的引用单独标注。

## 1. 架构总览

- 边界设计：`ApplicationService` 本体不过 Flutter ABI，Dart 只见 `VoicefoxController`（opaque）+ 命令枚举 + 事件流（`ffi/src/lib.rs:1-6`）。
- 命令通道：Dart 构造 `FfiCommand`（freezed sealed class）→ `dispatch(controller, command)` → `FfiCommand::into_application()` 映射为 `ApplicationCommand`（`ffi/src/lib.rs:1369-1595`）。
- 事件通道：`subscribe()` 取 `VoicefoxEventStream`，Dart 自泵循环 `eventNext()`（`flutter/lib/src/app_model.dart:152-175`）。
- 引导：`main.dart:48` → `bootstrapDesktop()` → `RustLib.init()` + `newDesktop()`（`app_model.dart:126-131`）。移动端备用路径 `attach(controller)`（`app_model.dart:133-137`）当前无调用方。
- dylib 加载：`libvoicefox_ffi.so` 由 `flutter/linux/CMakeLists.txt:110-138` 通过 cargo 构建并打包；`frb_generated.dart:70-76` stem `voicefox_ffi`。

## 2. 顶层函数（api.rs → bridge/api.dart，18 个）

| # | Rust（ffi/src/api.rs） | Dart 绑定 | 参数 | 返回 | Dart 调用点（grep 实测） | 结论 |
|---|---|---|---|---|---|---|
| 1 | `command_pause` :11 | `commandPause` api.dart:10 | — | `FfiCommand` | 无 | **未引用** |
| 2 | `command_resume` :14 | `commandResume` :13 | — | `FfiCommand` | 无 | **未引用** |
| 3 | `command_toggle` :17 | `commandToggle` :16 | — | `FfiCommand` | 无 | **未引用** |
| 4 | `command_stop` :20 | `commandStop` :19 | — | `FfiCommand` | 无 | **未引用** |
| 5 | `command_next` :23 | `commandNext` :21 | — | `FfiCommand` | 无 | **未引用** |
| 6 | `command_previous` :26 | `commandPrevious` :23 | — | `FfiCommand` | 无 | **未引用** |
| 7 | `command_search` :29 | `commandSearch` :26 | keyword: String, source: Option\<String\> | `FfiCommand` | 无 | **未引用** |
| 8 | `command_search_more` :32 | `commandSearchMore` :32 | keyword: String, page: u32 | `FfiCommand` | 无 | **未引用** |
| 9 | `command_play` :35 | `commandPlay` :40 | song: SongDto | `FfiCommand` | 无 | **未引用** |
| 10 | `command_queue_add` :38 | `commandQueueAdd` :43 | song: SongDto | `FfiCommand` | 无 | **未引用** |
| 11 | `command_queue_remove` :41 | `commandQueueRemove` :46 | index: u32 | `FfiCommand` | 无 | **未引用** |
| 12 | `command_queue_clear` :44 | `commandQueueClear` :49 | — | `FfiCommand` | 无 | **未引用** |
| 13 | `new_desktop` :50 | `newDesktop` :54 | — | `Result<VoicefoxController, String>`（非 desktop-mpv 构建返回 Err :58-61） | `app_model.dart:128` | 引用（桌面唯一引导） |
| 14 | `set_data_dir` :70 | `setDataDir` :63 | path: Option\<String\> | () | 无（宽松模式复核 0） | **未引用**（Android 宿主引导预留，注释 :64-69） |
| 15 | `state` :74 | `state` :66 | controller: &VoicefoxController | `VoicefoxState` | `app_model.dart:140, 240` | 引用 |
| 16 | `dispatch` :78 | `dispatch` :69 | controller, command: FfiCommand | `Result<(), String>` | `app_model.dart:958`（`AppModel.dispatch` 封装，全部 UI 经此） | 引用 |
| 17 | `subscribe` :82 | `subscribe` :77 | controller | `VoicefoxEventStream` | `app_model.dart:141, 167`（含断线重订阅） | 引用 |
| 18 | `event_next` :86 | `eventNext` :81 | stream: &mut VoicefoxEventStream | `Result<VoicefoxEvent, String>` | `app_model.dart:159` | 引用 |

要点：12 个 `command_*` 构造助手在 Dart 全部零引用 —— UI 直接 `const bridge.FfiCommand.xxx(...)` 构造（搜索含 `commandPause` 等 12 名的无括号宽松 grep 为 0）。它们仅被 Rust 侧示例 `ffi/examples/runtime_smoke.rs` 以外的路径间接覆盖（该示例用 `new_desktop`/`state`，也不用助手）。

## 3. FfiCommand 变体（55 个，按模块）

Rust 定义 `ffi/src/lib.rs:1194-1367`；Dart 工厂 `bridge/lib.dart:283-427`。映射层 `into_application` 在 `lib.rs:1370-1595`。调用点均为 `grep -rn --include="*.dart" "FfiCommand\.<v>(\|FfiCommand_<v>("` 实测（生成物除外）。

### 3.1 player（13 个变体 + 无歌词命令）

| 变体（Rust） | 参数 | Dart 构造 | 调用点 | 结论 |
|---|---|---|---|---|
| `Pause` :1195 | — | `FfiCommand.pause()` | 无（UI 只有 toggle/stop） | **未引用** |
| `Resume` :1196 | — | `FfiCommand.resume()` | 无 | **未引用** |
| `Toggle` :1197 | — | `FfiCommand.toggle()` | `app_model.dart:1003` | 引用 |
| `Stop` :1198 | — | `FfiCommand.stop()` | `myune_seam/app_model_audio_backend.dart:159` | 引用 |
| `SeekMs(u64)` :1199 | 毫秒（Dart 侧 `BigInt`） | `FfiCommand.seekMs(ms)` | `app_model.dart:1006` | 引用 |
| `SetVolume{volume: u32}` :1201 | 0-100，Rust 侧 `min(100)` 钳制（lib.rs:1378） | `FfiCommand.setVolume(volume: …)` | `app_model.dart:976`（Dart 也 clamp） | 引用 |
| `PlaySong{song: SongDto}` :1204 | 单曲 | `FfiCommand.playSong(…)` | `app_model.dart:1008` | 引用 |
| `QueueAdd{song, next}` :1207 | `command_queue_add` 助手固定 `next=false`（api.rs:39） | `FfiCommand.queueAdd(song, next: false)` | `app_model.dart:1010` | 引用 |
| `QueueRemove{index: u32}` :1211 | 队列下标 | `FfiCommand.queueRemove(index: …)` | `app_model.dart:1012`；`myune_seam/app_model_audio_backend.dart:154` | 引用 |
| `QueueClear` :1214 | — | `FfiCommand.queueClear()` | `myune_shell/voicefox_queue_drawer.dart:34` | 引用 |
| `Next` :1215 | — | `FfiCommand.next()` | `app_model.dart:1004` | 引用 |
| `Previous` :1216 | — | `FfiCommand.previous()` | `app_model.dart:1005` | 引用 |
| `PlaySongs{songs, index}` :1363 | 列表播放（榜单/专辑"播放全部"） | `FfiCommand.playSongs(…)` | `app_model.dart:800` | 引用 |

### 3.2 lyric（0 个命令，纯数据面）

歌词无任何 `FfiCommand` 命令；暴露方式为：

| 面 | Rust | Dart 消费 | 结论 |
|---|---|---|---|
| 状态快照 | `VoicefoxState.lyrics: LyricsDto`（lib.rs:102；`LyricsDto`/`LyricLineDto` lib.rs:296-309） | `app_model.dart:108, 259, 813, 857`；`player_page.dart:97`；`widgets/lyrics_view.dart:18, 38` | 引用 |
| 事件推送 | `ApplicationEvent::LyricsChanged` → kind `"lyrics"`（lib.rs:700, 1048） | `app_model.dart:190`（case） | 引用 |
| 配置镜像 | `ConfigDto.show_translation / show_yrc / lyric_offset_ms`（lib.rs:161-163） | `settings_page.dart`（经 ConfigUpdate 回写） | 引用 |

### 3.3 source（音源/搜索/登录/浏览/同步/推送/本地曲库，24 个变体）

| 变体（Rust） | 参数 | 调用点 | 结论 |
|---|---|---|---|
| `Search{keyword, source: Option<String>}` :1217 | source 为音源过滤，`parse_source` 校验（lib.rs:1394-1400） | `search_page.dart:40, 51, 170` | 引用 |
| `SearchMore{keyword, page}` :1222 | Rust 侧固定 `source: None`（lib.rs:1401-1405） | `search_page.dart:75` | 引用 |
| `QrLoginStart{source, kind}` :1279 | kind 仅识别 `"wechat"`，其余 → Standard（lib.rs:1461-1467） | `qr_login_page.dart:38` | 引用 |
| `QrLoginCancel` :1283 | — | `qr_login_page.dart:56, 89` | 引用 |
| `AccountPlaylists{source}` :1290 | — | `app_model.dart:612` | 引用 |
| `AccountFavorites{source}` :1293 | — | `app_model.dart:617` | 引用 |
| `AccountPlaylistDetail{source, playlist_id}` :1296 | — | `app_model.dart:627` | 引用 |
| `SyncPreview{source}` :1300 | — | `app_model.dart:655` | 引用 |
| `SyncRun{source}` :1303 | — | `app_model.dart:665` | 引用 |
| `SyncCancel` :1306 | — | `app_model.dart:668` | 引用 |
| `PushTargets{source}` :1307 | — | `app_model.dart:710` | 引用 |
| `PushCreateTarget{source, name}` :1310 | — | `app_model.dart:720` | 引用 |
| `PushPlan{source, local_name, local_songs, is_favorites, target_kind, target_id, target_name, target_song_count}` :1314 | target_kind 仅 `"playlist"`/`"favorites"`，否则报错（lib.rs:1511-1515） | `app_model.dart:737` | 引用 |
| `PushRun{source}` :1324 | — | `app_model.dart:757` | 引用 |
| `PushCancel` :1327 | — | `app_model.dart:761` | 引用 |
| `PlaylistCategories{source}` :1329 | — | `app_model.dart:450` | 引用 |
| `PlaylistList{source, category, page}` :1332 | — | `app_model.dart:460` | 引用 |
| `PlaylistDetail{source, playlist_id, page}` :1337 | — | `app_model.dart:476` | 引用 |
| `LeaderboardBoards{source}` :1342 | — | `app_model.dart:486` | 引用 |
| `LeaderboardSongs{source, board_id, page}` :1345 | — | `app_model.dart:496` | 引用 |
| `ArtistSongs{artist: ArtistDto, page}` :1350 | — | `app_model.dart:506` | 引用 |
| `ArtistAlbums{artist: ArtistDto, page}` :1354 | — | `app_model.dart:511` | 引用 |
| `AlbumSongs{album: AlbumDto, page}` :1358 | — | `app_model.dart:516` | 引用 |
| `LocalScan{paths, max_depth}` :1285 | 本地曲库扫描 | `app_model.dart:298` | 引用 |

音源能力数据面：`VoicefoxState.sources: Vec<SourceCapabilitiesDto>`（lib.rs:110，DTO lib.rs:419-447）→ `app_model.dart:306-310, 804, 820, 864, 878`；`home_page.dart:330, 467`；`search_page.dart:110`。引用。

### 3.4 download（3 个变体）

| 变体（Rust） | 参数 | 调用点 | 结论 |
|---|---|---|---|
| `DownloadEnqueue{song}` :1271 | — | `app_model.dart:1014`；`downloads_page.dart:144`（失败/取消重试复用 task.song，DTO 字段 lib.rs:132） | 引用 |
| `DownloadCancel{id: u64}` :1274 | 任务 id（Dart `BigInt`） | `downloads_page.dart:136` | 引用 |
| `DownloadClearFinished` :1277 | — | `downloads_page.dart:49` | 引用 |

数据面：`VoicefoxState.downloads: Vec<DownloadTaskDto>`（lib.rs:108，DTO lib.rs:124-139）→ `downloads_page.dart:17, 81`；`app_model.dart:265, 819, 863`。事件 kind `"downloads"`（lib.rs:704）→ `app_model.dart:191`。引用。

### 3.5 core（app/application 库与配置，15 个变体）

| 变体（Rust） | 参数 | 调用点 | 结论 |
|---|---|---|---|
| `LibraryRefresh` :1227 | — | `app_model.dart:147`（引导即拉） | 引用 |
| `FavoritesAdd{song}` :1228 | — | `app_model.dart:1022` | 引用 |
| `FavoritesRemove{song}` :1231 | — | `app_model.dart:1021` | 引用 |
| `FavoritePlaylistAdd{playlist}` :1234 | — | 无（宽松模式复核 0） | **未引用** |
| `FavoritePlaylistRemove{playlist}` :1237 | — | 无 | **未引用** |
| `HistoryRemove{song}` :1240 | — | 无 | **未引用** |
| `HistoryClear` :1243 | — | `library_page.dart:306` | 引用 |
| `CustomPlaylistCreate{name}` :1244 | — | `app_model.dart:559` | 引用 |
| `CustomPlaylistRename{id, name}` :1247 | — | `app_model.dart:575` | 引用 |
| `CustomPlaylistDelete{id}` :1251 | — | `app_model.dart:581` | 引用 |
| `CustomPlaylistAddSongs{id, songs}` :1254 | — | `app_model.dart:587` | 引用 |
| `CustomPlaylistRemoveSong{id, song}` :1258 | — | `app_model.dart:592` | 引用 |
| `CustomPlaylistDetail{id}` :1262 | — | `app_model.dart:534` | 引用 |
| `ConfigGet` :1266 | — | `app_model.dart:148` | 引用 |
| `ConfigUpdate{config: ConfigDto}` :1267 | 子集镜像 DTO（lib.rs:144-258）；`dispatch` 特判：合并到 `config_base` 持有的完整配置（lib.rs:1154-1170），`unreachable!` 兜底 lib.rs:1591-1593 | `app_model.dart:999` | 引用 |

数据面：favorites/history/playlists/custom_playlists（lib.rs:103-107）→ `app_model.dart` 库状态与 `library_page.dart` 等消费；事件 kind `"library"`（lib.rs:703）→ `app_model.dart:193`。引用。

## 4. 事件流数据面（VoicefoxEvent，lib.rs:650-1051）

Dart 端 `app_model.dart:179-224` 的 `switch (event.kind)` 消费全部 15 个 kind：`progress` :180、`search` :184、`playback` :185、`queue` :188、`playlist` :189、`lyrics` :190、`downloads` :191、`library` :193、`notification` :196、`qr_login` :198、`local_music` :215、`browse` :219、`sync` :221、`config` :224、`state_changed`（未单列，走默认刷新）。sync/push 子状态（preview/progress/completed/failed、push_targets/push_target_created/push_preview/push_progress/push_completed/push_failed）在 `app_model.dart:389-440` 消费。**事件面全部被引用。**

## 5. 暴露的 Rust 类型（26 个，经 FRB 进 Dart）

| 类别 | 类型（Rust 定义） |
|---|---|
| opaque | `VoicefoxController`（lib.rs:1102）、`VoicefoxEventStream`（lib.rs:1179）—— dylib 中有对应 ARC 增减符号（nm 实测 4 个） |
| 状态/播放 | `VoicefoxState`（lib.rs:97）、`PlaybackDto`（lib.rs:468）、`SearchDto`（lib.rs:283） |
| 歌曲 | `SongDto`（lib.rs:20） |
| 歌词 | `LyricsDto`（lib.rs:303）、`LyricLineDto`（lib.rs:296） |
| 浏览 | `PlaylistDto`（lib.rs:312）、`PlaylistCategoryDto`（lib.rs:322）、`LeaderboardDto`（lib.rs:345）、`ArtistDto`（lib.rs:364）、`AlbumDto`（lib.rs:384）、`SourceCapabilitiesDto`（lib.rs:419） |
| 库 | `CustomPlaylistSummaryDto`（lib.rs:116） |
| 下载 | `DownloadTaskDto`（lib.rs:124） |
| 配置 | `ConfigDto`（lib.rs:144） |
| 登录 | `QrLoginSessionDto`（lib.rs:273） |
| 同步/推送 | `SyncRowDto`（lib.rs:581）、`SyncFailureDto`（lib.rs:592）、`SyncPreviewDto`（lib.rs:598）、`SyncReportDto`（lib.rs:610）、`PushTargetDto`（lib.rs:621）、`PushPreviewDto`（lib.rs:630）、`PushReportDto`（lib.rs:642） |
| 事件/命令 | `VoicefoxEvent`（lib.rs:651）、`FfiCommand`（lib.rs:1194） |

`VoicefoxController::from_application` / `with_config_base`（lib.rs:1121-1135）是 pub 但不在 `crate::api`，FRB 不生成 Dart 绑定 —— 属移动端宿主（Rust 侧）预留接口，非 Dart 暴露面。

## 6. 第二桥：vendored myune（flutter/lib/src/myune/src/rust/，非本仓库 ffi crate）

- 来源：myune_music 生成物原样 vendor（frb_generated.dart:1-4，FRB 2.10.0），期望 dylib stem `rust_lib_myune_music`（myune frb_generated.dart:71-76）。
- 暴露函数仅 2 个（`api/audio_info.dart`）：
  | 函数 | 参数 | 返回 | Dart 调用点 | 结论 |
  |---|---|---|---|---|
  | `readAudioInfo` :16 | path: String, options: AudioInfoOptions | `AudioInfo`（title/artist/album/cover/lyrics/durationMs/bitrate/sampleRate/year/genre/albumArtist/trackNumber） | `lyrics_handler.dart:296`；`page/playlist/playlist_content_notifier.dart:1041, 1100, 1138, 1363, 1526, 4410` | **有引用但实现缺失**（见下） |
  | `writeReplayGainTags` :24 | path, gainDb, peak | () | 无 | **未引用** |
- 风险事实（本次实测）：
  1. `PlaylistContentNotifier` 已接入 app（`main.dart:17, 129`、`myune_shell/projection.dart:215`），其 6 处 `readAudioInfo` 调用点在 vendored UI 路径上。
  2. myune 桥的 `RustLib.init()` 全库无调用 —— 全部 `RustLib.init()` 命中均为 voicefox 桥（`app_model.dart:127, 134`，import `bridge/frb_generated.dart`）。
  3. `nm target/release/libvoicefox_ffi.so` 全表 190 个 `wire__crate__api__*` 符号全部属于 `voicefox_ffi`，`audio_info` 相关符号计数为 0 —— 本仓库构建的 dylib 不含该实现。
  4. 推论：一旦执行到上述调用点，调用会因桥未初始化/符号缺失而失败。属于"暴露面声明存在、Dart 有引用、Rust 侧无对应实现"的悬空面；修复方向是本地实现 audio_info 或移除调用路径（超出本审计，未改动）。

## 7. 汇总

| 模块 | 命令/方法条目 | 被 Dart 引用 | 未引用 |
|---|---|---|---|
| 顶层函数（api.rs） | 18 | 5（newDesktop/state/dispatch/subscribe/eventNext） | 13（12 个 command_* 助手 + setDataDir） |
| player 命令变体 | 13 | 11 | 2（Pause、Resume） |
| lyric 命令变体 | 0 | —（纯数据面，已消费） | — |
| source 命令变体 | 24 | 24 | 0 |
| download 命令变体 | 3 | 3 | 0 |
| core 库/配置变体 | 15 | 12 | 3（FavoritePlaylistAdd、FavoritePlaylistRemove、HistoryRemove） |
| 事件 kind | 15 | 15 | 0 |
| vendored myune 桥 | 2 | 1（readAudioInfo，但实现缺失） | 1（writeReplayGainTags） |

方法级条目合计：18 + 55 + 2 = **75**（另有 26 个暴露类型与 15 个事件 kind 作为数据面）。

### 审计发现清单

1. **12 个 `command_*` 助手是死代码**（api.rs:11-46）：Dart 全部直接构造 `FfiCommand`，助手零引用；`ffi/examples/runtime_smoke.rs` 也不用它们。
2. **5 个命令变体零引用**：`Pause`、`Resume`（UI 只有 toggle/stop）、`FavoritePlaylistAdd`、`FavoritePlaylistRemove`、`HistoryRemove`（GUI v1 未提供入口）。API 面与 UI 面不一致，属预留或遗漏。
3. **`setDataDir` 零引用**（api.rs:70）：Android 宿主引导预留；对应的 `AppModel.attach`（app_model.dart:133）同样无调用方——移动端路径整体未接线。
4. **`ConfigUpdate` 依赖引导方式**：仅 `new_desktop` 经 `with_config_base` 注入 `config_base`（lib.rs:1110-1117）；若走 `from_application` 引导且未调用 `with_config_base`，`ConfigUpdate` 必报"配置存储不可用"（lib.rs:1157-1162）。当前桌面路径不受影响。
5. **vendored myune 桥悬空**：`readAudioInfo` 被 app 已接线的 vendored 代码 6+1 处引用，但该桥从未 init、dylib 无实现符号（§6）。是暴露面审计中最高的实际故障风险点。
6. 输入校验集中且一致：所有 source 字符串经 `parse_source`（lib.rs:60-78，13 个合法 token）；`SetVolume` 钳制 0-100（lib.rs:1378）；`theme_mode`/`play_mode`/`download_quality` 未知 token 回退原配置（lib.rs:214-247）。
