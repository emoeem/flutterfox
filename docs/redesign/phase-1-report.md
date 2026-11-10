# Phase 1 Report（数据链路和 P0 修复）——进行中，本报告覆盖 2026-11-10 实施批次

> 分支：`feat/ui-redesign`　模板：指南 §14
> 评审修订已并入：runtime 所有权落到进程级 OnceLock（非 ApplicationRuntime 字段）、
> 进度拆分保留状态迁移全模型通知、enter 作用域覆盖 from_parts 全函数体、SearchMore
> 兜底先读后写、lib.dart/lib.freezed.dart 纳入清单、本地完整 flutter test 全套。

## 范围

Phase 1 实施批次完成：P0-02 根因修复+运行时验证、P1-03 六处封面反写修复 + ArtworkResolver/VxArtwork（§8.2 第一批）、P1-04 SearchMore 补 source、§8.1 PlaylistKey 类型化 + 过期响应丢弃、§8.3 进度重建隔离（4Hz 不再打满全模型）、§10.1 布局层 inset 契约 + AnnotatedRegion、P0-01 事件速率观测 instrumentation、四份新测试。

## 修改文件

Rust：
- `runtime/src/lib.rs`：`enter_sync_bootstrap_runtime()`（进程级 `OWNED_RUNTIME: OnceLock<Arc<Runtime>>`，multi-thread flavor，enter 覆盖 from_parts 全函数体）+ 2 个回归测试；泵/downloads 由此获得 tokio 上下文。
- `application/src/service.rs`：`start_playback_pump` 失败分支加 eprintln+tracing::warn（GUI 无 tracing subscriber，静默 return 是 P0-02 不可排查的根源）；`start_search` SearchMore 兜底**先读后写** `state.search.source`（append && source=None）；`playback_pump_broadcasts_progress_for_watch_changes` 回归测试。
- `ffi/src/lib.rs` + `ffi/src/api.rs`：`FfiCommand::SearchMore` 增加 `source: Option<String>`。
- `ffi/src/frb_generated.rs`、`flutter/lib/src/bridge/{frb_generated.dart,frb_generated.io.dart,frb_generated.web.dart,lib.dart,lib.freezed.dart,api.dart}`：flutter_rust_bridge_codegen 2.13.0 重生成（评审-6 预期的 lib.dart/lib.freezed.dart 确实被重写）。

Dart：
- `flutter/lib/src/app_model.dart`：`PlaylistKey(kind,source,id)` 类型化键；`BrowseResult.appendArmed` + `_applyBrowseEvent` 过期/乱序/重复 append 丢弃（迟到响应不改在途 loading 态）；`prepareBrowseLoad`（initState 同步清槽不通知，postFrame 派发——修复返回已打开歌单闪旧曲目，同时不触发 build 期 markNeedsBuild）；`_PlaybackTickNotifier.playbackTick`（纯 position/duration 变化只通知 tick，**状态迁移仍走全模型 notifyListeners**——buffering→Playing、Ended→Stopped 等自动迁移只经 progress 事件广播，评审-2）；事件速率观测（stderr，5s 窗口）。
- `flutter/lib/src/services/artwork_resolver.dart`（新）：§8.2 解析/缓存服务（cacheKey=source|type|id、TTL 30min、失败负缓存退避 n²·2s 上限 3 次、single-flight（http 走 cache manager）、限尺寸解码 decodeCacheWidth、markFetchFailed/markDecodeFailed/retry）。
- `flutter/lib/src/design_system/components/vx_artwork.dart`（新）：统一封面组件（占位/失败+重试/固定盒防跳动/语义标签/cacheManager 可注入）。
- 六处封面反写修复 + playlist_detail hero 收编：`home_page.dart`、`discover_page.dart`、`search_page.dart`（含 loadMore 传 source）、`playlist_detail_page.dart`。
- 进度消费方迁移至 playbackTick（评审-2/3 名册）：`player_bar.dart`（2px 线 + LiveSeekRow）、`mini_player_bar.dart`（2px 线）、`progress_control.dart`（LiveSeekRow 改订阅 tick，去掉 position/duration props）、`lyrics_panel.dart`（_LyricTicker）、`player_page.dart`（歌词视图 + 滑条区）、`mobile_now_playing_page.dart`、`now_playing_page.dart`。
  **豁免名册**（读 state 但不迁移）：song_tile 均衡器/home Hero/now_playing 播放态（state 迁移全模型通知覆盖）、app_shell/player_page 快捷键（事件期直读 state 恒新鲜）、voicefox_audio_handler（Phase 4 链）、myune 投影（退役壳）、host_player_bridge（移动端 Phase 4）。mobile_shell.dart:351 的 AnimatedBuilder(model) 无需改动——模型不再 4Hz 通知（评审-3 由设计消解）。
- `flutter/lib/src/shell/android_insets.dart`（新）+ `mobile_shell.dart`：`statusBarOverlayStyle`/`resolveInsetLayers`/`AndroidInsetsLayer`（AnnotatedRegion 随主题亮暗，§10.1 此前全 lib 无任何 SystemUiOverlayStyle）。
- `flutter/lib/src/widgets/live_progress.dart`：注释更新（4Hz 泵已存在，原「Rust 无周期性 position 事件」失真）；评审-14③ 采纳：durationMs 重锚未加（锚点与 duration 无关）。
- `flutter/pubspec.yaml`：+flutter_cache_manager ^3.4.8（VxArtwork cacheManager 类型 + 测试注入 FileService；lock 仅 1 行变动）。

测试（新增 4 文件 + 既有 2 处小修）：
- `test/playlist_detail_isolation_test.dart`（7 项，§8.1 8 步序列 widget 层映射）
- `test/artwork_widget_test.dart`（13 项，§8.2 清单；传输层脚本化 FileService——TestWidgetsFlutterBinding 拦截真实 socket/编解码）
- `test/search_pagination_test.dart`（4 项，P1-04 + in-flight 锁 + requestId 释放）
- `test/android_insets_layout_test.dart`（7 项，§10.1 布局契约 + 键盘明项 + AnnotatedRegion 契约）
- `test/playlist_detail_page_test.dart` 前置数据改为 pump 后注入（initState 同步清槽语义）；`test/playlist_detail_isolation_test.dart` 移除未用参数。

文档：`04-defect-matrix.md`（P0-02/P1-03/P1-04 关闭、P3-03 落地、Phase 1 条件核对更新）、本报告。

## 关键设计决策

1. **P0-02 修复 = 进程级 owned runtime**（评审-1）：`new_desktop/new_host` 里 ApplicationRuntime 是局部变量，Arc<Runtime> 存进去会在几秒后 shutdown；OnceLock 进程级持有 + multi-thread flavor（泵任务 advance_after_end 会 await 同步 mpv FFI 与 JS 解析链）。
2. **进度拆分不切断状态通知**（评审-2）：`_applyPlaybackProgress` 比较 `event.playbackState` 与旧 state——变化则全模型 notify，纯位置变化只 fire playbackTick。18 个 state.playback 消费文件按「状态消费者豁免 / 位置消费者迁移」名册处置。
3. **SearchMore 兜底先读后写**（评审-5）：`start_search` 在覆盖 `state.search.source` 前捕获旧值，避免兜底永远拿到 None。
4. **过期响应丢弃用 arm+严格顺序页**：BrowseLoaded 带 request_id 但 Dart 无法回查派发时 token（dispatch 无返回值），采用槽级 `appendArmed`（page1 响应置位）+ `event.page == slot.page+1` 校验；迟到/重复/跳页 append 全部丢弃且不改 loading 态。
5. **§8.2 解析优先级裁剪**：本批落地 1/2/4/6 级；第 3 级（音源补全接口，playback.rs:49 已有 get_cover_url 调用）与第 5 级（实体匹配）**显式延后**——需后端补全链路设计，避免本批扩散进 source crate。
6. **测试环境受限的替代验证**：TestWidgetsFlutterBinding 拦截一切真实 socket（HttpClient 恒 400）与真实图片编解码——网络用例走脚本化 FileService（WebHelper 去重/状态码分支为真实代码）；「本地封面真实渲染」「非图片真实解码」以 resolver 契约层锁定，渲染级登记待真机/桌面运行。

## 数据流/交互变化

- 进度：4Hz PlaybackProgress → 状态迁移时全模型重建、纯位置变化只重建进度条/歌词 ticker/迷你栏进度线（页面不再 4Hz 重建）。
- 浏览：过期/乱序/重复 append 响应被丢弃；详情页重进首帧即加载态（不闪旧曲目）。
- 搜索：分页请求携带当前筛选 source；聚合分页保持聚合。
- 封面：六处卡片从「永不显示真实封面」改为 VxArtwork 统一路径（负缓存失败重试、缩略图限尺寸解码）。
- Android 触屏壳：状态栏/导航条图标颜色随主题亮暗翻转（此前从未设置）。

## 执行命令与退出码

| 命令 | 退出码 | 结果 |
|---|---|---|
| `flutter analyze --no-pub --fatal-infos` | **0** | No issues found! |
| `flutter test`（全套） | **0** | **220 passed**（基线 189 + 新增 31；评审-7 要求的本地全套回归） |
| `cargo fmt --all -- --check` | **0** | 全绿 |
| `cargo clippy --workspace --all-targets`（降级基线） | **0** | **30 条 must_use 告警 = Phase 0 基线，零新增** |
| `cargo test -p voicefox-runtime -p voicefox-application` | **0** | 72 + 40 passed（+1 泵测试、+2 引导测试） |
| `cargo check -p voicefox-ffi --lib` | **0** | codegen 后编译通过 |
| `flutter_rust_bridge_codegen generate`（2.13.0） | **0** | 生成文件与手写枚举一致 |
| `flutter build linux --release` | **0**（×3 次） | bundle 用于运行时验证 |
| 运行时验证（release bundle，niri+xwayland，DISPLAY=:1） | — | 启动日志含 `同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime` 与 `playback pump started`；播放真实音源后 `voicefox events: 19-24/5 s, last=progress`（≈4Hz）；PlayerBar 位置实时走动（00:09→00:29 截图，`docs/redesign/screenshots/phase-1-desktop/`），曲目结束自动切下一首（Ended 恢复） |

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 说明 |
|---|---|---|---|
| Flutter 全套 | **220** | 0 | 含 4 个新文件 31 项；既有 189 项零回归 |
| cargo runtime/application | 72 + 40 | 0 | 含 3 个新回归测试；1 ignored（既有） |
| lx-source 已知 flaky | — | — | 未触碰（Phase 0 在案，本批未改 source crate） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux release ×3 | ✅ exit 0（本次未遇 CMake 缓存问题；rustup env 需 RUSTUP_HOME/CARGO_HOME） |
| Android APK | ❌ 未构建：无 JDK（P1-06 环境阻断，不变） |

## 设备和视口

- 桌面实机（niri+xwayland，DISPLAY=:1）：搜索→播放→进度→自动切歌全流程走通（约 3 分钟会话，**未复现 P0-01 卡死**——与「概率性」描述一致，不构成修复证据）。截图视口受 P2-04 合成器限制仍按实际渲染命名（1440x900 请求 / GL frame 948x1010）。
- 手机/平板视口矩阵、Android 真机 13 项：**未验证**（无 JDK/设备，P1-06 不变）。

## 截图路径

`docs/redesign/screenshots/phase-1-desktop/`（目录名偏离指南 §12.5 列举的 phase-1-mobile——本证据是桌面数据链路验证，如实命名）：
- `linux-search-1440x900-playing-00-09.png` / `…-00-29.png`：同一播放会话间隔 10s，位置走带 + Ended 自动切歌。

## 视觉 QA 结果

- PlayerBar 位置/时长/进度条实时走动（对照 Phase 0 的 00:00/--:-- 基线截图）。
- 歌单卡片/首页 Hero 封面改走 VxArtwork（截图未逐一回归——属 Phase 2/3 视觉批次；组件层 13 项测试锁定行为）。
- 未完成：浅色主题实机走查、手机视口截图（无设备）。

## 新增/关闭缺陷

- **关闭**：P0-02（泵未启动）、P1-03（6 处反写，含 2 处新发现）、P1-04（SearchMore 丢 source）、P3-03（类型化键+过期丢弃落地）、P3-01（cover_loader 注释并入 resolver，文件保留兼容）。
- **仍开放**：P0-01（instrument 已装：`voicefox events: N/5s` stderr 观测；本会话未复现卡死；根因未定位）、P1-05（同域）、P1-06（Android 环境阻断）。
- **新登记**：无新缺陷；评审-14① 勘误回应——`debugBrowseLoaded` 钩子存在（app_model.dart:949），本批新增的是 `debugBeginBrowse`（模拟刷新清槽，测试需要）。

## 未解决问题和原因

1. **P0-01 未定位**：事件速率观测已入码（stderr）；本会话实机搜索+播放未复现。评审-12 采纳：嫌疑列表剔除「4Hz 泵」（修复前泵未运行，不可能是旧卡死根因）；聚焦 257 行 setState、library 事件重取环、封面并发解码。**Phase 1 退出条件「P0 清零」未达成，不宣称完成。**
2. **本地音乐真实导入并播放未走通**：本机无媒体文件 + 会话时间用于 P0-02/P1-03/P1-04；登记延后至 Phase 5（§13 条件显式记录于 04 矩阵）。
3. **Android 全链未验证**：无 JDK/设备（P1-06）；§10.1 真机证据缺失，widget 契约测试已覆盖布局层。
4. **评审-8/9 部分项延后**：§8.2「离线状态」以脚本化 SocketException+负缓存覆盖、「本地 embedded artwork」以 resolver 契约+file:// 存在性覆盖；「首次加载/失败/重试截图」延后（P0-01 交互不可靠期间不承诺截图回归）；解析优先级 3/5 级延后（见决策 5）。
5. **并行实例冲突披露**：为消除 niri 多工作区点击路由歧义，终止了并行审计实例（PID 478147，app-run6.log，旧 bundle）；其观测结论与本次修复验证无依赖。
6. **search_page_test 未加 source 断言**：P1-04 回归由新文件 search_pagination_test 承担（4 项），未重复改动既有 11 项测试文件。

## QA 第 1/2 轮修复补记（2026-11-10，等门禁复检）

- **P1-07 已修复**（QA 新发现）：错误 toast 无高度上限且原始异常（含多音源 URL）直出 UI、遮挡 VxErrorState。两层修复：AppModel `sanitizeUserFacingMessage`（URL 打码/空白折叠/截断 140，原始异常 stderr 写日志，应用于 lastError/lastNotification 全部赋值点）+ vendored toast 兜底限高（maxLines 4、maxHeight 160，本地改造已标注）。回归 `error_toast_test.dart` 9 项全绿；全套 flutter test **229 passed**、analyze 0。运行时离线失败状态未复现（隔离 HOME + 死代理未被搜索路径生效，未深查），修复正确性由测试锁定——已在 04 矩阵 P1-07 声明。
- **P0-01/P1-05 维持开放**（QA 确认口径一致）：QA 2 分钟会话未复现（概率性），观测点在位（app_model.dart:248-258）。
- **phase-1-mobile 目录命名误导**：已加 README 勘误（内容为 Linux 桌面壳渲染，非手机证据；§12.4 手机/平板矩阵零覆盖，P1-06）。
- **§13「手机系统栏无重叠」**：widget 层 7 项测试通过（QA 实跑确认），真机证据仍缺失（P1-06）。
- **门禁数据更新**：flutter test 189→**229**（+9 toast、+4 隔离已在 220 计入、+…）；analyze 0；本批未触碰 Rust（此前 72+40/clippy 30 条结论不变）。

## 下一阶段进入条件

- Phase 1 **未整体退出**（P0-01 开放、本地导入未走通）：后续批次应先跑 P0-01 profile 定位（观测点已就位），再走 §13 退出核对。
- 视觉批次（Phase 2 MobileShell 等）可并行推进：数据正确性修复已合入且 220 项测试护航。
