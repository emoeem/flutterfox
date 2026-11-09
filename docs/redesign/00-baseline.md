# 重构前基线审计（00-baseline，2026-11-10）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §0.1.1 / §1.1
- 原则：以当前代码为准重新审计；旧报告问题逐条验证后才引用，禁止照抄。
- 审计方式：全量读代码 + 门禁实跑 + 桌面实机运行（`DISPLAY=:1`，GDK_BACKEND=x11，
  xwayland-satellite 会话，niri 合成器）+ X11 注入式交互（点击/悬停/键盘）。
- 缺陷矩阵见 `docs/redesign/04-defect-matrix.md`。

---

## 1. Git 状态

| 项 | 值 |
|---|---|
| 当前分支 | `feat/ui-redesign` |
| HEAD | `d9ee22fa66dee29fe86159643ca67df0591aa346` |
| 工作区 | 仅 1 个未跟踪文件：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md`（无源码改动） |
| 与本地 main 差异 | `main…feat/ui-redesign` = 0 ahead / **1 ahead**（领先 1 个提交：d9ee22f 门禁脚本+format 基线） |
| upstream | remote `flutterfox` = git@github.com:emoeem/flutterfox.git（本会话 fetch 失败：ssh_askpass 无、Host key verification failed，未取到远端新状态）；本地 ref `flutterfox/main = a0cfbf4`，`flutterfox/main…feat/ui-redesign` = 0 behind / **20 ahead** |
| remote origin | /home/emo/code/voicefox（原 TUI 仓库，未推送） |

结论：本分支 = flutterfox/main + 20 个提交（myune 基底收敛 → Phase 2 新 Shell → 设计系统 → 门禁脚本），无未提交源码改动。

## 2. 工具链与环境

| 组件 | 版本 / 状态 | 取证命令 |
|---|---|---|
| Flutter | 3.47.9 stable（revision c197ca5199，2026-10-29） | `flutter --version` |
| Dart | 3.13.7 stable | `dart --version` |
| Rust | cargo 1.99.1 / rustc 1.99.1（需 `RUSTUP_HOME=/home/emo/.rustup` `CARGO_HOME=/home/emo/.cargo`） | `cargo --version; rustc --version` |
| JDK | **无**（`java: command not found`） | — |
| Gradle | 系统无全局 gradle（Android 构建走 flutter 包装，但因无 JDK 不可用） | — |
| Android SDK | /home/emo/android-sdk：有 build-tools/cmake/cmdline-tools/ndk/platform-tools/platforms；**无 emulator 包、无 system-images** | `ls /home/emo/android-sdk` |
| 真机/模拟器 | `/home/emo/android-sdk/platform-tools/adb devices` → `List of devices attached`（空）→ **无真机、无模拟器** | adb devices |
| 桌面链路 | DISPLAY=:1（niri + xwayland-satellite），GTK3/libmpv dev 已装，桌面构建与运行通过 | 本次实跑 |
| 构建环境坑 | `flutter/build/linux/x64/release/CMakeCache.txt` 缓存了失效路径（`/usr/sbin/ninja`、`/usr/sbin/clang++`、`/usr/sbin/pkg-config` 等，2026-11-07 旧环境遗留）；逐行修补 3 次仍连环失败后，删除可再生构建产物 `flutter/build/linux` 重新构建成功（exit 0）。 Phase 7 构建前需清理该缓存。 | /tmp/build-linux*.log |

## 3. 门禁基线（scripts/redesign-gate.sh，各子命令退出码）

| 子命令 | 退出码 | 结果 |
|---|---|---|
| `dart-format` | **0** | `Formatted 229 files (0 changed)` |
| `flutter-analyze` | **0** | `No issues found! (ran in 11.9s)` |
| `flutter-test` | **0** | `00:18 +189: All tests passed!`（189 项） |
| `cargo-fmt` | **0** | 无输出（全绿） |
| `cargo-test` | **101** | `lx-source` 1 failed：`cover_cache::tests::sweep_evicts_down_to_the_limit_by_oldest_access`（FLUTTER_MIGRATION_PROGRESS.md 已记载的已知 flaky；本会话**单独复跑通过**：`cargo test -p lx-source --lib cover_cache::tests::sweep…` → `1 passed`）。`--workspace` 在第 4 个 crate 中止：lx-core 47 + lx-lyric 19 + lx-player 12 通过；随后补跑 `cargo test --workspace --exclude lx-core --exclude lx-lyric --exclude lx-player --exclude lx-source` → exit 0，**513 passed**（voicefox-app 333+1 ignored / application 71 / download 65 / ffi 6 / runtime 38+1 ignored / lx_test 0）。全仓合计 ≈808 passed / 1 known-flaky |
| `cargo-clippy`（gate 原命令：`--workspace --all-targets --all-features -- -D warnings`） | **101（构建失败）** | `--all-features` 激活 `voicefox-player` 的 `build_libmpv` feature → `libmpv2 6.0.0` build.rs panic：`env var MPV_SOURCE not set`（需 mpv 源码树）。**本环境无法按原样执行** |
| `cargo-clippy`（去 `--all-features`，保留 `-D warnings`） | **101** | lx-core 28 个 `must_use/double_must_use` 错误后中止 |
| `cargo-clippy`（`--workspace --all-targets`，不带 `-D warnings`） | **0，30 条 unique 告警** | 全部为 `#[must_use]`/`double_must_use`（`#[async_trait]` 展开触发）：lx-core 28（`core/src/traits/source.rs` 19、`core/src/sync/mod.rs` 8、`core/src/traits/lyric_fetcher.rs` 1）+ voicefox-application 2（`application/src/services/playback.rs`） |

**Phase 7 对比基线：clippy 告警 30 条（不得更差）；flutter-test 189；analyze 0 issues。**
另：clippy 原样命令（`--all-features`）在本环境属于「无法执行」而非「告警为 0」，勿在 Phase 7 误当作已通过。

## 4. 当前 Shell 与路由结构

- 入口 `flutter/lib/main.dart`：
  - 桌面（非触屏）：`VoicefoxShell`（`src/shell/app_shell.dart`，Phase 2 新壳）。
  - 触屏（Android/iOS）：`TouchShell` → 按宽度 `MobileShell` / `TabletShell`（`src/shell/mobile_shell.dart`）。
  - Rust 引导完成前 `_BootstrapScreen` 骨架屏；就绪后挂 `MyuneHost` Provider 图。
  - 验收钩子：`VOICEFOX_START_PAGE/SEARCH/TAB/SECTION/DETAIL/SIZE/POS` 环境变量（仅影响启动，运行时行为一致）。
- `VoicefoxShell` 结构（app_shell.dart:398-455）：AppHeader（唯一窗口标题栏，含返回/前进/全局搜索框 Ctrl+K/面板开关）→ Sidebar → 中央 IndexedStack（7 目的地常驻）→ ContextPanel（≥1440 内嵌 / <1440 浮层）→ PlayerBar（全屏播放页打开时不进树）。
- 导航语义：5 一级入口 `kShellPrimaryDestinations = home/discover/search/library/downloads`；settings/help 为侧栏底部二级页；统一 `kShellDestinationOrder`（app_shell.dart:43-51）与 `mapLegacyNavIndex`（旧 9 入口索引映射）；桌面与移动壳共享 `buildShellPage`（同一目的地同一页面实现）。
- 旧壳 `src/myune_shell/app_shell.dart` 已标记 **RETIRED**（文件头声明，main.dart 不再挂载）。
- 桌面快捷键（app_shell.dart:352-377）：Space 播放/暂停、←/→ ±5s、Esc 关全屏播放页→pop、Ctrl/Cmd+K 聚焦搜索；输入框聚焦时不拦截。

## 5. 断点与真实行为（responsive_shell.dart）

桌面（非触屏平台，宽度无关恒为 desktop 形态）：

| 可用宽度 | Sidebar | ContextPanel | 内容边距 |
|---|---|---|---|
| ≥1440 | 240（展开） | inline 内嵌（可关） | ≥1600:32 / 否则 28 |
| 1200–1439 | 240（展开） | overlay 浮层 | 28 |
| 960–1199 | 72（折叠） | overlay 浮层 | 20 |
| <960 | hidden（Header 菜单浮出） | overlay 浮层 | 20 |

触屏（MobileBreakpoints + resolveDeviceFormFactor/resolveTabletLayout）：

| 宽度 | 形态 |
|---|---|
| <600 | MobileShell：顶栏(56) + IndexedStack + MiniPlayerBar(有歌时) + NavigationBar 五入口；PopScope 全屏播放页优先返回 |
| 600–899 | TabletShell rail：图标 NavigationRail + 内容，右栏浮层 |
| 900–1199 | TabletShell dual：展开带标签 Rail(200) + 内容 |
| ≥1200 | TabletShell triple：Rail + 内容 + ContextPanel 内嵌 |

断点为纯函数（`resolveShellMetrics`/`resolveDeviceFormFactor`），有单测覆盖。指南 §4.1 的 600/840/1200 三档与本实现语义一致（本实现触屏拆为 600/900/1200 三档，平板双档更细）。

## 6. AppModel 状态字段（flutter/lib/src/app_model.dart）

- 核心快照 `_state: bridge.VoicefoxState`：playback / queue / queue_index / search / lyrics / playlists / favorites / favorite_playlists / history / custom_playlists / downloads / sources / local_songs（13 字段，ffi/src/lib.rs:99-113）。
- 模型自有字段：themeKey、useDynamicColor、lastNotification、lastError、qrSession/qrStatus/qrUser、scanWarnings、scanningLocal、_cachedConfig、sync*（7 字段）、push*（7 字段）。
- 浏览数据面：`_browse` 按 `'$browseKind|$source|$id'` 分槽 `BrowseResult{loading,error,notice,page,hasMore,songs,playlists,albums,boards,categories}`（app_model.dart:19-37,293-297）。
- 事件泵：`_eventLoop` 逐条消费；异常时 1s 退避重订阅并**整份重拉快照**（lag 自愈，app_model.dart:164-186）；`progress` 事件只替换 playback 子快照（:255-279），其余 kind 走 `_refreshState()`。
- 命令面：`dispatch(FfiCommand)` + 60 余个封装方法（loadPlaylist*/loadLeaderboard*/loadArtist*/loadAlbumSongs/playSongs/scanLocal/setVolume/seekMs 等）。

## 7. FFI commands / events / snapshot

- **FfiCommand 55 变体**（ffi/src/lib.rs:1311-1420）：播放 12（Pause/Resume/Toggle/Stop/SeekMs/SetVolume/PlaySong/QueueAdd/QueueRemove/QueueClear/Next/Previous）、搜索 2（Search 带 source 过滤 / SearchMore **无 source 参数**，:1516-1520，见缺陷 P1-04）、库 8（LibraryRefresh/FavoritesAdd·Remove/FavoritePlaylistAdd·Remove/HistoryRemove·HistoryClear）、自建歌单 7、配置 2（ConfigGet/ConfigUpdate）、下载 3（Enqueue/Cancel/ClearFinished）、扫码登录 2、LocalScan、账号镜像 3（AccountPlaylists/AccountFavorites/AccountPlaylistDetail）、同步 3、推送 5、浏览 7（PlaylistCategories/PlaylistList/PlaylistDetail/LeaderboardBoards/LeaderboardSongs/ArtistSongs/ArtistAlbums/AlbumSongs）。
- **事件 kind 15 种**（VoicefoxEvent，ffi/src/lib.rs:653-780）：state_changed/progress/search/playback/queue/lyrics/playlist/notification/library/downloads/config/qr_login/local_music/browse/sync（progress 携带 position_ms/duration_ms/playback_state；browse 携带 browse_kind/source/id/分页载荷；sync 复用为推送进度通道）。
- **快照**：`state(controller)` 返回完整 VoicefoxState；`subscribe/eventNext` 事件流；`hostPlayerStream`（Android 转发型播放指令通道）。
- Android 引导链已存在（main.dart:203-223）：setDataDir → newHost（无 mpv 转发型后端）→ attach → audio_service/just_audio → HostPlayerBridge。**因无 JDK 无法构建验证**（见 §14 未验证项）。

## 8. DTO 唯一标识

| DTO | 字段 | 唯一标识 |
|---|---|---|
| SongDto（ffi/src/lib.rs:22-32） | id/source/name/singer/artist_id?/album_name/album_id?/duration_ms/cover_url? | **source+id**（artist_id/album_id 可空，UI 回退展示名） |
| PlaylistDto（:314-322） | id/name/source/cover_url?/song_count/description? | source+id；**无 type 字段**——账号歌单 vs 公开歌单的隔离靠 browseKind（`account_playlist_detail` vs `playlist_detail`）进 browse key（app_model.dart:57,293）。语义隔离成立，但指南 §8.1 建议的显式 `PlaylistKey(source,id,type)` 抽象未建立（登记 P3） |
| AlbumDto/ArtistDto | id/name/source/cover_url?/artist? | source+id |
| CustomPlaylistSummaryDto | id/name/cover_url?/song_count | 本地自建 id |
| DownloadTaskDto | id(u64)/name/singer/source/quality/dest/**song(完整载荷)**/state/active/downloaded/total?/error?/trigger_auto_cache | 任务 id；重试走内嵌 song |
| SourceCapabilitiesDto（:421-433） | id/name/playlists/playlist_categories/playlist_search/album/artist/leaderboard/login/qr_login | source id；驱动入口显隐 |

## 9. 播放状态 / 进度 / 时长 / 队列 / 播放模式的数据链

链路（代码层完整）：mpv engine watcher（player/src/engine.rs:176-237，duration 属性 observer :453-455）→ `ApplicationService::start_playback_pump`（application/src/service.rs:163-247，进度 4Hz 节流 :64，`PlayerEvent::Ended`→按播放模式自动切歌 :240-247）→ runtime/lib.rs:200 挂泵 → FFI `kind="progress"` 事件 → AppModel `_applyPlaybackProgress` → UI（PlayerBar `_ProgressLine`/LivePlayback 插值）。
- 音量：SetVolume 命令 → `PlaybackService::set_volume`（application/src/services/playback.rs:306-307）→ PlayerBar 音量滑条真实下发（player_bar.dart:504-570）。
- seek：SeekMs → PlaybackService::seek（:302）。
- 队列：queue/queue_index 唯一真源 AppModel.state.queue；QueuePanel 读 state 不自持副本（player/queue_panel.dart:3-5），当前曲高亮（:60,130）、单曲移除、清空二次确认（:33-42）。
- **实机验证结果：链路在「播放启动/状态回显」环节正常，但 position/duration 到 UI 恒 0（见缺陷矩阵 P0-02）**；Ended 自动切歌未能观察（先被 P0-01 卡死阻断）。

## 10. 封面链路（URL 来源 / 缓存 / 刷新 / 失败处理）

三套并存，无统一 ArtworkResolver（§8.2 目标）：

1. `widgets/cover_image.dart`（CoverImage）：cached_network_image；空 URL/加载失败 → surfaceContainerHighest 占位盒（:37-58）；无内存/磁盘策略细节（交给 cached_network_image 默认）。
2. `myune_seam/cover_loader.dart`：播放页用；内存 LRU 32 张 + `_inflight` single-flight（:15-41）；http(s)/file:// /本地路径三态 fetch，失败返回 null 走占位（:44-73）。**注释宣称「磁盘缓存（系统临时目录）」但实现中不存在任何磁盘缓存代码（:1-5 注释与实现不符）**。
3. `design_tokens.dart` VxCoverGradients + VxCoverFallback：设计占位渐变（按名字种子稳定取色）。

**实机缺陷（P1，代码+截图双证据）**：home_page.dart:147/207/260 与 discover_page.dart:571-578 四处 `cover: (url?.isNotEmpty ?? false) ? null : CoverImage(...)` 三元**反写**——有封面 URL 时传 null（卡片回退渐变占位），无 URL 时才建 CoverImage；导致「有真实封面的数据全部显示渐变占位」。实机截图中发现页酷我热门歌单卡、首页继续收听/最近播放封面全部为渐变首字母占位。library_page.dart:595-601 同场景写法正确（非反写）。

## 11. 本地文件导入链路

`local_music_page.dart`：
- 入口：顶部「添加目录」（:112）+ 空态主 CTA（:260）+ 空态次按钮（:302）。
- 流程：`FilePicker.getDirectoryPath`（PlatformException → 手输绝对路径对话框兜底 :400-423）→ ConfigUpdate `localMusicPaths` → `scanLocal(paths, maxDepth)`（app_model.dart:300-313）→ `local_music` 事件带回 warnings → `state.localSongs` 刷新。
- 移除目录有确认对话框（:426-447）；进入页面按 TUI 同规则自动补扫（:374-394）；扫描中按钮禁用、加载态/空态/错误态齐全。
- 播放全部/单曲播放/入队走 playSongs/queueAdd。
- **未验证**：Android SAF（无设备）；`file_picker` 在 Android 返回 content:// URI 后 Rust 侧 `File` 直读是否可用未验证（Rust local 源按路径读文件，SAF URI 兼容性是 Phase 5 风险）。

## 12. 音源列表 / 能力 / 登录态 / 搜索分页

- 13 音源（kw/kg/tx/wy/mg/bili/soda/qianqian/joox/jamendo/fivesing/apple/local），能力位经 SourceCapabilitiesDto 下发；发现页按 `playlists/leaderboard/playlistCategories` 能力位聚合多源内容（discover_page.dart:144-186），单源 scope chips 切换。
- 登录：扫码登录命令/事件/DTO 齐（qr_login 事件含 waiting/scanned/success/expired/failed 等 status）；设置页含扫码入口。
- 搜索页（search_page.dart）：300ms 防抖（:56,151-153）；音源多选筛选（单选走后端 source 过滤，多选聚合+本地过滤展示 :129-132）；**分页 in-flight 锁** `_moreInFlight` + requestId 失效检测（:74-77,159-167,110-125）；类型 Tab（全部/歌曲/专辑/歌手/歌单；专辑/歌手由歌曲结果聚合，聚合搜索无歌单数据时如实说明）。
- 已知缺口：SearchMore 后端丢 source（P1-04）。

## 13. 测试、CI、设备覆盖

- 本地门禁：`scripts/redesign-gate.sh`（见 §3）；CONTRIBUTING.md 要求 clippy/check/test + analyze/test 全绿（其记载的「53 tests」基线已过时，现为 189）。
- Flutter 测试层级：widget/unit 为主（shell/layout/search/local_music/song_tile/设计系统 Gallery golden 等 189 项）；integration/device 层无。
- CI（.github/workflows/ci.yml，374 行）：jobs = lint / build-linux / build-windows / build-macos / build-android / flutter。
- 设备：无真机、无模拟器、无 JDK → Android 全链未验证（§14）。

## 14. 可用设备 / 模拟器与未验证项（诚实清单）

| 项 | 状态 | 原因 |
|---|---|---|
| Android 真机/模拟器运行 | **未验证** | adb devices 空；SDK 无 emulator/system-images；无 JDK（java 不存在）→ APK 无法构建 |
| Android 系统栏/inset/SAF/后台播放/锁屏/耳机 | **未验证** | 同上 |
| 浅色主题实机走查 | **未验证**（代码层疑点见缺陷 P2-01） | 本次交互会话中设置页主题切换未完成（UI 卡死缺陷阻断） |
| 平板三态断点实机 | 未实机验证（仅单测） | 无触屏设备；MobileShell/TabletShell 有 widget 测试 |
| MPRIS/托盘/系统媒体集成 | 未实现（Rust 侧 app/src/mpris.rs 350 行存在，GUI 未接） | Phase 6 计划项 |
| 桌面窗口尺寸契约 | 部分验证 | VOICEFOX_START_SIZE=1440x900 在 niri+xwayland-satellite 下未按预期生效（缺陷 P2-04） |

## 15. 现有截图与实机页面的差异

- `docs/shots/`、`docs/UI_AUDIT_2026-11-04.md §0`、`docs/UI_AUDIT_DESKTOP.md §1` 的截图对应**旧 myune 壳**（九入口 rail/旧首页仪表盘），与本分支现役 VoicefoxShell（5+2 入口/新设计系统/Vx* 组件）已完全不同——旧截图仅作历史证据，不作为当前 UI 基线。
- 本轮基线截图（真实数据、实机交互）：`docs/redesign/screenshots/baseline/` 8 张（命名 `<platform>-<page>-<viewport>-<state>.png`）：
  - linux-home-1656x817-empty.png（空库 Hero + 真实酷我热门榜单）
  - linux-home-1656x817-history.png（继续收听 Hero + 最近播放，重启后历史仍在=持久化证据）
  - linux-discover-1656x817-default.png（发现页：精选歌单/排行榜/歌手/专辑/分类 chips + 多源真实歌单卡）
  - linux-library-1656x817-empty.png（曲库四类 chips + 本地/网易云/QQ 分段 + 空态）
  - linux-downloads-1656x817-empty.png（全部/进行中/已完成/失败分段 + 表头 + 空态）
  - linux-settings-1656x817-default.png（9 分组：播放与音效/音源/下载/歌词/外观/网络/账号与集成/快捷键/关于）
  - linux-search-1656x817-results.png（love → 257 结果、8 音源徽标、时长）
  - linux-search-1656x817-playing.png（播放中：行内均衡器图标 + PlayerBar 歌曲信息；**同时是 P0-02 的证据**：进度 00:00 / --:--）
- 未截到（被缺陷 P0-01 阻断）：全屏播放页（NowPlaying）、队列面板（ContextPanel queue tab）。

## 16. 旧审计条目在本基线的现状（抽样复核，非照抄）

| 旧条目 | 现状 |
|---|---|
| P0-01 播放器 watcher 无消费 | 已修（泵存在 service.rs:163-247）；但 **position/duration 到 UI 恒 0**（新证据，P0-02） |
| P0-02 Toggle 不回写 | 已修（Toggle 经状态广播回环） |
| P0-03 Ended 无消费者 | 代码已修（service.rs:240）；实机未观察成功（被 P0-01 阻断） |
| P0-05 无 SetVolume | 已修（FFI 命令 + service.rs:306 + PlayerBar 真实滑条） |
| P0-06 ConfigDto 往返损坏 | 用户配置目录 `~/.config/voicefox/` 现不存在（全新环境），无法回归实测；runtime/config_loader.rs 有 >4MB 隔离/损坏改名自愈逻辑（38 项 runtime 测试含此） |
| P0-07 错误静默 | 已修（lastError/lastNotification + ToastOverlay 全局出口） |
| P0-09 seed alpha=0 | 已修（seed_colors hexOf 0xFF 强制不透明；实机页面底色正常非纯黑） |
| P1-03 搜索无筛选/无状态/永久 spinner | 大体已修（音源筛选/骨架屏/in-flight 锁）；遗留 SearchMore 丢 source（P1-04） |
| P1-04 队列无高亮/移除/确认 | 已修（voicefox 新 QueuePanel；旧 myune 队列抽屉退役） |
| P1-11 lag 不重拉 | 已修（app_model.dart:164-186） |
| P0-A1 readAudioInfo 悬空桥 | **仍存在**（7 处调用、so 无导出）；调用点均有 try/catch 降级（如 playlist_content_notifier.dart:1073-1076 catch 后置「未知歌手 (解析失败)」）→ 降级为 P3 登记 |
| P1-C1 播放页音效面板空转 | 未复核（myune 播放页在新壳下可达性待查） |
| P1-C2 全局热键 stub | 未复核 |
| P1-C3 SearchMore 丢 source | **仍存在**（ffi/src/lib.rs:1516-1520）→ P1-04 |
| P1-D1 下载缺暂停/继续/速度/打开目录 | 未逐项复核（下载页分段/取消/重试 UI 在） |
| P1-D4 桌面系统集成缺失 | 仍缺（GUI 未接 MPRIS；Phase 6 计划项）P2 登记 |
| U-11 reduce-motion | 已修（disableAnimationsOf 用于 app_shell/mobile_shell/now_playing/lyrics_panel 等 5 处） |
| U-17 主题预览逐卡 build ThemeData | 已修（设置页迷你 wireframe 预览） |
| P2-V9 窄窗仍是桌面壳 | 已修（<960 降级布局；触屏平台另有 Mobile/Tablet 壳；桌面窄窗降级侧栏浮出） |

## 17. 结论（进入 Phase 1 前必须先处理的阻断）

1. **P0-01 UI 主 isolate 卡死**（搜索结果/播放后概率性冻结，5 实例 4 中）——任何截图回归/交互验收在此之前不可靠。
2. **P0-02 播放 position/duration 恒 0**——§8.3 数据正确性第一修复项。
3. **P1-03 封面三元反写 4 处**——一小时内可修，修复后封面链路才能进入 §8.2 统一改造。
