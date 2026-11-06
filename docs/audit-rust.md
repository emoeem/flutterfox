# Rust 模块能力盘点（audit-rust）

- 日期：2026-11-05
- 范围：`/home/emo/code/voicefox-gui` 下 `core/ source/ player/ lyric/ application/ runtime/ download/ app/ ffi/` 九个 crate（Cargo workspace，`Cargo.toml:3-13`）
- 方法：只读静态盘点。逐文件读取各 crate 的 `lib.rs`、公开 trait/struct/enum/fn 声明与模块文档注释；以 FFI 生成物（`flutter/lib/src/bridge/api.dart`、`lib.dart`）交叉验证 FFI 面。未运行构建、未运行测试。
- FFI 暴露判定口径：本仓库 FFI = flutter_rust_bridge 2.13.0，`flutter_rust_bridge.yaml` 声明 `rust_input: crate::api`、`rust_root: ./ffi`，即对外面只有 `ffi/src/api.rs` 及其 `pub use` 再导出（`ffi/src/api.rs:6-9`）与被 DTO 传递引用的类型（`ffi/src/lib.rs`）。Dart 侧生成物核对一致：6 个顶层函数 + 13 个 `command_*` 工厂（`flutter/lib/src/bridge/api.dart:10-81`），`FfiCommand` 在 Dart 侧 55 个变体（`lib.dart` 中 `FfiCommand_` 计数 = 55，与 Rust 枚举 `ffi/src/lib.rs:1194-1367` 一致）。
- 标注含义：✅ = 经 FFI 命令/事件/状态可达；◐ = 间接或仅子集可达（写明路径）；❌ = 从未被 FFI 暴露。

## FFI 通道本身（voicefox-ffi）

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 1 | 引导：桌面运行时构造（mpv + 完整配置 + 播放泵）、宿主注入数据目录、移动端明确报错 | `ffi/src/api.rs:50` `new_desktop`、`api.rs:70` `set_data_dir`；`runtime/src/lib.rs:200` 启动播放泵 | ✅ |
| 2 | 控制器三件套：拉全量状态 / 派发命令 / 订阅事件流 | `ffi/src/lib.rs:1102-1191`（`VoicefoxController`、`VoicefoxEventStream`），`api.rs:74-88` | ✅ |
| 3 | 命令面：55 个 `FfiCommand` 变体（播放控制、搜索、队列、库、配置、下载、扫码、本地扫描、同步/推送、浏览数据面） | `ffi/src/lib.rs:1194-1367`；工厂函数 `api.rs:11-46` | ✅ |
| 4 | 事件面：15 类事件 kind 映射为胖联合 `VoicefoxEvent` | `ffi/src/lib.rs:651-1052`；kind 映射在 `lib.rs:694-710` | ✅ |
| 5 | 状态快照：`VoicefoxState`（playback/queue/search/lyrics/playlists/favorites/history/custom_playlists/downloads/sources/local_songs） | `ffi/src/lib.rs:97-113`，`state()` 填充 sources/local_songs 在 `lib.rs:1137-1152` | ✅ |
| 6 | 配置子集镜像 `ConfigDto`（主题/音量/倍速/播放模式/音源/下载/歌词/网络/本地音乐），回写以完整配置为底保留未镜像字段 | `ffi/src/lib.rs:144-259`（注释 142-143 明确「只覆盖 GUI 设置页 v1 编辑面」） | ◐ 子集 |
| 7 | C ABI 手写导出：无。除 FRB 生成物外没有 `#[no_mangle]`/`extern "C"` | `grep` 全 ffi/src 为 0 命中 | — |

## core（lx-core）— 领域模型与抽象

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 8 | 领域模型：`SongInfo`、`SourceId`(13 个 id)/`Quality`/`PlayerState`/`SourceHealth`、`LyricData/LyricLine/YrcLine/YrcWord/LyricState`、`Playlist/Album/Artist/CustomPlaylist`、`LeaderboardInfo`、`QrLoginSession/QrLoginKind`、`Config` 及全部子配置 | `core/src/model/song.rs:12`、`source.rs:16/223/344/5`、`lyric.rs:6-47`、`config.rs:837` 等 | ◐ 全部映射为 DTO；YRC 逐字 word 级、`SourceHealth`、多数 Config 子配置（见 #52）未过 FFI |
| 9 | 播放器后端抽象 `PlayerBackend`：prepare/play/play_with_headers/pause/resume/stop/toggle/seek、state/position/audible_position/duration/audio_info 五组 watcher、`PlayerEvent`（Playing/Ended/Error/Buffering） | `core/src/traits/player.rs:119-244`、`player.rs:108` | ◐ seek(`SeekMs`)、音量、状态/进度/时长经事件与快照可达；watcher 原语本身不过 ABI（`ffi/src/lib.rs:1-4` 注释明确不暴露） |
| 10 | 播放器音频增强：播放速度(0.01-100)、输出设备、ReplayGain（mode/preamp/clip）、声道布局、左右平衡、A-B 循环、均衡器频段、fade in/out | `core/src/traits/player.rs:48/61/75/89` 及 `player.rs:158-243` | ❌ 无任何 FFI 命令（grep ffi: equalizer/replaygain/ab_loop/balance/channel_mode/audio_device 均 0 命中）；仅倍速经 `ConfigDto.playback_speed` 持久化 |
| 11 | 音源统一接口 `MusicSource`：search/get_song_url/get_lyric/get_cover_url/supported_qualities/capabilities + 可选 parse_link、歌单分类/列表/搜索/详情、歌手歌曲/专辑、专辑曲目、排行榜、用户歌单、扫码登录、VIP/登录态/登出 | `core/src/traits/source.rs:107-301`、`SourceCapabilities:42`、`SongUrl:80`、`ParsedLink:24` | ◐ 大部分经 SourceManager 间接可达（见 #15-21）；`logout`/`is_logged_in`/`is_vip_account` ❌ |
| 12 | 歌词抓取抽象 `LyricFetcher` | `core/src/traits/lyric_fetcher.rs:8` | ❌ 内部端口，FFI 不可见 |
| 13 | 跨源同步引擎：`SyncEngine::plan/plan_bidirectional`、`SyncProvider` trait、`match_songs` 匹配器、SyncCollection/CanonicalSong/SyncPlan/SyncReport 模型 | `core/src/sync/mod.rs:56/101/103/237`、`matcher.rs:6`、`sync/model.rs` | ◐ 经 application 的 Sync/Push 命令间接使用（#44）；引擎与模型本身 ❌ |
| 14 | TUI 输入/动作面与键位系统：`InputEvent/PageId/AppAction`（含 ImportSource、CheckSourceHealth、QrLogout、睡眠定时、可视化等动作）、`keybinding::Action/PAGE_ORDER/KeybindingConfig/parse_keybinding/KeybindingResolver/colemak_preset` | `core/src/events.rs:13/22/31`、`core/src/keybinding/mod.rs:24/309/337/702/802/875` | ❌ 从未 FFI（GUI 侧以 `FfiCommand` 替代）；键位配置也不在 `ConfigDto` 镜像内 |
| 15 | 数据目录工具 `fsutil`（含进程级覆盖 `set_data_dir_override`） | `core/src/fsutil.rs`，FFI 侧调用 `ffi/src/api.rs:70-72` | ◐ 仅覆盖注入口可达 |

## source（lx-source）— 音源层

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 16 | 13 个内置音源实现：kw/kg/tx/wy/mg/bili/qianqian/soda/joox/jamendo/fivesing/apple/local（各含 search/url/lyric/playlist/leaderboard/login 子模块） | `source/src/lib.rs:1-25`、`source/src/wy/`、`source/src/kg/` 等 | ◐ 按 id 字符串可达（`ffi/src/lib.rs:60-78` `parse_source`） |
| 17 | 聚合搜索：`search`（默认源）、`search_scoped`（指定源）、`search_all`（多源聚合） | `source/src/manager.rs:399/420/467` | ✅ `Search`/`SearchMore` 命令；但 `SearchMore` 的 `source` 参数被硬编码为 None（`ffi/src/lib.rs:1401-1405`），分页续搜无法指定音源 |
| 18 | 播放地址解析：`get_song_url`（按音质/策略）、JS 源优先 `set_js_url_first/js_url_first`、`get_song_url_from_js_index` | `source/src/manager.rs:819/833/838/846` | ◐ 播放流程内部使用；JS 优先开关经 `ConfigDto.js_sources_first`（`ffi/src/lib.rs:188`） |
| 19 | 歌词与封面获取：`get_lyric`、`get_lyric_with_fallback`（跨源回退）、`get_cover_url`、cover_cache | `source/src/manager.rs:971/1010/1110`、`source/src/cover_cache.rs` | ◐ 歌词/封面随播放流程加载，经 state/事件以 DTO 可见 |
| 20 | 歌单浏览：`playlists`（按分类）、`playlist_categories`、`playlist_detail`（分页）、`playlist_sources`（能力声明） | `source/src/manager.rs:633/645/721/765` | ✅ `PlaylistCategories`/`PlaylistList`/`PlaylistDetail` |
| 21 | 歌单搜索 `search_playlists`、排行榜 `leaderboard/leaderboard_boards/leaderboard_sources`、歌手/专辑 `artist_songs/artist_albums/album_songs`、用户歌单 `user_playlists` | `source/src/manager.rs:710/600/612/619/732/743/754/655` | ◐ 排行榜/歌手/专辑 ✅（`LeaderboardBoards/LeaderboardSongs/ArtistSongs/ArtistAlbums/AlbumSongs`）；歌单搜索 ❌ 无 FFI 命令；`user_playlists` 经 `AccountPlaylists` 走镜像缓存而非直连 |
| 22 | 链接直解 `parse_link`（单曲/歌单/专辑链接 → 内容） | `source/src/manager.rs:320`；`SearchService::parse_link` `application/src/services/search.rs:31` | ❌ ffi 中 `parse_link` 0 命中（TUI 侧也未见命令；纯 Rust 内部能力） |
| 23 | 音源健康检查 `health_check`（→ `Vec<SourceHealth>`）与能力查询 `capabilities/sources_supporting` | `source/src/manager.rs:352/309/341` | ❌（TUI 有 `AppAction::CheckSourceHealth`，`core/src/events.rs:127`；GUI 无） |
| 24 | 跨源同曲匹配 `find_music/find_music_on`（播放失败换源、策略 `only` 用） | `source/src/manager.rs:1130/1138` | ❌ 内部编排能力 |
| 25 | 登录态管理：`create_qr_login/create_qr_login_kind/check_qr_login/is_logged_in/logout` | `source/src/manager.rs:667/675/686/695/702` | ◐ 扫码创建/取消/轮询 ✅（`QrLoginStart/QrLoginCancel` + `QrLoginCreated/QrLoginPolled` 事件）；登出/登录态查询 ❌（TUI 有 `AppAction::QrLogout`，`core/src/events.rs:146`） |
| 26 | JS 音源子系统：`JsEngine`（call_action 调用 lx-music 脚本）、loader（`load_source/download_source/is_source_cached`）、`JsSource`、SourceManager 注册族（generation 令牌式安装/卸载） | `source/src/js/engine.rs:18/262`、`loader.rs:356/234/125`、`js_source.rs:17`、`manager.rs:153-284` | ❌ 注册/加载/卸载完全未暴露；FFI 仅见 `js_sources_first` 标志与 `enabled_sources` 列表（TUI 有 `AppAction::ImportSource`，`core/src/events.rs:118`） |
| 27 | 会话存储：`SessionStore/SourceSession`（cookie/extra 读写、持久化路径 `session_path`） | `source/src/session.rs:19/124/213` | ❌ 登录流程内部读写 |
| 28 | 本地曲库 `LocalSource`：扫描 `scan/scan_for_generation`、快照 `all_songs/song_count`、元数据编辑 `edit_metadata`、按路径移除 `remove_by_path`、诊断（`corrupt_files/missing_songs/duplicates/duplicate_groups`）、文件监视 `start_watcher/refresh` | `source/src/local/mod.rs:78/140/340/424/359/468/473/497/528` | ◐ `LocalScan` 命令 + `state.local_songs` 快照 ✅（`ffi/src/lib.rs:1284-1288/112-115`）；元数据编辑/删除/诊断/监视器 ❌（TUI 有本地诊断页 `app/src/pages/local_music.rs`） |
| 29 | 网络层配置 `configure_network`（代理 + 超时，全局 reqwest 客户端） | `source/src/lib.rs:27-29` | ◐ 经 `ConfigUpdate`（proxy_url/network_timeout_secs）间接生效 |
| 30 | 同步提供者：`WySyncProvider`（网易云）、`TxSyncProvider`（QQ），`provider(source)` 工厂 | `source/src/sync.rs:18/21/498`（`docs/SYNC.md` 描述该分层） | ◐ 经 application Sync/Push 命令间接 |

## player（lx-player）— 播放引擎

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 31 | `MpvEngine`：libmpv2 全实现——播放/暂停/恢复/停止/seek、八组 mpv 属性观察器（时间/音频 PTS/时长/暂停/缓冲/编码器/码率/采样率）、事件泵（Playing/Ended/Error/Buffering）、代次令牌防旧请求回放 | `player/src/engine.rs:60/95`；watcher 常量 `engine.rs:25-32` | ❌ 类型不过 ABI（`ffi/src/lib.rs:1-4`）；桌面经 `new_desktop` → `ApplicationRuntime::desktop` 装配（`runtime/src/lib.rs:213`）；非 mpv 构建移动端由宿主自实现 PlayerBackend（`ffi/src/api.rs:48-62`） |
| 32 | 音频增强实现（EQ 滤镜 @voicefox-eq、ReplayGain preamp ±150dB、声道、balance、AB 循环、速度 0.01-100、音频设备、fade） | `player/src/engine.rs:36-46` 常量与 `PlayerBackend` 实现 | ❌ FFI 无对应命令（见 #10） |

## lyric（lx-lyric）— 歌词系统

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 33 | 歌词解析：LRC / QRC（QQ）/ YRC（网易云）+ 逐字自动识别 `parse_karaoke`、文本规整 `normalize_karaoke_text`（QRC XML 包装、转义、KRC 竖线）、兜底判定 `looks_like_karaoke` | `lyric/src/parser/mod.rs`、`parser/lrc.rs`、`parser/qrc.rs`、`parser/yrc.rs` | ◐ 结果经 `LyricsDto/LyricLineDto`（行文本+时间戳+时长）可见（`ffi/src/lib.rs:295-309`）；逐字 word 级数据（`YrcLine/YrcWord`）未过 FFI |
| 34 | 抓取适配 `SourceLyricFetcher`（MusicSource → LyricFetcher 桥） | `lyric/src/fetcher.rs:12-23` | ❌ 内部 |
| 35 | `LyricService`：代次令牌 `prepare/load/load_at`、进度对齐 `update_position`、状态读取 `current_state`、翻译开关、YRC 开关、偏移毫秒 | `lyric/src/service.rs:11/38/54/59/119/275/279/286/290` | ◐ 三开关经 `ConfigUpdate`（show_translation/show_yrc/lyric_offset_ms，`ffi/src/lib.rs:196-198`）；当前行/进度经 `state().lyrics`；load/update_position 由播放泵驱动 |

## application（voicefox-application）— 应用服务层（FFI 与 TUI 的共同边界）

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 36 | `ApplicationService`：命令派发、全量状态快照、事件订阅、音源能力声明、本地曲库快照、下载列表发布 | `application/src/service.rs:69/321/159/153/126/149/1424` | ✅ 由 `VoicefoxController` 包装（`ffi/src/lib.rs:1102-1177`） |
| 37 | 命令总线 `ApplicationCommand`（约 60 变体） | `application/src/event.rs:9-194` | ◐ 55 变体被 `FfiCommand` 覆盖；`PlayCurrent/RestorePlayback/LoadLyrics/PlaylistOpen/PlaylistSet/PlaybackFailed` ❌ 未映射（TUI/内部专用；播放恢复是 TUI 独有特性，见 #58） |
| 38 | 事件总线 `ApplicationEvent`（搜索/播放/队列/歌词/歌单/通知/库/下载/配置/扫码/本地扫描/浏览/同步 15 类） | `application/src/event.rs:215/414` | ◐ 全部 kind 有映射（`ffi/src/lib.rs:694-710`），但 `StateChanged/LyricsChanged/PlaylistChanged/LibraryChanged/DownloadsChanged/PlaybackPaused…` 映射为「仅 kind 无载荷」事件（`ffi/src/lib.rs:1041-1049`），前端须再拉快照 |
| 39 | `PlaybackService`：play（含音源多候选、代次令牌）、pause/resume/toggle/stop/seek/set_volume/volume、`url_for`、bili 分 P 展开 `expand_bili_parts`、封面地址解析 `resolve_cover_url`、音质/自动换源/来源序号查询 | `application/src/services/playback.rs:60/87/286-329/172/36` | ◐ 播放控制六件套+音量 ✅；`url_for/expand_bili_parts/quality/auto_toggle/source_index` ❌（bili 分 P 仅在 Play 流程内部触发） |
| 40 | `QueueService`：快照/替换/添加（可插队 next）/按序号移除/清空 | `application/src/services/queue.rs:9-76` | ✅ `QueueAdd/QueueRemove/QueueClear` + `PlaySongs` |
| 41 | `SearchService`：search / parse_link | `application/src/services/search.rs:17/31` | ◐ search ✅；parse_link ❌（同 #22） |
| 42 | `PlaylistService`：list/search/songs/categories/user/快照/替换/open/upsert/remove | `application/src/services/playlist.rs:9-110` | ◐ categories/list/detail ✅；歌单关键词搜索 ❌；快照管理内部 |
| 43 | 库端口 `LibraryStore`：收藏增删查、收藏歌单、历史增删清、自建歌单建改名删增删曲 | `application/src/ports.rs:12-38` | ◐ 增删与读取快照 ✅（`Favorites*/History*/CustomPlaylist*` 命令 + `state.favorites/history/custom_playlists`）；单曲 `is_favorite` 查询 ❌（前端自比对快照） |
| 44 | 配置端口 `ConfigStore`、下载端口 `DownloadsEngine`/`DownloadTaskInfo` | `application/src/ports.rs:41-49/51-78` | ✅ ConfigGet/ConfigUpdate、DownloadEnqueue/Cancel/ClearFinished + `state.downloads` |
| 45 | 播放模式与洗牌：`PlayMode`（四种模式推进逻辑）、`ShuffleScheduler`（可恢复的加权洗牌调度器，含 revision/jump/replace_current/持久化状态） | `application/src/playlist/mode.rs:21-93`、`shuffle.rs:163/931` | ◐ 播放模式字符串经 `ConfigDto.play_mode` 可设（`ffi/src/lib.rs:180-225`）；调度器与状态持久化 ❌ |
| 46 | 远端镜像缓存 `remote_cache`：merge/replace/all/all_mirrored/`favorites_songs`/`playlist`/`clear`/`cache_file_size`/`summary_counts`/`generation` | `application/src/remote_cache.rs:156/177/189/204/241/253/95/79` | ◐ 读经 `AccountPlaylists/AccountFavorites/AccountPlaylistDetail` ✅；`clear/cache_file_size` 等维护操作 ❌ |
| 47 | 同步与推送编排 `sync.rs`：`preview_source`、`sync_source_with_control`（可取消）、`push_list_targets/push_create_target/push_plan/push_execute` | `application/src/sync.rs:177/216/336/352/370/412` | ✅ SyncPreview/SyncRun/SyncCancel、PushTargets/PushCreateTarget/PushPlan/PushRun/PushCancel（事件 SyncPreviewReady→SyncCompleted、PushPlanReady→PushCompleted，`ffi/src/lib.rs:900-1020`） |

## runtime（voicefox-runtime）— 运行时装配与持久化

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 48 | `ApplicationRuntime`：装配 SourceManager/PlayerBackend/LyricService/ApplicationService + 启动播放泵 + 配置共享读口；`desktop()` 桌面一键构造 | `runtime/src/lib.rs:108/119/200/213/217` | ◐ 经 `new_desktop` 间接（`ffi/src/api.rs:50-62`） |
| 49 | 配置加载/保存：`config_loader::load/save/config_path`、`load_config/default_config_path`（TOML、旧目录迁移） | `runtime/src/config_loader.rs:79/331/313`、`runtime/src/lib.rs:323/333` | ◐ 经 new_desktop 与 ConfigUpdate 间接；配置文件路径本身 ❌ 不过 FFI |
| 50 | `Storage`：收藏/收藏歌单/自建歌单/历史全套 CRUD（含 trim）、播放会话持久化（`load/save/clear_playback_session`）、洗牌状态存取、数据导出导入（`export_data/import_data/export_default/import_default`，版本化 `DataBackup`，导入前自动备份）、单歌单导出 `export_custom_playlist`、外部歌单导入 `import_external_playlist`（M3U/LX Music/网易云）、同曲判定 `same_song_identity` | `runtime/src/storage.rs:184/531-871/914-995/228-311/100/116/1417` | ◐ 库 CRUD 经 application 命令 ✅；导出/导入/播放会话/洗牌状态 ❌（仅 TUI CLI `--export-data/--import-data/--import-playlist`，`app/src/cli.rs:17-44`） |
| 51 | 封面服务 `CoverService`（下载缓存/临时文件清理/宽高探测/URL 校验：`cover_src/source.rs:20-162`） | `runtime/src/cover.rs:20-107` | ❌ FFI 只传 `cover_url` 原始字符串（`SongDto.cover_url`），本地缓存路径/位图不过 FFI |
| 52 | 配置字段面差异：`Config` 完整面含键位、UI（状态栏/侧栏/主题/列配置）、通知、集成（MPRIS/SMTC/Now Playing/ListenBrainz token）、WebDAV、源策略（auto/prefer/only）等；`ConfigDto` 只镜像 v1 设置页字段 | `core/src/model/config.rs:642/672/699/740/837` vs `ffi/src/lib.rs:144-259` | ❌ 未镜像字段在 FFI 上不可读不可写（`ffi/src/lib.rs:142-143` 注释自述） |

## download（voicefox-download）— 下载系统

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 53 | `DownloadEngine`：分片下载（Range 探测/多线程分片）、重试判定 `DownloadError::is_retryable`、进度快照 `ProgressSnapshot`、候选 URL 生成与网易云 host 改写 | `download/src/engine.rs:219/294/254/87/106/128/922/943` | ❌ 引擎纯内部 |
| 54 | `DownloadManager`：enqueue（去重）/cancel/clear_finished/snapshot/active_count/`progress_summary`/`existing_download`（已下载复用）/`sync_config`/`maybe_auto_cache` | `download/src/manager.rs:196/513/350/366/291/323/331/287/245/526` | ◐ 入队/取消/清理 + 任务列表快照 ✅（`state.downloads`，`DownloadTaskDto` 含重试载荷，`ffi/src/lib.rs:123-139`）；`progress_summary/existing_download/maybe_auto_cache` ❌ |
| 55 | 命名与落盘：`render_filename`（模板渲染）/`sanitize_filename`/`unique_dest`/`resolve_download_dir`/扩展名探测 | `download/src/naming.rs:66/21/169/142/106` | ❌ |
| 56 | 标签与歌词文件：`embed_tags`（lofty 写 ID3/Vorbis）、`write_lyric_file`、`merge_lyric`、`standard_lyric`、封面压缩 `shrink_cover`、音频完整性校验 `validate_audio` | `download/src/tags.rs:44/81/99/125/180/220` | ❌ |
| 57 | 下载历史记录库 `DownloadRecords`（近 N 条、查重、清空） | `download/src/records.rs:109/161/192/207` | ❌ GUI 只见活跃任务，历史记录库无 FFI 面 |

## app（voicefox-app）— TUI 二进制（能力对 FFI 完全不可见）

| # | 能力 | 入口 | FFI |
|---|------|------|-----|
| 58 | 进程级 CLI：`--config/--log-level/--check-libmpv/--export-data/--import-data/--import-playlist` | `app/src/cli.rs:7-44`、`app/src/main.rs:1416` | ❌ |
| 59 | TUI 页面集：搜索/主界面/队列/设置/排行榜/歌单/收藏/历史/下载/本地音乐/详情/帮助/扫码登录/同步浮层，含上下文菜单、列排序、进度条等组件 | `app/src/pages/`（14 个页面文件）、`main.rs:5250 execute_action` | ❌ |
| 60 | 平台媒体集成：Linux MPRIS（zbus）、Windows SMTC（souvlaki 隐藏窗口消息泵）、macOS Now Playing；统一快照/命令层 `media_session` | `app/src/mpris.rs`、`app/src/smtc.rs:21`、`app/src/media_controls.rs`、`app/src/media_session.rs:37`；开关 `core/src/model/config.rs:642-669` | ❌ |
| 61 | 桌面通知 `DesktopNotifier` | `app/src/notification.rs:16-30` | ❌ |
| 62 | 睡眠定时器 `SleepTimerState`（arm/cancel/poll） | `app/src/sleep_timer.rs:39-119` | ❌ |
| 63 | ListenBrainz 听歌上报 `schedule` | `app/src/listenbrainz.rs:24` | ❌ |
| 64 | 频谱可视化（捕获/FFT/渲染）与 tmux 图像透传 | `app/src/visualizer/`、`app/src/tmux.rs:10/21` | ❌ |
| 65 | 进程单实例锁、数据缓存、播放编排（失败换源、bili 分 P 选择、播放恢复） | `app/src/instance_lock.rs:20`、`app/src/data_cache.rs:11`、`main.rs:6114/6441` | ❌（恢复播放等编排的 application 层等价命令 `RestorePlayback` 也未映射 FFI，见 #37） |

## 汇总：FFI 从未暴露的能力（❌ 全集）

按模块归纳，全部有代码出处（对应上表条目号）：

1. **播放器音频增强**（#10/#32）：播放速度直控、输出设备、ReplayGain、声道布局、左右平衡、A-B 循环、均衡器、fade in/out —— `PlayerBackend`/`MpvEngine` 已实现，FFI 无一命令；仅倍速可经配置持久化。
2. **登录态管理**（#25）：`logout`、`is_logged_in`、`is_vip_account` —— GUI 无法登出或查询登录态（TUI 可，`core/src/events.rs:146`）。
3. **JS 音源管理**（#26）：导入/下载/缓存判断/注册/卸载 JS 音源 —— 全内部；TUI 有 `ImportSource`。
4. **链接直解**（#22）：`parse_link`（单曲/歌单/专辑链接解析）。
5. **音源健康检查与诊断**（#23）：`health_check`/`SourceHealth`。
6. **跨源同曲匹配**（#24）：`find_music/find_music_on`（仅内部换源用）。
7. **歌单关键词搜索**（#21/#42）：`search_playlists`（接口层有默认回退实现，`core/src/traits/source.rs:148`）。
8. **本地曲库管理**（#28）：元数据编辑、按路径移除、损坏/缺失/重复诊断、文件监视器 —— GUI 只能触发扫描与读快照。
9. **歌词逐字数据**（#8/#33）：`YrcLine/YrcWord` word 级时间轴不过 FFI，GUI 只得整行。
10. **数据导出/导入与播放恢复**（#37/#50/#58）：Storage 的 export/import（含 M3U/LX/网易云歌单导入）、播放会话恢复（`RestorePlayback` 命令未映射）、洗牌状态持久化。
11. **下载周边**（#54-#57）：历史记录库、`progress_summary`、已下载复用查询、WebDAV 同步（`download/src/webdav.rs:104`，且 WebDAV 配置不在 `ConfigDto` 镜像内）。
12. **镜像缓存维护**（#46）：`remote_cache::clear/cache_file_size`。
13. **TUI 专属整层**（#14/#59-#65）：键位系统、页面/菜单/可视化、MPRIS/SMTC/Now Playing、桌面通知、睡眠定时、ListenBrainz、实例锁 —— 均不跨 FFI。
14. **配置未镜像面**（#52）：键位、UI/通知/集成/WebDAV/源策略等 Config 字段在 FFI 上不可读不可写。

## 其他观察（只盘点，不评判）

- FFI 命令面存在一处收窄：`FfiCommand::SearchMore` 丢弃了可选音源参数，硬编码 `source: None`（`ffi/src/lib.rs:1401-1405`），而 `ApplicationCommand::SearchMore` 本身支持指定源（`application/src/event.rs:14-18`）。
- `FfiCommand` → `ApplicationCommand` 的覆盖率为 55:61（`FfiCommand` 55 变体；`ApplicationCommand` 61 个变体，其中 6 个未映射，见 #37）。
- 事件面为「胖联合」设计：单个 `VoicefoxEvent` 结构承载全部 15 类事件（`ffi/src/lib.rs:651-690`），6 类事件只传 kind 不传载荷（`ffi/src/lib.rs:1041-1049`）。
- `docs/SYNC.md`、`docs/CONFIGURATION.md`、`docs/USER_GUIDE.md` 为用户文档；仓库内无 rustdoc 级模块文档，模块语义主要来自源码 doc comment。

## 计数

- 能力条目（上表编号 1-65）：**65 条**，其中 FFI 通道自身 7 条、core 8、source 15、player 2、lyric 3、application 12、runtime 5、download 5、app 8。
- FFI 暴露状态分布：✅ 完整暴露 11 条；◐ 间接/子集暴露 28 条；❌ 从未暴露 25 条；另 1 条为事实陈述（#7 无手写 C ABI）。
  逐表核对：FFI 通道 ✅5/◐1；core ◐5/❌3；source ✅2/◐8/❌5；player ❌2；lyric ◐2/❌1；application ✅4/◐8；runtime ◐3/❌2；download ◐1/❌4；app ❌8（明细见上表与「FFI 未暴露全集」）。
- 核对方式：FFI 判定均以 `ffi/src/api.rs` + `ffi/src/lib.rs` 静态比对为据，并经 Dart 生成物（`flutter/lib/src/bridge/api.dart`、`lib.dart`）与关键字 grep（logout/parse_link/equalizer/replaygain/ab_loop/balance/channel_mode/audio_device/health/find_music/export/import/webdav/listenbrainz/visualizer 等在 ffi 源码 0 命中）双重确认。
