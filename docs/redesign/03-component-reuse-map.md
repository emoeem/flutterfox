# 组件级复用映射（03-component-reuse-map，2026-11-11 修订轮）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §3.4 全局组件清单；复用判定遵循 §2.3 优先级
  （① 已 vendored 的 myune 组件 → ② 许可证兼容且技术栈匹配的 Flutter 组件 → ③ 可独立抽离的通用交互组件 → ④ 自实现）。
- 许可证判定依据见 `02-license-and-reuse-audit.md`；项目研究背景见 `01-reference-projects.md`。
- **来源三档定义**：
  - **【vendored】** = `flutter/lib/src/myune/**` 冻结树（Apache-2.0，pin `5188867b…`，§7.3 不回写不跟进）；
  - **【上游移植】** = 从外部参考仓库拷入并履行其许可证义务（当前仅 aethertune 0BSD / finamp MPL-2.0 有候选，均未落地）；
  - **【自实现】** = Voicefox 自有代码（含 `myune_seam/`、`myune_shell/projection.dart`，文件头实测自述
    "Newly written for voicefox, not vendored"）。
- **行号口径（2026-11-11 修订轮）**：本仓库路径与行号为本轮 `grep`/`sed` 逐一实测；参考项目的文件路径与行号来自
  研究记录（pinned SHA 下的静态阅读，外部克隆已清理无法复开，标注【仅参考】）。与 2026-11-10 旧版相比修正的漂移：
  mobile_shell TouchShell/MobileShell/TabletShell（62/257/383 → 63/260/386）、empty_state（:9 → :6）、
  lyrics_panel ticker（:235/:266 → :236/:258）、bridge LyricLineDto（512-534 → :516 起）、playlist_content_notifier
  seam（739/771 → 735-798 整块）、VxTrackRow source 字段（:62 → :55，final 声明 :82）。

## 1. §3.4 全局组件逐个映射

| # | §3.4 组件 | 现状 | 来源判定 | Voicefox 源文件（2026-11-11 实测） |
|---|---|---|---|---|
| 1 | `VxArtwork` | **已 live（本轮确认，2026-11-10 旧版的「待建」已过时）**：Phase 1 落地 `VxArtwork`（vx_artwork.dart:17）+ `ArtworkResolver`（services/artwork_resolver.dart:99，实体键 `source|type|id`、内存 LRU 256+TTL 30min、失败负缓存 n²·2s 退避、single-flight、限尺寸解码 16-1024）；已接入 home_page 3 处 / discover_page / search_page 专辑歌手网格 2 处 / playlist_detail hero（基线 §10.2，本轮 `grep -rln "VxArtwork(" flutter/lib/src/pages/` 实测 4 文件命中） | 自实现（统一入口已建成） | 主件：`flutter/lib/src/design_system/components/vx_artwork.dart:17`（class VxArtwork）、`flutter/lib/src/services/artwork_resolver.dart:99`（class ArtworkResolver）。**收编残留**：旧 `CoverImage`（`flutter/lib/src/widgets/cover_image.dart:9`）仍服务 song_tile/queue_panel/player_bar/library/downloads 等 ~15 处（基线 §10.3）；缺省占位 `flutter/lib/src/design_system/components/vx_cover_fallback.dart:12`（VxCoverFallback）、渐变 token `flutter/lib/src/design_system/design_tokens.dart:183`（VxCoverGradients）；`flutter/lib/src/myune_seam/cover_loader.dart`（本轮实测头注释：仅内存 LRU32，**没有磁盘缓存**，P3-01 已更正；头注释明言「新代码请改走 services/artwork_resolver.dart + VxArtwork」，本文件仅为 myune 播放页字节供给兼容层）。**开放缺陷 P1-08**：`flutter/lib/src/pages/search_page.dart:550` 的 `VxTrackRow` 未传 `cover:`，行内永远渲染渐变占位（本轮 sed 实测该调用无 cover 参数；vx_track_row.dart:166 `cover ?? VxCoverFallback(title: title)`），修复为单行补参 |
| 2 | `VxSongTile` | **已 live**（命名 `VxTrackRow`；表格形态 `VxSongTable`） | 自实现 | `flutter/lib/src/design_system/components/vx_track_row.dart:49`；`flutter/lib/src/widgets/song_table_view.dart:19`（VxSongTable）；页级既有行组件 `flutter/lib/src/pages/song_tile.dart`（SongTrackRow:171 / SongTile:273） |
| 3 | `VxAlbumCard` | **已 live** | 自实现 | `flutter/lib/src/design_system/components/vx_album_card.dart:9` |
| 4 | `VxArtistCard` | **已 live**（另有横幅变体 `VxArtistBanner`） | 自实现 | `flutter/lib/src/design_system/components/vx_artist_card.dart:18`；`flutter/lib/src/design_system/components/vx_artist_banner.dart:14` |
| 5 | `VxPlaylistCard` | **已 live** | 自实现 | `flutter/lib/src/design_system/components/vx_playlist_card.dart:9` |
| 6 | `VxSectionHeader` | **已 live** | 自实现 | `flutter/lib/src/design_system/components/vx_section_header.dart:12` |
| 7 | `VxEmptyState` | **已 live** | 自实现 | `flutter/lib/src/design_system/components/vx_empty_state.dart:9`；页级空态 `flutter/lib/src/widgets/empty_state.dart:6` |
| 8 | `VxErrorState` | **已 live** | 自实现 | `flutter/lib/src/design_system/components/vx_error_state.dart:9` |
| 9 | `VxLoadingState` | **已 live**（命名 `VxLoadingSkeleton`，骨架屏形态，符合 §3.4「不用永久 spinner」） | 自实现 | `flutter/lib/src/design_system/components/vx_loading_skeleton.dart:23` |
| 10 | `VxSourceBadge` | **待建**（本轮 `grep -rln "VxSourceBadge" flutter/lib/src/` 零命中，类不存在）；音源徽标目前内联散落（基线 §12：搜索页 8 音源徽标） | 自实现 | 无统一源文件；`VxTrackRow` 已有 `source` 字符串位（vx_track_row.dart:55 构造参数 / :82 final 声明）可下沉为徽标；落点建议 `design_system/components/vx_source_badge.dart`，数据源 `SongDto.source`/`SourceCapabilitiesDto`（基线 §8） |
| 11 | `VxMiniPlayer` | **已有实现待收编**（命名 `MiniPlayerBar`，移动壳在用） | 自实现 | `flutter/lib/src/player/mini_player_bar.dart:24`；【仅参考】finamp `lib/components/now_playing_bar.dart`（MPL-2.0：buffered 进度/marquee/模糊背景联动）、feishin playerbar.tsx 三区网格（GPL，仅交互） |
| 12 | `VxNowPlayingControls` | **已 live**（命名 `VxPlayerControls`；承载于 PlayerBar 与 NowPlayingPage） | 自实现 | `flutter/lib/src/design_system/components/vx_player_controls.dart:13`；`flutter/lib/src/player/player_bar.dart:27`（含 `_VolumeControl` 真实下发 SetVolume，基线 §9 实机验证）；`flutter/lib/src/player/now_playing_page.dart:35` |
| 13 | `VxQueuePanel` | **已有实现待收编**（命名 `QueuePanel`，读 state 不自持副本） | 自实现 + 【vendored】交互抽用 | `flutter/lib/src/player/queue_panel.dart:24`（当前曲高亮 :60 currentIndex / :130「当前播放」标签、移除、清空二次确认；拖动排序无后端命令，UI 禁用并说明，不伪造，:8 头注释实测）；可抽用【vendored】`flutter/lib/src/myune/widgets/playing_queue_drawer.dart:16`（定位当前曲 scrollToIndexInList+脉冲高亮 :36-51【研究轮行号】）与 `flutter/lib/src/myune/utils/scroll_to_index.dart`；【仅参考】feishin `sidebar-play-queue.tsx:37-80` 面板互斥、nuclear queueStore currentIndex 补偿（均禁止复制） |
| 14 | `VxContextPanel` | **已有实现待收编**（命名 `ContextPanel`，三 Tab：nowPlaying/lyrics/queue） | 自实现 | `flutter/lib/src/shell/context_panel.dart:20`（enum ContextTab）`:23`（ContextPanel）；挂载于 `flutter/lib/src/shell/app_shell.dart:99`（VoicefoxShell）；【仅参考】feishin `useSidebarPanels` 面板开关/排序模型（GPL，仅交互） |
| 15 | `VxImportEntry` | **待建**（本轮 `grep -rln "VxImportEntry" flutter/lib/src/` 零命中）；本地导入入口现内联在本地音乐页（基线 §11：添加目录按钮 + 空态主 CTA + 次按钮） | 自实现 | 现状参考：`flutter/lib/src/pages/local_music_page.dart`（FilePicker.getDirectoryPath 入口/空态 CTA/PlatformException 手输路径兜底 :400-423【基线行号】）；落点建议 `design_system/components/vx_import_entry.dart` |
| 16 | `VxResponsiveScaffold` | **已有实现待收编**：断点/Shell 选择已是纯函数并有单测（基线 §5），未抽成独立组件 | 自实现 | `flutter/lib/src/shell/responsive_shell.dart`（本轮实测：MobileBreakpoints :61、DeviceFormFactor :73、TabletLayout :78、resolveDeviceFormFactor :88、resolveTabletLayout :98、resolveShellMetrics :144）；桌面壳 `flutter/lib/src/shell/app_shell.dart:99`；触屏壳 `flutter/lib/src/shell/mobile_shell.dart`（TouchShell:63 → MobileShell:260 / TabletShell:386） |

**已 live 但 §3.4 清单之外的 Vx* 组件**（2026-11-11 实测类行，设计系统已有资产，继续复用）：
`vx_card_shell.dart:15`、`vx_detail_hero.dart:16,42`、`vx_hero.dart:14`、`vx_hover.dart:10`（VxHoverBuilder）、
`vx_seek_bar.dart:29`（VxTimeLabel）`:46`（VxSeekBar）`:122`（VxSeekRow）、design_tokens.dart 全套 token
（VxColors:15 / VxLightColors:72 / VxDarkSurface:132 / VxDarkHero:141 / VxLightHero:162 / VxSpacing:213 /
VxRadius:233 / VxDensities:248 / VxTypography:262）、`design_system/gallery_page.dart:25`（GalleryPage，
Golden/截图测试入口）。

## 2. 重点非 Vx 复用件（跨参考项目）

### 2.1 逐字卡拉OK歌词渲染：【vendored】小幅改造，最高价值复用件

| 项 | 内容 |
|---|---|
| 已 live | `flutter/lib/src/player/lyrics_panel.dart:25`（LyricsPanel，**线级 LRC ticker**：`_LyricTicker:236`/`_IndexReporter:258`，本轮实测） |
| 冻结目标件 | 【vendored】`flutter/lib/src/myune/widgets/lyrics_widget.dart:43`（实测 1739 行）、`flutter/lib/src/myune/widgets/karaoke_line_text.dart:14`（实测 705 行，ShaderMask 逐字填充）、`lyric_blur.dart`、`single_line_lyrics.dart`【研究轮内部行号：弹性入场 :81、高亮/退场 fade :100-119、按行距递增 blur :462-470、设置项 :1057-1066】 |
| **启用路径（实测缺口，2026-11-11）** | ① Rust 侧 `LyricsDto` 未透出逐字 token：`flutter/lib/src/bridge/lib.dart:516` 起 `LyricLineDto` 实测仅 `timestampMs/durationMs/text` 三字段；② 投影丢弃 token：`flutter/lib/src/myune_shell/projection.dart:164 _toLyrics` 只映射 timestamp/text。需：扩 bridge DTO 逐字字段 → Rust 透出 → `_toLyrics` 携带 tokens → `adoptExternalLyrics`（`flutter/lib/src/myune/lyrics/lyrics_handler.dart:70-80` seam，本轮实测）注入。UI 组件本身可零改动启用 |
| 许可 | vendored Apache-2.0，冻结树内，无新增义务 |
| 【仅参考】输入 | finamp lyrics_screen（MPL-2.0：手动滚动暂停+恢复 FAB、点击行 seek、ShaderMask 渐隐、0.5s 淡入；**若真拷贝须履行 MPL 文件级义务**，默认仅交互参考）；nuclear lyrics IR（annotations/ruby/vocalist 清单）；feishin lyrics-animation-engine（UX 蓝本）；harmonoid SplayTreeMap+lastKeyBefore 查找（算法对照） |

### 2.2 封面取色/氛围背景

| 项 | 内容 |
|---|---|
| 已 live | 【自实现】`flutter/lib/src/player/now_playing_page.dart`（本轮实测：`_CoverPalette:163`、`NowPlayingAutoPalette:207`、`NowPlayingBackdrop:130`） |
| 【vendored】参照 | `flutter/lib/src/myune/page/song_detail_page.dart`（本轮实测 `BackgroundBlurWidget:26`、`SongDetailPage:305`；研究轮内部行号：colorgram 提 6 色→HSL 钳制→MeshGradient 动态背景 :88-158,206-248 / 40σ 高斯模糊 :256-283 / 组件 5s 自动隐藏 :301-353）。**已停用为顶层播放页**（2026-11-11 实测 `myune_shell/myune_player_page.dart:1-13` 头注释：Phase 2 过渡入口只渲染如实空态，本体冻结不动），仅移植其参数与自动隐藏交互 |
| 【上游移植】候选 | aethertune `apps/mobile/lib/src/domain/artwork_palette.dart`（89 行纯 Dart 像素分桶，0BSD，**直接移植候选**），未落地；依赖 mesh_gradient(MIT)/colorgram(BSD-3) 已在 voicefox pubspec（2026-11-11 实测 pubspec.yaml:12,18 钉版本 ^2.0.0/^1.3.8） |

### 2.3 封面加载分层（并入 VxArtwork）

| 项 | 内容 |
|---|---|
| 已 live | 【自实现】`flutter/lib/src/services/artwork_resolver.dart:99`（统一解析：LRU256+TTL+负缓存+single-flight+限尺寸解码）+ `flutter/lib/src/design_system/components/vx_artwork.dart:17`（唯一展示入口）；【自实现】`flutter/lib/src/myune_seam/cover_loader.dart`（本轮实测头注释：内存 LRU32 :16 + 12s 超时 :17 + in-flight 去重 + 自定义 UA + file://，**没有磁盘缓存**；定位已收窄为「myune 播放页字节供给兼容层」，新代码改走 artwork_resolver+VxArtwork）；状态拉取 `projection.dart` 只在 URL 变化时拉取（基线） |
| 【vendored】可抽用 | `flutter/lib/src/myune/widgets/song_cover.dart:14`（SongCoverBuilder；快滚 `Scrollable.recommendDeferredLoadingForContext` 延迟磁盘读 :108-118【研究轮行号】） |
| 【仅参考】输入 | finamp album_image_provider（三层缓存/BlurHash 去重/scale 0.25：强绑 Jellyfin getImageUrl，不照搬）；feishin item-image 占位优先级 thumbHash/blurHash/dominantColor；aethertune track_artwork DPR 感知 maxWidth 钳制 64-1024（0BSD 小幅改造候选） |
| 前置状态 | 旧 P1-03 封面反写已关闭（基线 §10.5：反写 grep 为零，本轮 `grep "? null : CoverImage"` home/discover 实测零命中）；**残留单点 = P1-08**（search_page.dart:550 漏传 cover，本轮实测仍在） |

### 2.4 队列域

| 项 | 内容 |
|---|---|
| 已 live | 【自实现】`flutter/lib/src/player/queue_panel.dart:24`（当前曲高亮 :60,130、移除、清空二次确认）；队列唯一真源 `flutter/lib/src/app_model.dart`（state.queue/queueIndex） |
| 【vendored】可抽用 | `flutter/lib/src/myune/widgets/playing_queue_drawer.dart:16-256`（定位脉冲 :36-51、stopAfterQueue :77-89、保存为歌单 :177-243【研究轮行号】）+ `utils/scroll_to_index.dart`；播放模式逻辑参照 `page/playlist/playlist_content_notifier.dart`（本轮实测 PlayMode enum :40、stopAfterQueue :143-145、playMode :147-149、模式逻辑 :2601 起） |
| 【仅参考】输入 | feishin Play 七值枚举/pinAboveUpNext/getQueue(groupBy)（纯语义，可翻译为 Dart 队列接口：**行为参考非复制**）；nuclear currentIndex 补偿算法/虚拟滚动；finamp 四段队列模型+10s 周期保存 |

### 2.5 歌词数据侧（编排/解析/解密）

| 项 | 内容 |
|---|---|
| 【vendored】保留现状 | `flutter/lib/src/myune/lyrics/lyrics_handler.dart`（实测 1127 行；研究轮行号：多源管线 :122-178、加密检测 :222-261、间奏插入 :669-762、二分定位 :1076-1126；本轮实测 seam adoptExternalLyrics :70-80）、`parser/{krc,qrc,yrc}_parser.dart`+`parsed_models.dart`、`decryptor/{krc,qrc,eapi}_decryptor.dart`+`lyric_encryption_detector.dart`、`fetcher/{qqmusic,netease,kugou,amll}_fetcher.dart` |
| 判定 | **不采用为运行时路径**（voicefox 歌词由 Rust 多音源侧产出经 LyricsDto 注入，Dart 侧再抓取会与 Rust 重复且绕过统一请求头/代理面）；保留 `services/license_service.dart` lyricGeter MIT 署名注册（本轮实测 :9-45）；可作 Rust 歌词模块算法参照 |
| 【上游移植】候选 | aethertune `lrclib_lyrics_provider.dart`（0BSD，498 行：接入 myune/lyrics/lyric_source.dart 体系，**运行时公共 API only**）；aethertune `track_lyrics.dart` 多时间戳 LRC/SRT/VTT/TTML 解析（0BSD 小幅改造）。两项均未落地 |

### 2.6 主题、壳层与音频接缝

| 项 | 内容 |
|---|---|
| 已 live | 【vendored】`flutter/lib/src/myune/theme/theme_provider.dart:10`（M3 种子色+明暗三态+字体持久化；main.dart:384-385 消费，本轮实测）、`widgets/toast_overlay.dart`+`services/notification_service.dart`（shell 消费） |
| 接缝 | 【自实现】`flutter/lib/src/myune_shell/projection.dart`（AppModel→myune Provider 图只读投影；本轮实测 adoptExternalState :57/:137、adoptExternalLyrics :63、adoptExternalQueue :65、_toLyrics :164）；`flutter/lib/src/myune_seam/mpv_audio_kit_shim.dart`+`app_model_audio_backend.dart`（本轮实测：显式 no-op 区间 :184-230，setPitch :187/setRate :190/setReplayGain :193/setGapless :219/setAudioDevice :196/EQ :202/spectrum :207 等空实现，voicefox FFI 无对应命令，`grep ffi/src/lib.rs` 零命中，差距文档化；**注意 :14-15「setVolume 是 no-op」注释已过时**，:178-180 实际转发 model.setVolume） |
| 不采用 | 【vendored】`layout/{app_shell,main_view,navigation_notifier}.dart`（结构已 fork 演化为 src/shell；本体冻结可作断点/入口参照）、`widgets/playbar.dart:28`（live PlayerBar:27 已替代） |
| 【仅参考】输入 | finamp PlayerHideableController（player_screen.dart:465-668 空间预算自适应：MPL-2.0，**改造移植候选**）；harmonoid 桌面沉浸式播放页结构；aethertune 6 目的地+900/1200 断点决策；feishin 侧栏拖拽折叠阈值 |

### 2.7 快捷键

| 项 | 内容 |
|---|---|
| 已 live | 【vendored】`flutter/lib/src/myune/hot_keys.dart`+全局热键管理（桌面快捷键注册）；本轮实测壳层绑定 `flutter/lib/src/shell/app_shell.dart:355-375`（Space :355、← :358、→ :361 ±5s、Esc :364、Ctrl/Cmd+K :373/:375） |
| 【仅参考】输入 | nuclear 声明式命令表 commands.ts:7-53（id/defaultShortcut/section + 设置页展示组织方式）：**自实现注册表，不复制** |

## 3. 明确不采用 / 禁止清单

| 来源 | 件 | 理由 |
|---|---|---|
| feishin（GPL-3.0） | 一切源码（含 CSS module） | 许可证禁止复制；仅交互参考，保持零代码相似性 |
| nuclear（AGPL-3.0-only） | 一切源码（含改写式移植） | 许可证禁止；streamCandidates 音源呈现/歌词 IR/封面渐显参数以自写方式吸收 |
| harmonoid（PolyForm Strict） | 一切代码+assets 矢量/图标资产 | 禁衍生/禁再分发；仅设计级参考；旧 tag 快照是 GPL-3.0 同样禁止 |
| 【vendored】myune | `widgets/playbar.dart`、AudioService gapless/EQ/pitch/rate/独家模式 | live PlayerBar 已替代；backend 显式 no-op（app_model_audio_backend.dart:184-230，本轮实测），Rust FFI 无对应命令（ffi/src/lib.rs grep 零命中，本轮实测） |
| 【vendored】myune | 在线歌词 fetchers+解密器作为运行时路径 | 与 Rust 侧抓取重复、绕过统一请求头/代理面；保留为算法参照与 MIT 署名载体 |
| finamp | 服务层/队列服务/下载服务/pubspec 依赖矩阵 | Jellyfin DTO 深耦合；14 个 git-fork 依赖；与 Voicefox Rust FFI+自定义请求头根本不同 |
| feishin | DLNA cast/jukebox/MPRIS/Discord-RPC/butterchurn/多服务器接入层 | 技术栈不同或属其自托管生态特有 |
| nuclear | 音频管线实现（HTML5 audio/HLS/MSE hooks） | webview 播放模型与 Voicefox FFI 后端不适用 |

## 4. 依赖关系与组件纪律（§3.4 收尾要求）

- 组件必须使用真实 DTO/回调（§3.4）：现有 Vx* 组件实测采用**原始值 + 回调**纪律。VxTrackRow 构造参数实测
  （vx_track_row.dart:52-68）：title/artist/album/source(:55)/duration/index/density/isPlaying/isLiked/cover/
  showIndex/showAlbum + onTap/onLongPressStart/onPlay/onAddToQueue/onLike/onMore 回调；
  `grep -c "AppModel|MyuneHost|Provider" vx_track_row.dart` = **0**（本轮实测），页面层负责把 SongDto 拆成原始值传入；
  收编 MiniPlayerBar/QueuePanel/ContextPanel/ResponsiveScaffold 时保持同一纪律，不得让组件内访问全局单例或
  发起不透明网络请求。
- 【vendored】组件抽用时注意其 notifier 依赖面：playing_queue_drawer/lyrics_widget 依赖
  PlaylistContentNotifier/SettingsProvider：须经 projection.dart 投影供给，不得让 live 页面直接 new myune notifier。
- 休眠坑（基线 §16 P3-02）：vendored readAudioInfo 桥 7 处调用在当前接线无后端（调用点均有 try/catch 降级）；
  若激活 vendored 本地曲库页（AllSongs/内嵌歌词），须先在 Rust 侧实现该 API 或改接缝。

## 5. 未验证 / 风险

1. §3.4 全部 16 个组件中 **11 个已 live/已有实现**（本轮实测，含新增的 VxArtwork）；**5 个待建/收编**
   （VxSourceBadge、VxImportEntry、VxMiniPlayer 收编、VxQueuePanel 收编、VxResponsiveScaffold 抽出）；
   **均为计划而非已实施**，落地时另走 Phase 任务。
2. 【上游移植】候选（aethertune artwork_palette/track_artwork/lrclib、finamp PlayerHideableController/歌词屏）**均未
   落地**，本报告只登记候选与许可证履行方式；实施时须先过 02 报告 §3 的声明/NOTICE 要求。
3. 参考项目文件行号来自研究记录 pinned SHA 的静态阅读；**外部克隆已清理（/tmp/voicefox-ref，本轮实测不存在），
   无法在本轮复开上游文件核对行号**；SHA 与许可证结论按研究记录 + 汇总轮（5725231 旧版报告）背书引用。
   finamp 默认分支 redesign 持续变动，引用时必须 pin SHA `337a2fd8…`。
4. 逐字歌词启用路径依赖 Rust 侧 LyricsDto 扩展（bridge/lib.dart:516 现无 token 字段，本轮实测）；Rust 侧是否
   已保留逐字 token 数据未在本次验证（属 Rust 模块审计范围）。
5. **本轮登记的仓库内待办**：P1-08（search_page.dart:550 漏传 cover）属缺陷矩阵管辖，修复不在研究阶段范围；
   audio_backend :14-15 过时 no-op 注释待更正；vendored 文件头失效路径应改为仓库内 NOTICE（02 报告 §2.1）。
