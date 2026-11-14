# Phase 1 Report（数据链路和 P0 修复）：已完成（2026-11-11 复验轮收口）

> 分支：`feat/ui-redesign`　模板：指南 §14
> 覆盖批次：2026-11-10 实施批次、2026-11-11 QA 第 1~4 轮修复、2026-11-11 修复后复验轮（收口轮）。
> 状态口径：本阶段可修数据链路与 P0/P1 项全部收口并实机复验；**P0-01（概率性卡死，未复现未定位）与 Android 全链（P1-06 环境阻断）如实遗留**，属跨阶段约束，与本轮改动无关（详见「未解决问题和原因」）。
> 各轮次完整补记见文末「附录：批次与 QA 轮历史补记」。

## 范围

Phase 1 全程完成：

1. **2026-11-10 实施批次**：P0-02 根因修复（进程级 owned tokio runtime + 4Hz 播放泵）+ 实机走带验证；P1-03 六处封面反写修复 + `ArtworkResolver`/`VxArtwork`（§8.2 第一批）；P1-04 SearchMore 补 source；P3-03 `PlaylistKey` 类型化 + 过期 append 丢弃（§8.1）；§8.3 进度重建隔离（playbackTick）；§10.1 AnnotatedRegion + inset 契约；P0-01 事件速率观测 instrumentation。
2. **QA 第 1~4 轮修复（2026-11-11 入树）**：P1-07 错误 toast 净化 + 限高；P1-11 搜索页错误框净化（后续扩展到发现页/歌单页 `BrowseResult.error` 源头单点收口）；P1-10 repeat 三档视觉区分（`repeatSingle`/repeat_one 字形）并补齐激活态实机截图；**P1-08 搜索结果行封面（`cover: VxArtwork`）与 P1-09 Shell Chrome 浅色主题色源收口（`VxChrome` 亮度双源 token）**。此两项修复入树时未在既往报告补记中单独登记，本报告复验轮以代码 diff + 回归测试逐项核实后关闭。
3. **2026-11-11 修复后复验轮（收口轮）**：确认 QA 第 2 轮修复已追加入树，即 `_applyBrowseEvent` 源头净化（`flutter/lib/src/app_model.dart:485` BrowseFailed 错误走 `_logAndSanitize`，原始异常写 stderr；`flutter/lib/src/app_model.dart:516` notice 过 `sanitizeUserFacingMessage`），**单点收口覆盖 discover/playlist/leaderboard/library/custom_playlists 全部浏览消费面**；`playlist_detail_isolation_test.dart` 新增 §8.1 序列 7（A 触底分页在途切 B，迟到页 2 只落 A 槽）与 P1-11 回归（文件 7→9 项）。随后按同一矩阵在 `flutter clean` 全量重建 bundle 上重截受影响视口并完成实机复验；04 矩阵 P1-11「同类残余」改判已修复。

## 修改文件

Rust（2026-11-10 批次；**此后至收口轮零改动**，本轮 `git diff -- runtime/ application/ ffi/ source/ core/` 为空，实测）：
- `runtime/src/lib.rs`：`enter_sync_bootstrap_runtime()`（进程级 `OWNED_RUNTIME: OnceLock<Arc<Runtime>>`，multi-thread flavor，enter 覆盖 `from_parts` 全函数体）+ 2 个回归测试。
- `application/src/service.rs`：`start_playback_pump` 失败分支 eprintln+tracing::warn；`start_search` SearchMore 兜底**先读后写** `state.search.source`；泵回归测试。
- `ffi/src/lib.rs` + `ffi/src/api.rs`：`FfiCommand::SearchMore` 增加 `source: Option<String>`；flutter_rust_bridge_codegen 2.13.0 重生成（含 `lib.dart`/`lib.freezed.dart`）。

Dart（数据链路批次）：
- `flutter/lib/src/app_model.dart`：`PlaylistKey(kind,source,id)`；`BrowseResult.appendArmed` + `_applyBrowseEvent` 过期/乱序/重复 append 丢弃；`prepareBrowseLoad`（返回已打开歌单首帧加载态不闪旧曲目）；`_PlaybackTickNotifier.playbackTick`（状态迁移仍全模型通知）；事件速率观测；**QA 轮追加**：`sanitizeUserFacingMessage` 公开化 + `_logAndSanitize`（URL 打码/空白折叠/截断 140，原始异常写 stderr），`_applyBrowseEvent` page=0 失败分支错误经 `_logAndSanitize` 落槽（:485）、成功分支 notice 同口径净化（:516）。
- `flutter/lib/src/services/artwork_resolver.dart`（新）+ `flutter/lib/src/design_system/components/vx_artwork.dart`（新）：§8.2 解析/缓存服务与统一封面组件。
- 六处封面反写修复：`home_page.dart`、`discover_page.dart`、`search_page.dart`、`playlist_detail_page.dart`（含 hero 收编）。
- 进度消费方迁移 playbackTick：`player_bar.dart`、`mini_player_bar.dart`、`progress_control.dart`、`lyrics_panel.dart`、`player_page.dart`、`mobile_now_playing_page.dart`、`now_playing_page.dart`（豁免名册见附录实施批次记录）。
- `flutter/lib/src/shell/android_insets.dart`（新）+ `mobile_shell.dart`：AnnotatedRegion/inset 契约；`live_progress.dart` 注释更正；`pubspec.yaml` +flutter_cache_manager ^3.4.8。

Dart（QA 修复批次，2026-11-11 入树）：
- **P1-08**：`search_page.dart` 结果行 `VxTrackRow` 补传 `cover: VxArtwork(url: song.coverUrl, ...)`（不再被渐变占位吞掉）。
- **P1-09**：`design_tokens.dart:148-157` 新增 `VxChrome`（`surface1(brightness)`/`divider(brightness)` 亮度双源取 token）；`app_header.dart`、`app_shell.dart`、`app_sidebar.dart`、`context_panel.dart`、`player_bar.dart` 全部 Chrome 底色/分隔线改经 `VxChrome`（浅色不再深底深字）。
- **P1-10**：`design_system/components/vx_player_controls.dart` 新增 `repeatSingle` 参数（单曲循环档 `Icons.repeat_one` + tooltip「单曲循环」、列表循环档 tooltip「列表循环」、none 灰色）；`player_bar.dart`/`now_playing_page.dart` 接线。
- **P1-11**：`search_page.dart` 错误框渲染前净化（第 1 轮），随后 `_applyBrowseEvent` 源头单点收口（第 2 轮，见「范围」3）。
- `song_tile.dart`：§8.5 收藏菜单/tooltip 文案改为「收藏（本地曲库）」（不假装远端账号红心）。

测试（当前工作区，本轮全套 246 项实跑全绿）：
- `test/playlist_detail_isolation_test.dart`（**9 项**）：§8.1 序列映射 + **新增序列 7**（:259 A 触底分页在途切 B，A 的迟到页 2 只落 A 槽不污染 B）+ **P1-11 回归**（:335 错误/notice 源头净化，原始 URL 不落槽不直出；测试 stderr 实见 `voicefox error(raw): network error: error sending request for url (http://wapi.kuwo.cn/...)`）+ 「返回已打开过的歌单：首帧加载态，不闪现旧曲目」（:378）。
- `test/search_page_test.dart`（13 项，含「P1-08 回归：结果行封面走 VxArtwork」「P1-07 同类缺口回归：错误框 detail 净化」）。
- `test/chrome_theme_test.dart`（新，5 项）：P1-09 回归，`VxChrome` 纯函数双侧取值 + AppHeader/PlayerBar/ContextPanel/AppSidebar/VoicefoxShell 真实组件在浅/深主题渲染色。
- `test/repeat_mode_test.dart`（新，4 项）：P1-10 三档视觉 + 循环点击顺序（经真实 PlayerBar 代码）。
- `test/error_toast_test.dart`（9 项，P1-07）、`test/artwork_widget_test.dart`（13 项）、`test/search_pagination_test.dart`（4 项，P1-04 + in-flight 锁）、`test/android_insets_layout_test.dart`（7 项，§10.1）、`touch_longpress_test.dart` 等小修。

文档：`04-defect-matrix.md`（本轮关闭 P1-08/P1-09/P1-10 复拍完成）、`screenshots/phase-1-mobile/README.md`（复验轮状态）、本报告。

## 关键设计决策

1. **P0-02 修复 = 进程级 owned runtime**：`new_desktop/new_host` 里 `ApplicationRuntime` 是局部变量，`Arc<Runtime>` 存进去几秒后 shutdown；OnceLock 进程级持有 + multi-thread flavor（泵任务会 await 同步 mpv FFI 与 JS 解析链）。
2. **进度拆分不切断状态通知**：`_applyPlaybackProgress` 比较 `event.playbackState`，变化则全模型 notify，纯位置变化只 fire playbackTick；状态消费者豁免/位置消费者迁移按名册处置。
3. **过期响应丢弃用 arm + 严格顺序页**：槽级 `appendArmed`（page1 置位）+ `event.page == slot.page+1` 校验；迟到/重复/跳页 append 全部丢弃且不改在途 loading 态。序列 7 将其扩展到「A 触底分页在途切 B」场景。
4. **错误消息「原始进日志、净化进 UI」单点收口**：`_applyBrowseEvent` 对 BrowseFailed 错误走 `_logAndSanitize`（原始异常写 stderr）、notice 过 `sanitizeUserFacingMessage`（不写 stderr），在事件入口一处修复，覆盖全部浏览消费面，避免每个渲染点各自打补丁。净化截断 140 字导致长 URL 错误显示为 `...for url ([URL]`（无闭合括号为纯文本截断的设计行为）。
5. **P1-09 收口用亮度双源 token 而非删常量**：`VxChrome.surface1/divider(brightness)` 深色侧仍返回原 `VxColors` 常量（深色像素零变化），浅色侧返回 `VxLightColors`，修复浅色可读性同时不扰动既有深色视觉。
6. **P1-10 三档循环独立视觉态**：单曲循环档 `repeat_one` 字形 + 独立 tooltip，激活归属可判定（截图与读屏均可用），辅以 `config.toml play_mode` 地面真值核对。
7. **§8.2 解析优先级裁剪**：本阶段落地 1/2/4/6 级；第 3 级（音源补全接口）与第 5 级（实体匹配）显式延后（需后端补全链路设计）。
8. **测试环境受限的替代验证**：TestWidgetsFlutterBinding 拦截真实 socket/图片编解码，网络用例走脚本化 FileService；渲染级两项锁定在 resolver/回调契约层。

## 数据流/交互变化

- 进度：4Hz PlaybackProgress → 状态迁移全模型重建、纯位置变化只重建进度条/歌词 ticker/迷你栏进度线。
- 浏览：过期/乱序/重复 append 响应被丢弃（含「A 触底分页在途切 B，迟到页 2 只落 A 槽」）；详情页重进首帧即加载态（不闪旧曲目）。
- 错误/通知：toast（lastError/lastNotification）、搜索页错误框、发现页/歌单页 BrowseResult.error 与 notice 全部在源头净化，UI 只见 `[URL]` 占位，原始异常仅 stderr 日志。
- 搜索：分页请求携带当前筛选 source；结果行封面走 VxArtwork（真实封面可渲染，失败有统一占位）。
- 封面：卡片统一 VxArtwork 路径（负缓存重试、限尺寸解码）。
- 主题：浅色主题下 AppHeader/Sidebar/ContextPanel/PlayerBar 底色/分隔线随亮度取 token，不再深底深字。
- 播放控制：循环三档（无/列表/单曲）视觉与 tooltip 独立可判。
- Android 触屏壳：状态栏/导航条图标颜色随主题亮暗翻转。

## 执行命令与退出码

下表区分「本轮报告员实跑」（2026-11-11 收口轮，`/home/emo/flutter/bin/flutter` 3.47.9 + rustup stable cargo）与「复验轮记录」（运行验证员会话，报告员以产物/日志佐证）。

| 命令 | 退出码 | 结果 | 执行者 |
|---|---|---|---|
| `flutter analyze --no-pub --fatal-infos`（flutter/） | **0** | No issues found!（2.1s） | 报告员本轮实跑 |
| `flutter test`（全套） | **0** | **246 passed / 0 failed**（含 isolation 9、chrome 5、repeat 4、search_page 13） | 报告员本轮实跑 |
| `flutter test test/playlist_detail_isolation_test.dart`（单跑） | **0** | **9 passed**（含序列 7、P1-11 回归、「返回已打开过的歌单：首帧加载态」） | 报告员本轮实跑 |
| `cargo test -p voicefox-runtime -p voicefox-application` | **0** | **72 + 40 passed**（1 ignored 既有；runtime 72 / application 40） | 报告员本轮实跑 |
| `dart format --output=none --set-exit-if-changed lib test` | **0** | 239 files, 0 changed | 报告员本轮实跑 |
| `cargo fmt --all -- --check` | **0** | 全绿 | 报告员本轮实跑 |
| `git diff -- runtime/ application/ ffi/ source/ core/` | n/a | **空**（Rust 零改动佐证） | 报告员本轮实跑 |
| `flutter build linux --release`（flutter clean 后全量重建） | **0** | bundle `flutter/build/linux/x64/release/bundle/`（04:23）在位、含 `libvoicefox_ffi.so`（报告员验证 mtime 与文件存在）；**cargo 必须在 PATH**：CMake 钩子 `find_program(cargo)` 依赖 PATH，缺失时 bundle 静默缺 libvoicefox_ffi.so，启动报 Failed to load dynamic library | 复验轮记录 |
| 实机复验会话（Xvfb :3/:5，1440x900，XTEST + 真实数据/离线 netns） | n/a | 见「视觉 QA 结果」 | 复验轮记录 |
| `cargo clippy`（降级基线 30 条 must_use） | n/a | **本轮未复跑**（Rust 零改动，沿用 Phase 0 基线结论，如实标注） | 未执行 |

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过/忽略 | 说明 |
|---|---|---|---|---|
| Flutter 全套 | **246** | 0 | 0 | 本轮报告员实跑 `flutter test`；246 为当前工作区全部入树测试计数（复验轮记录口径：245 + 复验轮新增 1；isolation 文件本轮 7→9：新增 §8.1 序列 7 与 P1-11 回归） |
| playlist_detail_isolation_test（单跑） | **9** | 0 | 0 | 含「返回已打开过的歌单：首帧加载态，不闪现旧曲目」 |
| cargo voicefox-runtime | **72** | 0 | 0 | 本轮报告员实跑 |
| cargo voicefox-application | **40** | 0 | 1 ignored（既有） | 本轮报告员实跑 |
| cargo clippy | n/a | n/a | n/a | 未复跑（见上表） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux release（flutter clean + 全量重建，含第 2 轮 Dart 修复） | 通过，exit 0；bundle（04:23）在位，`libvoicefox_ffi.so` 存在（报告员验证）。构建注意：cargo 须在 PATH，否则 CMake 钩子静默缺 FFI 动态库 |
| Android APK | 未构建：无 JDK、SDK 无 emulator/system-images（P1-06 环境阻断不变，用户已明确搁置） |

## 设备和视口

- Linux 桌面实机：Xvfb 受控显示器 :3/:5（无 WM，`VOICEFOX_START_SIZE=1440x900` 请求即所得），release bundle + XTEST 注入交互 + 真实数据（真实音源搜索/播放、真实本地导入、`sudo unshare -n` 仅回环 netns + `HOME=/tmp/vf-root` 离线实例的真实网络失败）。验证用实例与 Xvfb 已清理；`/home/emo/Music/voicefox-phase1` 真实测试音频与 `/tmp/vf-root`、`/tmp/vf-offline` 隔离 HOME 保留供后续批次复用。
- 手机/平板视口矩阵（§12.4）、Android 真机 13 项（§12.6）：**未验证**（无 JDK/设备/模拟器，P1-06；用户明确搁置）。`AndroidInsets`/`MobileShell` 仅有 widget 契约测试层覆盖。

## 截图路径

`docs/redesign/screenshots/phase-1-mobile/`（目录名沿袭计划，内容为 Linux 桌面 1440x900 实机证据，目录 README 有勘误说明）。本轮清单 **28 个文件**（README.md + 27 PNG），三组 mtime（报告员 `ls -la` 实测）：

- **04:26 重截（复验轮，受影响视口，7 个）**：`README.md`、`linux-discover-1440x900-error-retry.png`、`linux-search-1440x900-error-retry.png`、`linux-search-1440x900-recovered-results.png`、`linux-playlist-1440x900-detail-a-gufeng.png`、`linux-playlist-1440x900-detail-b-jingdian.png`、`linux-playlist-1440x900-reenter-a-isolated.png`。
- **03:17-03:57（P1-10 复拍，4 个）**：`linux-search-1440x900-repeat-mode-1.png`、`-repeat-mode-2.png`、`-repeat-mode-2-glyph.png`、`-repeat-singleloop-active.png`（激活态）。
- **02:43（上轮采集，17 个，mtime+size 与上轮一致，沿用既有检查结论，含进度线与 position/duration 成比例、repeat_one 蓝色字形唯一对应 single-loop 激活等像素级验证）**：`linux-home-1440x900-default.png`、`-firstrun-empty.png`、`-firstrun-empty-fullframe.png`、`-error-toast.png`、`-cover-cache-removed-placeholder.png`、`linux-discover-1440x900-default.png`、`linux-search-1440x900-loading.png`、`-results.png`、`-playing-00-02.png`、`-playing-00-23-progress.png`、`-playing-00-35-progress.png`、`-playing-seek-04-05.png`、`-shuffle-on.png`、`linux-localmusic-1440x900-imported-6.png`、`linux-playerbar-1440x900-ended-auto-next.png`、`-ended-replay-loop.png`、`linux-downloads-1440x900-empty.png`。

另有 Phase 1 桌面数据链路证据 `docs/redesign/screenshots/phase-1-desktop/`（00:09→00:29 走带，2026-11-10 批次）。

## 视觉 QA 结果

**QA 第 2 轮复查结论（复验轮记录）**：此前唯一维持开放的 P1（发现页/歌单页 `BrowseResult.error` 直出原始 URL）已关闭，修复在源头单点收口；**无 P0、无开放 P1；遗留 4 条 minor（上轮延续，无新增）**。

本轮报告员在最新 bundle 截图上目检核实（Read 工具实际查看图像）：

1. **发现页错误框净化（第 2 轮修复核心）**：`linux-discover-1440x900-error-retry.png`（04:26）错误框 detail 显示 `network error: error sending request for url ([URL]`，kuwo 原始 URL 不再直出，重试按钮在位，酷我/酷狗两段均为真实离线失败态。复验轮记录的 stderr 日志原始异常在位：`voicefox error(raw): ... https://u.y.qq.com/...` 与 `http://qukudata.kuwo.cn/...` 实测两条，**「原始进日志、净化进 UI」契约两端核实**（报告员另在隔离测试单跑中实测 stderr `voicefox error(raw): ... wapi.kuwo.cn/...`，契约在测试层同样成立）。搜索页错误框同为 `[URL]` 占位（第 1 轮修复保持）。
2. **重试闭环**：同 HOME 杀掉 netns 后在线重启 → 同查询 259 结果恢复（`linux-search-1440x900-recovered-results.png`，LOVE/3B LAB.☆ 行封面加载）。
3. **歌单隔离对照三连重截**：A 古风戏腔（104 首·400 分钟：牵丝戏/银临·Aki阿杰、唐人恋曲、戏文说、相思遥等，报告员目检确认）与 B 经典老歌大放送（183 首·771 分钟：倩女幽魂/张国荣、吻别/张学友、星语心愿/张柏芝、鬼迷心窍/李宗盛）曲目零交叉；重进 A 与首进逐行一致、无 B 残留。复验轮像素级实测：detail-a vs reenter-a **AE=0**、A vs B **AE=26830**，隔离在最新 bundle 上成立。
4. **P1-10 单曲循环激活态维持**：`linux-search-1440x900-repeat-singleloop-active.png`（03:57），报告员目检确认 repeat_one 字形 primary 蓝激活、真实播放走带（LOVE/3B LAB.☆ 00:12/05:42）；复验轮记录 `config.toml play_mode="single-loop"` 地面真值同落盘核对。
5. **P1-08 视觉佐证**：同截图搜索结果第 1 行（LOVE/3B LAB.☆）真实封面渲染，不再整列渐变/占位吞没。

## 新增/关闭缺陷

- **关闭（累计）**：P0-02（泵未启动）；P1-03（封面三元反写）；P1-04（SearchMore 丢 source）；P1-07（错误 toast 直出原始异常）；P1-08（搜索结果行封面缺失）；P1-09（浅色主题 Chrome 深底深字，含 P2-01 并入关闭）；P1-10（repeat 第 2 档视觉不可区分；激活态截图已补齐，复拍全部完成）；P1-11（搜索页 + 发现页/歌单页 BrowseResult.error 同类残余，源头单点收口）；P2-07（设置分类导航）；P3-01（注释债）；P3-03 落地（PlaylistKey + appendArmed + 序列 7，长期验证记录）。
- **仍开放**：P0-01（概率性卡死未复现未定位 + ButtonPress 间歇失效同域观察；本轮会话未复现，不构成修复证据）；P1-05（进程静默退出，同域疑云）；P1-06（Android 环境阻断，维持）；P2-02/03/04/05/06/08/09 与 P3-02/04/05/06/07（minor 档，与 QA「遗留 4 条 minor、无新增」口径一致）。
- **新登记**：无新缺陷。
- **Rust 侧另行维持开放**（非矩阵编号）：`proxy_url` 死代理在搜索/播放路径未生效的问题，本轮 Rust 零改动（git diff 为空），未复验 proxy 行为变化。

## 未解决问题和原因

1. **P0-01 主 isolate 概率性卡死（含 ButtonPress 间歇失效变体）未定位**：事件速率观测在位；复验轮会话未复现。概率性缺陷的「未复现」不构成修复证据；长时间会话验收前必须以 profiler/devtools 定位（嫌疑方向与复现步骤存档见 04 矩阵 P0-01 行）。
2. **P1-05 进程静默退出**：与 P0-01 同域疑云，一并跟进；本轮未复现。
3. **Android 全链未验证（P1-06）**：无 JDK、SDK 无 emulator/system-images，禁止 APK/Gradle 构建与 AVD 创建（用户明确搁置）；§10.1/§12.4 手机矩阵零运行时覆盖，widget 契约测试层已覆盖。
4. **本地音乐真实导入端到端**：登记延后至 Phase 5（§8.4/§5.10）；Phase 1 期间的 imported-6 截图为真实导入证据，离线播放链路归 Phase 5。
5. **cargo clippy 基线（30 条 must_use）本轮未复跑**；除「执行命令与退出码」表所列外未执行其他检查。
6. **`proxy_url` 死代理未复验**：Rust 零改动，行为与上轮记录一致，未重测。
7. **P1-09 浅色主题实机截图未在本轮矩阵重采**：收口由 `chrome_theme_test.dart` 5 项（真实组件渲染色）+ 代码链路锁定；浅色主题整页实机走查归 Phase 2/7 视觉批次。
8. **测试计数口径**：246 为当前工作区全套实跑硬数；各轮「245+1」等分解来自各轮记录，不作为独立复核对象。

## 下一阶段进入条件

- Phase 1 按执行追踪表口径标记**已完成**（数据链路修复与可修 P0/P1 全部收口）；**P0-01 定位、P1-05 同域跟进、Android 环境补齐（P1-06）为跨阶段遗留**，不阻塞 Phase 2 启动。
- Phase 2（MobileShell 和手机首页）可进入：数据正确性修复已合入且 246 项测试护航；建议 Phase 2 视觉批次顺带补浅色主题实机走查与 P1-09 对照截图。
- 长时间会话验收（30 分钟以上交互）前必须先跑 P0-01 profile 定位（观测点已就位）。

---

## 附录：批次与 QA 轮历史补记

### 2026-11-10 实施批次（原始记录要点）

- P0-02：FRB 同步引导路径无 ambient tokio → `start_playback_pump` 的 `Handle::try_current()` guard 静默 return → 泵从未启动。修复 = 进程级 owned runtime。实机验证（niri+xwayland，DISPLAY=:1）：启动日志含 `同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime` 与 `playback pump started`；播放真实音源后 `voicefox events: 19-24/5 s, last=progress`（约 4Hz）；PlayerBar 00:09→00:29 走带截图；曲目结束自动切下一首（Ended 恢复）。
- 门禁（该轮）：analyze 0 / flutter test 220 / cargo fmt 0 / clippy 30 条=基线 / cargo 72+40 / `flutter_rust_bridge_codegen generate` 0 / `flutter build linux --release` exit 0（3 次）。
- 评审修订并入：runtime 所有权落到进程级 OnceLock（非 ApplicationRuntime 字段）、进度拆分保留状态迁移全模型通知、enter 作用域覆盖 from_parts 全函数体、SearchMore 兜底先读后写、lib.dart/lib.freezed.dart 纳入清单。
- 进度消费方豁免名册：song_tile 均衡器/home Hero/now_playing 播放态（state 迁移全模型通知覆盖）、app_shell/player_page 快捷键、voicefox_audio_handler（Phase 4 链）、myune 投影（退役壳）、host_player_bridge（移动端 Phase 4）；mobile_shell.dart:351 AnimatedBuilder(model) 无需改动。

### QA 第 1/2 轮修复补记（2026-11-10）

- P1-07 修复：错误 toast 无高度上限且原始异常直出 UI；两层修复（`sanitizeUserFacingMessage` 源头净化 + vendored toast maxLines 4/maxHeight 160，本地改造已标注）；error_toast_test 9 项；全套 229 passed。
- phase-1-mobile 目录命名误导：README 勘误（内容为 Linux 桌面壳渲染，非手机证据）。
- §13「手机系统栏无重叠」widget 层 7 项测试通过；真机证据缺失（P1-06）。
- 运行时离线失败状态未复现（隔离 HOME + 死代理未被搜索路径生效，未深查），即 `proxy_url` 死代理问题由来。

### QA 第 3 轮修复补记（2026-11-11，视觉/数据 QA 复拍轮）

- P1-10 修复：QA 复拍轮判定原 repeat-mode-2.png 证据失实（两档循环共用 Icons.repeat 同为 primary 色，激活归属不可判定；且硬编码坐标点击随歌名宽度位移 ±45px）。修复 = `repeatSingle` 三档视觉 + repeat_mode_test 4 项。当时激活态截图因 ButtonPress 间歇失效未取得；**已于复验轮补齐**（`-repeat-singleloop-active.png`）。环境勘误：增量 release 构建的 MaterialIcons 字体子集陈旧致 repeat_one 字形缺失，`flutter clean` 重建恢复。
- P1-11 第一层修复：state.search.error 为 Rust 快照字段不经净化链路 → `sanitizeUserFacingMessage` 公开化 + search_page 渲染前净化 + 回归。
- P0-01 同域新观察：Xvfb :5 ButtonPress 对 PlayerBar IconButton 间歇失效（hover/渲染走带/事件流正常），与第一轮「输入全失效 + 帧差=0」症状不同；实例并存与增量构建陈旧等环境变量排除后仍复现。
- 门禁：245 passed / analyze 0 / dart format 0 changed / flutter build linux --release（clean 后）exit 0；cargo 零改动。

### QA 第 4 轮修复补记（2026-11-11，BrowseResult.error 同类残余收口）

- `_applyBrowseEvent` 源头收口（page=0 失败分支 `_logAndSanitize`、notice 同口径净化）；单点覆盖 discover/playlist/leaderboard/library/custom_playlists 全部消费面；实机复拍（`unshare -Urn` 离线实例 + Xvfb）错误框显示 `network error: error sending request for url ([URL]`；04 矩阵与 phase-1-mobile/README 同步更新为已修复。
- 净化截断口径（140 字）导致长 URL 错误显示为 `...for url ([URL]`，无闭合括号为设计行为（纯文本展示）。
- 门禁：全套 246 passed / analyze 0 / dart format 0 changed / flutter build linux --release exit 0；cargo 零改动（workspace 816 passed 口径 / clippy 30 条基线结论不变）。

### QA 修复批次补录（2026-11-11 入树；本报告复验轮逐项核实后关闭）

- P1-08：search_page.dart `VxTrackRow` 补传 `cover: VxArtwork(url: song.coverUrl, ...)`；回归 `search_page_test.dart`「P1-08 回归」（全套 246 内通过，报告员实跑）；实机目检搜索结果行真实封面渲染（repeat-singleloop-active.png 第 1 行）。
- P1-09：`VxChrome`（design_tokens.dart:148-157）+ app_header/app_shell/app_sidebar/context_panel/player_bar 色源收口；回归 `chrome_theme_test.dart` 5 项（真实组件浅/深渲染色断言，全套 246 内通过，报告员实跑）；浅色主题实机整页走查归 Phase 2/7（见「未解决问题和原因」7）。
- 此两项修复发生在 QA 轮间（入树未及登记），本轮以代码 diff + 回归测试 + 实机截图三重核实，现予补录关闭。
