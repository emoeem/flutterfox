# Flutter GUI 迁移进度存档（断点续跑）

> 本文档是无人值守迁移的唯一状态来源。每完成一个可验证单元立即更新。
> 断点续跑：从「当前状态 / 下一步」一节继续，不要重读全部代码重新推导。

- 依据规划：会话内已审阅批准的《voicefox 跨平台 GUI 迁移规划（Flutter + flutter_rust_bridge）》（Phase 0-4）
- 铁律：改动必须实际验证；TUI 是回归基准（cargo test 全绿）；不静默删功能；iOS/频谱/kitty 封面不做
- **工作区**：/home/emo/code/voicefox-gui（自 /home/emo/code/voicefox @ dd116b1 克隆，原仓库保持不动）

## 当前状态 / 下一步（断点续跑入口）

- **Phase 0 ✅（99f75b9）Phase 1 ✅（9d569b4）Phase 2 ✅（01b589a）
  UI 设计 ✅（docs/flutter_ui_spec.md）Phase 3 ffi ✅（e914da7）Phase 3 UI 首批页面 ✅（acca624，桌面实跑通过）
  UI 改造轮次 ✅（FlClash 视觉对齐 + flex_color_scheme 多主题 + 全页面网格化，桌面实跑通过）
  播放页/全屏歌词 ✅
  浏览数据面 + 歌单详情 ✅（application/ffi Browse 命令/事件 + AppModel 分槽状态 +
  playlist_detail_page.dart + 首页「热门歌单」入口）
  排行榜 / 歌手 / 专辑 ✅
  本地音乐页 + SongDto 稳定 ID ✅（本轮：local_music_page.dart（播放全部/单曲/入队、
  加载/空/错误态、进入自动补扫）、曲库「本地音乐」入口、SongDto
  artistId/albumId 与 SongTile 优先按 ID 跳转；analyze 0 issues / test 32 / build 通过）
  自建歌单 CRUD ✅（曲库第三 tab + 详情页 + SongTile「加入歌单」、新建即加歌）
  账号歌单镜像 + 同步 ✅（歌单页「我的歌单」scope + 同步对话框；sync 模块迁入 application）
  本地 → 远端推送 + 账号红心镜像 ✅（本轮：wy/tx 目标选择/创建、追加 Diff 预览、计划复用、进度/取消/结果；收藏页可切换本地/网易云/QQ 红心缓存）
  帮助与关于 + 播放页快捷键 ✅
- **自建歌单数据面（本轮新增）**：
  · 命令 `CustomPlaylistDetail { id }` → 复用 browse 事件，
    `browseKind=custom_playlist`、`source=local`、`id=歌单 id`；
    缺失歌单发 `BrowseFailed`（前端走错误态 + 重试）。
  · 新建命令成功后追加 `CustomPlaylistCreated { id, name }`（kind=library，
    FFI 复用 `id/message` 字段），前端据此「新建并立即加歌」；
    `LibraryChanged` 仍负责刷新摘要快照。
  · 前端：AppModel 增加 `loadCustomPlaylist / create/rename/delete /
    addToCustomPlaylist / removeFromCustomPlaylist`；库事件后对已打开的自建歌单
    详情做静默重取（不闪加载态）。
  · 页面：`custom_playlists_page.dart`（列表空态/新建/重命名/删除 + 详情页
    播放全部、单曲移除）；`widgets/custom_playlist_dialogs.dart`
    （名称输入 + 加入歌单弹层，含就地新建）。
- **帮助**：`help_page.dart`（播放页快捷键/功能地图/自建歌单操作/版本），
  设置页与手机「更多」均有入口；播放页支持空格播放暂停、←/→ 快退快进 5s、Esc 收起。
- **账号歌单镜像 + 同步（本轮新增）**：
  · **模块迁移**：`app/src/sync.rs`（449 行）与 `app/src/remote_cache.rs`（536 行）
    迁入 `application` crate（`application/src/sync.rs`、`remote_cache.rs`）；
    缓存落盘改用 `lx_core::fsutil::default_data_dir()`；app 侧在 main.rs 保留
    `mod remote_cache/mod sync` 的 `pub use` 别名，TUI 全部 `crate::remote_cache::…`
    路径零改动。同步函数去掉未使用的 `&Storage` 参数（呼叫点同步更新）。
  · **命令**：`AccountPlaylists{source}` / `AccountPlaylistDetail{source,playlist_id}`
    （browseKind `account_playlists` / `account_playlist_detail`，只读镜像缓存，
    红心集合不进列表）；`SyncPreview{source}` / `SyncRun{source}` / `SyncCancel`。
  · **事件**：`SyncPreviewReady` / `SyncProgress` / `SyncCompleted` / `SyncFailed`，
    kind=`sync`，FFI `status` 区分 preview/progress/completed/failed；进度由
    300ms 轮询 `SyncControl` 推送。
  · **前端**：歌单页新增「推荐歌单 / 我的歌单」scope（wy/tx 可用，其他音源禁用
    并说明）；账号 scope 下「同步」打开 `widgets/sync_dialog.dart`
    （预览 → 确认 → 进度 → 结果/失败，取消与重试内收口）；账号歌单详情复用
    `PlaylistDetailPage(account: true)` 读缓存曲目。同步完成后已打开的
    账号列表/详情自动静默刷新。
- **本地 → 远端推送 + 账号红心镜像（本轮新增）**：
  · application 增加 PushTargets / PushCreateTarget / PushPlan / PushRun / PushCancel；
    预览生成的 `SyncPlan` 暂存并在执行时复用。目标与结果通过独立事件传递，
    进度复用 `SyncControl`；平台白名单仍为 wy/tx，推送策略只追加。
  · FFI 增加推送 DTO/命令，并增加 `AccountFavorites` 浏览命令；红心歌曲只从
    `remote_cache::favorites_songs` 读取，不触发远端请求。
  · Flutter 新增 `push_dialog.dart`（平台/目标选择、创建目标、Diff、确认、进度、
    取消、结果），入口位于自建歌单详情和本地收藏页；收藏页可切换网易云/QQ 红心镜像。
  · 验证：FRB codegen；`cargo test -p voicefox-application -p voicefox-ffi`
    （68 passed）；`flutter analyze --fatal-infos`；`flutter test`（52 passed）。
- **Android JS 音源 feature gate（本轮新增）**：
  · `lx-source` 新增默认开启的 `js-sources` feature，`source::js` 按 feature 导出；
    GUI 依赖链（application/runtime/download/lyric）关闭 `lx-source` 默认 feature，
    runtime 显式透传该 feature，FFI 桌面默认开启；FFI `--no-default-features` 不启用，
    TUI 直接依赖仍默认开启。
  · 验证：`cargo check -p voicefox-ffi --no-default-features` 通过；`cargo tree`
    确认该构建未激活 lx-source default/JS feature；TUI 与 lx-source 测试通过；
    Android `arm64-v8a` FFI 交叉构建通过。
- **浏览数据面已落地**：
  · 命令：PlaylistList / PlaylistDetail / LeaderboardBoards / LeaderboardSongs /
    ArtistSongs / ArtistAlbums / AlbumSongs；PlaySongs（复用 ApplicationCommand::Play）
  · 事件：kind=`browse`，按 `browseKind + source + id` 分槽；`page=0` 为失败，
    `page>=1` 为成功；不支持的音源发「空数据 + message」走空态，不报错误。
  · Snapshot：`VoicefoxState.sources`（能力位）、`localSongs`（本地扫描结果）。
  · AppModel：`browse(kind,source,id)` / `loadPlaylists` / `loadPlaylistDetail` /
    `loadLeaderboard*` / `loadArtist*` / `loadAlbumSongs` / `playSongs` /
    `scanLocal(paths,maxDepth)`。
  · 本地扫描：`local_songs()` 只读快照，不会自动扫描；手动触发命令
    `FfiCommand::LocalScan` 已暴露，AppModel 封装为 `scanLocal()`，配置目录经
    ConfigDto 的 `localMusicEnabled/localMusicPaths/localMusicMaxDepth` 读写。
- **下一步精确入口（Phase 4 Android）**：
  Phase 3 UI 剩余项已完成：推送仅对 wy/tx 开放并做登录预检，只追加不删除；
  预览计划在执行时复用，不重复读取远端。收藏页红心从账号镜像缓存只读展示。
  桌面 `platform/` 抽取仍是单独未完成项。
  1. Android 入口清单：
     a. flutter/lib/src/app_model.dart 已预留 attach(controller)——Android 侧需要
        宿主先构造 ApplicationService：Android 端直接跑 cdylib（cargo-ndk 产物）+
        Dart 音频后端（just_audio + audio_service 实现 core 的 PlayerBackend 语义：
        Rust 只解析 URL/歌词，播放由 Dart 侧执行）。
        ⚠ ffi 的 from_application 路径 config_base=None → ConfigUpdate 会报
        "配置存储不可用"，Android 引导时需另想（扩 with_config_base 或 ConfigDto 走
        runtime 直读）。
      b. ✅ `js-sources` feature-gate 已完成：lx-source 默认开启；application / runtime /
        download / lyric 的 GUI 依赖关闭 source 默认功能，runtime 显式透传，桌面 FFI
        默认开启，`--no-default-features` 关闭；TUI 仍默认开启。
        验证：`cargo check -p voicefox-ffi --no-default-features` 通过，依赖树无
        lx-source default/JS feature；`cargo test -p voicefox-app`（333 passed）、
        `cargo test -p lx-source`（218 + 4 passed）；设置 `ANDROID_NDK_HOME` 后
        `cargo ndk -t arm64-v8a build -p voicefox-ffi --no-default-features` 通过；
        Linux Flutter 默认桌面构建通过。
     c. 路径核对：lx_core::fsutil::default_data_dir 在 Android 返回
        dirs::data_dir()=null → fallback "."；需要 Android 上传 app 私有目录
        （PathProvider 传参或 cargo 端 cfg(target_os="android")）。
     d. gradle 集成：cargo-ndk 产 libvoicefox_ffi.so 放
        flutter/android/app/src/main/jniLibs/<abi>/；RustLib.init 自动加载。
        桌面 linux bundle 需手动 cp .so 到 bundle/lib/（已验证可行）。
     e. 模拟器实测：后台播放（audio_service foreground service）、锁屏控制、
        下载通知。
- **已知 flaky**：source::cover_cache::sweep_evicts_down_to_the_limit_by_oldest_access
  在满负载并行时偶发（单独跑稳定），mtime 已修到毫秒档仍可复现，待后续用
  注入时钟的方式根治。
- **待确认决策（延续记录）**：
  · 状态管理 v1 = ChangeNotifier（未引 riverpod/bloc），理由：单控制器事件流
    已够用，避免提前固化架构；引入时机 = 出现跨页共享的派生状态时。
  · dynamic_color 固定 1.7.0：0.13.0 引入第三方 material_ui，其 ColorScheme
    与 Flutter SDK 类型不兼容。
  · ConfigDto 为子集镜像（v1 设置面），完整镜像成本高且 FFI 层膨胀；
    扩设置项 = 扩 ConfigDto 字段 + apply_to 一行。
  · 二维码渲染 v1 未接 qr_flutter（显示内容串兜底），pub.dev 有成熟包
    qr_flutter（周下载量高、近一年维护），接入点 = qr_login_page.dart _QrView。
  · 旧 flutter scaffold（app.dart/shell.dart 459 行占位）被新架构替代，git 历史可查。

## Phase 2 交付明细（新增命令/事件清单）

- 命令：LibraryRefresh / FavoritesAdd·Remove / FavoritePlaylistAdd·Remove / HistoryRemove·HistoryClear / CustomPlaylistCreate·Rename·Delete·AddSongs·RemoveSong / ConfigGet·ConfigUpdate / DownloadEnqueue·DownloadCancel·DownloadClearFinished / QrLoginStart·QrLoginCancel / LocalScan
- 事件：LibraryChanged / DownloadsChanged / ConfigChanged / QrLoginCreated / QrLoginPolled(status 字符串: waiting/scanned/success/expired/failed/network_error/risk_control/server_error/invalid_session) / LocalScanCompleted
- 端口：application/src/ports.rs（LibraryStore/ConfigStore/DownloadsEngine + DownloadTaskInfo DTO）
- 适配器：runtime（Storage→LibraryStore；RuntimeConfigStore；RuntimeDownloads 包装 DownloadManager + 500ms 变更桥）
- 关键决策：无 tokio 上下文时下载端口优雅留空（Handle::try_current）；QR 轮询 2s/次、取消用 AtomicBool；scan 走 spawn_blocking


## 已完成清单（文件级）

- [x] 审阅与规划（会话内，规划文档已批准）
- [x] 环境搭建：Flutter 3.47.9 装于 ~/flutter（tarball 1.58GB 断点续传下载）；~/android-sdk 补装 platforms;android-36 与 cmdline-tools 软链；flutter doctor Android/Linux 均绿
- [x] 新工作区建立：git clone → voicefox-gui @ dd116b1，原仓库保持干净
- [x] 根 Cargo.toml：reqwest → default-features=false + rustls-tls + charset + http2
- [x] ffi/Cargo.toml：voicefox-runtime 依赖加 default-features = false（否则 runtime 默认特性仍拉 mpv）
- [x] runtime/Cargo.toml：lx-player 依赖加 default-features = false（同上）
- [x] player/src/lib.rs：engine 模块加 #[cfg(feature = "desktop-mpv")]
- [x] ffi/src/api.rs：new_desktop 改为始终存在、体内 cfg 分支（FRB 生成代码无条件引用它，不能在签名上 cfg 门控）
- [x] .github/workflows/ci.yml：新增 build-android（cargo-ndk 三 ABI，--no-default-features）与 flutter（analyze --fatal-infos）两个 job，YAML 校验通过
- [x] flutter/：flutter create 四平台 runner（android/linux/macos/windows）+ .gitignore/.metadata/analysis_options/main.dart/widget_test；pubspec 补 flutter_lints ^6、SDK 约束升 >=3.10.0；修 6 处 lint（app.dart/shell.dart 花括号与插值、mini_player_test 未用 import）
- [x] FRB codegen 跑通：ffi/src/frb_generated.rs 与 flutter/lib/src/bridge/api.dart 重生成（feat: new_desktop 包装函数变化）

## UI 改造轮次交付明细（FlClash 视觉对齐 + 多主题 + 网格化）

- **主题系统**：`theme/registry.dart`（16 TUI 同源 + FlClash 定制 #D64BF5/#0D0D0D + 27 套
  flex_color_scheme 8.4 内置扩展，key `flex:*`）；voicefox_theme.dart 经 FlexThemeData 构建 +
  GappedSliderTrackShape（FlClash 断轨滑条）+ 浅色双表面规则（spec §2）；
  ConfigDto 链路加 `dynamic_color`（lx_core ThemeConfig 字段 serde 默认 false → ffi → Dart），
  useDynamicColor 默认改 false，设置页「跟随系统动态取色」开关持久化。
  TUI 对未知 theme 名按自身规则回退（core ThemeConfig 文档），`flex:*` key 安全，TUI 341 测试全绿。
- **壳层**：shell.dart 重写——三档断点 ≤600 底栏 / 600-840 图标轨 / >840 可折叠宽轨
  （AnimatedContainer 80↔200 250ms + FlClash 式整行药丸高亮 + 顶部折叠钮）；
  手机底栏 5 tab（首页/队列/搜索/收藏/更多），MoreSheet 收纳 下载/设置/扫码登录（push 路由）；
  mini player 加封面 + 底缘细进度线。
- **首页仪表盘**（新 pages/home_page.dart）：hero 状态卡（大圆播放钮 + 插值进度）、
  播放模式胶囊、曲库统计、快捷开关、下载进度、最近在听横滑（可点击播放）。
  共享组件：widgets/{cover_image, live_progress, song_card}.dart、config_ext.dart（ConfigDto copyWith 统一重建点）。
- **网格化**：queue 桌面分栏（380px hero 列 + 队列列）、search 桌面双列、library 封面网格
  （spec §2 最小列宽 120/150）、downloads 双列、song_tile 封面 48px。
- **运行坑根治（本轮新发现两个）**：
  1. flutter/linux/CMakeLists.txt 加 install 规则：target/release/libvoicefox_ffi.so
     自动装入 bundle/lib——flutter run 重建不再抹掉（旧「手动 cp」方案作废）。
  2. ffi new_desktop 开头 `libc::setlocale(LC_NUMERIC, "C")`——宿主 locale（zh_CN）
     导致 mpv 初始化失败的根因修复，无需再带 LC_NUMERIC=C 环境变量。
- ⚠️ **依赖红线（新坑记录）**：flex_color_scheme 9.x 与 cached_network_image 4.x 均依赖
  第三方 material_ui 包，其 ThemeData/ColorScheme 与 Flutter SDK 同名类型不兼容
  （即 dynamic_color 0.13 钉版决策记录的同一污染源）。必须钉
  `flex_color_scheme ^8.4.0` + `cached_network_image ^3.4.1`，升级前先查 material_ui 是否退出其依赖树。

### UI 改造轮次验证记录

| 命令 | 状态 |
|---|---|
| `cargo check -p voicefox-ffi` + FRB codegen（ConfigDto.dynamicColor） | ✅ |
| `cargo test -p voicefox-ffi -p lx-core` | ✅ 48 passed |
| `cargo test -p voicefox-app`（TUI 回归，config schema 变更后） | ✅ 341 passed |
| `flutter analyze --fatal-infos` | ✅ 0 issues |
| `flutter test`（注册表/首页冒烟/骨架屏，7 个） | ✅ 全过 |
| 桌面实跑（flutter build linux --debug 直跑 bundle，无环境变量补偿） | ✅ 引导成功（setlocale 修复实证）、宽/窄截图通过 |
| CMake 自动安装 .so | ✅ build 后 bundle/lib 内有 libvoicefox_ffi.so |

### 视觉修复轮次（FlClash 源码级复刻，用户反馈图标/字体/观感差之后）

- **根因**：pubspec 手写时缺 `flutter: uses-material-design: true` → MaterialIcons 字体
  未打包 → 图标码位被 CJK 后备字体渲染成汉字（"收藏→混"、"播放→稟"）。一个开关修好全部图标。
- **字体**（复刻 FlClash lib/ui/font.dart）：不打包中文字体，`theme/typography.dart`
  按平台注入 Han fallback（Linux: Noto Sans CJK SC → Noto Sans SC → Source Han Sans SC →
  WenQuanYi Micro Hei）；打包 JetBrainsMono-Regular.ttf（FlClash 同源，OFL）用于统计数字/时长。
- **配色**（复刻 FlClash lib/ui/color.dart）：`theme/flclash_scheme.dart` 用
  material_color_utilities Hct 做中性分层——页面底(主题bg)之上卡片 tone+8 / 块面 +14、
  chroma 压 3（dark，light 反向），accent tone clamp（dark 50-78 / light 35-60）；
  16 同源主题保留各自 bg 个性（相对层级）。
- **滑块**（复刻 FlClash lib/ui/theme.dart）：trackHeight 14、GappedSliderTrackShape(gap:6)、
  inactive=secondaryContainer、thumb 9px 主色无阴影。
- **侧栏**（复刻 FlClash lib/ui/sidebar.dart）：48↔220px Easing.standard 250ms、item 高 40
  圆角 10、icon 24、选中 = onSurface 8% 填充 + 左缘 3×16 primary 竖条、NoSplash、
  折叠图标居中。
- **其它**：主题色卡双块预览(108px)、播放模式统一胶囊 ChoiceChip、EmptyState 组件
  （downloads/search/library/queue 四处）、页面大标题、等宽数字。
- **红线更新**：FlClash 官方本身用 material_ui + 只打包 JetBrainsMono/Twemoji；我们因
  material_ui 类型污染（前述红线）不迁移其解耦 Material 栈，观感经上述复刻已对齐。
- 验证：analyze 0 issues；flutter test 7/7；bundle 内 MaterialIcons-Regular.otf 确认存在；
  实跑截图图标全部正常（宽/窄两张）。

### 播放页 / 全屏歌词轮次（已完成）

- **新页面** `flutter/lib/src/pages/player_page.dart`：完整传输区（封面/曲名/歌手/专辑、
  进度滑条 + 本地插值、上一首/大圆播放/下一首、播放模式 ChoiceChip）+ 全屏歌词；
  宽屏（≥840）左右分栏（360 传输列 + 歌词），窄屏上下布局。收藏/下载进 AppBar。
  该页是独立路由，用 `ListenableBuilder` 直接订阅 AppModel（根 AnimatedBuilder 不重建子路由）。
- **歌词组件** `flutter/lib/src/widgets/lyrics_view.dart`：
  `lyricIndexAt()` 二分推导当前行（与 Rust `LyricService::update_position` 的归行规则一致），
  `SingleChildScrollView + Column` 全量渲染 + `Scrollable.ensureVisible` 居中滚动，
  点击歌词行 seek 到该行时间戳。
- **关键修复点**：Rust `LyricState.current_line` 只在 `load()` 时算一次，GUI 无逐帧位置
  事件（application 层也从不调用 `update_position`），直接消费快照歌词会永远停在第 0 行。
  因此 GUI 侧用「LivePlayback 插值位置 + config.lyric_offset_ms」在前端推导当前行。
- **转场**：mini player 点击由「切队列 tab」改为 push `PlayerPage`，用
  `PageRouteBuilder` 淡入 + 0.92→1 缩放的容器变换近似（spec §9）。
- **构建链路修复**：`flutter/linux/CMakeLists.txt` 原规则只拷贝已存在的
  `target/release/libvoicefox_ffi.so`，干净工作区里 `flutter build linux --debug`
  产出的 bundle 缺 `.so`（运行即崩）。现改为按 CMAKE_BUILD_TYPE 选 profile，
  并注册 `voicefox_ffi` 自定义 target 自动执行 `cargo build -p voicefox-ffi`
  （Debug→debug，Profile/Release→release），再无条件装入 `bundle/lib`。
- **已知限制**：FFI 的 `LyricsDto.translation` 只有「快照当前行」一条翻译（无逐行翻译表），
  快照 currentLine 陈旧时无法对齐；歌词视图仅当本地推导行 == 快照行时展示翻译，
  其余情况不展示（宁缺勿错）。根治需在 lyric/application/ffi 扩逐行翻译表（下轮可选）。
- **验证**：`flutter analyze --fatal-infos` 0 issues；`flutter test` 14/14 通过
  （新增 `test/player_page_test.dart`：lyricIndexAt 边界/偏移、歌词渲染与点击 seek、
  空歌词空态、播放页空态）；`cargo check --workspace` 与
  `cargo test -p voicefox-ffi -p lx-core`（48 passed）绿；
  `flutter build linux --debug` 成功且 `bundle/lib/libvoicefox_ffi.so` 存在。

### 本地音乐 + SongDto 稳定 ID 轮次（本轮）

- **FFI DTO**：`SongDto` 新增 `artist_id/album_id`（`Option<String>`，空串归一为
  `None`）。`From<SongInfo>` 从 `extra["artist_id"]` 与 `song.album_id` 填充，
  `into_song` 回写，保证 FFI 往返不丢字段。音源侧补齐：wy `ar[0].id`、
  kg `Singers[0].id`、kw `ARTISTID`、JS 通用键
  `artist_id/artistid/artistId/singer_id/singerid/singerId`。
  影响面：Rust DTO + FRB 重生成（`frb_generated.rs` / `lib.dart`）+ Dart 构造点；
  `SongTile` 的「查看歌手 / 查看专辑」优先用 ID，缺失回退展示名。
- **本地音乐页** `flutter/lib/src/pages/local_music_page.dart`：消费
  `state.localSongs`；播放全部（`playSongs`）、单曲播放（SongTile onTap）、入队
  （更多菜单）；加载态（扫描中）、空态（未配置目录引导添加 / 已配置但无结果引导
  重扫）、错误态（`scanWarnings` 展示并重试）。入口：曲库页标题行「本地音乐」。
  进入时按 TUI `should_scan_local_music_on_entry` 规则自动补扫一次（启用 + 有目录 +
  曲库为空 + 未扫描）。
- **扫描命令**：确认 `local_songs()` 只读快照、不会触发扫描；FFI 已有
  `FfiCommand::localScan`，本轮在 AppModel 暴露 `scanLocal()`，并让 ConfigDto 镜像
  `localMusicEnabled/localMusicPaths/localMusicMaxDepth`，页面可直接添加目录并扫描。
- **验证**：`cargo check --workspace` 绿；`flutter analyze --fatal-infos` 0 issues；
  `flutter test` 32/32（新增 local_music_page_test 4 项、song_tile_test 4 项）；
  `flutter build linux --debug` 成功。

### 自建歌单 + 帮助 + 账号歌单同步轮次（本轮）

- **Rust/FFI**：`CustomPlaylistDetail` 命令 + `BrowseKind::CustomPlaylist`；
  `CustomPlaylistCreated` 事件（带 id）；`AccountPlaylists /
  AccountPlaylistDetail / SyncPreview / SyncRun / SyncCancel` 命令；
  `SyncPreviewReady / SyncProgress / SyncCompleted / SyncFailed` 事件；
  sync/remote_cache 从 app 迁入 application（TUI 别名 re-export）。
  application 测试补齐 `custom_playlist_create_and_detail_round_trip`、
  `custom_playlist_detail_missing_emits_browse_failed`、
  `account_playlists_mapping_drops_favorites_and_keeps_counts`，
  MockLibrary 支持内存歌单。
- **前端**：见上方「自建歌单数据面」「帮助」「账号歌单镜像 + 同步」。
- **验证**：

| 命令 | 状态 |
|---|---|
| `cargo test -p voicefox-application`（+9：新增 3 项 + 迁入 remote_cache 6 项，共 66） | ✅ |
| `cargo test -p voicefox-ffi` | ✅ 2 passed |
| `cargo test -p voicefox-app`（TUI 回归；8 个 remote_cache 测试迁出后 333） | ✅ 333 passed / 1 ignored |
| `flutter analyze --fatal-infos` | ✅ 0 issues |
| `flutter test`（自建歌单 7 + 同步对话框 6 + 账号歌单 3，共 50） | ✅ 全过 |
| `flutter build linux --debug` + bundle/lib/libvoicefox_ffi.so | ✅ |
| 桌面实跑 10s（无 Rust 报错，dynamic_color 检测成功） | ✅ |

## 遇到的坑与已做决策

| 时间 | 坑/决策 | 说明 |
|---|---|---|
| D0 | 用户要求新项目文件夹 | 全部迁移工作在 /home/emo/code/voicefox-gui 进行，原 /home/emo/code/voicefox 不再修改（已还原本会话对其的改动） |
| D0 | 环境缺 flutter | 解法：下载官方 stable 3.47.9 tarball（第一次下载 586MB 后连接重置 exit 56，断点续传重试中），解压到 ~/flutter，不改系统 |
| D0 | reqwest 切 rustls 不能只加 feature | 必须同时 `default-features = false`，否则 native-tls 仍被拉入（Android 拖 OpenSSL）；需手动补 `charset`（GBK 解码，国内音源需要）与 `http2` |
| D0 | 原仓库 Cargo.lock 有非本会话的本地改动 | git status 显示 M Cargo.lock（chacha20/cpufeatures 重排，疑似用户本地另跑过 cargo），**未动它**，仅记录 |
| D0 | 状态管理待定 | shell.dart 现状极简（无状态管理库），Phase 3 引入时 riverpod/bloc 二选一，理由写入待确认决策 |
| D9 | FRB codegen 卡死 11 分钟 | codegen 内部执行 `flutter --version`，PATH 命中的是 `/usr/sbin/flutter`（AUR unionfs wrapper，会卡在挂载）。解法：`PATH=$HOME/flutter/bin:$PATH flutter_rust_bridge_codegen generate`，几十秒完成 |

## 验证状态

| 命令 | 状态 | 时间 |
|---|---|---|
| `cargo check --workspace`（reqwest 切换后） | ✅ 绿 | D0 |
| `cargo test --release`（Phase 0 基线） | ✅ 792 passed / 0 failed（日志 /tmp/baseline_test.log） | D0 |
| `cargo check -p voicefox-ffi --no-default-features` | ✅ 绿（无 mpv ABI） | D0 |
| `cargo tree -p voicefox-ffi --no-default-features -i libmpv2` | ✅ libmpv2 不在依赖树 | D0 |
| `cargo ndk -t arm64-v8a build -p voicefox-ffi --no-default-features` | ✅ 产出 /tmp/voicefox-ndk-test/arm64-v8a/libvoicefox_ffi.so (10.5MB) | D0 |
| `flutter analyze` | 未跑（flutter 下载中） | - |
| `flutter_rust_bridge_codegen generate` | 未跑 | - |

## Phase 完成度对照

- [x] Phase 0 基础设施
- [x] Phase 1 抽取（download crate / 歌单迁移 / 配置统一）
- [x] Phase 2 边界扩宽
- [x] Phase 3 ffi + Flutter UI（页面与同步推送已齐；桌面 platform/ 抽取另列）
- [ ] Phase 4 Android 落地

（各 Phase 内部细项见下方分节，完成一项勾一项）

## Phase 0 细项

- [x] reqwest → rustls-tls（根 Cargo.toml）
- [ ] cargo check/test 回归通过
- [ ] flutter create 平台 runner（android/windows/linux/macos）
- [ ] FRB codegen 跑通（ffi/src/frb_generated.rs 重生成）
- [ ] CI 加 Android target（cargo-ndk: aarch64/armv7/x86_64-linux-android）+ Flutter analyze/build job

## Phase 1 细项

- [ ] 新 crate `download/`（voicefox-download）：迁移 app/src/download/*（manager/engine/records/tags/naming/webdav）
- [ ] 歌单管理 app/src/playlist/{manager,shuffle,mode}.rs → application 或 runtime
- [ ] 配置统一：app/src/config/loader.rs 并入 runtime/src/lib.rs load_config
- [ ] app（TUI）改消费新库；cargo test 全绿 + TUI 手动无回归

## Phase 2 细项

- [ ] application/src/event.rs：ApplicationCommand/ApplicationEvent 扩 favorites/history/downloads/settings/QR 登录/跨源同步/local/封面

## Phase 3 细项

- [x] ffi/src/api.rs DTO/FfiCommand/事件流扩宽
- [x] Flutter 页面对齐 app/src/pages/ 全部（help/local/custom/账号镜像/推送与红心展示已完成）
- [x] 16 主题色板 → M3 ColorScheme（seed 共用，不分叉）
- [ ] 桌面 platform/ crate（MPRIS/SMTC/通知从 app 抽出接回）
- [x] docs/flutter_ui_spec.md（FlClash 调研 + 具体设计值）

## Phase 4 细项

- [ ] just_audio + audio_service（Android 音频后台）
- [ ] js-sources feature-gate（source/src/js/engine.rs node 子进程）
- [ ] 路径核对（dirs 在 Android 的落位）
- [ ] cargo-ndk + gradle 集成
- [ ] 模拟器实测：后台播放/锁屏控制/下载通知

## 2026-11-04 轮次（断点协议）

- [DONE] 2026-11-04 01:10 · Phase 4 单元①「数据目录宿主覆盖」：`lx_core::fsutil` 新增 `set_data_dir_override/data_dir_override`（进程级，有覆盖时跳过旧目录迁移），`ffi::api::set_data_dir(path)` 导出（FRB 已重新 generate），解决 Android `dirs::data_dir()=None` 回退 "." 的路径落位问题 · 验证：`cargo test -p lx-core` 47 全绿（新增 1 例覆盖优先级/清除/不触发迁移）；`cargo test` 全仓 21 组 ok 0 failed；`flutter analyze` 0 issues；`flutter test` 52 全绿
- [DONE] 2026-11-04 01:15 · UI 规范核查（对照 flutter_ui_spec.md 5 项）：硬编码 Colors.white/black=0、elevation>0=0、BoxShadow=0、断点 840 页面宽窄 8 处 + shell ≤600/600–840 文档化实现、999 药丸圆角 5 处 → **无偏离项**，本轮无纯视觉修复可做；桌面实跑截图 `docs/shots/20261104-home.png`（1920×1080，release 构建 Impeller 启动正常）
- [NEXT] Phase 4 剩余：just_audio+audio_service 后台播放、cargo-ndk+gradle 集成（setDataDir 接入 Android 引导）、锁屏控制实测
- [BLOCKED] `cargo fmt --check` 整体未绿：application/src/service.rs:57/655/672 与 ffi/src/lib.rs:1411 为工作树既有 WIP 格式漂移（未动，保留用户 WIP）；本组件本轮改动文件已全部 rustfmt（edition 2024）

## 本轮 UI 核查表

| 页面/全局 | 检查项 | 结果 |
|---|---|---|
| 全页面 | 硬编码 Colors.white/black/#FFF | 0 处 |
| 全页面 | elevation>0 / BoxShadow | 0 处 |
| shell.dart | 断点 ≤600 / 600–840 / >840 | 符合（文档化 + 实现一致） |
| downloads/search/home/queue/artist/album/local/custom_playlists | 840 宽窄切换 | 8 处，全部使用约束条件判断，无魔法布局数 |
| 全局 | 药丸 999px 圆角 | 5 处（分段/底栏/徽标） |

## 2026-11-04 · UI 换基底：myune_music vendor（决策后第一单元）

- [DONE] 2026-11-04 01:55 · 基底选定 myune_music（Apache-2.0，github.com/xiaobaimc/myune_music @ 5188867b，gh-proxy 镜像克隆至 /home/emo/code/myune_music-reference 只读参考）；全量 vendor 其 lib/（111 个 dart 文件，逐文件加来源/commit/许可头）至 `flutter/lib/src/myune/`；新建 `mpv_audio_kit_shim.dart`（自研，复刻 vendored UI 用到的 mpv_audio_kit 类型面：Player/PlayerStream/PlayerState/Media/Device/Gapless/AudioEffects 全族 28 个 update*/Spectrum/ReplayGain/LoudnessScan/PcmFrame/FftFrame/MediaSession 等），14 处 mpv import 改指 shim；voicefox pubspec 新增 myune 所需 22 个 pub 依赖（pub.flutter-io.cn 镜像安装）；vendored 树加入 analysis_options exclude（冻结上游风格） · 验证：`flutter analyze` 0 issues、`flutter test` 52 全绿、`cargo test -p voicefox-ffi -p voicefox-application` 4 组 ok；Rust/FFI 零改动
- [NEXT] AppModelAudioBackend：用 voicefox AppModel 实现 shim 的 AudioBackend（open→playSong/queue、seek/volume/pause 映射、position/duration/playing 流），`main.dart` 注入 activeAudioBackend；然后 shell 开关切播放页/歌词页（旧页移 lib/legacy/）
- [BLOCKED] 无

- [DONE] 2026-11-04 02:15 · 第二单元「播放接缝」：`myune_seam/app_model_audio_backend.dart` 实现 AudioBackend（open/openAll/队列/seek/暂停恢复 映射 AppModel.playSong/playSongs/queueAdd/toggle/seekMs，position/duration/playing 流跟随 AppModel 监听）；接缝整体移出 vendored 目录（`lib/src/myune_seam/`）纳入 analyze；main.dart 启动时 `attachVoicefoxAudioBackend(model)`；ui_spec 升 v2（基底声明） · 验证：`flutter analyze` 0 issues、`flutter test` 52 全绿、`cargo test -p voicefox-ffi -p voicefox-application` 4 组 ok
- [NEXT] 壳切换：shell.dart 加 `useMyuneShell` 开关，myune app_shell/main_view 接 AppModel 状态后切播放页/歌词页（旧页移 lib/legacy/）；myune 侧 provider 图（settings/playlist notifier）需要补 voicefox 侧数据源；setVolume 空档需 Rust 新增 FfiCommand::SetVolume
- [BLOCKED] 无
- [DONE] 2026-11-04 09:20 · 第三单元「壳切换（播放页）」：`shell.dart` 的 `_playerRoute` 加 `useMyunePlayer` 开关（true 走 vendored myune 播放页，false 回退自研 PlayerPage，旧页未删）；新增 `lib/src/myune_shell/myune_player_page.dart`（Provider 图 SettingsProvider/ThemeProvider/NotificationService/PlaylistContentNotifier + AppModel 状态投影）；vendored notifier 加入**唯一一处显式 seam** `adoptExternalState`（只读投影，标记 voicefox seam: begin/end）；`hotkey_manager`、`system_fonts` 用本地纯 Dart stub（packages/，dependency_overrides，避免 keybinder-3.0 系统库），移除未使用的 tray_manager/windows_taskbar/flutter_single_instance；标题栏 "MyuneMusic"→"voicefox" · 验证：`flutter analyze` 0 issues、`flutter test` 53 全绿、`flutter build linux` 成功、`flutter run -t lib/myune_preview.dart` 实跑截图 `docs/shots/20261104-myune-player.png`（无歌词态 + 进度条 + 播放控制在 voicefox FlClash 主题下正常渲染）
- [NEXT] 播放队列映射：AppModel.state.queue → myune 歌单（当前只投影 now-playing，`playSongAtIndex` 仍走 myune 空歌单）；歌词数据源接 voicefox LyricsDto；音量 `FfiCommand::SetVolume` 需 Rust 侧新增；随后切歌单页/本地库页
- [BLOCKED] 无

## 2026-11-05 · P0 修复收口 + myune 基底架构收敛 + 播放器式视觉迭代

- [DONE] M1/M2 复核：播放事件泵/自动切歌/SetVolume 已在 WIP 实现并验证（runtime/lib.rs pump 调用、Ended→模式感知推进、Toggle/SetVolume 即时回读广播）；ConfigDto roundtrip 测试已有。本轮新增：`runtime/config_loader.rs` 加载保护——>4MB 直接隔离、解析失败改名 `.corrupt-<ns>` 留档回默认、非法 play_mode 重置（134MB 损坏自愈），3 个新测试 · `cargo test -p voicefox-runtime` 38 全绿
- [DONE] 主题管线统一：Rust `ThemeConfig.mode`（system/light/dark，serde default）+ ConfigDto `theme_mode` 镜像（codegen 已重跑，roundtrip 测试）；Flutter 侧 ThemeProvider 成为唯一 ThemeData 产源（MaterialApp theme/darkTheme/themeMode 全接），`MyuneProjection` 桥接 seed（16 套 TUI 同源 accent）+ 明暗三态 + Material You 动态色；旧 flex/FlClash 管线仅存设置页预览卡 · 实机验证明暗三态生效
- [DONE] 架构收敛：`MyuneHost` app 级 Provider 图（Rust 引导完成后挂载，消灭每页临时建图）；`myune_shell/projection.dart` 常驻投影（state/lyrics/queue + lastError/lastNotification → myune toast 统一错误出口）；`myune_shell/app_shell.dart` 新壳（九入口 rail + voicefox 队列抽屉 + 自绘标题栏 window_manager TitleBarStyle.hidden）；删除旧 shell.dart（485 行）与 barrel 引用 · `flutter analyze` 0 issues
- [DONE] P1 补齐：qr_flutter 真渲染二维码；file_picker 选本地目录（手输兜底）；搜索音源筛选 chips（FfiCommand::Search 加 source 参数，codegen）；队列抽屉 VoicefoxQueueDrawer（当前高亮/滑动移除/清空确认）；曲库收藏歌单 tab；下载重试（DownloadTask 全链携带 song：manager→ports→DTO→codegen）；历史/队列清空确认；设置页 7 组（播放器/音源/下载/歌词/主题/网络/账号集成）；playlist_browse 三处 build 副作用改监听器+帧后调度（含 leaderboard/home 同模式） · `flutter test` 52 全绿
- [DONE] 视觉迭代（用户实机反馈，基准 Spotify/QQ 音乐）：首页重设计——问候/正在播放 hero + 最近在听/热门歌单/排行榜横向书架 + 快捷入口（nav_bus 总线切 shell 导航），删除统计卡/快捷开关/下载卡/模式卡；Playbar 重写 `myune_shell/voicefox_playbar.dart`（单行三区：曲目/传输+插值进度/模式+悬停音量+队列，LivePlayback 逐帧插值取代 vendored 200ms 节流）；设置页明暗段固定 360 宽、主题卡改迷你 wireframe 预览、分区卡 surfaceContainer 分离；歌单卡隐藏误导性「0 首」 · `flutter test` 53 全绿
- [DONE] 动画流畅度：定位到 Linux Impeller(OpenGLES) 反复 "Timed out waiting for OpenGL frame"（走带掉帧元凶）；进程内 setenv 无效（引擎静态初始化期读 env，早于 main），CMake wrapper 方案弃用，最终用 embedder 官方 API `fl_dart_project_set_enable_impeller(project, FALSE)`（my_application.cc）——重建后日志无 Impeller 行；页面切换转场 fade→fade+scale(0.985)
- [DONE] 文档：flutter_ui_spec.md 重写为 v3（myune 视觉基准 + token 表 + 单一 ThemeData 产源 + 队列抽屉导航），v2 FlClash 基准归档
- [NEXT] ①「最近在听」封面缺失：history 落库时多数歌曲无 cover_url（Rust 侧 record_history 前 resolve_cover_url 或回填 cover cache）——UI 侧无法修；② spec v3 要求的 silky_scroll 全站接入未做（仅 myune 内部用）；③ Phase 4 Android（from_application 注入 + just_audio/audio_service + gradle）仍是下一大阶段；④ P1-13 桌面集成（MPRIS/SMTC/托盘）维持后置 platform/ crate
- [BLOCKED] 无
