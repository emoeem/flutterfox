# 参考项目重点研究结果（01-reference-projects，2026-11-10）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §2.1/§2.2；复用判定优先级遵循 §2.3。
- 输入：6 份研究记录（finamp / nuclear / feishin / harmonoid / myune / aethertune）+ 基线审计 `docs/redesign/00-baseline.md`。
- 汇总人在产出本报告时做了二次核验（2026-11-10）：6 个参考仓库克隆均仍在 `/tmp/voicefox-ref/`，
  `git rev-parse HEAD` 实测与记录 SHA **逐一一致**（finamp `337a2fd8…`、nuclear `46d1d938…`、feishin `e60dcc80…`、
  harmonoid `927ff721…`、myune 检出在 vendored pin `5188867b…`、aethertune `ccde7234…`）；
  并以 `head LICENSE` 复核 6 仓库根许可证与 Voicefox 根 `LICENSE`（MIT，Copyright (c) 2026 emoeem）。
- 许可证与合规细节集中在 `02-license-and-reuse-audit.md`；组件级落点在 `03-component-reuse-map.md`。

## 0. 研究方式与诚实声明（§2.2 偏差登记）

**§2.2 要求「页面截图或运行证据」——6 份研究记录均未产出，本报告如实登记为未满足，不得当作已运行：**

- 全部结论来自**静态源码级核验**：克隆仓库 → `git rev-parse HEAD` 固定 SHA → LICENSE 全文或首部实读 →
  依赖许可证逐一实查（pub.dev API score tag / raw.githubusercontent / pub-cache 归档解包）→ 组件逐文件阅读。
- 未运行参考项目的原因：研究环境无对应构建/运行链（finamp、aethertune、myune 需 Flutter 工程；
  nuclear、feishin 需 node/pnpm；且各记录均记载本环境 `which flutter/npm/node` 缺失或构建未执行；
  harmonoid 公开树缺 9/10 子模块，本就不可构建）。
- 因此「组件真实存在」由源码阅读与行号引用背书（引用行号以各记录 pinned SHA 为准），而非运行截图。

## 1. finamp（Jellyfin 客户端，Flutter）

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/finamp-app/finamp |
| 默认分支 | `redesign`（origin/HEAD → origin/redesign，非 master/main；`git symbolic-ref refs/remotes/origin/HEAD` 实测） |
| 研究日期 | 2026-11-08（clone/commit）；依赖核验 2026-11-10 |
| commit SHA | `337a2fd8887af8744b831a739daf0d8ae57ecfa8`（2026-11-08，Merge PR #1866；本次汇总复测一致） |
| 版本 | 1.0.3+203，351 个 dart 文件 |
| 根许可证 | **MPL-2.0**（记录全读 LICENSE 374 行；汇总人 `head` 复核首行 "Mozilla Public License Version 2.0"） |

**依赖许可证边界**（记录 2026-11-10 用 `curl https://pub.dev/api/packages/<name>/score` license tag 逐一实查 24 个直依赖）：
Apache-2.0 = just_audio、rxdart、hive_ce、isar；BSD-3 = background_downloader、palette_generator(fork)；
MIT = audio_service、provider、flutter_riverpod、get_it、octo_image、flutter_cache_manager、chopper、audio_session、
flutter_rust_bridge、media_kit_libs_linux、smtc_windows、window_manager、scroll_to_index、marquee、
infinite_scroll_pagination、flutter_sticky_header 等。全部与 MIT 主项目兼容。
**风险**：pubspec.lock 实数 **14 个 git-fork 依赖**（just_audio/audio_service/smtc_windows/isar 三件套/palette_generator/
balanced_text/flutter_carplay/split_view 等 pin 到 fork ref），fork 端 LICENSE 未逐一打开核验。

**UI 框架 / 状态管理 / 导航**：纯 Dart/Flutter（无 Rust 播放后端）。导航无 go_router——`MaterialApp.routes`
命名路由表（`lib/main.dart:995-1039`，initialRoute=SplashScreen），builder=`buildPlayerSplitScreenScaffold`（main.dart:1041）。
状态管理**三套混用**：get_it 单例服务（QueueService/MusicPlayerBackgroundTask/DownloadsService/JellyfinApiHelper，
main.dart:237-491）+ Riverpod（ProviderContainer 注册进 get_it，main.dart:356-361；新代码 riverpod_annotation 生成）
+ 旧 provider 包与 rxdart BehaviorSubject——历史包袱明显。存储 Hive（设置/队列/离线收听）+ Isar（下载树/歌词/任务）。
音频 audio_service(fork)+just_audio(fork)+just_audio_media_kit；Android Auto/CarPlay/MPRIS/SMTC/Discord RPC 全家桶。

**与 Voicefox 多音源架构的差异**：与 Jellyfin API 深耦合（chopper 生成 REST 客户端，队列项直接携带 Jellyfin
BaseItemDto；播放 URL 拼 `/Items/{id}/File` 或 `/Audio/{id}/main.m3u8` + **ApiKey query 参数**鉴权而非请求头，
`music_player_background_task.dart:1397-1450`，注释明言 just_audio HLS header 历史问题）。Voicefox 是 Rust FFI
后端 + 自定义请求头流媒体 + 多音源——服务层照搬等于重写；其 ApiKey 踩坑记录值得写进 myune_seam 设计备注。

**重点研究结果（值得吸收的 UI 件，行号以 pinned SHA 为准）**：
- **歌词屏** `lib/screens/lyrics_screen.dart`：行级同步高亮 + AutoScrollController 自动滚动（:173-239）、
  手动滚动即暂停 + 一键恢复 FAB（:179-186, 748-767）、逐字 cue 卡拉OK染色含 0.5s 淡入算法（:578-646）、
  点击行 seek（:373-393）、ShaderMask 上下渐隐（:720-746）。`LyricLine{text,start,cues{position,start,endPosition,end}}`
  模型与 Voicefox 逐字 KRC/QRC/YRC 概念同构——换数据源即可用；但注意其歌词是 **Jellyfin 服务端解析**
  （GET /Audio/{itemId}/Lyrics），**finamp 无 LRC/KRC/QRC 解码代码**（grep qrc/krc 仅命中模型注释）。
- **PlayerHideableController 空间预算算法**（`lib/screens/player_screen.dart:465-668`）：按优先级隐藏
  bigPlayButton→bottomActions→features→twoLineTitle→progressSlider 的自适应布局，横竖屏/桌面通吃。
- **player_screen 手势体系**（:163-187）：下滑关、上滑队列、左滑歌词。
- **now_playing_bar.dart**（555 行）常驻迷你条：buffered 进度、marquee、模糊背景联动。
- **progress_slider.dart**：bufferedPosition + StreamBuilder<ProgressState> 模式（:56, :226-249）。
- **封面三层缓存思路**（`lib/services/album_image_provider.dart`）：下载文件→内存 key 缓存→cache_manager→网络；
  BlurHash 去重（:106-111）、scale 0.25 支持 4x 放大省内存（:158,168-173）、StubImageCache 阻断 audio_service
  自带缓存（:252-321）——对照 myune_seam/cover_loader.dart 的 32 张 LRU 可吸收 blurhash 占位与 scale 技巧。
- 仅参考状态机：`queue_service.dart`（1770 行）四段队列 previous/current/nextUp/regular（:66-69）+ 镜像 just_audio
  原生队列 + NextUpShuffleOrder + Hive 持久化（60 份，:97-101）+ 10s 周期保存；`queue_list.dart`（1324 行）三段
  SliverReorderableList + sticky header + offset 重排（:428-621）；`downloads_service.dart`（1794 行）Isar 树 +
  background_downloader 9.5.9 + 节流同步 + 离线收听落盘；`metadata_provider.dart`「下一曲预取 next:3, previous:1」
  （current_track_metadata_provider.dart:11-22）。

**复用判定**：总体**仅参考交互** + 个别 UI 文件**小幅改造**移植；无直接移植项；服务层不采用。
理由：① Jellyfin 深耦合；② 14 个 git-fork 依赖引入即背维护债，禁止照搬 pubspec；③ MPL-2.0 逐文件合规路径存在
（保留 MPL 头、文件级开源）但成本大于仅借鉴。
**移植后许可证履行方式**（细则见 02 报告 §finamp）：每个拷贝文件保留 MPL-2.0 头 + 来源仓库/SHA/修改声明；
被拷贝文件及其修改保持 MPL-2.0 开源（§3.1），Voicefox 整体 MIT 不受传染（§3.3 Larger Work）；不得移除版权/许可声明（§3.4）。
**默认分支是 redesign（UI 重写中）**，接口/布局还在动——引用必须 pin 到本次 SHA。

## 2. nuclear（Tauri 2 重写版）

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/nukeop/nuclear |
| 默认分支 | `master`（`git symbolic-ref refs/remotes/origin/HEAD` 确认） |
| 研究日期 | 2026-11-06 |
| commit SHA | `46d1d938dba8fa56e30c41cdb4e53c07b48e4fed`（"player@1.54.2"；汇总复测一致） |
| 根许可证 | **AGPL-3.0-only**（根 LICENSE 全文 AGPL v3；package.json:49 `"license": "AGPL-3.0-only"`；player/src-tauri/Cargo.toml 同） |

**重大事实纠偏**：ask 备注「Electron/React 桌面播放器」**已过时**——当前 master 是 Tauri 2（Rust+React）
pnpm/Turborepo monorepo 重写；Electron 版仅存于 `origin/legacy/electron` 分支（抽查分支头 package.json：
electron ^33.3.1、AGPL-3.0）。

**UI 框架 / 状态管理 / 导航**：React 18 + TanStack Router（文件路由，packages/player/src/App.tsx:14-44）+
TanStack Query + zustand/immer（17 个 store，packages/player/src/stores/）+ tailwindcss4 + motion + dnd-kit +
esbuild-wasm 插件运行时（多音源/元数据/歌词均为 JS 插件 provider，plugin-sdk/src/types/providers.ts:1-32 按
kind=metadata/streaming/lyrics/… 注册）。Rust 后端不做音频流：fs/历史(sqlite+sqlx)/MPD/HTTP API/MCP server/
discord-rpc/yt-dlp 下载管理；音频播放是 webview 内 HTML5 `<audio>` + HLS/MSE hooks（packages/hifi/src/Sound.tsx:57-69）。

**与 Voicefox 架构的差异**：播放走 webview HTML5 audio（无自定义请求头），与 Voicefox Rust/mpv 自定义请求头
流媒体根本不同；音频管线实现不可借鉴。歌词 provider 全在 JS 插件层，nuclear 无 KRC/QRC/YRC 加密格式处理经验。

**重点研究结果（交互参考，全部须重写为 Flutter 自有代码）**：
- **音源呈现（最高参考价值）** `packages/ui/src/components/QueueItemPopover/QueueItemPopover.tsx:29-73`：
  队列项右键弹出 TrackHeader + StreamThumbnail 候选缩略图 + StreamQualityInfo（qualityLabel·kbps·codec，
  StreamQualityInfo.tsx:13-22）+ CandidateList（失败标记/选中态/点选切换，CandidateList.tsx:21-37）；
  配套 StreamVerification 五态指示器（loading/unverified/weaklyVerified/verified/verifiedByUser，
  model/src/streaming.ts:38-39）显示在右栏 footer（routes/__root.tsx:141）。
- **多候选数据模型** `model/src/streaming.ts:3-45`：StreamCandidate{id,title,durationMs,thumbnail,stream?,failed,source}
  + Stream{protocol,mimeType,bitrateKbps,codec,qualityLabel,contentLengthBytes}；queueStore.ts:304-356 的
  updateCandidate/removeCandidate/selectCandidate（选中候选提到队首并重置 failed 以重试）——nuclear 多源架构
  最成熟的部分，与 Voicefox 单一音源选择的差异点。
- **歌词数据模型** `packages/model/src/lyrics.ts:52-84`：plain/lineSynced/wordSynced/instrumental 四型；行含
  segments（ruby 注音）、background（和声）、vocalistIds（按演唱者着色）、annotations（translation/romanization）、
  sections（段落 label）——可作 Voicefox 歌词 IR 设计检查清单（Voicefox 有逐字但未见 annotations/ruby/vocalist 建模）。
- **同步歌词交互** `packages/ui/src/components/Lyrics/SyncedLyrics/useSyncedLyrics.ts:9,25-52`：findLastIndex 找当前行、
  ANCHOR_RATIO=0.3 活动行锚定视口 30%、autoScroll 开关、滚动偏离后 CurrentLinePill 回当前行（SyncedLyrics.tsx:57-63）、
  点击行 seek（ConnectedSyncedLyrics.tsx:37 传 offsetMs 校正）；逐字卡拉OK SyncedLyricsLine/WordSyncedText.tsx:23-41。
- **封面渐显** `packages/ui/src/components/ImageReveal/ImageReveal.tsx:21-121`：blur 8px→0 + scale 0.98→1 +
  0.6s ease[0.22,1,0.36,1]、lazy loading、onError 占位、useReducedMotion 尊重系统动画偏好；多尺寸选择打分
  model/src/artwork.ts:3-63（purpose+宽高比差×50+尺寸差×0.1，upscale>1.5 罚 -1000）；Mosaic.tsx:6-26 无艺人封面 2x2 四宫格。
- **队列 store 算法** `packages/player/src/stores/queueStore.ts:127-411`：QueueItem{id:uuid,track,status,addedAtIso}；
  Tauri LazyStore 落盘 queue.json；重载时 status 重置 idle（:141-145）；removeByIds/reorder 的 **currentIndex 补偿**
  （:184-268）；shuffle/repeat 在 getDirectionalIndex（:57-99）。UI 层 QueuePanel.tsx:38-154 虚拟滚动 + dnd-kit 拖拽重排。
- **声明式快捷键命令表** `packages/player/src/shortcuts/commands.ts:7-53`：COMMANDS{id,defaultShortcut,section}——
  对照 Voicefox 已有 myune/hot_keys.dart + global_hotkey_manager.dart，可参考「命令注册表 + 设置页展示」组织方式。
- **解析回退链** `services/streamResolution/streamResolution.ts:24-103`：逐候选尝试（失败 removeCandidate 后递归下一个
  :92-98）；supersedeActiveResolution（:134-146）切歌时 abort 旧解析并复位旧条目——竞态防护思想适用于 Voicefox FFI 播放层。

**复用判定**：**不采用（代码移植）+ 仅参考交互**。理由：① AGPL-3.0-only 传染性，禁止任何源码级移植（含「改写式
移植」）；② 技术栈完全不同。
**移植后许可证履行方式**：不存在「移植后」场景——**禁止复制任何 nuclear 源码文本/代码结构到 Voicefox**；
交互与信息架构思想以「重写为 Flutter 自有代码」方式吸收，实现不携带 nuclear 源码，不留代码级相似性。

## 3. feishin（JetAudio 系桌面客户端，Electron）

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/jeffvli/feishin |
| 默认分支 | `development`（`git remote show origin` 输出 'HEAD branch: development'；汇总复测 origin/HEAD 一致） |
| 研究日期 | 记录未标注研究执行日；HEAD commit 2026-11-09（本次 `git show -s` 实测，"fix(ui): show title combined in playlist list (#2689)"）；依赖许可经 raw.githubusercontent 在线核验 |
| commit SHA | `e60dcc80e223703d285639736ee0bd9e3c9e9d43`（汇总复测一致） |
| 根许可证 | **GPL-3.0**（记录逐行读完 LICENSE 675 行 FSF 标准原文；package.json:23 同；汇总复核首行一致） |

**依赖许可证边界**（记录以 raw.githubusercontent 实读）：zustand/@tanstack/react-query/@mantine/core/react-window/
motion/music-metadata/@radix-ui react-context-menu/fast-average-color 均 MIT，wavesurfer.js BSD-3-Clause——均宽松；
但 feishin 自有源码（src/**）整体按 GPL 处理。node-mpv 依赖是 jeffvli 私有 fork（package.json），**许可证未核验**。

**UI 框架 / 状态管理 / 导航**：Electron 43 + React 19 + TypeScript（vite/electron-vite，pnpm）；zustand v5
（player.store.ts:1-10，createWithEqualityFn + persist + immer + devtools + subscribeWithSelector）+
@tanstack/react-query v5 + 事件总线；react-router v7 HashRouter 嵌套 Outlet 链（app-router.tsx:222-360）。
桌面三栏：default-layout WindowBar+MainContent+PlayerBar；main-content.tsx:196-223 LeftSidebar+Outlet+RightSidebar
（CSS 变量驱动、原生 mousemove 拖拽、:143-153 左栏低于 ~160px 自动折叠）；右栏 SidebarPlayQueue 三面板
（lyrics/queue/visualizer，useSidebarPanels 顺序过滤，sidebar-play-queue.tsx:37-80）。UI 库 Mantine 9。

**与 Voicefox 架构的差异**：多服务器（Subsonic/Jellyfin/Navidrome）接入层是其自托管生态特有；MPV 双实例
gapless（player.store.ts:116-160 player1/player2 预载对）在主进程 node-mpv——Voicefox 的 mpv 在 Rust FFI 侧，
位置不同；其歌词解析仅 LRC + NetEase 开放格式，**无 KRC/QRC/YRC 解密**（Voicefox 的 decryptor+parser+fetcher 是超集）。

**重点研究结果（仅参考交互，实现须全部重写）**：
- **队列操作语义** `src/renderer/store/player.store.ts:34-84,116-204` + `src/shared/types/types.ts:122-130`：
  Play 七值枚举（INDEX/LAST/NEXT/NOW/SHUFFLE…）、addToQueueByUniqueId 的 pinAboveUpNext（player.store.ts:794/877）、
  选中项 move/sort/shuffle、getQueue(groupBy) 分组——纯语义无 UI 依赖，是 feishin **最值得吸收的部分**，
  可直接翻译为 Dart 队列接口（行为参考非复制）。
- **右上下文面板** `sidebar-play-queue.tsx:37-80`：面板开关/排序/与 now-playing 页互斥模型——映射 shell/context_panel.dart 面板注册表。
- **侧栏拖拽折叠** `main-content.tsx:134-194` + resize-handle.tsx：拖至阈值自动折叠、右栏宽/高双向拖、尺寸持久化——
  Flutter 用 GestureDetector/MouseRegion 复刻。
- **播放栏三区网格** playerbar.tsx:43-63（左曲目/中传输/右音量）+ 点击开全屏播放页（:29-33）。
- **歌词交互集** lyrics.tsx（500ms 换歌防抖 :83-105、多层翻译/注音 overlay :200-250、delayMs 偏移、本地/远程换源、
  LRC 导出）+ hooks/lyrics-animation-engine.ts——UX 蓝本；注意 Voicefox 侧已是解析超集。
- **队列恢复/续播** use-queue-restore.ts / use-autosave.ts / use-resume-position.ts——交互设计参考。
- **封面加载** item-image.tsx:56,103-135（占位优先级 thumbHash/blurHash/dominantColor + 会话级 cacheKey 防抖）——
  对照 myune_seam/cover_loader.dart:1-73，可借鉴占位优先级与 inflight 去重。
- 不采用：Electron 窗口栏/DLNA cast/jukebox/MPRIS/Discord-RPC/scrobble/butterchurn 可视化/react-window 虚拟表格/
  多服务器接入层（技术栈不同或属 feishin 生态特有）。

**复用判定**：**禁止直接移植/小幅改造**（GPL-3.0 强制开源 + TS/React 与 Flutter 异构，逐文件翻译即重写）；全部**仅参考交互**。
**移植后许可证履行方式**：不存在「移植后」场景——任何 feishin 源码（含 CSS module）复制进 Voicefox 即要求整体 GPL。
纪律：『读设计不读着抄』，记录设计来源页但不留代码级相似性。注意 Voicefox 侧现役壳是
`flutter/lib/src/shell/app_shell.dart`（myune_shell/ 已 RETIRED），参考结论只落在新壳。

## 4. harmonoid（本地曲库播放器，Flutter）⚠️ 最高法律风险

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/harmonoid/harmonoid |
| 默认分支 | `master`（clone 后 `git branch --show-current` = master） |
| 研究日期 | 2026-11-07 |
| commit SHA | `927ff7219f961e1a24e8fcf8f9fa0c7c0fb780ce`（2026-11-07，"fix(android): notifyActivityDestroyed"；汇总复测一致）；pubspec 版本 0.3.38+9049 |
| 根许可证 | **PolyForm Strict License 1.0.0**（记录实读全部 104 行；**汇总人本次 `head LICENSE` 复核首行 "# PolyForm Strict License 1.0.0"，证实**） |

**UI 框架 / 状态管理 / 导航**：Flutter 多平台（Windows/Linux/macOS/Android/iOS，desktop+tablet+mobile 三布局）。
播放引擎 media_kit（libmpv 封装，pubspec.yaml:59-88 固定 git ref c533e446），核心封装
lib/core/media_player/media_player.dart:41-590（单例 ChangeNotifier 包 media_kit Player；mpv property 调优
:445-477、icy 流元数据 :478-496、WASAPI 独占 :261-271、ReplayGain）；跨平台系统集成走 mixin 注册表
（MPRIS/SMTC/audio_service/lastfm/Discord RPC/windows_taskbar）。状态管理：单例 ChangeNotifier
（MediaPlayer/LyricsNotifier/ThemeNotifier/Configuration .instance）+ provider 包；模型层 freezed。
导航：go_router 16.3.0 嵌套 ShellRoute（lib/routing/router.dart:44-333），页面转场统一 SharedAxis。
架构定位：**本地曲库播放器**（TagReader 解析、coverForUri 本地封面、drift/SQLite），非多源在线流媒体；
封面走 tag 解析 + 本地 coverForUri（rendering.dart:109 TODO 自述 "Add support for HTTP URIs"，不支持网络封面）。

**与 Voicefox 架构的差异**：本地曲库 vs 多音源在线流媒体；media_kit/libmpv 播放栈与 Voicefox Rust FFI 后端冲突；
队列管理直接委托 media_kit Playlist（media_player.dart:149-246）；歌词仅 LRC（lyrics_notifier.dart:602-606）且 API
走 Supabase edge function 并**被订阅/试用付费墙门控**（lyrics_notifier.dart:110-118、api/lyrics_get.dart:27-29
402→LyricsGetAccessException、桌面歌词 gate :571-584）。Voicefox 已有 KRC/QRC/YRC 解析器+解密器+多源 fetcher
（myune/lyrics/parser/{krc,qrc,yrc}_parser.dart、decryptor/、fetcher/，Apache-2.0 vendored），能力完全覆盖且远超。

**公开树不可构建（source-available 幻觉）**：`.gitmodules` 10 个子模块中 **9 个实测 "Repository not found"**
（private/smtc-win32/tag_reader/adaptive_layouts/media_library/identity/taglib/discord_social_sdk/lastfm 等，
仅 assets/localizations 可访问）；闭源包依赖面覆盖 lib/ 266 个 dart 文件中的 media_library 73 个、
adaptive_layouts 68 个、identity（UI 套件，含 LyricsView）28 个、tag_reader 4 个、lastfm 4 个；
`lib/core/media_player/media_player.dart:14` 直接 import 闭源 CrossfadePlayer（:296,:416-426 使用）——连 MediaPlayer
都编译不过。README 展示完整功能，实际是产品商店版的外壳。

**重点研究结果（仅「交互参考对象」，无任何可移植组件）**：
- 桌面 now-playing 的「强制暗色主题 + 封面轮播背景 + 双层渐变遮罩 + 歌词覆盖层开关」结构
  （desktop_now_playing_screen.dart:67-167）。
- 逐行同步算法：SplayTreeMap<毫秒,行号> + lastKeyBefore(position+1) 查找（lyrics_notifier.dart:96,595-600,771）；
  逐曲 offset 持久化（:248-253,:346-368）；增强 LRC 词级时间戳清洗正则（:625-646）——Voicefox 已有 karaoke_line_text.dart
  逐字渲染，此算法仅作查找结构对照。
- 移动端锁屏歌词：flutter_local_notifications BigTextStyle 当前句加粗 ±2 行上下文、静默通道、hide action 持久化
  （lyrics_notifier.dart:686-758）——交互思路可参考。
- 队列弹窗：ReorderableListView + 初始滚动定位当前曲（:31-40）+ mixOffset 感知重排（:79-89）+ 'Mix' 分区头/开关
  （desktop_now_playing_playlist.dart:30-140）。
- 自定义 ImageProvider（async_file_image.dart:21-177：per-key Lock 去重、fallback 占位、generation 失效、后台重试
  上限 3 次/1s 冷却）——概念参考；Voicefox cover_loader.dart 已有 32 张内存 LRU+磁盘缓存+超时，互有优劣，不建议照搬。
- 移动端 NowPlayingBar 与底栏互斥动画时序（media_library_shell_route.dart:52-93）。
- mpv 输出/缓存属性按平台选择（media_player.dart:444-477：Android audiotrack/opensles、iOS audiounit、macOS coreaudio、
  禁 demuxer 磁盘缓存）——若 Voicefox Rust 核心走 mpv 后端可作参数清单参考。

**复用判定**：**不采用（代码级移植）+ 仅参考交互（设计级）**。理由：① 法律层面 PolyForm Strict 明文禁止「基于该
软件制作新作品」与再分发（LICENSE:11-17），复制任何代码/资产都构成衍生作品；② 工程层面公开树不可构建（9/10 子模块
闭源），无「挑文件搬走」的可能；③ 架构层面本地曲库播放器与 Voicefox 多音源模型冲突。
**移植后许可证履行方式**：不存在「移植后」场景——设计参考必须停留在「读了之后自己写」，不复制代码、不照抄
assets/ 内矢量与图标资产。
**许可证历史陷阱**：≤2022-02-15 的旧快照（commit 1197a8be 及更早）是 **GPL-3.0**；2022-02~2024-02 期间是专有
EULA；2024-02-22（commit 96b6df96）起才是 PolyForm Strict。**不存在任何「MIT 时代」——从旧 tag 摘代码会让
Voicefox 整体陷入 GPL-3.0 传染**。另 syncfusion_flutter_sliders（社区许可，年收入<$1M 且开发者<5 人）非 OSI。

## 5. myune_music（仓库内 vendored 基底）

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/xiaobaimc/myune_music（上游）；仓库内 vendored 树 = `flutter/lib/src/myune/**` |
| 分支 | 上游 master；**vendored pin = `5188867b2f986e79260d8191c0c659bc1d2216ad`**（110 个 .dart 文件头统一标注，本次汇总在 /tmp/voicefox-ref/myune 检出该 SHA 并确认） |
| 研究日期 | 记录未标注；pin commit 2026-11-01（"feat: 新增逐字歌词上浮动画功能及设置开关"，本次 `git show -s` 实测）；上游 HEAD 2026-11-09（本次实测 origin/master） |
| commit SHA | 上游 HEAD `c7614d0d22fbb735ba3ba57cd3a1cb0679f3657d`（2026-11-09 "feat: 新增流派页面"，**领先 vendored pin 3 个 commit**，本次实测 origin/master 可达）；vendored 树对应 pin `5188867b…` |
| 根许可证 | **Apache-2.0**（记录在 pinned SHA 实读 /tmp/voicefox-ref/myune/LICENSE:1-39；汇总复核首行一致）——与 Voicefox 根 MIT 兼容 |

**依赖许可证边界**（记录全部实际读取）：lyricGeter（WisteriaZy/lyricGeter，KRC/QRC/YRC 解析参考实现）= **MIT**，
以内嵌全文注册于 `flutter/lib/src/myune/services/license_service.dart:8-40`（本次实读确认，关于页署名义务已履行）；
上游音频引擎 mpv_audio_kit（git 依赖 pin e8768813）= BSD-3（clone HEAD 实读；**pin 精确版本文件未读**，fetch 两次
网络失败，风险低——voicefox 不发行该包，shim 为本地新写）；vendored UI 依赖面在 ~/.pub-cache 实读：provider 6.1.5
MIT、rxdart Apache-2.0、mesh_gradient 1.3.8 MIT、silky_scroll 2.6.4 MIT、window_manager MIT、file_picker MIT、
cached_network_image MIT、scrollable_positioned_list BSD-3、pinyin BSD-2、markdown_widget MIT、colorgram BSD-3、
http/crypto/path/shared_preferences 等 Dart/Flutter authors BSD-3、uuid MIT、pointycastle Bouncy Castle BSD-3 风格；
hotkey_manager 0.2.3 与 system_fonts 1.0.1 被 voicefox 以**本地 clean-room stub**（flutter/packages/，文件头自述为
voicefox 编写）覆盖，上游两包许可证未验证。vendored 树自身无 LICENSE 文件，文件头引用的
/home/emo/code/myune_music-reference/LICENSE 在本机已不存在（git rev-parse 报 exit 128）——**建议改为仓库内 NOTICE**
（本报告建议已登记，整改不在本次范围）。

**UI 框架 / 状态管理 / 导航**：Flutter 桌面应用（上游版本 0.9.5）。状态管理 provider 包（ChangeNotifier +
context.watch/read/Consumer）；导航 NavigationRail + 页面内嵌 Navigator（named routes + PageRouteBuilder 150ms 淡入）+
自管路由历史 NavigationNotifier（flutter/lib/src/myune/layout/navigation_notifier.dart:7-46）；播放 mpv_audio_kit
经本地新写 shim（myune_seam/mpv_audio_kit_shim.dart）转发到可插拔 AudioBackend（myune_seam/app_model_audio_backend.dart:17-241）；
主题 Material 3 ColorScheme.fromSeed + ThemeProvider（theme/theme_provider.dart:10-235）。

**voicefox 侧真实接线（本次实读确认）**：main.dart:289 `MyuneHost.attach` 挂 app 级 Provider 图；
main.dart:306-391 MaterialApp 直接用 host.theme；live 壳为 `src/shell/VoicefoxShell`（仅消费 myune 的 ToastOverlay 与
SettingsProvider）；旧壳 `myune_shell/app_shell.dart` 文件头标注 **RETIRED**。投影层
`myune_shell/projection.dart`（文件头自述 "Newly written for voicefox, not vendored"，本次实读确认）：
`adoptExternalState`（:57,:137）、`adoptExternalLyrics`（:63）、`adoptExternalQueue`（:65）——**只做只读投影，
不触发任何播放入口**。

**冻结验证（记录实跑，本次汇总确认 clone 处于该 pin）**：对全部 110 个 vendored .dart 与上游 5188867b 逐文件 diff
（剥离 4 行来源头、忽略空白、归一 mpv_audio_kit import 改道），残留差异仅 28 个文件，性质为 dart format 换行、
window_manager/相对路径 import 修正、以及仅 2 处显式 `// === voicefox seam: begin/end ===` 注入：
lyrics_handler.dart:70-80 adoptExternalLyrics（本次实读 :73 确认）与 playlist_content_notifier.dart adoptExternalState/
adoptExternalLyrics（本次实读 :739/:771）。

**重点研究结果**：
- **逐字歌词渲染**（vendored，冻结完整）：lyrics_widget.dart:43（1739 行：弹性入场 :81、高亮/退场 fade :100-119、
  按行距递增 blur :462-470、设置项 :1057-1066）+ karaoke_line_text.dart:14（705 行，ShaderMask 逐字填充 :532）+
  lyric_blur.dart + single_line_lyrics.dart。**启用条件 = 投影层透传逐字 token**：本次实读确认
  `myune_shell/projection.dart:165-176 _toLyrics` 只映射 timestampMs+text，且 bridge `LyricLineDto`
  （flutter/lib/src/bridge/lib.dart:512-534）本身只有 timestampMs/durationMs/text **无逐字 token 字段**——
  Rust 侧 LyricsDto 需先透出逐字 token（详见 03 报告）。
- **歌词编排** lyrics_handler.dart（1127 行）：:122-178 多源管线（内嵌标签→外置 .lrc/.krc/.qrc/.yrc→在线
  qq/netease/kugou 主备+兜底）；:222-261 先常数级加密检测再解密；:419-531 LRC+逐字 token 解析；:533-925
  awlrc(LX Music base64 逐字/翻译/罗马音)；:669-762 >8s 间奏自动插入；:1076-1126 二分查找当前行+点击行 500ms 锁定。
- **SongDetailPage**（page/song_detail_page.dart:26-823）：BackgroundBlurWidget:26 用 colorgram 从封面提 6 色→HSL
  钳制→MeshGradient 动态网格背景（:88-158,206-248）或 40σ 高斯模糊+渐变遮罩（:256-283），组件 5s 自动隐藏
  （:301-353），竖屏横屏双布局。**按 §7.3 已停用为顶层播放页**（本次实读 myune_shell/myune_player_page.dart:1-12
  确认：自带标题栏/队列 Drawer/控制区与全局壳职责重复；本体冻结不动）。
- **Playbar**（widgets/playbar.dart:28-441）：三区布局，进度 Slider（StreamBuilder+throttleTime(200ms)+拖拽会话 id
  :206-300）——live PlayerBar 已替代。
- **SongCoverBuilder/SongCoverStore**（widgets/song_cover.dart:14-123）：按 filePath 缓存键挂 store 监听、
  快滚时 Scrollable.recommendDeferredLoadingForContext 延迟磁盘读（:108-118）。
- **PlayingQueueDrawer**（widgets/playing_queue_drawer.dart:16-256）：宽 400 Drawer、定位当前曲
  scrollToIndexInList+LocatePulseNotifier 脉冲高亮（:36-51）、播完队列暂停 stopAfterQueue（:77-89）、保存队列为歌单
  （:177-243）；live queue_panel.dart 已替代，但定位脉冲交互值得单独抽用。
- **播放模式** playlist_content_notifier.dart:40(PlayMode enum),143-149,361,2103,2601-2691。
- **在线歌词 fetchers+解密器+解析器**（lyrics/fetcher/{qqmusic,netease,kugou,amll}_fetcher.dart、
  decryptor/{krc,qrc,eapi}_decryptor.dart+lyric_encryption_detector.dart、parser/{krc,qrc,yrc}_parser.dart）——
  **不采用为运行时路径**（voicefox 歌词由 Rust 多音源侧产出经 LyricsDto 注入，Dart 侧再抓取会重复且绕过统一
  请求头/代理面）；保留 license_service.dart 的 lyricGeter MIT 署名注册，可作 Rust 歌词模块算法参照。
- **不采用**：vendored AudioService（gapless/EQ/pitch/rate/独家模式）——backend 侧全为显式 no-op
  （app_model_audio_backend.dart:184-228），voicefox Rust FFI 无对应命令（ffi/src/api.rs pub fn 清单实读）。
- **休眠风险**：vendored 树内嵌 myune 自己的 flutter_rust_bridge 生成码（readAudioInfo），voicefox ffi 无该导出；
  7 处调用点当前休眠（基线 §16：P0-A1 降级为 P3 登记，调用点均有 try/catch 降级）。若未来激活 vendored 本地曲库页，
  必须先在 Rust 侧实现该 API。

**复用判定**：vendored 冻结树**已按 §2.3 优先级 1 落地且与上游可核对**——分组件判定见 03 报告：
ThemeProvider/ToastOverlay+NotificationService/SettingsProvider/mpv shim/投影已 live；歌词渲染小幅改造待启用；
SongDetailPage/PlayingQueueDrawer/SongCoverBuilder 仅参考交互或可抽用；Playbar/AudioService/在线 fetcher 不采用。
**移植后许可证履行方式**：已履行中——110 个文件头「Vendored from …@5188867b」+ license_service.dart lyricGeter MIT
注册满足 Apache-2.0 §4 基本要求；**待办**：文件头引用的外部 LICENSE 路径已失效，应改为仓库内 NOTICE 文件；
若以二进制分发，Apache-2.0 §4 要求保留上游许可证与修改声明。

## 6. aethertune（Flutter 跨平台播放器，alpha）

| 项 | 值 |
|---|---|
| 仓库 URL | https://github.com/Yunushan/aethertune（**注意同名混淆**：GitHub 另有 nevermore23274/AetherTune 为 Rust 终端电台播放器，外部初步核查命中的即是它——文档引用必须固定 Yunushan/aethertune + SHA） |
| 默认分支 | `main` |
| 研究日期 | commit 2026-10-02；pub.dev 依赖核验 2026-11-10 |
| commit SHA | `ccde72345c31e302dc0bf8041db41a845a4f0ba4`（2026-10-02，"Fix native window close and accept ordinary Linux releases (#55)"，浅克隆 rev-parse，与 GitHub API 最新 main 一致；汇总复测一致） |
| 版本 | pubspec 0.1.0+1，**alpha**：无 git tag、无 GitHub Release、CHANGELOG 处于 Unreleased；仓库 2026-07-05 创建、847 commits/4 个月、2 stars——年轻且高速变动 |
| 根许可证 | **0BSD**（BSD Zero Clause，Copyright (C) 2026 AetherTune Contributors；记录实读 + 汇总复核首行一致）——不要求署名，允许任意使用/修改/分发 |

**依赖许可证边界**（记录经 pub.dev API score tags 核查 + vendored 包实读）：just_audio Apache-2.0/MIT、media_kit MIT、
provider MIT、audio_service MIT、audio_session MIT、just_audio_media_kit Unlicense、dynamic_color Apache-2.0、
window_manager/sqlite3/file_picker/tray_manager/hotkey_manager/smtc_windows MIT、flutter_secure_storage/share_plus/
material_ui BSD-3、app_links Apache-2.0。**无 copyleft 污染**。NOTICE 实读：vendored rhttp 保留 MIT（Tien Do Nam，
基于 codeberg Tienisto/rhttp @9871f1c，改动记录于 AETHERTUNE_PATCHES.md）；vendored audio_service_mpris 保留 MIT
（Boris Drazhzhov）；flutter_secure_storage BSD-3-Clause 全文内嵌于 NOTICE。

**UI 框架 / 状态管理 / 导航**：Flutter（Dart SDK ≥3.12）+ Material 3（aethertune_app.dart:514 useMaterial3:true）+
dynamic_color/AMOLED 主题。状态管理 provider 包 MultiProvider 挂约 20 个 ChangeNotifier/ProxyProvider
（aethertune_app.dart:71-297），PlayerController extends ChangeNotifier。导航：单 HomeScreen 6 目的地
（Home/Library/Playlists/History/Sources/Options，home_screen.dart:701-731），桌面 ≥900px NavigationRail、移动
NavigationBar、IndexedStack 页体（:1150-1315），≥1200px 桌面队列面板（responsive_layout.dart）。
音频 just_audio + just_audio_media_kit，PlaybackAudioEngine 抽象 + SystemMediaPlaybackEngine 包装；
**AudioSource.uri 不带自定义 HTTP 头**（playback_audio_engine.dart:458-463）。Rust 仅存在于 vendored rhttp
（flutter_rust_bridge 2.12.0），只用于 library sync 传输，不用于音频流。

**与 Voicefox 架构的差异**：单来源 SelfHosted 体系（provider DI 图）vs Voicefox 13 音源 AppModel；
其播放链不支持自定义请求头，任何播放相关代码都不能满足 Voicefox 需求。

**重点研究结果**：
- **artwork_palette.dart**（apps/mobile/lib/src/domain/，89 行，纯 Dart 像素分桶取主色，仅依赖 flutter/material）
  → **直接移植候选**，零耦合，用于封面氛围底色。
- **track_artwork.dart**（apps/mobile/lib/src/ui/widgets/，221 行）→ 小幅改造：scheme 分流 ImageProvider
  （http/file/data，:180-205）、DPR 感知 maxWidth 钳制 64-1024（:50-52）、provider 封面回退加载链；
  需把 SelfHostedProviderStore 依赖换成 voicefox 的 cover_loader.dart。
- **track_queue.dart**（apps/mobile/lib/src/domain/，290 行）→ 仅参考数据模型：TrackQueueSnapshot 版本化 JSON
  持久化、SavedTrackQueue 最多 12 套设备本地队列、moveQueueItem 纯函数。
- **track_lyrics.dart** 的 parseSyncedLyricLines/syncedLyricLineIndexAt → 小幅改造：多时间戳 LRC/SRT/VTT/TTML
  解析与行级高亮算法；不覆盖 KRC/QRC/YRC。
- **lrclib_lyrics_provider.dart**（apps/mobile/lib/src/data/，498 行）→ 小幅改造：LRCLIB 作为 voicefox 歌词源之一；
  运行时调用公共 API，不捆绑歌词库（NOTICE 明确该边界，移植须保留）。
- **Hero 封面过渡**（player_bar.dart:106-117 / now_playing_screen.dart:1474，playerArtworkHeroTag）与 720px 紧凑切换
  → 仅参考交互。
- **6 目的地导航 + 900/1200px 断点** → 仅参考交互（Voicefox 触屏断点 600/900/1200 与其决策可互证）。

**复用判定**：总体**仅参考交互 + 少量组件级移植**，不建议整页移植。理由：① 0BSD 法律上允许直接复制，但 Voicefox
UI 基线是已 vendored 的 myune（§2.3 优先级 1：已 vendored 代码优先）；② 其 widget 全部耦合 provider DI 图，
整页移植会拖入 provider+store 体系，与 Voicefox AppModel+projection seam 冲突；③ 音频栈不可移植。
**移植后许可证履行方式**：0BSD 不要求署名，按 §2.2 仍应在移植文件头保留来源声明（仓库+SHA）；若拷贝其 vendored
rhttp/audio_service_mpris（MIT）须保留其 LICENSE 文本；LRCLIB 适配仅限运行时公共 API 调用，保留该边界与出处标注。

## 7. Spotify（§2.1 之列，不在本次 6 份记录内）

指南 §2.1 将 Spotify 定位为「仅产品体验与视觉参照，不复制专有代码/资源」，无公开可研究仓库，本次 6 份研究记录
不含 Spotify——三份报告不覆盖其代码级结论，视觉方向遵循指南 §3.2（信息层级参考 Spotify、保留 Voicefox 紫色品牌）。

---

## 8. 横向结论

| 项目 | 根许可证 | 代码移植 | 交互参考 | 核心价值 |
|---|---|---|---|---|
| myune（vendored） | Apache-2.0 | ✅ 已落地（优先级 1） | — | 逐字歌词渲染/主题/投影接缝（冻结树内现成） |
| aethertune | 0BSD | ✅ 少量零耦合组件（artwork_palette 等） | ✅ | 纯 Dart 取色器、LRC 系解析、LRCLIB 源 |
| finamp | MPL-2.0 | ⚠️ 仅个别 UI 文件小幅改造（须保留 MPL 头） | ✅ | 歌词屏交互、空间预算自适应布局、封面缓存分层 |
| feishin | GPL-3.0 | ❌ 禁止 | ✅ | 队列操作语义（Play 枚举/pinAboveUpNext）、三栏面板注册 |
| nuclear | AGPL-3.0-only | ❌ 禁止（含改写式） | ✅ | 音源候选呈现 UI、多候选数据模型、歌词 IR 清单 |
| harmonoid | PolyForm Strict 1.0.0 | ❌ 禁止（含资产） | ✅ 设计级 | 桌面沉浸式播放页结构、逐行同步查找算法 |

未验证项与风险汇总见 `02-license-and-reuse-audit.md` §7。
