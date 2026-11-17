# 重构前基线审计（00-baseline，2026-11-10 第二轮全量复审）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §0.1.1 / §1.1。
- 原则：以当前代码为准重新审计；旧报告（UI_AUDIT_2026-11-04 / UI_AUDIT_DESKTOP / 第一轮 00-baseline / phase-1-report）的每条结论都重新验证后才引用，未验证的明确标注。
- 工作区状态：feat/ui-redesign @ `5725231`，工作区含 Phase 1 未提交改动（application/ffi/runtime/flutter 共 29 文件修改 + 9 新增文件）——本基线审计的对象即「Phase 1 实施后的当前工作区」，不是 d9ee22f 提交点。
- 缺陷矩阵：`docs/redesign/04-defect-matrix.md`（本轮新证据后重写）。
- 审计方式：全量读代码 + 门禁实跑（每个子命令独立记录退出码）+ 桌面实机运行与交互（Xvfb 自管显示器 :2，1920x1080x24，无合成器干扰；此前在 :1 niri+xwayland-satellite 上的两轮会话用于窗口行为观察）+ XTest 注入式交互（`/tmp/vx-baseline2/vxinject`，X11 XTest：move/click/dclick/key/type）。

---

## 1. Git 状态

| 项 | 值 |
|---|---|
| 当前分支 | `feat/ui-redesign` |
| HEAD | `5725231634f32436455b89ffda7a0f3215777f00`（docs: phase 0 基线审计与开源研究） |
| 工作区 | 29 个已跟踪文件修改（application/src/service.rs、ffi/src/{api,lib,frb_generated}.rs、runtime/src/lib.rs、flutter 侧 app_model/bridge/各页/shell/player 等、docs 指南与旧缺陷矩阵）+ 9 个未跟踪新文件（phase-1-report.md、vx_artwork.dart、services/、android_insets.dart、5 个新测试）——全部为 Phase 1 实施改动，无与本轮无关的杂项 |
| upstream | 本分支无 upstream；remote `flutterfox`（github emoeem/flutterfox）、remote `origin`（/home/emo/code/voicefox，原 TUI 仓库）。未执行 fetch/push |
| 与 main 关系 | 分支领先本地 main 若干提交（Phase 2 Shell / 设计系统 / 门禁脚本 / Phase 0 文档）；本轮未做分支操作 |

## 2. 工具链与环境

| 组件 | 版本 / 状态 | 取证 |
|---|---|---|
| Flutter | 3.47.9 stable | `./scripts/redesign-gate.sh env`（本轮实跑，exit 0） |
| Dart | 3.13.7 stable | 同上 |
| Rust | cargo 1.99.1（需 `RUSTUP_HOME=/home/emo/.rustup` `CARGO_HOME=/home/emo/.cargo`） | 同上；未设这两个变量时 `cargo` 命令不可用（exit 127） |
| JDK / Android SDK | **无 JDK**；/home/emo/android-sdk 有 build-tools/ndk/platforms 但**无 emulator、无 system-images**；`adb devices` 空列表 | 沿用第一轮审计结论，本轮未复测（无理由变化） |
| 桌面链路 | GTK3/libmpv dev 已装；`flutter build linux --release` exit 0（本轮）；bundle/lib/libvoicefox_ffi.so mtime(11-10 03:51) 晚于最后 Rust 源码编辑(runtime/src/lib.rs 03:50:57)，产物与工作区源码一致 | 本轮构建日志 /tmp/vx-baseline2/build-linux.log |
| 显示器 | 实机截图会话在 **Xvfb :2（1920x1080x24，无 WM）**——应用按请求 1440x900 呈现；:1（niri 26.04 + xwayland-satellite）仅用于窗口行为观察 | /tmp/vx-baseline2/app-run3.log |

## 3. 门禁基线（scripts/redesign-gate.sh，本轮实跑退出码）

| 子命令 | 退出码 | 结果（本轮实测） |
|---|---|---|
| `dart-format` | **0** | `Formatted 229 files (0 changed)` |
| `flutter-analyze` | **0** | `No issues found!` |
| `flutter-test` | **0** | `00:21 +229: All tests passed!`（229 项，较第一轮 189 增加 40：artwork/error_toast/isolation/pagination/insets 等新测试） |
| `cargo-fmt` | **0** | 无输出（全绿） |
| `cargo-test` | **0** | **全部通过，0 failed**：lx-core 47 / lx-lyric 19 / lx-player 12 / lx-source 218+2 ignored / js_user_api 4 / voicefox(TUI) 333+1 ignored / voicefox-application 72 / voicefox-download 65 / voicefox-ffi 6 / voicefox-runtime 40+1 ignored → **816 passed**。第一轮记录的 lx-source `sweep_evicts…` flaky 本轮未复现（0 failed） |
| `cargo-clippy`（gate 原命令：`--workspace --all-targets --all-features -- -D warnings`） | **101（构建失败）** | `--all-features` 激活 `libmpv2 6.0.0` build.rs panic：`env var MPV_SOURCE not set`（registry rsproxy.cn 路径实证）。**本环境无法按原样执行**，属「无法执行」而非「0 告警」 |
| `cargo clippy --workspace --all-targets -- -D warnings`（去 --all-features） | **101** | lx-core 28 个 `must_use` 错误后中止（`core/src/traits/source.rs` 19 / `core/src/sync/mod.rs` 8 / `core/src/traits/lyric_fetcher.rs` 1）+ voicefox-application 2（`application/src/services/playback.rs`） |
| `cargo clippy --workspace --all-targets`（不带 -D warnings） | **0，30 条 unique 告警** | 全部为 `#[must_use]`/`double_must_use`（`#[async_trait]` 展开触发）：lx-core 28 + voicefox-application 2；无其他类别告警 |

**Phase 7 对比基线：clippy unique 告警 30 条（不得更差）；flutter-test 229 passed；analyze 0 issues；cargo-test 816 passed 0 failed。**
clippy 原样命令（`--all-features`）在本环境因 MPV_SOURCE 不可执行——Phase 7 复验时沿用「去 --all-features + 统计告警」口径，并保持 MPV_SOURCE 环境缺失的事实披露。

## 4. 当前 Shell 与路由结构

- 入口 `flutter/lib/main.dart:100-188`：
  - 桌面（非触屏，`isTouchPlatform = Platform.isAndroid || Platform.isIOS`，responsive_shell.dart:26）：`VoicefoxShell`（src/shell/app_shell.dart）。
  - 触屏：`TouchShell` → 按宽度 `MobileShell` / `TabletShell`（src/shell/mobile_shell.dart:85-115，`resolveDeviceFormFactor`）。
  - Rust 引导 `bootstrapDesktop()` 后台执行；就绪前 `_BootstrapScreen` 骨架屏，就绪后挂 `MyuneHost` Provider 图（main.dart:287-291）。
  - 验收钩子（仅影响启动）：`VOICEFOX_START_PAGE/SEARCH/TAB/SECTION/DETAIL/KEYWORD/SOURCE/SIZE/POS`（main.dart:55-98）。
- `VoicefoxShell`（app_shell.dart:349-455）：AppHeader（唯一窗口标题栏：返回/前进/Ctrl+K 全局搜索/右栏面板开关）→ Sidebar → 中央 IndexedStack（7 目的地常驻，`kShellDestinationOrder` app_shell.dart:43-51）→ ContextPanel（≥1440 内嵌 / <1440 浮层）→ PlayerBar（全屏播放页打开时不进树，:433-447）。Esc 顺序：先关全屏播放页再 pop 路由（:364-372）；Space/←/→ 在输入框聚焦时不拦截。
- 导航语义：5 一级入口 `kShellPrimaryDestinations = home/discover/search/library/downloads`（app_shell.dart:54-60）+ settings/help 侧栏底部二级；旧 9 入口经 `mapLegacyNavIndex`（:65-73）映射；桌面与移动壳共享 `buildShellPage`（:628-650，同一目的地同一页面实现）。
- 旧壳 `src/myune_shell/app_shell.dart` 保持 RETIRED（未挂载）。
- 移动壳（mobile_shell.dart:314-382）：顶栏 56 + IndexedStack + MiniPlayerBar（有歌时）+ NavigationBar 五入口；PopScope 全屏播放页优先返回；设置/帮助经 endDrawer 复用完整 AppSidebar。平板壳三态 rail/dual/triple（:530-616）。

## 5. 断点与真实行为

桌面（非触屏平台，宽度无关恒 desktop 形态，responsive_shell.dart:87-95）：

| 可用宽度 | Sidebar | ContextPanel | 内容边距 |
|---|---|---|---|
| ≥1440 | 240 展开 | inline 内嵌（可关） | ≥1600:32 / 否则 28 |
| 1200–1439 | 240 展开 | overlay 浮层 | 28 |
| 960–1199 | 72 折叠 | overlay 浮层 | 20 |
| <960 | hidden（Header 菜单浮出） | overlay 浮层 | 20 |

触屏（MobileBreakpoints + resolveDeviceFormFactor/resolveTabletLayout，responsive_shell.dart:50-102）：<600 手机壳；600–899 平板 rail；900–1199 平板 dual；≥1200 平板 triple（右栏内嵌）。

- 断点为纯函数（`resolveShellMetrics`/`resolveDeviceFormFactor`/`resolveTabletLayout`），有单测与 widget 测试（shell_test/tablet_shell_test/mobile_shell_test/viewport_matrix_test）。
- **实机观察（P2-04 相关）**：niri 平铺下请求 1440x900 实得 tile 1212x1274（surface 948x1010，948<960 → 降级布局）；Xvfb 下请求即所得（1440x900）。视口相关的验收截图必须在受控显示器（Xvfb）采集。
- **窗口行为风险（本轮新证）**：:1 会话中经 xwayland-satellite 转发的 X 客户端 configure resize（1212x1274→1600x950→1920x1080）后出现 `Timed out waiting for OpenGL frame`（app-run1.log 23:35:38），数分钟内进程静默消失（无 panic、无 core dump，/var/lib/systemd/coredump 仅 vinput-daemon 旧核）。与缺陷矩阵 P1-05（进程静默退出）同域；niri IPC 路径的全屏（上一轮会话）未复现该问题。登记为矩阵 P2 条目的观察证据，不在此定罪根因。

## 6. AppModel 状态字段（flutter/lib/src/app_model.dart，本轮逐项核对）

- 核心快照 `_state: bridge.VoicefoxState` 13 字段：playback / queue / queueIndex / search / lyrics / playlists / favorites / favoritePlaylists / history / customPlaylists / downloads / sources / localSongs（ffi/src/lib.rs:99-113）。
- 模型自有字段：themeKey、useDynamicColor、lastNotification、lastError、qrSession/qrStatus/qrUser、scanWarnings、scanningLocal、_cachedConfig、sync*（7）、push*（7）。
- **PlaylistKey**（app_model.dart:23-42）：`kind|source|id` 类型化键（==/hashCode/toString 完整），browse 缓存槽、请求、事件与 UI 读取统一使用（Phase 1 新增，P3-03 落地验证）。
- BrowseResult（:46-71）：loading/error/notice/page/hasMore/appendArmed + songs/playlists/albums/boards/categories；`prepareBrowseLoad`（:389-406）同步预清槽不通知（首帧 loading 不闪旧曲目）；`_applyBrowseEvent`（:470-516）对过期/乱序/重复 append 丢弃（`appendArmed` + 严格顺序页校验）。
- 事件泵 `_eventLoop`（:220-244）：异常 1s 退避重订阅 + 整份重拉快照（lag 自愈）；`_handleEvent`（:246-321）按 kind 分派；progress 事件只替换 playback 子快照（:331-367），状态迁移走全模型通知、纯位置/时长走 `playbackTick`（:79-94，4Hz 不打满全模型）。
- 错误净化（:1184-1208）：`sanitizeUserFacingMessage` URL→`[URL]`、空白折叠、140 字截断；原始异常 stderr（`_logAndSanitize`）；应用于 lastError/lastNotification 全部赋值点。
- 命令面：`dispatch` + 60 余个封装（playSongs/scanLocal/setVolume/seekMs/loadPlaylist*/loadLeaderboard*/loadArtist*/loadAlbumSongs/自建歌单 CRUD/账号镜像/同步/推送）。

## 7. FFI commands / events / snapshot

- **FfiCommand 55 变体**（ffi/src/lib.rs:1311-1495，本轮逐一清点）：播放 13（Pause/Resume/Toggle/Stop/SeekMs/SetVolume/PlaySong/QueueAdd/QueueRemove/QueueClear/Next/Previous/PlaySongs）、搜索 2（Search + SearchMore **均带 `source: Option<String>`**，:1339-1345——P1-04 修复已入 FFI 层）、库 8、自建歌单 7、配置 2、下载 3、扫码登录 2、LocalScan、账号镜像 3、同步 3、推送 5、浏览 7。
- **事件 kind 15 种**（VoicefoxEvent，ffi/src/lib.rs:653 起）：state_changed/progress/search/playback/queue/lyrics/playlist/notification/library/downloads/config/qr_login/local_music/browse/sync。
- 快照：`state(controller)` 全量；`subscribe/eventNext` 事件流；`hostPlayerStream`（Android 转发型指令通道，:1284）。
- Android 引导链（main.dart:203-223）：setDataDir → newHost → attach → audio_service/just_audio → HostPlayerBridge。**因无 JDK 无法构建验证（未验证项）**。

## 8. DTO 唯一标识

| DTO | 唯一标识 | 本轮核对 |
|---|---|---|
| SongDto（ffi/src/lib.rs:22-32） | **source+id**（+artist_id?/album_id? 可空回退展示名） | ✓ |
| PlaylistDto（:314-322） | source+id；无显式 type 字段，账号 vs 公开歌单以 browseKind（`account_playlist_detail` vs `playlist_detail`）隔离进 PlaylistKey | ✓（语义隔离成立；显式 `PlaylistKey(type)` 字段维持 P3 建议） |
| AlbumDto/ArtistDto（:366-403） | source+id | ✓ |
| CustomPlaylistSummaryDto（:118） | 本地自建 id（source 恒 `local`） | ✓ |
| DownloadTaskDto（:126） | 任务 id(u64) + 内嵌完整 song 载荷（重试用） | ✓ |
| SourceCapabilitiesDto（:421-433） | source id；10 能力位（playlists/playlist_categories/playlist_search/album/artist/leaderboard/login/qr_login 等）驱动入口显隐 | ✓ |

## 9. 播放状态 / 进度 / 时长 / 队列 / 播放模式的数据链（本轮实机验证通过）

链路（代码层）：engine watcher（player/src/engine.rs）→ `start_playback_pump`（application/src/service.rs:169-210，无 tokio 上下文时显式 eprintln 拒绝启动）→ runtime `from_parts` 进入 `enter_sync_bootstrap_runtime()`（runtime/src/lib.rs:22-32,232——FFI 同步引导路径自建进程级 multi-thread runtime，`OnceLock` 持有）→ 泵启动日志 `voicefox: playback pump started` → 4Hz `PlaybackProgress`（PROGRESS_INTERVAL=250ms service.rs:65）→ FFI progress 事件 → AppModel `_applyPlaybackProgress` → UI（playbackTick 订阅者）。

- **实机证据（Xvfb :2，release 构建，真实音源）**：启动日志含 `同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime` + `playback pump started`；播放 L-O-V-E（汽水）PlayerBar `00:02 / 00:30` 走带（截图 linux-search-1440x900-playing-00-02-progress.png）；曲目结束**自动切换下一首**（LOVE/Aki阿杰·5sing 00:00/02:34，截图 …ended-auto-next…png）；后续 00:26/02:34 走带（…00-26-progress.png）；stderr 事件速率 `19-22/5 s, last=progress`（≈4Hz）。会话内 Ended 自动切歌共发生 2 次（L-O-V-E→LOVE/Aki阿杰→Love/American Authors）。
- 音量：SetVolume → `PlaybackService::set_volume`（application/src/services/playback.rs:306-307）→ PlayerBar 音量滑条 + 全屏播放页音量条真实下发（实机播放页音量 80 显示一致）。
- seek：SeekMs → `PlaybackService::seek`（:302）；桌面快捷键 ←/→ ±5s（app_shell.dart:340-347）。
- 队列：唯一真源 AppModel.state.queue/queueIndex；QueuePanel 只读不自持副本（queue_panel.dart:3-10），当前曲高亮 + 单曲移除 + 清空二次确认 + 随机开关（updateConfig）；拖动排序无后端命令，UI 禁用并说明（不伪造）。
- 播放模式：config.playMode 四态（顺序/列表循环/单曲循环/随机）设置页可切（实机截图）；Ended 按 mode 推进（service.rs:252-260 旧代次竞态过滤）。

## 10. 封面链路（URL 来源 / 缓存 / 刷新 / 失败处理）

本轮确认的现状（§8.2 目标：唯一入口 VxArtwork + ArtworkResolver）：

1. **ArtworkResolver**（services/artwork_resolver.dart，Phase 1 新增）：实体键 `source|type|id`（缺实体键退化 URL 键）；内存 LRU 256 + TTL 30min；失败负缓存（n²·2s 退避，3 次后 1h）；本地路径存在性校验 + single-flight；`decodeCacheWidth` 限尺寸解码（16–1024）。§8.2 六级解析优先级落地 1/2/4/6，第 3 级（音源补全接口）与第 5 级（实体匹配补全）裁剪未实现（phase-1-report 已登记）。
2. **VxArtwork**（design_system/components/vx_artwork.dart）：唯一封面展示入口——空 URL 占位 / 失败态含重试按钮 / http(s) 走 CachedNetworkImage（磁盘+内存+同 URL 单飞）/ 本地走 ResizeImage(FileImage) / 语义标签携带实体名 / 首帧淡入。已接入：home_page 3 处、discover_page、search_page 专辑/歌手网格 2 处、playlist_detail hero。
3. **旧组件残留（§8.2 未收口部分）**：`CoverImage`（widgets/cover_image.dart）仍用于 song_tile/queue_panel/player_bar/library/downloads/album/artist/playlist_browse/custom_playlists/player_page 等约 15 处；`myune_seam/cover_loader.dart`（myune 播放页字节供给兼容层，头注释已更正为「没有磁盘缓存」）；`VxCoverFallback`（渐变首字母，设计决策 Phase 0 V1）作为 VxTrackRow 的缺省封面占位。
4. **本轮新缺陷（P1-08）**：search_page.dart:550 的 `VxTrackRow` **未传 `cover:`** → 行内永远渲染 `VxCoverFallback` 渐变首字母（vx_track_row.dart:166 `cover ?? VxCoverFallback(title)`），**即使 song.coverUrl 非空**。实机对照：同一首歌（Love/Cloudy Skies·千千）在搜索列表是渐变占位、在队列面板（queue_panel.dart:208 CoverImage）显示真实封面。song_tile.dart:233 的同类调用传了 `cover: CoverImage(...)`（正确写法）——属单点遗漏，非架构回退。
5. **实机修复证据（P1-03 关闭确认）**：发现页酷我/酷狗热门歌单卡全部渲染真实封面（linux-discover-1440x900-default.png，多源 12+ 张真实图片）；队列面板两行真实封面；首页「最近播放」本地曲「晴天」真实照片封面。第一轮的 4 处三元反写全部消失（grep 无 `? null : CoverImage` 模式）。

## 11. 本地文件导入链路

`local_music_page.dart`（本轮代码复核，未实机导入——本机无媒体文件，Phase 5 项）：
- 入口：顶部「添加目录」+ 空态主 CTA + 次按钮（第一轮结论维持）。
- 流程：`FilePicker.getDirectoryPath`（PlatformException → 手输绝对路径兜底 :400-423）→ ConfigUpdate `localMusicPaths` → `scanLocal(paths, maxDepth)`（app_model.dart:409-422）→ `local_music` 事件带回 warnings → `state.localSongs` 刷新；移除目录有确认（:426-447）；进入页面按 TUI 规则自动补扫。
- **未验证**：Android SAF URI（无设备）；真实文件导入端到端（无媒体文件；Phase 5 计划项）。

## 12. 音源列表 / 能力 / 登录态 / 搜索分页

- 13 音源（kw/kg/tx/wy/mg/bili/soda/qianqian/joox/jamendo/fivesing/apple/local）；能力位经 SourceCapabilitiesDto；发现页按能力位聚合多源分组内容（实机：热门歌单·酷我 / 热门歌单·酷狗 分组，音源选择器「全部」+ 单源 chips）。
- 登录：qr_login 命令/事件/status 全链在（代码复核维持第一轮结论）。
- 搜索页（search_page.dart）：300ms 防抖（:56）；音源多选筛选（单选走后端 source、多选聚合+本地过滤，`_dispatchSource` :131）；分页 in-flight 锁 `_moreInFlight` + requestId 失效释放（:74-77,110-125,160-167）；类型 Tab（全部/歌曲/专辑/歌手/歌单；聚合搜索无歌单数据时如实说明 :524-530）。
- **P1-04 修复验证**：FfiCommand.SearchMore 带 source（ffi/src/lib.rs:1339-1345）；Rust `start_search` append 且 source=None 时先读后写沿用 `state.search.source`（application/src/service.rs:1462-1484，覆盖顺序陷阱注释在位）；`search_pagination_test.dart` 4 项覆盖单选/聚合/in-flight/requestId。**代码+测试层确认，实机未做多页翻页交互观察**（诚实标注）。

## 13. 测试、CI、设备覆盖

- 本地门禁：`scripts/redesign-gate.sh`（§3 本轮数据）；CI（.github/workflows/ci.yml）：lint / build-linux / build-windows / build-macos / build-android / flutter。
- Flutter 测试 37 个文件 229 项：widget/unit 层（shell/mobile/tablet/insets/artwork/error_toast/isolation/pagination/mini_player/downloads/settings/hero/sync/push 等）；golden（design_system_gallery_test）与 viewport_matrix_test 在列；integration/device 层无。
- Rust 测试 816 项通过（§3）。
- 设备：无真机、无模拟器、无 JDK → Android 全链未验证（§14）。

## 14. 可用设备 / 模拟器与未验证项（诚实清单）

| 项 | 状态 | 原因 |
|---|---|---|
| Android 真机/模拟器运行、系统栏/inset/SAF/后台播放/锁屏/耳机 | **未验证** | 无 JDK（java 不存在）、SDK 无 emulator/system-images、adb 无设备；用户已明确搁置 Android 验证（禁止 APK/Gradle 构建与 AVD 创建） |
| 本地音乐真实导入端到端 | **未验证** | 本机无媒体文件；导入 UI/扫描链路仅有代码层与 widget 测试证据（Phase 5 计划项） |
| 搜索分页实机多页交互 | **未验证（代码+测试已验证）** | 本轮实机会话未做触底翻页操作；in-flight 锁与 source 透传由 search_pagination_test 4 项锁定 |
| 歌单隔离 §8.1 八步序列实机 | **未验证（widget 测试已覆盖映射）** | playlist_detail_isolation_test 7 项锁定 AppModel 层语义；实机多歌单切换观察未做 |
| 浅色主题 | **本轮已实机验证（发现 P1 缺陷，见矩阵 P1-09）** | 浅色下 Shell Chrome 对比度破坏，截图 linux-settings-1440x900-light-theme.png |
| MPRIS/托盘/系统媒体集成 | 未实现（Rust 侧 app/src/mpris.rs 存在，GUI 未接） | Phase 6 计划项 |
| 平板三态断点实机 | 未实机验证（无触屏设备） | widget 测试覆盖 |
| niri 全屏/最大化路径窗口行为 | 部分观察 | 上一轮会话 niri IPC 全屏可用（1656x817）；本轮 satellite X-configure resize 后出现 OpenGL frame timeout + 进程静默消失（矩阵 P2-08 观察项） |

## 15. 现有截图与实机页面的差异

- `docs/shots/`、`docs/UI_AUDIT_*` 内截图为**旧 myune 壳**历史证据，不作为当前 UI 基线。
- 第一轮基线 8 张（`*-1656x817-*`，niri 全屏、P0-02 修复前）保留作历史对照。
- **本轮新基线 13 张（Xvfb :2，1440x900，真实数据，播放中状态）**，命名 `<platform>-<page>-<viewport>-<state>.png`：
  - linux-home-1440x900-playing.png（问候 + Continue Listening Hero 播放中 + 最近播放真实封面 + 我的歌单）
  - linux-search-1440x900-results.png（love → 259 结果、8 音源徽标、类型 Tab）
  - linux-search-1440x900-playing.png（搜索页 + PlayerBar 播放中）
  - linux-search-1440x900-playing-00-02-progress.png / …ended-auto-next-00-00.png / …00-26-progress.png（**P0-02 关闭与 Ended 自动切歌走带三连证据**）
  - linux-library-1440x900-songs.png（曲库：快捷卡三张真实计数 + 分类 chips + 来源分段 + 空态）
  - linux-discover-1440x900-default.png（发现：多源真实歌单封面分组——P1-03 关闭证据）
  - linux-downloads-1440x900-empty.png（四分段 + 表头 + 空态）
  - linux-settings-1440x900-default.png（左侧分类导航 9 组——旧 P2-07 关闭证据）
  - linux-settings-1440x900-light-theme.png（**P1-09 浅色 Chrome 对比度破坏证据**）
  - linux-nowplaying-1440x900-playing.png（全屏播放页：渐变占位封面非黑块、01:11/02:34 走带、歌词诚实空态）
  - linux-queue-1440x900-playing.png（队列面板：当前曲高亮 + 256 待播 + 真实封面对照——P1-08 证据）
- 第一轮因 P0-01 阻断缺失的播放页/队列截图本轮已补齐。

## 16. 旧审计条目在本基线的现状（本轮复核，非照抄）

| 旧条目 | 本轮现状 |
|---|---|
| UI_AUDIT P0-01/02/03/05/06/07/09、P1-02/03/04/05/08/11/12 | 已修（第一轮已核，本轮无回归迹象；门禁全绿 + 实机行为正常） |
| P0-A2（duration 恒 0）= 第一轮 P0-02 | **已关闭**：sync bootstrap runtime 修复 + 本轮实机走带三连证据（§9） |
| P1-C3（SearchMore 丢 source）= 第一轮 P1-04 | **已关闭**：FFI + Rust + Dart 三层修复在位（§12） |
| P1-03 封面反写 | **已关闭**：反写模式 grep 为零；发现/首页/队列实机真实封面（§10.5）；**残留单点 → 新 P1-08** |
| P1-D4/P2-V1（桌面系统集成/侧栏展开态） | 仍缺（Phase 6）；侧栏本轮实测 240 固定宽度、无拖宽记忆 |
| U-17 主题预览性能 | 已修（wireframe 预览卡，实机设置页渲染流畅） |
| P2-V9 窄窗降级 | 已修（<960 hidden 侧栏 + 菜单浮出；948 宽实机降级布局正常） |
| P2-07 设置单列长页 | **已修**：左侧分类导航 9 组（实机截图） |
| P3-01 cover_loader 注释 | 已修（头注释更正「没有磁盘缓存」） |
| P3-02 readAudioInfo 悬空桥 | 维持 P3（调用点 try/catch 降级，nm 导出 0 维持第一轮结论） |

## 17. 结论（进入下一阶段前的阻断与重点）

1. **P0：无开放项**（P0-01 本轮未复现、P0-02 已关闭——均见矩阵状态说明）。
2. **新 P1 ×2**：P1-08 搜索结果行封面普遍缺失（VxTrackRow 漏传 cover，单行修复）；P1-09 浅色主题 Shell Chrome 对比度破坏（VxColors 硬编码被 shell 组件无条件消费，P2-01 升级）。
3. Phase 1 遗留：P0-01 根因未定位（本轮 8 分钟实机交互未复现）；Android 全链未验证（环境）。
4. 门禁基线锁定：clippy 30 条 / flutter-test 229 / cargo-test 816 / analyze 0 / 两套格式化 0。
