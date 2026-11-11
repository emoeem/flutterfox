# 缺陷矩阵（04-defect-matrix，2026-11-10 第二轮全量复审）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §5/§6/§7/§8/§12.7，以当前工作区（feat/ui-redesign @ 5725231 + Phase 1 未提交改动）为准逐条验证。
- 更新（2026-11-11 复验轮）：P1-08/P1-09 关闭（QA 修复批次入树，代码 diff + 回归测试 + 实机目检三重核实）、P1-10 复拍全部完成（激活态实机截图补齐）；P1-11「同类残余」已于 QA 第 2 轮修复时改判已修复。本轮门禁（报告员实跑）：analyze 0 / flutter-test 246 / cargo-test 72+40 / dart-format 0 / cargo-fmt 0；Rust 零改动（git diff 为空）。
- 更新（2026-11-11 Phase 2 缺陷复验轮）：P1-12/P1-13 登记并关闭（QA 轮发现 → 本轮修复 + 三视口回归测试 + golden 重截目检三重复核，见 P1 节）；新登记 minor 两条（P2-10 入口卡标签截断、P3-08 旧 golden 截图未更新/数据种子不一致）。本轮唯一新增代码改动为 `library_page.dart`（430 视口库页标题折行修复，桌面 ≥512 渲染零变化）；受影响视口仅 library 430×932。报告员实跑定向 7 文件 51 项全绿（`00:05 +51: All tests passed!`）+ 重截 PNG（430x932）目检通过；全量门禁由外部门禁统一执行（本轮已知事实「门禁全绿」），报告员未复跑。Rust 零改动。详见 `docs/redesign/phase-2-report.md`。
- 更新（2026-11-11 Phase 3 实施轮）：P2-10 关闭（入口卡两行卡 + 同域两处潜在缺陷修复，见 P2 节）、P2-03 代码修复（实机复验待 QA）。Phase 3 净新增：搜索音源 chips 化（§5.4:355 裁决，search_page.dart:366 原下拉引 §4.3 属误引）+ 搜索历史（shared_preferences 本地持久化，容错降级，记录点=回车/历史项/Shell 种子）；曲库来源筛选 chips（favorites+history+localSongs 实际派生，组合规则登记于 library_page.dart 注释与 mobile_library_page_test）；三详情页下拉刷新（AppModel.awaitBrowseResponse 完成判据 = page1 响应或错误落槽，preset 页不接，15s 超时兜底）；收藏 pending 乐观态（成功确认走 `library` 事件 _refreshState 真实快照，失败经 dispatchWithError 回滚，pending 在途忽略再击；错误呈现仅全局 toast 一处）；发现页 P2-03 末 padding。定向 8 文件 71 项全绿（报告员实跑 `flutter test` 8 文件，`+71: All tests passed!`）；analyze 0；dart-format 0（6 文件规范化）；golden 重截 1 张（430x932，临时测试用后即删）；全量门禁由外部门禁统一执行，报告员未跑全量 flutter test/cargo test；Rust 零改动（FavoritePlaylistAdd/Remove 命令既有，bridge/lib.dart:328-333）。§5.3-5.6/§8.5/§9 已核验原文；§5.4 历史单项删除+清空确认、§9 破坏性操作确认均已落实。遗留：P0-01 开放、P1-06 Android 真机零覆盖维持、下拉刷新/收藏回滚/chips 交互实机走查未做（无 Android 环境）。
- 实机环境（本轮）：**Xvfb :2（1920x1080x24，无 WM）**，release 构建（`flutter build linux --release` exit 0），XTest 注入交互；另在 :1（niri 26.04 + xwayland-satellite）做窗口行为观察。第一轮会话（niri 全屏 1656x817）的证据仅标注引用，不冒充本轮复现。
- 更新（2026-11-11 Phase 3 收口轮）：P2-03 关闭（代码+测试层修复后经实机复验，见 P2 节）。收口证据（报告员实跑）：定向 10 文件 72 项全绿（`flutter test` 10 文件，`00:09 +72: All tests passed!` exit 0）+ playlist_detail_isolation_test 单独 13/13；`flutter build linux --release` exit 0（bundle 07:54 在位）+ Xvfb :99 实跑真实 Rust 数据源（~/.config/voicefox/config.toml，kw/酷狗/酷我真实联网非 mock），4 视口截图（library/search/playlist 390x844 + discover 360x800，`import -window`+magick 精确视口）逐张 QA 通过：无白屏/overflow/遮挡/封面错图；跨页一致（discover 古风戏腔 104首·酷我 ↔ playlist 详情同封面同来源，返回条全标题完整）；数据抽查 3 处一致（playlist_detail_page.dart:234-258 标题/计数/总时长绑定、library_page.dart:250-264 计数按源过滤、search_page.dart:485,495-519 计数与四态）；library 空态 Icons.music_off_outlined 正常渲染且文案逐字一致（song_table_view.dart:181 / library_page.dart:569）；search「网易云」chip 右缘裁切 = 横向滚动 ListView 设计行为（search_page.dart:443-444）；main.dart:163 minimumSize 临时放宽已精确还原（git diff 空）。阶段报告：`docs/redesign/phase-3-report.md`。遗留：P0-01 开放、P1-06 Android 真机零覆盖维持、交互式运行时手操/浅色主题（归 Phase 7）/golden 基线比对未做（如实登记）。Rust 零改动。
- 更新（2026-11-12 全屏播放页封面带修复轮，Phase 2 追加批次）：**P2-12 登记并关闭**（全屏播放页封面落 §5.7:446-447 280-340dp 自适应带，见 P2 节）、**P2-06 关闭**（封面横滑切歌 `_SwipeableCover`，速度阈值 500px/s + 方向提示层，只绑封面区避开 LiveSeekRow 横拖与屏幕缘返回手势 §5.7:459；真机边缘手势冲突验证 §5.7:463 维持未验证）；**P2-09 补记**：全屏播放页队列挂载形态已落 §5.7:452 底部 sheet（DragHandle 下滑/点遮罩关闭，queue_interaction_test 8 用例），拖拽排序/队内跳播维持开放（后端无 FfiCommand，如实禁用）。同批：歌词点击门槛（§5.7:461 无时间戳不挂 seek 并如实说明，lyrics_panel.dart）+ audio_session 中断处理与通知 artUri 守卫（voicefox_audio_handler.dart ±34；flutter/test 全目录 grep `VoicefoxAudioHandler|configureAudioService|interruption|artUri` 0 命中，无专项单测，真机音频输出/通知未验证，如实登记）。报告员实跑（本轮）：定向 4 文件 **39 项全绿**（`flutter test test/mobile_now_playing_layout_test.dart test/mobile_now_playing_test.dart test/mini_player_interaction_test.dart test/queue_interaction_test.dart --reporter compact`，`00:08 +39: All tests passed!` exit 0）+ 3 文件 --no-pub **32 项全绿**（`00:08 +32` exit 0）；golden 重截 fluttertest-nowplaying-{360x800,390x844,430x932}-dark-playing.png（临时测试用后即删，报告员 `git status --porcelain` 实查零残留），逐张目检 + magick 像素实测封面 **320/340/340** 与公式逐视口一致；上轮 library/emptyhero 复截件（61983B/100843B，01:53）复核维持关闭；release bundle 未重建（golden/测试同源编译，平台隔离 mobile_shell.dart:107-119 下桌面证据面不变，上轮 bundle 结论不失效）；Android 真机/浅色主题/全屏页桌面窗口呈现维持未验证。详见 `docs/redesign/phase-2-report.md` 追加批次节。Rust 零改动。
- 更新（2026-11-12 Phase 3 复验轮，验证收尾）：定向 10 文件基线复跑 72 项全绿（flutter/ 下 /home/emo/flutter/bin/flutter 3.47.9，`00:11 +72: All tests passed!` exit 0）；`search_page_test.dart` 新增 1 用例「防抖窗口紧界：250ms 未派发、300ms 恰好一次、350ms 无二次派发」（fake-time 虚拟时钟，注释锁定 search_page.dart:60 `debounceMs` 库内私有常量的硬编码耦合，不构成实机毫秒计时）后复跑 **73 项全绿**（`00:11 +73` exit 0）+ expanded 单跑 search_page_test 逐名核对（+14，两条防抖用例均在册）；dart format 1 文件规范化 + dart analyze 0（`No issues found!`）；phase-3-report.md 未做项口径同步改写（fake-time 锁常量 ≠ 实机毫秒计时，后者归 Phase 7 手操维持未做）。Rust 零改动；Android 真机（P1-06 维持）/浅色主题/交互式手操/golden 基线比对维持未验证如实登记。
- 更新（2026-11-12 Phase3-QA1 修复轮）：**P0 四态证据缺口补齐**（QA 视觉轮按本轮证据规则「测试缺失或未实跑 = P0」登记：曲库本地收藏空态「还没有收藏」test/ 全目录 grep 0 命中、红心镜像载入/错误+重试（library_page.dart:573-584）零断言、发现页骨架与「歌单加载失败」（discover_page.dart:496-518）零断言、专辑页错误态零断言）：补 6 条 widget 断言，曲库空态（mobile_library_page_test +1）、红心镜像载入态/错误态+重试（push_and_favorites_test +2，重试断言回到载入态）、发现页载入骨架/歌单错误+重试（discover_page_test +2，重试断言重新派发 PlaylistList）、专辑页错误+重试（artist_album_page_test +1）；定向 10 文件复跑 **79 项全绿**（`00:12 +79: All tests passed!` exit 0）+ dart format 4 文件（1 changed）+ dart analyze 0（`No issues found!`）；§13 Phase 3 退出条件「空/错/载/成功四态齐全」证据面由 search 四态用例扩展至曲库/发现/专辑（对照成立部分维持：search_pagination_test.dart:364、playlist_detail_page_test.dart:53/:81、playlist_detail_isolation_test.dart:409、custom_playlist_page_test.dart:108）。**同轮登记 4 张 Phase 3 证据截图重截**（QA 视觉轮发现复验轮重截未登记）：linux-{library-390x844-songs,search-390x844-results,playlist-390x844-detail,discover-360x800-default}.png mtime `stat` 实测 2026-11-12 03:23:45-03:25:31（+0800），归属复验轮批次，同管道同状态仅真实数据漂移（搜索 love/256 结果、快捷卡 22/0/0）；对照本矩阵 04:107 先例（无声替换判 P0）本案非证据质量劣化，判 P1 登记即关闭；phase-3-report.md 逐张 Read 目检复核（无白屏/overflow/遮挡，104 首·酷我跨页一致仍成立）并同步四处口径（勘误节 + 设备视口节 + 截图路径节 + 视觉 QA 第 5 条）。Rust 零改动。
- 更新（2026-11-12 Phase3-QA 复查轮，修复验证与重截）：QA1 轮两条登记均经本轮复查确认关闭。**P0（四态证据缺口）关闭**：6 条 widget 断言全部在位（报告员 `git diff` 逐名核对：曲库本地收藏空态「还没有收藏」、红心镜像载入态/错误态+重试回载入态、发现页载入骨架/歌单错误+重试重新派发 PlaylistList、专辑页错误+重试回「加载中…」），定向 10 文件 79 项全绿双实跑（QA 独立 `00:10 +79: All tests passed!` exit 0，ask 记录；报告员复跑 `00:14 +79` exit 0；4 改动文件 24 项双实跑：实施者 `00:02 +24`、报告员 `00:05 +24`），§13「四态齐全」证据面扩展至曲库/发现/专辑；**P1（4 张证据截图重截未登记）关闭**：phase-3-report.md 勘误节登记（mtime/归属/非劣化判定）+ 四处口径同步（love/256、快捷卡 22/0/0）+ 本矩阵与指南 §17 同步。同轮：release 重建 exit 0（`✓ Built bundle/voicefox_flutter`，03:52:19 在位；lib/ 零改动内容等价重建，`git diff HEAD -- flutter/lib` 实测空）+ Xvfb :99 受影响视口（曲库/发现/专辑，对应四个被改测试文件的页面）重截 3 张（library 03:52:44/discover 03:53:09/album 03:56:16 新增；数据全真实：专辑 20/歌手 17/最近播放 22 首、酷我/酷狗真实分类与封面；search/playlist 03:24 版本未动）逐张 Read 目检通过：专辑详情为真实错误态+重试实拍（九点九/Aling贝多/千千音乐真实封面，操作钮明确禁用，§9 符合）。**登记未验证**：专辑详情成功态（曲目列表渲染）实机未取得，种子路径 5 次尝试均未成功（登记在案返回：kw 源真实「加载失败 not found」×2、wy 落汽水音乐「该音源不支持专辑」×1），疑真实音源数据缺口或种子源映射问题，保留真实错误态+重试为证（即新增断言对象）；VOICEFOX_START_SOURCE 专辑种子疑似未生效（SOURCE=kw→千千音乐徽标、SOURCE=wy→汽水音乐徽标），仅登记观察未判缺陷未修。残留 minor 4 条：第 5 张专辑截图上轮未登记（报告本轮补登记）且「仅此 4 文件」口径失实（已同步）、QA1 勘误 mtime 对 library/discover 2 张过期（本轮重截所致）、专辑错误态直出原始「not found」串可读性、bottom inset 未断言。进程清理复核（报告员 pgrep）：无 :99/voicefox 残留（仅存并行会话 Xvfb :3 非本轮产物）。Rust 零改动。
- 评级口径（§12.7）：P0 数据错乱/播放不可用/崩溃；P1 核心操作无法完成/封面普遍缺失/关键页面不可用；P2 视觉与次要功能缺口；P3 可选增强/文档债。
- 基线事实与门禁数据：`docs/redesign/00-baseline.md`（§3 门禁、§9 播放链、§10 封面链）。

---

## P0（阻断级）

### P0-01 主 isolate 概率性卡死（搜索结果/播放后 UI 全死）——【开放；本轮未复现】

- **状态**：开放。第一轮会话 5 实例 3 复现（搜索结果到达后或播放启动后输入全失效、帧差=0）；**本轮 Xvfb 会话约 8 分钟全流程交互（搜索 259 结果渲染、双击播放、走带 3 分钟、队列/全屏播放页/五个页面导航/主题切换）未复现一次**。概率性缺陷的「未复现」不构成修复证据，根因仍未定位（Phase 1 加的事件速率观测 `voicefox events: N/5 s` 本轮持续输出正常，无洪泛/静默异常）。
- **第一轮复现步骤（存档，非本轮复现）**：release 构建 + `VOICEFOX_START_PAGE=search VOICEFOX_START_SEARCH=love` 启动 → 等待结果渲染 → XTest 点击任意行/侧栏 → 无响应；`x11tool key Tab` 两次后 `magick compare -metric AE f1.png f2.png` = 0。
- **影响**：用户视角=应用随机整体无响应；截图回归/交互验收在此缺陷未定位前对「长时间会话」不可信。
- **嫌疑方向（未定罪）**：AppModel 事件泵热路径（搜索结果 setState）、progress 4Hz 泵、library 事件 `_reloadCustomPlaylistDetails/_reloadAccountBrowse` 重取循环；需 profiler/devtools 定位。
- **2026-11-11 QA 复拍会话新增观察（同域，变体症状）**：Xvfb :5 多轮 boot 实测，ButtonPress 点击对 PlayerBar IconButton 间歇性完全失效（repeat/shuffle/pause 均复现），同期 hover 高亮与 tooltip 正常、进度渲染走带正常（AE 帧 diff ≠ 0）、事件流正常（19-24/5s），与第一轮「输入全失效 + 帧差=0」症状不同：渲染存活、仅按压失效；且同会话内行双击/next 按钮偶发有效，行为非确定性。两个实例并存、增量构建陈旧等环境变量已逐一排除（清理后仍复现）。定位优先级维持：长时间会话验收前必须定位。

### P0-02 播放中 position/duration 恒 0——【已关闭，Phase 1；本轮实机复核通过】

- **根因与修复**（Phase 1）：FRB 同步引导路径无 ambient tokio → `start_playback_pump` 的 `Handle::try_current()` guard 静默 return → 泵从未启动。修复 = `runtime/src/lib.rs:22-32` `enter_sync_bootstrap_runtime()`（进程级 `OnceLock<Arc<Runtime>>`，enter 作用域覆盖 `from_parts` 全函数体）。
- **本轮实机复核（Xvfb :2，release）**：
  1. 启动日志 `voicefox: 同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime` + `voicefox: playback pump started`（app-run3.log）。
  2. 双击搜索行播放 L-O-V-E（汽水）：PlayerBar `00:02 / 00:30`（docs/redesign/screenshots/baseline/linux-search-1440x900-playing-00-02-progress.png）。
  3. 曲目结束**自动切换下一首**：LOVE/Aki阿杰·5sing `00:00 / 02:34`（…ended-auto-next-00-00.png）——Ended 自动下一首同时复核通过（旧 P0-03 行为）。
  4. 26 秒后 `00:26 / 02:34` 走带（…00-26-progress.png）；stderr `voicefox events: 19-22/5 s, last=progress`（≈4Hz）。
- **回归测试**：runtime `sync_bootstrap_path_provides_tokio_context` / `ambient_runtime_path_is_untouched`；application `playback_pump_broadcasts_progress_for_watch_changes`（cargo-test 816 全绿内）。

## P1（功能缺口）

### P1-03 封面三元反写（有 URL 显示渐变占位）——【已关闭，Phase 1；本轮实机复核通过】

- **关闭证据（本轮）**：反写模式（`? null : CoverImage`）全仓 grep 为零；home/discover/search(专辑歌手网格)/playlist_detail 共 7 处走 `VxArtwork` + `ArtworkResolver`（负缓存/退避/TTL/单飞/限尺寸解码，13 项 artwork_widget_test 全绿）。
- **实机复核**：发现页酷我/酷狗热门歌单卡 12+ 张真实封面全部渲染（linux-discover-1440x900-default.png）；队列面板 2 行真实封面；首页最近播放本地曲「晴天」真实照片封面（linux-home-1440x900-playing.png）。
- **范围声明（维持）**：§8.2 解析优先级第 3 级（音源补全接口）与第 5 级（可靠实体匹配补全）未实现（后端补全链路依赖，phase-1-report 登记）；渲染级两项（本地封面真实解码/非图片字节真实解码）由 TestWidgetsFlutterBinding 环境所限，锁定在 resolver/回调契约层。

### P1-04 搜索「加载更多」丢失音源过滤——【已关闭，Phase 1；本轮代码+测试复核通过】

- **修复**：`FfiCommand::SearchMore` 带 `source: Option<String>`（ffi/src/lib.rs:1339-1345）；search_page `_loadMoreIfNeeded` 传 `_dispatchSource`；Rust `start_search` append 且 source=None 时**先读后写**沿用 `state.search.source`（application/src/service.rs:1462-1484）。
- **回归**：flutter/test/search_pagination_test.dart 4 项（本轮 flutter-test 229 全绿内）。
- **诚实标注**：本轮实机未做触底多页交互观察；正确性由代码链路核对 + 测试锁定。

### P1-05 进程静默退出（无崩溃日志）——【开放；本轮新增 1 例观察】

- **本轮观察（新增）**：:1 会话实例（run1）在经 xwayland-satellite 转发的 X 客户端 configure resize（1212x1274→1600x950→1920x1080，间隔数分钟）并出现 `Timed out waiting for OpenGL frame of size 948x1010 (have 1440x900)`（app-run1.log 23:35:38）后，数分钟内进程消失（pgrep 空、X 窗口消失）；日志无 panic、无 core dump（/var/lib/systemd/coredump 仅 vinput-daemon 旧核）、journal 无条目。
- **复现步骤（本轮实际操作）**：niri :1 会话启动 release 应用 → 对 X toplevel 连续 `XResizeWindow`（python-xlib configure）→ 等待 GL frame timeout → 数分钟内 `pgrep -f voicefox_flutter` 为空。
- **诚实声明**：触发链含非用户常规操作（X 客户端直发 configure 经 satellite 转发）；niri IPC 全屏路径（第一轮）与本轮 Xvfb 会话均未复现进程消失。与 P0-01 同域疑云（同属静默死亡），Phase 1 后续需一起定位；正常运行路径下的第一轮复现步骤（搜索+播放后停留，进程消失）保留。

### P1-06 Android 全链不可构建/未验证（环境阻断，非代码缺陷）——【维持】

- 无 JDK、SDK 无 emulator/system-images、adb 无设备 → `flutter build apk` 与真机/模拟器验证均无法执行；用户已明确搁置 Android 验证（禁止 APK/Gradle 构建与 AVD 创建）。指南 §5/§10/§12.6 真机 13 项全部未验证；MobileShell/TabletShell/AndroidInsets 仅有 widget 测试层覆盖（android_insets_layout_test 7 项）。

### P1-07 错误 toast 无高度上限且原始异常直出 UI——【已关闭，Phase 1；维持关闭声明】

- 修复两层（AppModel `sanitizeUserFacingMessage` 源头净化 + vendored toast maxLines 4/maxHeight 160）本轮代码复核在位（app_model.dart:1184-1208、toast_notification_widget.dart:69,104）；error_toast_test 9 项全绿。
- 运行时复现声明（维持）：离线失败状态未在运行时强造（隔离代理配置未生效，QA 环境失败条件不可复现），正确性由测试锁定。

### P1-08 搜索结果歌曲行封面普遍缺失（VxTrackRow 调用点漏传 cover）【已关闭，QA 修复批次 2026-11-11；代码+回归+实机三重复核】

- **现象**：搜索结果列表全部 259 行封面均为「渐变 + 首字母」占位，即使 DTO 带真实 cover_url。
- **根因**：`search_page.dart:550-568` 的 `VxTrackRow(...)` 未传 `cover:` 参数 → 组件缺省渲染 `VxCoverFallback`（vx_track_row.dart:166 `cover ?? VxCoverFallback(title)`，渐变首字母是 Phase 0 设计占位）。对照正确写法：`song_tile.dart:233` 同组件传了 `cover: CoverImage(url: song.coverUrl, size: 40, radius: 6)`。
- **实机对照证据（同一首歌、同一数据源）**：Love/Cloudy Skies（千千音乐）在搜索列表为渐变「L」占位（linux-search-1440x900-results.png），在队列面板显示真实封面（linux-queue-1440x900-playing.png 第 8 行，queue_panel.dart:208 CoverImage）。
- **复现步骤**：启动应用 → 搜索任意关键词 → 观察结果行封面：无一显示真实图片；播放其中一首 → 打开队列面板 → 同曲显示真实封面。
- **影响**：§12.7「封面普遍缺失」在搜索这一核心路径成立；§8.2「页面散落不同 fallback 决策」的活证据（同一 VxTrackRow，封面行为由调用点各自决定）。
- **修复（QA 修复批次 2026-11-11 入树，复验轮补录）**：search_page.dart 结果行 `VxTrackRow` 补传 `cover: VxArtwork(url: song.coverUrl, ...)`，行封面统一走 VxArtwork 路径（负缓存/失败占位/重试与全仓封面策略一致）。
- **回归**：`search_page_test.dart`「P1-08 回归：结果行封面走 VxArtwork，song.coverUrl 不再被渐变占位吞掉」（全套 flutter test 246 项内通过，2026-11-11 报告员实跑）。
- **实机复核（复验轮）**：`linux-search-1440x900-repeat-singleloop-active.png` 第 1 行（LOVE/3B LAB.☆）真实封面渲染（报告员目检），不再整列渐变/首字母占位。

### P1-09 浅色主题下 Shell Chrome 对比度破坏（导航/播放栏文字不可读）【已关闭，QA 修复批次 2026-11-11；代码+回归复核；P2-01 并入本行一并关闭】

- **现象**：设置 → 外观 → 明暗模式切「浅色」后：内容区（页面/卡片）正确变浅，但 **AppHeader、Sidebar、PlayerBar 背景仍是硬编码深色（VxColors.surface1 等）**，而其内部文字/图标颜色切为浅色主题的 onSurface（深色）→ 深底深字，左侧导航文字、左上角品牌字标、PlayerBar 歌名几乎不可读。
- **根因**：shell 组件无条件引用 `VxColors`/`VxDarkSurface` 硬编码深色常量（app_header.dart 4 处、app_shell.dart:481/571、app_sidebar.dart、context_panel.dart、player_bar.dart:76 等；唯 theme-aware 的是 player_bar.dart:177 seekTrack 三元）；MaterialApp 真源是 myune ThemeProvider `ColorScheme.fromSeed`（main.dart:384-386），Chrome 背景不走 ColorScheme。违反 §3.2「不使用硬编码页面颜色，全部从 Theme/ColorScheme token 获取」与「浅色主题必须完整支持」、§11.2 对比度 ≥4.5:1。
- **复现步骤**：启动应用 → 设置 → 外观 → 明暗模式点「浅色」→ 观察 Header/Sidebar/PlayerBar（截图 docs/redesign/screenshots/baseline/linux-settings-1440x900-light-theme.png）。
- **影响**：浅色主题下全局 Chrome 可读性破坏 → 「浅色主题完整支持」验收不成立。评级 P1（关键页面不可用级别的主题形态）。
- **修复（QA 修复批次 2026-11-11 入树，复验轮补录）**：`design_tokens.dart:148-157` 新增 `VxChrome`（`surface1(brightness)`/`divider(brightness)` 亮度双源：深色侧仍返回原 VxColors 常量、浅色侧返回 VxLightColors，深色像素零变化）；app_header/app_shell/app_sidebar/context_panel/player_bar 全部 Chrome 底色/分隔线改经 VxChrome。
- **回归**：`chrome_theme_test.dart` 5 项（VxChrome 纯函数双侧取值 + AppHeader/PlayerBar/ContextPanel/AppSidebar/VoicefoxShell 真实组件浅/深渲染色断言；全套 flutter test 246 项内通过，2026-11-11 报告员实跑）。
- **诚实标注**：浅色主题整页实机走查与对照截图本轮未重采（归 Phase 2/7 视觉批次）；收口由代码链路 + 真实组件渲染色测试锁定。

### P1-10 repeat 模式第 2 档（单曲循环）视觉不可区分 + QA 截图证据失实（QA 2026-11-11 复拍轮）【已关闭，复拍全部完成】

- **现象（QA 复拍轮登记）**：`repeat-mode-2.png` 原采集实际渲染非激活态（图标灰 rgb(167,168,177)）而非预期单曲循环激活态；根因有二：(a) 代码层两档循环共用 `Icons.repeat` 且同为 primary 色，激活态归属不可判定；(b) 采集点击硬编码坐标，实测 PlayerBar 控制列随歌名宽度位移 ±45px，点击可落旧位置。
- **修复**：`VxPlayerControls` 新增 `repeatSingle` 参数（vx_player_controls.dart），single-loop 档渲染 `Icons.repeat_one` + tooltip「单曲循环」，list-loop 档 tooltip「列表循环」，none 档灰色「循环播放」；`player_bar.dart`/`now_playing_page.dart` 接线。回归 `repeat_mode_test.dart` 4 项（三档视觉 + 循环点击顺序经真实 PlayerBar 代码）。
- **复拍状态（全部完成，2026-11-11 复验轮）**：`repeat-mode-1.png`（list-loop 激活：播放中 + config.toml 地面真值 + primary 蓝采样 + tooltip）；`repeat-mode-2.png`/`-glyph.png`（single-loop：config 地面真值 + repeat_one 字形 + tooltip「单曲循环」）；**激活态已补齐**：`linux-search-1440x900-repeat-singleloop-active.png`（03:57，真实播放中 repeat_one 字形 primary 蓝激活，报告员目检确认；复验轮记录 config.toml `play_mode="single-loop"` 落盘核对），激活态不再仅由测试锁定。
- **环境勘误**：增量 release 构建的 MaterialIcons 字体子集陈旧导致新字形（repeat_one）不渲染，`flutter clean` 重建恢复（详见 phase-1-mobile/README.md）。

### P1-11 搜索页错误框直出原始 URL/异常（P1-07 同类新表面，QA 2026-11-11）【已修复】

- **现象**：`linux-search-1440x900-error-retry.png` 错误框 detail 直出 migu 原始 URL；`state.search.error` 为 Rust 快照字段，不经 `lastError/lastNotification` 净化链路（app_model.dart:265-270 search 事件仅 `_refreshState`）。
- **修复**：`AppModel.sanitizeUserFacingMessage` 公开化（app_model.dart），`search_page.dart` 错误框渲染前净化（URL 打码/空白折叠/截断 140，与 P1-07 toast 同口径）；原始异常仍在命令/事件层写 stderr。
- **回归**：`search_page_test.dart`「P1-07 同类缺口回归」（原始 URL 不得直出、[URL] 占位呈现）。
- **同类残余（QA 第 2 轮 2026-11-11 确认后已修复）**：发现页/歌单页 `BrowseResult.error` 直出（`_applyBrowseEvent` page=0 分支原样落槽）已在本轮修复：错误与 notice 均在 `_applyBrowseEvent` 源头净化（app_model.dart，单点收口覆盖 discover/playlist/leaderboard/library/custom_playlists 全部消费面），错误走 `_logAndSanitize`（原始异常写 stderr）；回归 `playlist_detail_isolation_test.dart`「P1-11 回归」；实机复拍 `linux-discover-1440x900-error-retry.png`（离线 netns 实例，错误框显示 `([URL]`，原始 URL 仅在 stderr 日志）。

### P1-12 曲库页 430 视口「我的音乐」h1 标题折行（Phase 2 QA 轮发现）【已关闭，缺陷复验轮 2026-11-11】

- **现象**：曲库页 header 标题「我的音乐」与定宽 200 搜索条 + 筛选/刷新/视图图标同 Row，430 视口下 h1 仅剩 90px，必折两行（「我的音/乐」）；360 视口更挤。
- **修复**：`library_page.dart` `_header` 改 `LayoutBuilder`（:81），`maxWidth < 512` 走标题独占一行 + compact 工具行（:88，分界由最宽工具档「专辑/歌手 360px 需 ≥505.6」反推），title 加 `maxLines: 1` + ellipsis（:91，结构上不可能再折行）；`_tools` 增加 `compact` 参数（:301），compact 时搜索框改 `Expanded` 弹性宽度（固定 200 在 360 视口专辑/歌手档会横向溢出）；**≥512 保持原 Row 桌面渲染零变化**。
- **回归**：`mobile_shell_test.dart:173`「窄视口曲库布局：标题单行不折行、各档工具条无横向溢出（Phase 2 QA P1 回归）」，遍历 430×932 / 390×844 / 360×800 三视口进曲库页断言（上一轮「窄视口曲库布局无测试覆盖」缺口同步补上）；定向 7 文件 51 项全绿（2026-11-11 报告员实跑）。
- **重截目检**：`fluttertest-library-430x932-dark-default.png`（430x932 dpr=1.0 golden 重截，临时测试已删零残留）中「我的音乐」单行、搜索条 + 筛选/刷新整行移至第二行（报告员目检）；受影响视口仅此一张，home 两视口不含库页不受影响。
- **证据勘误与复截（2026-11-12 Phase 2 QA 修复轮）**：上条所述 06:34 批次 golden（48831B）在 610d6d8（phase 3 提交）中被无声替换为「页面级 pump LibraryPage + 未注入 CJK 字体」版本（18496B，mtime 11-11 07:29）：该版本全部文字渲染为空心方框、底栏与「我的音乐」高亮不在画面内，规格要素无法核对，本行与 P2-10 对该文件的目检结论对该版本不成立（Phase 2 QA 轮 2026-11-12 判 P0）。已按 06:34 批次口径复截（临时测试 pump 真实 MobileShell、底栏第四入口切库页断言 selectedIndex==3、430×932 dpr=1.0、深色主题、规格要素断言通过后才捕获，用后即删零残留）：现文件 **61983B，mtime 11-12 01:53**。字体口径实测更正：NotoSansCJK .ttc 在 flutter_tester `loadFontFromList` 下静默加载失败（advance 为 .notdef），且家族内混入 Roboto 时 w400/w700 CJK 落回测试字体方框；改注入本机 MiSans 单源全覆盖 face（Regular/Medium/Semibold/Bold OTF，Latin+CJK 同 face）+ JetBrainsMono（pubspec 资产）+ MaterialIcons（SDK 缓存），与 phase-2-report.md:30「Noto Sans CJK」口径的差异如实登记。复截目检（修复轮实看图像）：「我的音乐」单行、入口卡标签完整（最近播放/本地音乐/喜欢的歌曲，两行卡形态）、分类 chips 歌曲/专辑/歌手/歌单、来源分段与来源 chips（全部来源/网易云/QQ/本地音乐）、底栏第四入口「我的音乐」高亮，均清晰可核对；debug banner 已按运行时口径关闭（MaterialApp debugShowCheckedModeBanner=false）。定向回归 mobile_library/mobile_home/mobile_shell 三文件 18 项全绿 + flutter analyze 0 issue（2026-11-12 修复轮实跑）。

### P1-13 首页空库 Hero 两 CTA 横排折行（Phase 2 QA 轮发现）【已关闭，缺陷复验轮 2026-11-11】

- **现象**：空库 Hero「搜索音乐」「导入本地音乐」两按钮横排等分，390 视口每按钮仅 ~149px，按钮文字词中断行。
- **修复**：`mobile_home_page.dart:152-167` 改竖排 Column 两全宽按钮（`width: double.infinity`；FilledButton「搜索音乐」在上、OutlinedButton「导入本地音乐」在下，各 ~280-310px 单行容纳），横排等分宽度不足的成因已消除，触控目标同步增大（§5.9）。
- **回归**：`mobile_home_page_test.dart:176-208`「窄视口 390：两 CTA 竖排全宽，按钮文字单行不折行（Phase 2 QA P1 回归）」，断言两按钮宽 >280、纵向排列（导入在上之下）、label 高 <30 单行；定向 7 文件 51 项全绿（2026-11-11 报告员实跑）。
- **诚实标注**：该文件为未跟踪新文件、无 git diff，以当前源码 + 回归测试为准；无独立 golden（首页空库态以 390×844 emptyhero 既有截图与测试覆盖）。
- **golden 证据闭环（2026-11-12 Phase 2 QA 修复轮）**：上条所引 390×844 emptyhero 截图（06:04 批次）停留修复前横排形态（「导入本地音/乐」词中断行，phase-2-report.md「沿用」即证据层未闭环，本轮判 P1）。已随当前代码复截：同库页口径（真实 MobileShell + MiSans/JetBrainsMono/MaterialIcons 注入 + 深色主题 + debug banner 关闭，390×844 dpr=1.0），断言两 CTA 宽 >280、竖排、label 高 <30 单行通过后才捕获；现文件 **100843B，mtime 11-12 01:53**，目检两 CTA 竖排全宽单行（搜索音乐在上、导入本地音乐在下），与 mobile_home_page.dart:152-167 一致。

## P2（登记）

| ID | 问题 | 证据 | 指南条款 |
|---|---|---|---|
| P2-01 | 【已关闭，随 P1-09 关闭（2026-11-11 复验轮）】VxColors/VxDarkSurface 硬编码深色常量被 shell 组件无条件引用；已收口为 VxChrome 亮度双源 token（design_tokens.dart:148-157，浅色侧 VxLightColors，深色像素零变化） | chrome_theme_test 5 项 + 代码 diff | §3.2 |
| P2-02 | 双 ThemeData 产源：运行时真源 = myune ThemeProvider；`design_system/voicefox_theme.dart` buildDark/LightTheme 仅 Gallery 页与测试使用（当前只有一套运行时真源，风险受控） | grep buildDarkTheme 调用点 | §1.2-4 |
| P2-03 | 【已关闭（2026-11-11 Phase 3 收口轮）】发现页/首页横向书架最右卡被窗口右缘裁切：`discover_page.dart` `_playlistGroup` 水平 ListView 补末尾 `padding: EdgeInsets.only(right: VxSpacing.lg)`（:530-535），滚动到末尾不再贴边裁切 | discover_page.dart:530-535 代码 diff + 实机截图 linux-discover-360x800-default.png（真实后端运行，默认滚动位右缘可见卡完整渲染无溢出，报告员目检）+ 收口轮 QA 逐张复核；横滑到末尾的末态未单独手势演练，由 ListView 末尾 padding 语义结构性保证（如实登记） | §12.5 |
| P2-04 | 窗口尺寸契约在 niri 下不可靠：请求 1440x900 实得 tile 1212x1274（surface 948x1010，<960 触发降级布局）；Xvfb 下请求即所得。验收截图须在受控显示器采集 | 第一轮 + 本轮 :1 观察；本轮 Xvfb 对照 | §12.4 |
| P2-05 | 桌面系统集成（MPRIS/托盘/系统通知）GUI 未接；Rust 侧 app/src/mpris.rs 存在 | 代码 | §12.6-8 |
| P2-06 | 【已关闭（2026-11-12 封面带修复轮）】移动全屏播放页封面横滑切歌已落地：`_SwipeableCover` 只绑封面区（避开 LiveSeekRow 横向拖动与屏幕左右缘系统返回手势，§5.7:459），速度阈值 500px/s 滤误触，左滑 next/右滑 previous 走 AppModel 真实命令，拖动中方向提示层随 Cancel/End 整体移除不残留 hit-test 区 | mobile_now_playing_test.dart group「封面横滑切歌（P2-06，§5.7 只绑封面区）」4 用例（左滑 next/右滑 previous/慢速不切/方向提示可见反向切换 Cancel 隐藏）；真机边缘手势冲突验证（§5.7:463）维持未验证（P1-06），如实披露 | §5.7 |
| P2-07 | 【已修复】设置页左侧分类导航 9 组（播放与音效/音源/下载/歌词/外观/网络/账号与集成/快捷键/关于） | linux-settings-1440x900-default.png | §7.3 |
| P2-08 | xwayland-satellite 转发的 X 客户端 resize 触发 `Timed out waiting for OpenGL frame`，随后进程静默消失（关联 P1-05 观察）；niri IPC 与 Xvfb 路径未见 | app-run1.log + pgrep/coredump 取证 | §11 |
| P2-09 | 队列拖动排序 / 队列内跳播：后端无对应 FfiCommand，UI 禁用并说明（不伪造）；§7.4「拖拽排序」目标待后端命令落地。2026-11-12 补记：全屏播放页队列挂载形态已落 §5.7:452 底部 sheet（DragHandle 下滑/点遮罩关闭，enableDrag=false 与列表滚动解耦），拖拽排序仍如实禁用 | queue_panel.dart:8-10；queue_interaction_test.dart 8 用例（sheet 开关/清空确认/移出/随机/空态/拖拽禁用说明） | §7.4 |
| P2-10 | 【Phase 3 已关闭（2026-11-11）】曲库页快捷入口卡标签省略号截断（430 视口三列等分标签宽度不足）：`library_page.dart` `_entryCards` 加 LayoutBuilder（<512 与 `_header` compact 同阈值），窄视口改两行卡（标签独占一行 + 图标/计数次行），桌面 ≥512 单行布局零变化；修复同时暴露并修复同域潜在缺陷两处：`vx_track_row.dart`（<480 窄视口 hover 操作列不再预留 4×40px 固定宽，触屏无 hover、长按菜单为真实替代，360-430 手机档行尾溢出实测 11/23px）与 `vx_empty_state.dart`（矮槽位改「居中+可滚动」结构，chips 行挤压歌单档空态不再 RenderFlex overflow） | mobile_library_page_test.dart 2 项（360/390/430 无溢出 + TextPainter 宽度断言标签不截断）+ golden 重截 fluttertest-library-430x932-dark-default.png（临时测试用后即删零残留，目检：入口卡两行形态、标签完整、行表/chips 无溢出条纹）；该 golden 的 610d6d8 中间版本（18496B，07:29）为页面级 tofu 渲染、本目检对其不成立，已按 2026-11-12 复截版（61983B，01:53）复核，目检结论在有效证据上重新成立，详见 P1-12「证据勘误与复截」 | §5.5 |
| P2-12 | 【已关闭（2026-11-12 登记并关闭，Phase 2 追加批次）】全屏播放页封面恒 320 封顶、未落 §5.7:446-447 280-340dp 自适应带（原 `(height-330).clamp(160,320)`：390/430 视口未达带上限 340，且无带语义测试）：改 `max(min(min(height-330, width-40), 340), min(160, widthCap))`（mobile_now_playing_page.dart:337-348），<560 极矮视口回退 240 + 滚动、歌曲信息与播放控制不被挤出可视区（§5.7:447） | mobile_now_playing_layout_test.dart group「全屏封面 280-340dp 自适应带（§5.7:446-447，Phase 4）」3 用例（三视口 [280,340]／极矮 430×560 回退 240／矮 430×680 收缩分支）+ golden fluttertest-nowplaying-{360x800,390x844,430x932}-dark-playing.png：报告员 magick 像素实测封面 320/340/340 逐视口与公式一致（360 宽度封顶分支、390 带内、430 带上限），逐张目检无溢出/tofu/debug banner、全屏独占符合 §5.1 | §5.7:446-447 |

## P3（可选增强 / 文档债）

| ID | 问题 | 证据 |
|---|---|---|
| P3-01 | 【已修复】cover_loader.dart 头注释更正为「没有磁盘缓存」 | 代码 |
| P3-02 | readAudioInfo 悬空桥（7 处调用、so 无导出），调用点均有 try/catch 降级（「未知歌手 (解析失败)」），维持 P3 | 第一轮 nm 取证 + 本轮代码抽查 |
| P3-03 | 【Phase 1 已落地→长期验证记录】PlaylistKey(kind,source,id) 类型化键 + appendArmed 过期 append 丢弃；playlist_detail_isolation_test 7 项覆盖 §8.1 八步序列的 widget 层映射；实机八步序列未走查 | app_model.dart:23-42,470-516 |
| P3-04 | PlaylistDto 无 creator/play_count/link（into_playlist 全丢），歌单详情 Hero 元数据受限 | ffi/src/lib.rs:448-461 |
| P3-05 | ATK `atk_socket_embed` 断言失败与 OpenGL frame timeout 告警（运行日志非致命；后者与 P2-08 关联观察） | 运行日志 |
| P3-06 | CONTRIBUTING.md 基线数字过时（「53 tests」实为 229）；KEYBINDINGS.md 为 TUI 文档，GUI 键位无独立文档 | 文档对照 |
| P3-07 | 全屏播放页歌词仅空态文案（「本版本暂无手动重新获取入口」自认）；5sing 等源未取到歌词时无手动重取 | linux-nowplaying-1440x900-playing.png |
| P3-08 | 【Phase 2 复验轮登记，遗留 minor】旧 golden 截图未更新/数据种子不一致；本轮仅覆盖重截受影响的 fluttertest-library-430x932 一张，其余沿用 | phase-2-report.md「截图路径」节 |

## 已验证正常（本轮实机/门禁证据，避免重复修复）

- 播放链路端到端：走带三连证据 + Ended 自动切歌 ×2 + 4Hz 事件泵（§9/矩阵 P0-02）。
- 封面链路：发现页多源真实封面、队列真实封面、首页本地封面（P1-03 关闭证据）。
- 队列：当前曲高亮（行内均衡器图标）、单曲移除按钮、清空确认、随机开关、共 259 首/接下来播放 256 计数（linux-queue-1440x900-playing.png）。
- 全屏播放页：渐变占位封面（非黑块）、进度走带、音量条真实值（80 与配置一致）、诚实歌词空态（linux-nowplaying-1440x900-playing.png）。
- 设置：左侧分类导航 9 组、明暗三态切换即时生效（深→浅→深往返）、主题矩阵渲染（linux-settings-1440x900-*.png）。
- 曲库：快捷卡真实计数（最近播放 7/本地 0/喜欢 0）、分类 chips 计数（专辑 6/歌手 5 来自真实聚合）、来源分段（linux-library-1440x900-songs.png）。
- 下载页四分段 + 表头 + 空态引导（linux-downloads-1440x900-empty.png）。
- 静态门禁全绿：dart-format/analyze/cargo-fmt exit 0；flutter-test 229、cargo-test 816 全通过（00-baseline §3）。
- 事件流 lag 自愈、SetVolume 真实通路、搜索防抖/in-flight 锁、reduce-motion、错误净化（代码复核 + 测试维持第一轮结论）。

## Phase 1 退出条件核对（§13）——【本轮复审后更新】

| 条件 | 状态 |
|---|---|
| P0 清零 | P0-02 已关闭；P0-01 开放但本轮未复现（根因未定位，不能宣称修复） |
| 歌单隔离测试 | ✅ widget 层 9 项（新增 §8.1 序列 7：A 触底分页在途切 B 迟到页 2 只落 A 槽；实机八步未逐项走查，隔离对照三连实机通过，见 P3-03） |
| 封面错误态 | ✅ 13 项；P1-08 搜索结果行封面已关闭（cover: VxArtwork + 回归 + 实机目检） |
| 手机系统栏无重叠 | widget 层 ✅；真机未验证（P1-06 环境阻断维持） |
| 本地音乐真实导入并播放 | 未达成（无媒体文件，Phase 5） |
| 播放状态/进度/duration/seek/Ended（§8.3） | ✅ 实机走带三连 + 自动切歌 ×2 |

**下一阶段进入条件**：P1 全部关闭（P1-03/04/07/08/09/10/11），Phase 2 可进入；P0-01 继续以「概率性未复现」状态跟进，长时间会话验收前必须定位（ButtonPress 间歇失效同域观察在案）；浅色主题实机整页走查归 Phase 2/7。

## Phase 2 偏差登记（2026-11-11，手机壳收口批次）

以下为 Phase 2 实现中**有意识保留的规格偏差**，逐条给出理由与裁决点；均不冒充已修复：

- **D1 触屏 ≥1200 仍走 TabletShell.triple 而非 §4.1 表的 DesktopShell**（responsive_shell.dart `resolveDeviceFormFactor`；mobile_shell.dart TouchShell switch）：桌面零回归铁律 + window_manager 平台差异，本阶段不动。裁决点：指南 §6.3 是平板验收截图清单、并无 ≥1200 裁决条款，故此条为本矩阵自建裁决点——待平板阶段（§6.3 截图批次）实测 1199/1200 边界后裁决。
- **D2 TabletShell home 槽维持桌面 HomePage**：`buildShellPage` 的 `ShellFormFactor` 参数缺省 desktop，TabletShell 调用点显式不传（mobile_shell.dart 平板 IndexedStack 有注释标记）；平板首页规格（§6.x）未定义前不擅自套手机首页。裁决点同 D1。
- **D3 §5.2 第 8 项「最近添加或最近播放列表」整块缺席**：「最近播放」已由第 4 项横滑书架承载（同一真实数据源 `state.history`，纵向列表为同数据重复展示）；「最近添加」需要本地扫描时序元数据，`state.localSongs` 无添加时间字段——不造假数据补位。裁决点：本地曲库元数据补齐后重评。
- **D4 抽屉塌缩条目落点与高亮规则**（§5.9）：在线歌单/排行榜 → 发现（mapLegacyNavIndex 3/4 同语义）、本地音乐 → 推入真实 LocalMusicPage、音源管理 → 设置页 sources 分组（`SettingsSection.sources`，真实音源开关所在；全仓无独立「音源管理」页，grep 零命中）。高亮塌缩规则：仅规范目的地行（首页/发现/搜索/我的音乐/下载/设置/帮助）在 current==dest 时高亮，塌缩次级行永不高亮（mobile_shell_test 锁定单高亮断言）。
- **D5 「喜欢的歌曲」快捷入口落点 = LibraryPage songs 档**：曲库 songs 档即「喜欢的歌曲（含账号红心镜像）」语义（library_page.dart 头注与入口卡同口径），非新造收藏页。裁决点：若后续建独立收藏页，本入口换指。
- **D6 §5.10 导入三落点收口状态**：①首页空库 Hero CTA 已接真实选择器流程（`importLocalMusicDirectory`，与本地音乐页同一实现，picker 挂钩 `localDirectoryPicker` 测试可注入）；②本地音乐页顶部主按钮既有（窄视口 <600 压缩为带 tooltip 图标按钮——本次顺带修复 390dp 下顶栏 Row 溢出 54px 的 RenderFlex 崩溃）；③「我的音乐快捷入口」由曲库页本地音乐入口卡承载（既有桌面语义，移动同页面复用）。导入→扫描→播放链路（无媒体文件/无 Rust 控制器）按既有口径归 Phase 5，测试仅锁回调触发层。
- **P1-06 维持**：本轮全部新增手机壳/首页测试为 widget 层；§5/§10 真机项（edge-to-edge、手势导航、刘海、系统导航条）依旧未验证，不因测试全绿而改判。
- **本轮回归**：定向 9 文件（mobile_shell / mobile_home_page / mini_player_interaction / mobile_now_playing_layout / tablet_shell / home_page / android_insets_layout / shell / chrome_theme）65 项全绿（2026-11-11 报告员实跑，含 tablet_shell 断点边界 839/840 改判与 home_page 桌面既有 6 项回归）；dart analyze 0、dart format 12 文件对齐。全量 flutter test / cargo test 由外部门禁统一执行，本轮未跑。
- **缺陷复验轮回归（2026-11-11，Phase 2 收口轮）**：定向 7 文件（mobile_shell / mobile_home_page / mini_player_interaction / mobile_now_playing_layout / viewport_matrix / phase5_library / local_music_page）**51 项全绿**（`00:05 +51: All tests passed!`，报告员实跑），含 P1-12/P1-13 两条新增回归；`flutter build linux --release` exit 0（RUSTUP_TOOLCHAIN=1.99.0）；golden 重截 fluttertest-library-430x932-dark-default.png（临时测试用后即删，仓库零残留）。QA 复查：两条 P1 均关闭，当前无 P0/P1，遗留 minor 仅 P2-10/P3-08 两条。详见 `docs/redesign/phase-2-report.md`。

## 用户实测缺陷登记（2026-11-11，用户运行当前构建实拍）

证据截图：`docs/redesign/screenshots/user-feedback/2026-11-11-desktop-playerbar-fullscreen-gap.png`（红箭头指向播放栏右缘空置区；同图可见发现页 B 站歌单加载失败态四态呈现正常、千千音乐封面行真实渲染）。

| 编号 | 严重程度 | 位置 | 问题 | 归属 | 建议 |
| --- | --- | --- | --- | --- | --- |
| P1-14 | P1 | flutter/lib/src/player/player_bar.dart（桌面全局播放栏） | 播放栏未随窗口/全屏宽度自适应：窗口拉宽或全屏时，进度条右端到右簇控件（音量/设备/歌词/队列）之间大片空置，右簇不贴右缘；用户实拍宽窗口复现 | Phase 6（§7.5 Global Player Bar） | 右簇对齐策略（Spacer/flexible）核对，全屏与窗口两种宽度各截对照图 |
| P2-11 | P2 | 桌面 Shell 播放栏挂载层 | 播放栏常驻性：用户预期「任何时候常驻」（含无歌曲态）；§7.5 规定「无歌曲时显示合理空播放器状态，不保留不可点击的假控件」，当前实现疑似无歌曲时整条隐藏 | Phase 6（§7.5） | 落地为常驻空态（与用户预期一致）；裁决点：若产品上决定保留隐藏行为，须回指南改 §7.5 并征得用户同意 |

用户原话（登记依据）：「底部的那个播放状态栏，不应该是什么时候都常驻的吗」；「全屏的时候，底部状态栏明显没有自动适应，右边空了一大截」。
