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
- 更新（2026-11-12 Phase 4 收口轮）：**P1-15 登记并关闭**（网易系封面 CDN 封杀 Dart 默认 UA，全屏播放页大封面 403 灰占位；修复 + 根因双向实锤 + 回归 + 实机重截四重核实，见 P1 节）。报告员实跑（本轮）：定向 5 文件 **56 项全绿**（`flutter test test/cover_image_headers_test.dart test/voicefox_audio_handler_test.dart test/mobile_now_playing_test.dart test/mobile_shell_test.dart test/now_playing_test.dart --reporter compact`，`00:08 +56: All tests passed!` exit 0；逐文件 12+8+14+9+13 与 grep 声明数吻合）+ 2 文件修复验证 **26 项全绿**（`00:04 +26` exit 0）；根因独立复跑：同一封面 URL（/tmp/p4/verify_run3.log:76 实取 `p2.music.126.net/…/109951173908998514.jpg`）Dart UA 403 text/html 146B、voicefox UA 200 image/jpg 602586B（magick identify JPEG 3000x3000），与 Phase4-QA1 实锤一致；debug 重建 exit 0（bundle 06:22 在位，早于 06:24-06:25 重截）；Xvfb :101 600x900（:99 被并行 actor 1200x1600 占用，pgrep 复测在位）真实 kw/wy 在线播放重截受影响视口 3 张逐张 Read 目检通过（大封面真实 CNBLUE《BLUE LOVE》，queue-open 保留原截图 05:18 未重拍：队列要素完好但大封面区为灰占位（修复前形态），与「其封面为酷我源本就正常」表述有出入，如实登记记 minor，大封面证据不由该图承担）。修复代码与新增测试为未提交工作区改动，随收口提交入树。**未验证如实登记**：403 修复未抓包核对实际请求头（正确性由 cover_image_headers_test 12 项单测锁定，其中 UA/Referer 头逻辑断言 10 项）；release bundle 未随修复轮重建（上轮 03:52:19 不含本修复）；锁屏媒体控制/audio_service 全链真机侧维持 P1-06；移动视口 560 钳制（main.dart:163 minimumSize）与移动端全屏页运行时（isTouchPlatform 隔离）维持 widget 层证据。Rust 零改动（本轮 Rust 源未动，cover_referer 镜像引用既有 source.rs:166-174）。详见 `docs/redesign/phase-4-report.md`。
- 更新（2026-11-13 Phase 5 收口轮）：**P1-16/P1-17/P2-13/P2-14/P3-09 登记，全部开放**（Phase 5 运行时验证发现 D1-D5，运行环境 Xvfb :105 真实后端 + xdotool 驱动真实 UI；widget 测试全绿但运行时不符，如实登记，见各节）。本阶段**无既有矩阵缺陷项被修复关闭**（无对应修复证据，如实登记；Phase 1 退出条件表「本地音乐真实导入并播放」行更新为 Phase 5 桌面已验证，非缺陷关闭项）；偏差 E1-E6 登记「Phase 5 偏差登记」节。报告员实跑（本轮）：定向 3 文件 **31 项全绿**（`flutter test test/local_music_import_test.dart test/phase5_downloads_test.dart test/phase5_local_music_test.dart --reporter compact`，`00:04 +31: All tests passed!` exit 0；local_music_import 7 + phase5_downloads 18 + phase5_local_music 6，grep 计数与总数吻合）；debug bundle mtime 2026-11-13 00:37:47 + `lib/libvoicefox_ffi.so` 287203584B 在位（ls/stat 佐证，运行验证基于含修复产物）；4 张 final/ 截图逐张 Read 目检通过（真实数据渲染：/tmp/p5music-real+10k 目录与 12 首真实条目、三态分组计数、已完成真实封面 3.3/2.3/5.3MB、失败态「失败 · 音频…」截断 + **D5 的 1.4MB/475.7KB 异常显示在图内直接可见**）；config.toml 已还原 phase1 单路径（cat 核实）、/tmp/p5music-*（10000/20000 文件）在位。运行时验证与真实数据（在线搜索 kw/酷我/酷狗/汽水/咪咕 200+ 结果、真实下载 5.5MB m4a/2.6MB mp3+lrc 落盘 ~/voicefox/ ffprobe 342s、导入/持久化跨 3 次重启 10012→14900→30012/性能 10k≈2.5s·30k 滚动流畅·启动≈30-40s）为实施/QA 会话 ask 已知事实，报告员未复跑，如实转述。独立 QA：**P0=0、P1=0、minor=3**，§13 四条退出条件全部有实跑测试支撑，无阻塞可收口；D1/D2 为运行时验证发现的 P1，开放待后续修复批次（不影响 Phase 6 进入）。环境注记：10k/20k 目录因 D1 崩溃无法经 UI 加入，改关 app 后外部编辑 config.toml 加路径（测试后已还原 phase1 单路径）；扫描入库 30012 首留本地曲库 DB。全量 flutter test / cargo test 外部门禁统一执行，报告员未复跑。详见 `docs/redesign/phase-5-report.md`。
- 更新（2026-11-13 Phase6-QA1 修复轮）：**P1-18 登记并关闭**（推入式详情页整页覆盖壳层，常驻 PlayerBar/AppHeader/Sidebar 全部消失，违反 §7.5「播放器在页面切换、搜索、歌单详情和设置中持续存在」（指南 :700）与 Phase 6 退出条件「播放器跨页面保持」（:1221））：桌面壳层中央内容区内嵌 Navigator（nav_bus.dart `contentNavigatorKey`）承接推入式详情页，内容区内的 `Navigator.of(context)` 就近解析自动落内嵌（QA 列名的 LocalMusic/RecentSongs/PlaylistDetail/ArtistDetail/AlbumSongs 与同模式的侧栏自建歌单详情全部覆盖，机制页面无关）；壳层兄弟子树的推入入口（侧栏歌单项、seed 详情下钻）经同一 key 显式落内嵌；Esc 链补内容区档（根路由 > 内容区内嵌，§4.3 先关最上层）；同轮修复内嵌 Navigator 引入的焦点回落缺陷（全屏播放页切换拆 shell-main 后焦点落 home ModalScope，§9 快捷键全链失灵，Phase 6 Esc 链用例经 A/B 实跑确认被本修复波及，`Focus(autofocus)` 直改 `FocusNode` + `_setNowPlayingOpen` 转场帧后收回 primary，NowPlayingPage 自身 Esc 绑定与壳层重复、双路径语义不变）。本轮实跑：定向 7 文件 **81 项全绿**（`flutter test test/desktop_three_column_layout_test.dart test/desktop_queue_interaction_test.dart test/shell_test.dart test/mobile_now_playing_layout_test.dart test/queue_interaction_test.dart test/tablet_shell_test.dart test/mobile_shell_test.dart --reporter compact`，`00:13 +81: All tests passed!` exit 0 = 78 基线 + shell_test 新增 3 条推入路由回归）+ 壳系 3 文件 22 项全绿（ui_only_boot/now_playing/chrome_theme）+ **全量 flutter test 375 项全绿**（`00:33 +375: All tests passed!` exit 0；本修复改壳层结构且内嵌 Navigator 影响所有桌面推入路由，故全量复跑而非仅定向）+ `flutter analyze` 0 issue + dart format 5 文件（1 changed）。**未验证如实登记**：运行时实拍未重拍（未起 Xvfb/未重建 bundle），QA 实拍 desktop-library-1024x640-minwindow.png 对应场景现由 shell_test「1024×640（QA 视口）：推入本地音乐页后 PlayerBar/侧栏仍在」widget 用例锁定，运行时形态待下轮实拍复核；推入页渲染进中央内容列后「行右键菜单（showSongMenu bottom sheet）挂载点从窗口底移到内容区底」为机制伴生形态变化（desktop_queue_interaction 全 7 项仍绿），未单独实拍。Rust 零改动。
- 更新（2026-11-13 Phase 7 收口轮，最终质量收敛）：**P1-19 登记即关闭（证据缺陷）+ P2-15/P3-10 新增开放**。报告员本轮独立复跑全部门禁：dart format 首跑 exit 1（Phase 7 执行批次 main.dart 改动未格式化，251 files 1 changed → 机械化 format 后 exit 0 语义零变化）/ flutter analyze 0 / 全量 flutter test **375 项全绿** exit 0 / cargo fmt 0 / 全量 cargo test --workspace **826 passed / 0 failed** exit 0 / clippy 原样门禁命令 exit 101（libmpv2 6.0.0 build.rs:23 `env var MPV_SOURCE not set: NotPresent` panic，与 Phase 0 基线登记一致，报告员实测复现；降级采集 lx-core 28 条 `#[must_use]` 告警与基线吻合）/ `RUSTUP_TOOLCHAIN=1.99.0 flutter build linux --release` exit 0（bundle 07:33:34 + libvoicefox_ffi.so 24475344B）。**P1-19**：final/ uionly 截图 7 张视口标注失实（desktop-home-1024 实为 1280×720 默认窗左上裁切；6 张 phone 标注 360/390/430 实为 560 宽，执行批次 Xvfb 屏 :227-:232 即 560 系），根因 = uiOnly 分支不应用 VOICEFOX_START_SIZE/WindowOptions（main.dart:143-175 属真实分支，uiOnly 分支 :106-116 提前 return；xdotool getwindowgeometry 实测 uiOnly 默认窗 1280×720），真 1024×640 重截渲染折叠 rail + PlayerBar 与 Phase 6 QA 一致证明应用本体无回归，7 张以真实视口重截件替换并逐张目检（详见 phase-7-report.md「截图路径」节）；**P2-15**：真 360×800 重截目检发现曲库入口卡「喜欢的歌曲」标签省略号截断（P2-10 回归测试 mobile_library_page_test.dart:148-157 仅对 4 字标签「最近播放」做 TextPainter 宽度断言，5 字标签漏锁），开放；**P3-10**：uiOnly 分支不支持 VOICEFOX_START_SIZE（验收截图管线缺陷，xdotool 后置调窗为现行 workaround），开放。设置页两档截图为 uiOnly 永久「配置加载中…」态（无后端 config 快照，设置真实 UI 不可达）如实登记。**无 Android 真机验证（全程）**：环境实测 ANDROID_HOME=/opt/android-sdk 指向不存在目录、adb 不存在、无设备/模拟器（JDK 21 在位），叠加用户搁置指令（禁止 APK/Gradle 构建与 AVD 创建），Android 构建状态 = 全程未构建（P1-06 维持）。性能 profiling 与无障碍专项检查未执行（Phase 7 工作清单项，如实登记）。§13 退出条件判定：Linux 桌面目标可收口；「P0/P1 为 0」字面未满足（P0-01 未复现开放 + P1-05/16/17 开放 + P1-06 环境阻断）。最终计数（开放）：P0×1 / P1×4 / P2×8 / P3×8。详见 `docs/redesign/phase-7-report.md`。
- 更新（2026-11-13 Phase6-QA 复查轮，修复验证与运行时实拍复核）：**P1-18 上轮登记的「运行时实拍待复核」缺口关闭**：重建 `flutter build linux --debug` exit 0（kernel_blob.bin 05:06:57 + libvoicefox_ffi.so 05:06:53 286283424B，报告员 stat 佐证）→ Xvfb :61 + GDK_BACKEND=x11 重跑修复版 bundle（窗口内容=外框减 264px 阴影边精确裁切）→ 受影响视口重截 2 张（≤3）逐张 Read 目检通过（报告员本轮实看）：①desktop-library-1024x640-minwindow.png（05:11:38，68497B，替换）：本地音乐详情页壳内渲染（折叠 72 侧栏+AppHeader+PlayerBar 空态「未在播放/选择一首歌曲开始播放」全部在位，行贴底缘缺陷消失）；②desktop-library-1280x800-playing.png（05:12:17，107523B）：1280×800 表格页双击第 3 行实跑 **0 次 Unhandled Exception**（修复前会话 1 双击 12 次+会话 2 播放全部 1 次），行 3 当前播放均衡器高亮、PlayerBar 真实播放态（P5测试曲1/P5艺术家·local、⏸ 主钮、进度 00:00/00:01 前进中与列表时长吻合）、日志 last=progress 事件流动、歌词加载失败 toast 为本地曲预期真实错误态非致命。回归护栏：shell 大改后定向 tablet_shell_test.dart 复跑 8/8 全绿（报告员本轮独立复跑 `00:05 +8: All tests passed!` exit 0）。未受影响视口（1280 threecolumn/panelhidden、1920 threecolumn，均我的音乐页非推入详情页）维持 04:07 原截图不重截。QA 复查：**P0=0，上轮 P1（P1-18）关闭确认**；四项退出条件全部成立：五视口无布局缺陷（两张新图无 overflow/遮挡/白黑屏）、三栏可折叠、右面板 overlay 不挤压（上轮已核）、播放器跨页面保持（本轮闭环）。§12.5 复查：无白/黑屏、无 overflow、遮挡仅 DEBUG 横幅（debug 固有）、封面无异常、本地音乐计数（30012）/曲目（P5测试曲1）/时长（00:01）三方一致真实数据、深色对比度可读（浅色仍归 Phase 7）。残留 minor 4 条均非阻塞：计数头滚动态碰撞维持 open、DEBUG 横幅、30012 陈旧条目建议立矩阵项、30013±1 未归因。**未验证如实登记**：MPRIS 仍未修复（busctl --user list 无 org.mpris.MediaPlayer2.voicefox.*，grep voicefox→none；本轮修复未触碰 app/src 与 ffi/src：git diff --stat 仅 shell 侧 12 文件报告员实测；MPRIS 仍只在 TUI run_app app/src/main.rs:1646 接线，Flutter 桌面 FFI 路径无 media_controls，P2-05 维持开放）；键盘焦点移动仍未通过（点击选行可用，ArrowDown×3 后无焦点指示移动，仅 mouse hover 跟随，本次修复未涉及）；真实出声无法验证（无头环境 pipewire client.conf 加载失败，仅见引擎 progress 事件）；平板两档 rail 桌面运行时不可达（responsive_shell.dart:95-100 isTouch=false 恒 desktop），仅定向 widget 测试 8/8 绿作证据；1 秒测试曲时长限制（播放推进/自动切歌长程行为无法演示）；报告员侧 7 文件 81 项+全量 375 项+analyze 0 本轮未复跑（QA1 修复轮登记在案，未独立复核）。详见 `docs/redesign/phase-6-report.md`。
- 更新（2026-11-14 清尾 L1 轮，Phase 7 后开放缺陷清理）：**P1-16/P1-17/P2-02/P2-13/P2-14/P2-15/P3-10 七项关闭；P1-05/P2-08 崩溃取证面补齐但维持开放**。报告员本轮独立实跑门禁：dart analyze 0 / dart format 253 files 0 changed exit 0 / **全量 flutter test 380 项全绿**（`00:42 +380: All tests passed!` exit 0 = 基线 375 + 本轮新增 5：crash_log 1 + theme_source_guard 2 + local_music_import 1 + mobile_library_page 1）/ cargo fmt --all --check 0 / cargo 定向 3 crate 全绿（voicefox-ffi crash_log 2 项、lx-source --lib local:: 30 passed 含 P1-17/P2-13 两条新测试、voicefox-download pause_during_resolving 1 项，均 exit 0）。报告员独立重建 uiOnly debug bundle（`RUSTUP_TOOLCHAIN=1.99.0 flutter build linux --debug --dart-define=VOICEFOX_UI_ONLY=true` exit 0；bundle/kernel_blob/libvoicefox_ffi.so 2026-11-14 00:35:21-28，so 286350280B 含本轮 ffi crash_log 重建）+ Xvfb :117 运行时验证：**P3-10 几何实核**（VOICEFOX_START_SIZE=360x800 → getwindowgeometry 360×800 精确生效，无 1280×720 默认、无 560 钳制）+ **P2-15 运行时目检**（360×800 曲库「喜欢的歌曲」标签完整渲染无省略号，截图 docs/redesign/screenshots/final/phone-library-360x800-uionly-recheck.png）。**P1-16 运行时复走未达成（如实登记）**：uiOnly <960 降级壳内曲库入口卡 tap 未推入 LocalMusicPage（同页来源分段 tap 响应正常、widget 层推入链路由 phase5_library_test.dart:219-222 锁定且全量绿，不归因本轮 diff，本轮 library_page.dart 仅改标签渲染）；实测首页空库 Hero「导入本地」当前接线为 home_page.dart:118 `navRequest.value = 5`（导航曲库）而非导入流，Phase 2 偏差 D6 的「与本地音乐页同一实现」口径已过期（既有接线、非本轮改动，如实登记）。最终计数（开放）：**P0×1 / P1×2 / P2×4 / P3×7**。
- 更新（2026-11-14 第二轮·门禁恢复批次）：**SR-01/SR-02/SR-12 处理（P2-17/P2-18 测试面补齐，运行时证据仍缺维持开放；CI 门禁根因修复）**。(1) **CI SDK 漂移根因修复**：ci.yml/release-flutter.yml 全部 6 处 `channel: stable` 补 `flutter-version: 3.47.9`（新 stable 将 `package:flutter/material.dart` 整体弃用 deprecated after v3.47.0-0.0.pre，115 条 `deprecated_member_use` info 使 `--fatal-infos` 必挂，本地 3.47.9 同仓 analyze exit 0 复现对照）；`flutter` 单 job 拆为 `flutter-analyze`/`flutter-test` 独立 job（analyze 失败不吞测试证据），两 job 均输出 `flutter --version`/`dart --version`；material_ui 迁移登记为独立升级任务不做。本轮 analyze/test 在 PR #12 新 run 上验证待推送后观察（未 push，如实登记）。(2) **P2-17×P2-18 交叉解决**：新增共用 `LyricsRetryButton`（lyrics_panel.dart），在途禁用防重复、成功以歌词内容变化复位、失败以「歌词加载失败」notification 复位、12s 超时兜底；全屏播放页无歌词单列布局内新增重取入口（now_playing_page.dart `_LeftColumn`），解决「单列不渲染 LyricsPanel 导致重取入口不可达」；`application/src/service.rs:1732` `[DIAG-lyric]` eprintln 调试残留清除（与 Notification 事件内容重复）。(3) **now_playing_test.dart 旧空态断言按新行为重写**（不削弱断言）：原「暂无歌词 findsOneWidget + 重试 findsNothing」与 P2-18 单列分支冲突，重写为 6 用例组（单列无面板+重取可达/双列面板+入口退出/LoadLyrics 真实命令+在途禁用/歌词回填双列恢复/失败通知复位可重试/切歌复位无失败误报）。报告员实跑：dart format 3 文件（1 changed）exit 0 / `flutter analyze --fatal-infos` exit 0（3.47.9）/ now_playing_test **18 项全绿** exit 0 / 相关 5 文件（mobile_now_playing+layout/shell/desktop_queue_interaction/mobile_shell）**60 项全绿** exit 0 / **全量 flutter test 386 项全绿**（00:32 `+386: All tests passed!` exit 0 = L1 基线 380 + 本轮新增 6）/ Rust 侧补 service.rs LoadLyrics 接线回归 2 项（mock LyricFetcher 注入：成功回填 state+LyricsChanged / 失败发「歌词加载失败」Notification 且 state 不动）/ `cargo fmt --all --check` exit 0 / `cargo test --workspace` 833+2 **passed 0 failed** exit 0 / clippy 30 条基线告警对账吻合（全部 `#[must_use]` 类，与本次改动无关）。CI push 观察：commit `e58e7c2` 推送后 run `43556931399` **8/8 job 全绿**（flutter-analyze 1m11s 修复直接生效、flutter-test 3m30s 独立出证据、Lint/四平台构建全绿；版本日志实测 Flutter 3.47.9 / Dart 3.13.7 与本地一致），SR-01 关闭。运行时实机复验（真实 App 内点按钮看 loading/失败 toast/歌词回填）本轮未做，P2-16/P2-17/P2-18/P1-20 四项运行时证据缺口维持。
- 更新（2026-11-14 第三轮 Phase 0 + Batch A 只读审计）：**SR-11 口径裁决修正（右键菜单「整体缺失」有误，SongTile showSongMenu 真实存在且 song_tile.dart 未退役，7 类表面消费 + 4 触发面实测，残余缺口收窄为网格卡面）；FFI-R01..R12 风险登记开放（10 项已证实 / R05 需设备验证 / R11 已排除 / R12 观察态，见文末「FFI 边界风险登记」节）**。本批次零生产代码改动；基线复核报告 `docs/reports/WORK_REPORT_2026-11-14_second-round-baseline-review.md`，交付 `docs/architecture/ffi-contract-inventory.md` + `docs/architecture/ffi-reliability-design.md`。
- 基线事实与门禁数据：`docs/redesign/00-baseline.md`（§3 门禁、§9 播放链、§10 封面链）。
- 评级口径（§12.7）：P0 数据错乱/播放不可用/崩溃；P1 核心操作无法完成/封面普遍缺失/关键页面不可用；P2 视觉与次要功能缺口；P3 可选增强/文档债。

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

### P1-05 进程静默退出（无崩溃日志）【开放；2026-11-14 清尾 L1 轮 panic/Flutter 异常取证面补齐，静默退出根因未定位维持开放】

- **清尾 L1 轮取证面补齐（非修复，2026-11-14）**：GUI 侧 panic/Flutter 异常面落盘已接：`ffi/src/crash_log.rs`（新建：append 方式落盘 `<config>/crash.log`，`VOICEFOX_CRASH_LOG` 可覆盖，写盘失败静默降级；`install_gui_panic_hook` 在 ffi/src/lib.rs:1158 `new_desktop` 接线）+ `main.dart:172 installCrashLogHandlers`（FlutterError.onError 与 PlatformDispatcher.instance.onError 落盘同文件同格式，保留既有 stderr/红屏行为）；回归 crash_log_test.dart（Dart 1 项）+ ffi crash_log 单测（Rust 2 项），报告员实跑全绿。诚实边界（crash_log.rs 模块注释登记）：引擎级 SIGABRT/GL abort 无 unwind、不经 panic hook，P1-05/P2-08 观察到的静默死亡路径（GL frame timeout 后进程消失）仍无取证，外部 watchdog 归独立批次；本轮无新增静默退出实例，根因未定位。
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

### P1-15 网易系封面 CDN 封杀 Dart 默认 UA，全屏播放页大封面 403 灰占位（Phase 4 收口轮发现）【已关闭，2026-11-12 登记并关闭】

- **现象**：kw/wy 真实在线播放网易系曲目时，全屏播放页大封面持续显示失败灰占位，而队列行（酷我等音源）封面正常渲染；首页卡片/迷你栏封面同受影响。
- **根因（双向实锤）**：网易系封面 CDN（p2.music.126.net 等）封杀含 `Dart/` 的 User-Agent，一律 403 text/html。Phase4-QA1 实锤 + 报告员独立复跑同结果（2026-11-12）：同一封面 URL `http://p2.music.126.net/DrNrcSu1YLan6Oya57x60A==/109951173908998514.jpg`（取自本轮 QA 运行日志 /tmp/p4/verify_run3.log:76），`curl -A "Dart/3.9 (dart:io)"` 返回 **403 text/html 146B**，`curl -A "voicefox"` 返回 **200 image/jpg 602586B**（JPEG 3000x3000，magick identify 实测）。
- **复现步骤**：wy 源播放任一网易系封面曲目 → 打开全屏播放页 → 大封面灰占位；同曲队列行若为酷我源则正常（coverReferer 注释与 Phase4-QA1 实锤一致）。
- **影响**：§12.7「封面普遍缺失」在网易系（主力音源之一）大封面路径成立；Phase 4 退出条件「锁屏媒体控制」的 artUri 通知链依赖可下载封面，同受此根因牵连。
- **修复（Phase 4 收口轮入树）**：`cover_image.dart` +35：`coverUserAgent = 'voicefox'`（:17，对齐 Rust 侧 UA 家族 runtime/src/cover_src/source.rs）+ `coverReferer(url)` 按音源映射（:21-33，逐条镜像 Rust `cover_referer` source.rs:166-174：kuwo/kugou/qq/163+126→null）+ `coverImageHttpHeaders(url)`（:36-41）+ `CachedNetworkImage(httpHeaders: …)` 下发（:87）；flutter_cache_manager HttpFileService（package:http IOClient `headers.set`，io_client.dart:119-120）整体覆写默认 UA，大封面与队列行共用单点映射。
- **回归**：`cover_image_headers_test.dart` 新增 12 项全绿：coverReferer 按音源映射 5 项（镜像 Rust）+ 请求头构造 4 项（UA 为 voicefox 家族不含 Dart / 126.net 附 music.163.com Referer / 酷我附 Referer / 无防盗链仅 UA）+ `CachedNetworkImage.httpHeaders` 下发 widget 3 项（网易 UA+Referer / 非网易仅 UA / 空 URL 占位不构造网络请求）；定向 5 文件 56 项全绿（报告员实跑 `00:08 +56: All tests passed!` exit 0）。
- **实机复核（重截目检）**：debug 重建（bundle 06:22）+ Xvfb :101 600x900 + GDK_BACKEND=x11 + VOICEFOX_START_SIZE 真实 app，kw/wy 在线播放 Love CNBLUE（wy=原缺陷触发源）：受影响视口重截 3 张（560x844 playing/lyrics-unavailable、560x800 playing，mtime 06:24:35-06:25:28，53KB→137KB）逐张 Read 目检通过，大封面由灰占位变为真实 CNBLUE《BLUE LOVE》专辑图（560x844 与 560x800 两视口确认），进度/滑块/深色对比一致；首页卡片/迷你栏封面同步恢复（QA 记录）。queue-open 一张未重拍（保留 05:18 原截，记 minor；该图大封面区为灰占位属修复前形态，队列要素完好，大封面证据由 3 张重拍承担）。
- **诚实标注**：修复仅目检验证（封面真实渲染）+ curl 双向对照，未抓包核对实际请求头；请求头构造正确性由 12 项单测锁定（其中 UA/Referer 头逻辑断言 10 项）。release bundle 未随修复轮重建（上轮 03:52:19 不含本修复）。Rust 零改动（仅镜像引用既有 source.rs:166-174）。



### P1-16 导入方式选择 bottom sheet 流程运行时触发 debug 断言红屏（Phase 5 收口轮发现）【已关闭，2026-11-14 清尾 L1 轮】

- **现象（Phase 5 登记）**：经 UI 走导入方式选择流程（添加目录后的「选择文件夹/选择文件」双选项 bottom sheet）触发 Flutter debug 断言 `_dependents.isEmpty`（framework.dart:6281），红屏且 UI 死亡；**3 个会话复现**。widget 测试全绿但运行时主导入入口坏；10k/20k 大目录验证因此无法经 UI 加入。
- **根因（实施轮定位，local_music_page.dart:604-611 注释登记）**：导入流可重入。运行时实证（实施轮 Xvfb 真实后端复走，报告员未独立复核原红屏，如实登记）：无 portal 环境下系统选择器挂起不返回，sheet 已 pop 而后续对话框未出现，处于该间隙的用户再次点击「添加目录」叠开第二条 modal 流，两条流交叉 push/pop 撕裂路由 teardown（flutter/flutter#39131 同族触发），命中 `_dependents.isEmpty`。
- **修复（清尾 L1 轮入树）**：`local_music_page.dart:613` 模块级重入门禁 `_importFlowActive`；`importLocalMusicDirectory`（:630-637）进行中二次触发直接返回，`try/finally` 保证门禁释放；`debugResetImportFlowGate`（:617）供测试复位（与选择器 seam 的 setUp 复位同口径）。
- **回归**：`local_music_import_test.dart` 新增「导入流重入门禁（P1-16）」：选择器挂起（Completer 不返回）复现运行时间隙 → sheet pop → 间隙二次触发断言不叠开第二条流（`find.text('添加本地音乐目录')` findsNothing）→ 走完首条流门禁释放 → 第三次触发正常开 sheet 且整条流走完不残留门禁；setUp 经 debugResetImportFlowGate 复位。全量 flutter test 380 项全绿内（报告员实跑 `00:42 +380` exit 0）。
- **诚实标注（清尾 L1 轮报告员）**：运行时复走未达成：uiOnly <960 降级壳内曲库入口卡 tap 未推入 LocalMusicPage（同页来源分段 tap 响应正常；widget 层推入链路由 phase5_library_test.dart:219-222 全绿锁定；不归因本轮 diff）；首页 Hero「导入本地」当前接线为 home_page.dart:118 导航（D6 口径过期，既有行为）。关闭依据 = 门禁机制结构性消除复现窗 + 确定性 widget 复现锁定 + 实施轮运行时实证在案；原红屏现象本身报告员未复现复核。

### P1-17 扫描取消后部分结果入库（违反「取消→结果未提交」契约）【已关闭，2026-11-14 清尾 L1 轮】

- **现象（Phase 5 登记）**：扫描中点击取消停在 4888/20000，但 **14900 首被提交入库**且统计条显示部分值；跨 3 次重启持久化序列 10012→14900→30012 中的 14900 即该部分入库结果，现象自洽；不能排除「点击取消」与「扫描自然结束提交」的竞态。
- **根因收口（清尾 L1 轮入树）**：扫描器协作式取消返回「已处理部分」报告（scanner.rs 契约：调用方丢弃、不提交），但点击取消可晚于根目录循环内检查点（最后一个根目录扫描途中或提交段前），循环正常走完并带着部分结果进入提交段。修复 = `source/src/local/mod.rs:458-468` 提交段前新增最终取消检查点：取消置位时丢弃本轮报告、入库快照保持原样、置 `last_scan_cancelled`、消费取消标志，竞态窗口结构性消除（运行时 14900 首部分入库即该形态）。
- **回归**：`source/src/local/mod.rs` tests 新增 `cancelled_before_commit_segment_does_not_commit`（空 paths 直达提交段前检查点 + cancel_scan → 断言不提交、统计条不展示本轮值、`last_scan_was_cancelled()==true`、`is_scanning()==false`、取消标志已消费且下一次扫描正常提交）。
- **报告员实跑（本轮）**：`cargo test -p lx-source --lib local::` 30 passed / 0 failed / 1 ignored，exit 0（本轮两条新测试均 ok）；运行时扫描取消场景未重走（widget 层取消契约用例维持，如实登记）。

### P1-18 推入式详情页整页覆盖壳层，常驻 PlayerBar 全部消失（Phase6-QA1 视觉/数据 QA 轮发现）【已关闭，2026-11-13 登记并关闭】

- **现象**：桌面 1024x640 最小窗（QA 实拍 docs/redesign/screenshots/phase-6/desktop-library-1024x640-minwindow.png）：本地音乐页推入后 AppHeader/Sidebar/ContextPanel/PlayerBar 全部消失，仅剩页面自身标题+列表。播放不中断（AppModel 常驻），损失的是常驻播放栏 UI 与传输控制。
- **根因**：推入式详情页走根 Navigator 的 MaterialPageRoute，整页覆盖壳层。代码链路：library_page.dart:978-982 `_openRecent`/:984-989 `_openLocalMusic`（RecentSongsPage/LocalMusicPage，local_music_page.dart:42 自建 Scaffold 不含 PlayerBar），同模式波及 PlaylistDetailPage（playlist_detail_page.dart:184，来源 library/discover/search/playlist_browse/custom_playlists/sidebar 等全部推入点）、ArtistDetailPage（artist_detail_page.dart:134）、AlbumSongsPage（album_songs_page.dart:134）。此前 shell_test「切换页面后 PlayerBar 仍在」仅覆盖 IndexedStack 壳页（IndexedStack 恒挂载，P2-11 关闭口径），未覆盖推入路由。
- **修复（Phase6-QA1 修复轮入树）**：桌面壳层中央内容区内嵌 Navigator（app_shell.dart `Navigator(pages:[MaterialPage(IndexedStack…)])`，key=nav_bus.dart `contentNavigatorKey`）：内容区内的 `Navigator.of(context)` 就近解析自动落内嵌，推入页只占中央内容列，Header/侧栏/右栏/PlayerBar 天然常驻（pages API 让壳层 setState 重建传导进基页，SDK `_updateSettings`→`changedInternalState` 实证）；壳层兄弟子树推入入口显式落内嵌：app_sidebar.dart:557 自建歌单项、app_shell.dart `_openSeedDetail` 四分支；Esc 链补内容区档（根路由 pop 优先于内嵌 maybePop，根路由恒渲染在内嵌之上）；同轮修复内嵌 Navigator 引入的焦点回落缺陷：`Focus(autofocus)` 改显式 `_shellShortcutsFocus` + `_setNowPlayingOpen` 统一出口在转场帧后收回 primary（全屏播放页切换拆 shell-main 后焦点默认落 home ModalScope，§9 Esc/空格/方向键全链失灵，A/B 实跑确认 Phase 6 Esc 链用例被波及；NowPlayingPage 自身 Esc 绑定与壳层重复，Phase 3 双路径语义不变）。
- **回归**：shell_test.dart 新增 group「推入式详情页播放器跨页面保持（§7.5 / Phase 6 退出条件）」3 条：1024x640（QA 视口）推入本地音乐页后 `contentNavigatorKey.canPop()==true` + PlayerBar/AppSidebar 在树 + 曲目「夜航」/「04:04」保持；1440 推入页不挡右栏（队列面板可达）+ Esc 先关右栏再退推入页 + PlayerBar 常驻；详情页自身返回钮（tooltip「返回」）经内嵌 Navigator 返回壳层保持。定向 7 文件 **81 项全绿**（78 基线 + 3 新增，`00:13 +81` exit 0）+ 壳系 3 文件 22 项（ui_only_boot/now_playing/chrome_theme，全屏进出与浅色主题不受影响）+ 全量 flutter test **375 项全绿**（`00:33 +375` exit 0）+ analyze 0 + dart format 5 文件。
- **行为变化（如实登记）**：(1) 推入页渲染进中央内容列（与 §7.5 三栏 Shell 语义一致），行右键菜单（showSongMenu bottom sheet）等经内嵌 Navigator 的浮层挂载点从窗口底移到内容区底（desktop_queue_interaction 全 7 项仍绿）；(2) 打开全屏播放页再关闭后推入详情栈不复存在：AnimatedSwitcher 交换 shell-main 的 §5.1 既定设计下内嵌栈随之进出树，此前推入根路由时代该场景不可达（推入页盖住 PlayerBar，入口不存在），非回归；(3) 移动/平板壳不用内嵌 Navigator，全屏推入是移动形态既定设计，零变化（mobile_shell/tablet_shell 全绿）。
- **诚实标注**：运行时实拍已于 2026-11-13 QA 复查轮补齐复核（重建 debug bundle kernel_blob 05:06:57 → Xvfb :61 → 受影响视口重截 2 张逐张目检通过：1024x640 详情页壳内渲染 + 1280x800 双击行 3 实跑 0 次 Unhandled Exception、PlayerBar 真实播放态，见本文件顶部复查轮条目），widget 用例与运行时实拍双证据齐；Rust 零改动。

### P1-19 final uionly 截图 7 张视口标注失实（Phase 7 收口轮报告员目检发现）【已关闭，2026-11-13 登记即关闭】

- **现象**：`docs/redesign/screenshots/final/` 13 张 uionly 截图中 7 张视口标注与实际渲染不符：(a) `desktop-home-1024x640-uionly.png` 展开侧栏（1024 按 responsive_shell.dart:155-172 应为折叠 72 rail）+ 无 PlayerBar + 无 DEBUG 横幅，三重矛盾指向「1280×720 默认窗在 1024×640 屏上的左上裁切」；(b) 6 张 phone-*（标注 360/390/430）实际全部 560 宽（magick identify 实测，执行批次 Xvfb 屏 :227-:232 即 560×800/844/932 系）。
- **根因**：uiOnly 分支不应用 `VOICEFOX_START_SIZE`/WindowOptions：初始窗口尺寸/minimumSize 代码块位于 main.dart:143-175（真实桌面分支），uiOnly 分支 main.dart:106-116 提前 return；报告员 `xdotool getwindowgeometry` 实测 uiOnly 启动默认窗 **1280×720**。另实测 uiOnly 无 560 钳制（xdotool windowsize 360×800 成功），560 系截图系执行批次误按真实分支 minimumSize 经验取 560 屏。
- **应用本体无回归（关闭关键证据）**：真 1024×640（xdotool 精确调窗）重截渲染折叠 72 rail + PlayerBar 空态 + DEBUG 横幅，与 resolveShellMetrics 断点逻辑及 Phase 6 QA 实拍（desktop-library-1024x640-minwindow.png）一致；真 360×800 渲染降级布局 + 移动形态页面内容无溢出。
- **处置（登记即关闭）**：7 张全部以报告员真实视口重截件替换（Xvfb :77 + debug bundle kernel_blob 06:33:23 + xdotool windowsize + getwindowgeometry 核实 + import -window 逐张捕获 + identify 尺寸核验 + 逐张 Read 目检），尺寸现全部与标注一致；逐张目检结论见 phase-7-report.md「截图路径」节。处置遵循本矩阵 04:11/04:107 先例（证据失实判 P1、重截后登记即关闭）。
- **诚实标注**：root cause 的 uiOnly START_SIZE 缺口以 **P3-10** 单独立项开放（验收截图管线缺陷，不影响生产运行时，真实分支 WindowOptions/minimumSize 链路不受影响）；本轮重截为 debug 构建（DEBUG 横幅固有）+ uiOnly 无后端（页面呈真实空/错误态、设置页永久「配置加载中…」），证据价值限于壳层/布局/断点，不承担功能验证。

## P2（登记）

| ID | 问题 | 证据 | 指南条款 |
|---|---|---|---|
| P2-01 | 【已关闭，随 P1-09 关闭（2026-11-11 复验轮）】VxColors/VxDarkSurface 硬编码深色常量被 shell 组件无条件引用；已收口为 VxChrome 亮度双源 token（design_tokens.dart:148-157，浅色侧 VxLightColors，深色像素零变化） | chrome_theme_test 5 项 + 代码 diff | §3.2 |
| P2-02 | 【已关闭（2026-11-14 清尾 L1 轮，护栏锁定）】双 ThemeData 产源收口：运行时唯一真源 = myune ThemeProvider（ColorScheme.fromSeed + MiSans，main.dart MaterialApp 消费）事实化登记；`src/theme/voicefox_theme.dart` 头注改为「非运行时真源」（现仅设置页主题色卡逐卡预览 `_ThemeCard` + myune_preview + 测试）、`src/design_system/voicefox_theme.dart` 头注改为「Design-system 预览 ThemeData」（仅 Gallery 预览页 + design_system 测试；`vxMonoStyle` 等宽样式仍被 vx 组件族引用，与 ThemeData 无关）；运行时入口不得引入任一预览构建器由 test/theme_source_guard_test.dart 锁死 | 护栏 2 项（运行时 5 文件 main.dart/app_shell/responsive_shell/myune provider/app_model 零引用断言 + settings_page 逐卡预览 import 例外在位断言），报告员实跑绿（全量 380 项内）；两文件头注 diff | §1.2-4 |
| P2-03 | 【已关闭（2026-11-11 Phase 3 收口轮）】发现页/首页横向书架最右卡被窗口右缘裁切：`discover_page.dart` `_playlistGroup` 水平 ListView 补末尾 `padding: EdgeInsets.only(right: VxSpacing.lg)`（:530-535），滚动到末尾不再贴边裁切 | discover_page.dart:530-535 代码 diff + 实机截图 linux-discover-360x800-default.png（真实后端运行，默认滚动位右缘可见卡完整渲染无溢出，报告员目检）+ 收口轮 QA 逐张复核；横滑到末尾的末态未单独手势演练，由 ListView 末尾 padding 语义结构性保证（如实登记） | §12.5 |
| P2-04 | 窗口尺寸契约在 niri 下不可靠：请求 1440x900 实得 tile 1212x1274（surface 948x1010，<960 触发降级布局）；Xvfb 下请求即所得。验收截图须在受控显示器采集 | 第一轮 + 本轮 :1 观察；本轮 Xvfb 对照 | §12.4 |
| P2-05 | 【维持开放（2026-11-13 Phase 6 W6 运行时核验）】桌面系统集成（MPRIS/托盘/系统通知）GUI 未接：Xvfb 真实后端起 GUI（debug bundle）后 `busctl --user list` 实跑，user session bus 上 grep `org.mpris.MediaPlayer2` 零命中（仅 DE 自身 dev.noctalia.Mpris 服务，非本应用）；grep 复核 mpris 仅存在于 TUI crate（app/src/main.rs:17 cfg(linux)），runtime/ffi 0 命中。GUI 无 MPRIS 服务为实跑事实，Rust 实装留独立批次（桌面零回归铁律） | busctl 实跑输出（2026-11-13，app 运行中）+ grep 证据 | §12.6-8 |
| P2-06 | 【已关闭（2026-11-12 封面带修复轮）】移动全屏播放页封面横滑切歌已落地：`_SwipeableCover` 只绑封面区（避开 LiveSeekRow 横向拖动与屏幕左右缘系统返回手势，§5.7:459），速度阈值 500px/s 滤误触，左滑 next/右滑 previous 走 AppModel 真实命令，拖动中方向提示层随 Cancel/End 整体移除不残留 hit-test 区 | mobile_now_playing_test.dart group「封面横滑切歌（P2-06，§5.7 只绑封面区）」4 用例（左滑 next/右滑 previous/慢速不切/方向提示可见反向切换 Cancel 隐藏）；真机边缘手势冲突验证（§5.7:463）维持未验证（P1-06），如实披露 | §5.7 |
| P2-07 | 【已修复】设置页左侧分类导航 9 组（播放与音效/音源/下载/歌词/外观/网络/账号与集成/快捷键/关于） | linux-settings-1440x900-default.png | §7.3 |
| P2-08 | 【维持开放（2026-11-14 清尾 L1 轮：panic/Flutter 异常面 crash.log 取证已接，引擎级 GL abort 无 unwind 仍无取证，见 P1-05 清尾 L1 条目）】xwayland-satellite 转发的 X 客户端 resize 触发 `Timed out waiting for OpenGL frame`，随后进程静默消失（关联 P1-05 观察）；niri IPC 与 Xvfb 路径未见 | app-run1.log + pgrep/coredump 取证 | §11 |
| P2-09 | 队列拖动排序 / 队列内跳播：后端无对应 FfiCommand，UI 禁用并说明（不伪造）；§7.4「拖拽排序」目标待后端命令落地。2026-11-12 补记：全屏播放页队列挂载形态已落 §5.7:452 底部 sheet（DragHandle 下滑/点遮罩关闭，enableDrag=false 与列表滚动解耦），拖拽排序仍如实禁用 | queue_panel.dart:8-10；queue_interaction_test.dart 8 用例（sheet 开关/清空确认/移出/随机/空态/拖拽禁用说明） | §7.4 |
| P2-10 | 【Phase 3 已关闭（2026-11-11）】曲库页快捷入口卡标签省略号截断（430 视口三列等分标签宽度不足）：`library_page.dart` `_entryCards` 加 LayoutBuilder（<512 与 `_header` compact 同阈值），窄视口改两行卡（标签独占一行 + 图标/计数次行），桌面 ≥512 单行布局零变化；修复同时暴露并修复同域潜在缺陷两处：`vx_track_row.dart`（<480 窄视口 hover 操作列不再预留 4×40px 固定宽，触屏无 hover、长按菜单为真实替代，360-430 手机档行尾溢出实测 11/23px）与 `vx_empty_state.dart`（矮槽位改「居中+可滚动」结构，chips 行挤压歌单档空态不再 RenderFlex overflow） | mobile_library_page_test.dart 2 项（360/390/430 无溢出 + TextPainter 宽度断言标签不截断）+ golden 重截 fluttertest-library-430x932-dark-default.png（临时测试用后即删零残留，目检：入口卡两行形态、标签完整、行表/chips 无溢出条纹）；该 golden 的 610d6d8 中间版本（18496B，07:29）为页面级 tofu 渲染、本目检对其不成立，已按 2026-11-12 复截版（61983B，01:53）复核，目检结论在有效证据上重新成立，详见 P1-12「证据勘误与复截」 | §5.5 |
| P2-12 | 【已关闭（2026-11-12 登记并关闭，Phase 2 追加批次）】全屏播放页封面恒 320 封顶、未落 §5.7:446-447 280-340dp 自适应带（原 `(height-330).clamp(160,320)`：390/430 视口未达带上限 340，且无带语义测试）：改 `max(min(min(height-330, width-40), 340), min(160, widthCap))`（mobile_now_playing_page.dart:337-348），<560 极矮视口回退 240 + 滚动、歌曲信息与播放控制不被挤出可视区（§5.7:447） | mobile_now_playing_layout_test.dart group「全屏封面 280-340dp 自适应带（§5.7:446-447，Phase 4）」3 用例（三视口 [280,340]／极矮 430×560 回退 240／矮 430×680 收缩分支）+ golden fluttertest-nowplaying-{360x800,390x844,430x932}-dark-playing.png：报告员 magick 像素实测封面 320/340/340 逐视口与公式一致（360 宽度封顶分支、390 带内、430 带上限），逐张目检无溢出/tofu/debug banner、全屏独占符合 §5.1 | §5.7:446-447 |
| P2-13 | 【已关闭（2026-11-14 清尾 L1 轮）】失败重试后损坏文件计「复用」而非重新解析失败：`source/src/local/mod.rs:253-262` scan() 失败清单非空时强制重扫（force=true，失败文件重新解析并重新报告），失败清单清空后恢复无变化快路径（§8.4 性能契约不受影响）；与偏差 E3「重试=重扫」语义对齐，失败文件不再被快路径计成复用、失败清单不再蒸发 | 回归 `manual_rescan_reparses_failed_files_instead_of_counting_reuse`：首轮 failed=1 → 无变化重扫 failed=1/reused=1（损坏文件重新解析仍失败，非复用/蒸发）→ 修复文件重扫 parsed=1 且失败清单清空 → 再扫恢复快路径 reused=2；`cargo test -p lx-source --lib local::` exit 0（报告员实跑） | §5.10 流程 6 |
| P2-14 | 【已关闭（2026-11-14 清尾 L1 轮，测试锁定）】解析（resolving）阶段暂停打成「失败」：生产行为已在树，即 pause() 接受 Queued/Resolving/Downloading/Tagging（点击立即 Paused）+ finish/update_state 对 Paused 短路防迟到结果改写，经 `git show 57db10b:download/src/manager.rs` 实核自 Phase 5 收口提交在位（:413/:642/:659，与当前工作区行号一致）；D4 运行时观察对应收口提交前的会话构建。本轮补确定性回归测试锁定契约（本轮生产代码零改动）。诚实边界：无法排除「解析失败先于暂停落地」的微竞态（finish(Failed) 先到则暂停无操作，此时显示失败为语义正确）；运行时重走未做（如实登记） | 回归 `pause_during_resolving_keeps_paused_against_late_results`（manager 层无网络：Resolving 点击暂停立即 Paused → 迟到 Failed/Downloading/Done 全部短路 → 四活跃态均可暂停）；`cargo test -p voicefox-download pause_during_resolving` exit 0（报告员实跑） | §5.11 |
| P2-15 | 【已关闭（2026-11-14 清尾 L1 轮）】360 视口曲库入口卡「喜欢的歌曲」标签省略号截断：`library_page.dart:219-224` compact 两行卡标签改 `FittedBox(fit: BoxFit.scaleDown)` 按需整行缩小渲染，省略号路径结构性不可能触发（只缩放不裁切）；P2-10 的「find.text 对 ellipsized Text 仍命中」测试盲区以结构性断言关闭：mobile_library_page_test.dart 新增 360 最窄档用例（FittedBox 在树 + RenderParagraph 按 `getMinIntrinsicWidth(infinity)` 理想宽度布局断言，旧形态 plain Text + maxLines:1 + ellipsis 在 360 档布局宽度被压到理想宽度以下该断言即失败） | 报告员运行时目检：uiOnly debug bundle（2026-11-14 00:35 重建）+ Xvfb :117 + VOICEFOX_START_SIZE=360x800 → 360×800 曲库截图「喜欢的歌曲」标签完整无省略号（同排最近播放/本地音乐完整），docs/redesign/screenshots/final/phone-library-360x800-uionly-recheck.png；widget 用例在全量 380 项内绿 | §5.5 |

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
| P3-09 | 【开放（2026-11-13 Phase 5 收口轮登记，运行时验证发现 D5）】进行中下载行 560 宽 debug overflow 23px + 进度「1.4MB/475.7KB」已收字节大于声明总量的显示异常（音源大小不一致；失败原因文案 UI 截断「失败 · 音频…」关联登记，完整原因未在 UI 内展开） | 运行时实跑观察 + docs/redesign/screenshots/final/desktop-downloads-560x844-failed.png（1.4MB/475.7KB 与「失败 · 音频…」在图内可见，报告员目检） | §5.11 |
| P3-10 | 【已关闭（2026-11-14 清尾 L1 轮）】uiOnly 验收分支支持 `VOICEFOX_START_SIZE/POS`：`_startSizeFromEnv`/`_startPosFromEnv` 提取为共享 helper（main.dart:105-124），uiOnly 分支同样应用（main.dart:180-199，waitUntilReadyToShow；两个 env 均缺省时不走该路径，既有启动零变化）；minimumSize 语义裁决落地 = uiOnly 有意不设（无 560 钳制，360-560 宽可达，对截图管线有利，main.dart uiOnly 分支注释登记）；真实桌面分支复用同一 helper（默认 1150x720 与 minimumSize 链路零变化，diff 仅重构） | 报告员运行时实核：uiOnly bundle + VOICEFOX_START_SIZE=360x800 启动 → xdotool getwindowgeometry 360×800 精确生效（无 1280×720 默认、无 560 钳制）；真实分支运行时未重测（代码 diff 复用同一 helper，如实登记） | §12.4 |

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
| 本地音乐真实导入并播放 | Phase 5 桌面已验证（合成 PCM WAV 真实导入：Rust 单测覆盖 10k 指纹增量/取消不回滚/单文件导入/缓存重启加载；Android 实机维持未验证，见 Phase 5 偏差 E1） |
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
| P1-14 | 【已关闭（2026-11-13 Phase 6 收口轮，根因定位 + 修复）】播放栏右簇不贴右缘的根因：PlayerBar 左区 `Flexible(flex=1, loose)` 与中区 `Expanded(flex=1)` 平分剩余空间,左区实际内容仅约 278px 用不满 flex 预算,中区被钳 826px(1920 宽 render-tree 实测),行尾留下约 547px 尾距(与用户实拍形态一致)。修复：左区改非 flex 子项(ConstrainedBox maxWidth 340/260 钳宽;内层 `_TrackInfo` mainAxisSize.min + 文本 Flexible 保窄窗不溢出),中区 Expanded 独占全部剩余空间(player_bar.dart Phase 6 批次注释) | desktop_three_column_layout_test.dart「P1-14 右簇贴右缘 + P2-11 空态常驻」1024/1920 两宽位置断言(最右控件距播放栏右缘 <32px)+ 五视口不变式 1024/1150/1280/1440/1920 + 运行时实拍对照 docs/redesign/screenshots/phase-6/desktop-{1024x640,1920x1080}.png(右簇贴右缘,逐张目检);修复前同一断言在 widget 层复现 563.5px 尾距(2026-11-13 实跑) | §7.5 |
| P2-11 | 【已关闭（2026-11-13 Phase 6 收口轮）】播放栏常驻性落地：PlayerBar 恒挂载(app_shell.dart 仅全屏时摘除,维持)+ 空态不保留不可点击的假控件,`_CenterTransport` 无歌曲早退(传输控制与进度行不进树),左区保留「未在播放 / 选择一首歌曲开始播放」空态提示,右区音量/输出/歌词/队列全部真实可用(player_bar.dart) | desktop_three_column_layout_test.dart 空态用例(PlayerBar 在树 + 空态提示在 + VxPlayerControls/LiveSeekRow findsNothing)+ 运行时 5 视口实拍空态一致(phase-6/desktop-*.png 逐张目检);矩阵原「疑似无歌曲时整条隐藏」与实际不符,按「常驻 + 空态去假控件」闭合,未采用「保留隐藏行为改指南」分支 | §7.5 |

用户原话（登记依据）：「底部的那个播放状态栏，不应该是什么时候都常驻的吗」；「全屏的时候，底部状态栏明显没有自动适应，右边空了一大截」。

## Phase 5 偏差登记（2026-11-13，统计/取消/持久化/下载暂停续删除收口批次）

- **E1 Android SAF `content://` 导入翻译未实装**：导入入口双选项（选择文件夹/选择文件）在位，`localFilePicker`/`localImportResolver`（local_music_page.dart）均为可注入 seam；生产缺省 resolver 对 `content://` 抛 `UnsupportedError`，UI 显示「暂不支持该文件来源（content://）」错误文案，不伪造导入成功。本环境无 JDK/模拟器（P1-06 同口径），SAF 持久授权翻译与实机行为登记为未验证。裁决点：Android 构建环境就绪后实装 resolver 并实机验证。
- **E2 暂停态 `.part` 孤儿文件策略（最小语义）**：暂停保留 staged 前缀、取消暂停任务/删除任务会清理本任务的 `.part`（manager.rs `cancel`/`delete_file`）；但应用重启后内存任务消失，历史 `.part` 不做启动清扫，同曲重新入队走全新 `unique_dest` 时旧 `.part` 可能残留。裁决点：入队前按 stem 清扫孤儿 `.part`，或重启后以 staged 前缀重建续传（需持久化 last_url）。
- **E3 §5.10 流程 6「失败项可重试」以重扫语义实现**：统计条失败项>0 时提供「重试」按钮（重扫即重试：失败文件没有指纹记录，重扫必然重新解析；部分失败不回滚已提交结果——扫描快照整体替换语义天然保证）。逐文件选择重试队列未做。
- **E4 下载任务跨会话恢复不做**（计划明确不做）：进行中/失败任务重启后消失；已完成记录持久化于 downloads.json（records.rs:109）。`.part` 孤儿见 E2。
- **E5 wire 状态词汇表统一（根因修复，有行为变更）**：`DownloadTaskDto.state` 由 `DownloadState::label()` 中文串改为 `code()` 英文机读键（queued/resolving/downloading/tagging/done/skipped/cancelled/paused/failed）——历史上 Dart 侧匹配英文键在生产全为死代码（runtime/src/lib.rs 发中文），本轮修复根因而非在错误词汇表上加 'paused'；中文文案由 Dart `downloadStateLabel` 映射，TUI 继续用 `label()`。FFI 为进程内接口，无外部契约受影响。
- **E6 §5.2 D3「最近添加」列表本体不做**（计划明确不做）；数据地基已备：`first_seen`（来源文件 → Unix 秒）随曲库缓存持久化（source/src/local/cache.rs），后续列表功能直接消费。
- **本轮验证记录（报告员实跑）**：定向 flutter 4 文件 39 项全绿（local_music_import 7 + phase5_local_music 8 + phase5_downloads 12 + mobile_home_page 12）；cargo 定向 download 70 / lx-source local:: 28（含 10k 复用契约）/ application 72 / runtime 40 / ffi 6 / app 333 全部通过；clippy 六 crate 新增告警 0（lx-core 基线 30 条维持）；codegen（flutter_rust_bridge_codegen generate 2.13.0）+ build_runner（freezed）已跑，生成文件随本轮提交。全量 flutter test / cargo test 未跑（外部门禁统一执行）。

## Phase 6 偏差与收口登记（2026-11-13，DesktopShell 规格对齐批次）

- **G1 侧栏折叠 override 优先级（§7.2 最小语义的自建裁决）**：用户记忆值（折叠/展开 + 拖调宽度，SharedPreferences `shell.sidebar.width` / `shell.sidebar.collapsed`）仅作用于 ≥1200 展开档；960-1199 规格硬带不接受用户展开 override，1024 展开态 Header 实测 RenderFlex 溢出 21px（2026-11-13 widget 层实证，品牌区 240 + 固定件 + 搜索框最小宽不满足）；<960 降级布局恒隐藏不受用户值影响。裁决点：若产品要求窄带可展开，须先解决 Header 溢出（搜索框 minWidth 或品牌区策略）。
- **G2 规格数值冲突按 ask/§7.1 采用**：侧栏拖调带取 §7.1 图 240-300（计划转述 §7.2 文字为 220-320/默认 260）；右栏取 §7.4 300-420 默认 340；播放栏取 §7.5 76-84 上沿 84。规格原文（01 计划书）按上下文纪律本轮未核读，数值经 ask「实现要点」逐项确认；冲突裁决点留 owner。
- **G3 VxTrackRow 三档密度 50/58/66 vs §7.6 行高 56-64**：standard 58 在带内（桌面歌单表缺省档达标），compact 50 / comfortable 66 越界；改档会波及移动端复用组件，本阶段不动实现，desktop_queue_interaction_test 密度断言锁登记口径防漂移。
- **G4 平板 840-1199 右栏挂载形态改 end panel 内嵌**（§6.2:546「overlay 或 end panel」二选一取 end panel）：原 overlay+scrim 挡中央内容与 §6.3:554「中央内容仍可操作」相悖；600-839 rail 档维持 Modal/Overlay 语义（§6.1:539）。**D1/D2 维持现状**（触屏 ≥1200 走 TabletShell.triple）：tablet_shell_test 新增 1199/1200 边界 widget 断言（dual/triple 均为内嵌，差异仅在 rail extended 语义与断点归属），裁决点留 owner（≥1200 切 DesktopShell 涉 window_manager 平台差异，独立批次）。
- **G5 golden 基础设施不存在（计划 risk①/W3/W5 的「golden」承诺无对象）**：全仓 grep `matchesGoldenFile|goldenFileComparator` 0 命中（2026-11-13 复核），此前提交信息中的「golden」均为尺寸/像素断言。本轮以尺寸断言（mobile_now_playing_layout_test 触点 34/26/48 组，锁桌面渲染零变化）+ 运行时 5 视口实拍替代；image golden harness（基线目录/--update-goldens 流程）建立与否归 Phase 7 裁决。
- **G6 平板壳运行时不可达**：Linux 桌面 isTouchPlatform=false，main.dart 无强制触屏入口（grep touchPlatformOverride/VOICEFOX_FORCE 0 命中），平板 5 视口运行时截图不可拍；平板证据面 = widget 层（tablet_shell_test/mobile_shell_test 全绿 + 1199/1200 边界断言），触屏真值维持 P1-06 口径未验证。
- **G7 W2 按评审修正执行**：计划原「缺右键菜单（grep onSecondaryTap 0 命中）」前提为假，实跑 8 命中；右键菜单（showSongMenu）与「下一首播放」真实命令（FfiCommand.queueAdd next:true，song_tile.dart）早已在位，本轮核验覆盖 + 新增 desktop_queue_interaction_test 7 项，未新建第二份菜单、未禁用活功能。「后端无 FfiCommand 的项如实禁用」仅适用于队内移动/插入位置类（P2-09 口径维持）。
- **G8 W6 MPRIS 核验结论**：GUI 运行中 user bus 无 org.mpris.MediaPlayer2.*（busctl 实跑，app up 后采集），P2-05 维持开放，Rust 实装不在本阶段（桌面零回归铁律）。
- **G9 运行时未验证项（如实披露）**：真实桌面拖调把手交互（无输入合成驱动拖调实机）未验证；侧栏宽度/折叠记忆的运行时重启路径由 widget 层重启用例（desktop_three_column_layout_test）+ SharedPreferences mock 通道覆盖；侧栏折叠/展开过渡帧溢出修复（OverflowBox 自然宽布局 + Stack 裁剪，2026-11-13 widget 层实证 _NavRow <68px 中间帧溢出 21px）实机动画观感未走查。
- **本轮验证记录（报告员实跑）**：定向 7 文件 **78 项全绿**（`flutter test test/desktop_three_column_layout_test.dart test/desktop_queue_interaction_test.dart test/shell_test.dart test/mobile_now_playing_layout_test.dart test/queue_interaction_test.dart test/tablet_shell_test.dart test/mobile_shell_test.dart --reporter compact`，`+78: All tests passed!` exit 0；desktop_three_column 19 + desktop_queue_interaction 7 + shell 10 + mobile_now_playing_layout 15 + queue_interaction 8 + tablet_shell 7 + mobile_shell 9，与 +78 计数吻合）；flutter analyze 0 issue；dart format 12 文件（6 changed）；debug bundle 重建（`flutter build linux --debug` exit 0，RUSTUP_TOOLCHAIN=1.99.0，Rust 零改动）；Xvfb 真实后端 5 视口（1024x640/1150x720/1280x800/1440x900/1920x1080）实拍逐张 Read 目检通过（30k 曲库 debug 启动约 90-120s，poll `playback pump started` 后采集；P1-14 两宽对照 + P2-11 空态在图内直接可核）；MPRIS `busctl --user list` 实跑（app 运行中）grep org.mpris.MediaPlayer2 零命中。全量 flutter test / cargo test 外部门禁统一执行，本轮未跑；不执行 git commit/push。

## 用户实测缺陷登记 · 第二批（2026-11-14 02:0x，用户全屏实际使用中报告）

证据：`docs/redesign/screenshots/user-feedback/2026-11-14-discover-source-dropdown.png`（音源下拉展开）、`docs/redesign/screenshots/user-feedback/2026-11-14-nowplaying-no-cover-lyrics.png`（全屏播放页 02:02 实拍）。清尾「用户实测缺陷修复」批次收口。

| 编号 | 严重程度 | 位置 | 问题 | 归属 |
| --- | --- | --- | --- | --- |
| P1-20 | P1 | 发现页音源筛选器（discover_page.dart `_selectSource`/`_loadAggregated`） | 用户实测：音源下拉选择单音源后，再选「全部音源」无法回到聚合视图（静态读码 fetch/渲染链路看似正确，需运行时复现定位真实根因） | 清尾修复批次 |
| P2-16 | P2 | Now Playing 封面链 | 全屏播放页 Light It Up（来源待查）封面灰占位；P1-15 的 403 修复未覆盖该曲目/音源，需定位该曲封面 URL 与所属音源后补齐 | 清尾修复批次 |
| P2-17 | P2 | 歌词页（now_playing 歌词区） | 【2026-11-14 门禁恢复批次：代码+测试面闭环，运行时复验缺，维持开放】歌词「暂无」且文案自述「本版本暂无手动重新获取入口」。处置：LoadLyrics FFI 命令链（eb1afc3）+ 本批次补 `LyricsRetryButton`（在途禁用/成功复位/失败通知复位/12s 超时兜底）+ 6 项 widget 断言；`service.rs` DIAG 残留清除。缺：真实 App 内实机点按验证 | 清尾修复批次 + 门禁恢复批次 |
| P2-18 | P2 | 桌面全屏播放页布局（§7.7） | 【2026-11-14 门禁恢复批次：代码+测试面闭环，运行时实拍缺，维持开放】布局空旷：封面固定左中，右半区大面积空置（02:02 实拍）。处置：hasLyrics 单列回退（eb1afc3）+ 本批次解决与 P2-17 的交叉（单列内保留重取入口）+ now_playing_test 旧断言按新行为重写（18 项全绿）。缺：无歌词单列布局运行时实拍 | 清尾修复批次 + 门禁恢复批次 |

用户原话（登记依据）：「显示没有封面也没有歌词啊」「这个切换歌单啊，居然最开始是全部歌单，但是随便选择一个歌单之后，居然无法切回去啊」「整个界面的ui部分也不够」。

## FFI 边界风险登记（2026-11-14 Batch A 只读审计，HEAD 4e40ee7）

来源：第三轮工程演进计划 Batch A 审计。判定与修复方案见 `docs/architecture/ffi-reliability-design.md`，接口清单见 `docs/architecture/ffi-contract-inventory.md`。全部为静态读码判定，未做实机压测；修复实施前一律维持开放。

| 编号 | 级别 | 位置 | 判定与内容 | 归属 |
| --- | --- | --- | --- | --- |
| FFI-R01 | P1 | host_player.rs:88,146-161 / main.dart:225-301 | 【2026-11-14 A-1 批次：代码+测试面闭环，运行时/真机证据缺，维持开放】已证实：Dart 订阅前 Rust 派发 Play 静默丢失。处置：`pending_play` 挂起槽 + `subscribe()` 首个订阅者补投（stop 清除/补投后清空/二次订阅不重复）；旧「丢指令但接受」测试强化重写为补投断言。缺：真实移动端引导窗口复验 | Batch A-1 |
| FFI-R02 | P2 | host_player_bridge.dart:141-155 / mobile_audio_player.dart:184-196 | 已证实（串行结构）：命令泵逐条 await，慢 Play（网络加载数秒）阻塞 Pause/Stop/切歌；延迟幅度需设备验证 | Batch A-1 |
| FFI-R03 | P1 | host_player.rs:88 / lib.rs:1332-1340 / host_player_bridge.dart:146-150 | 【2026-11-14 A-1 批次：重同步半边闭环（lagged 后回灌当前快照），字符串协议识别与积压根因（缓冲语义）维持开放】已证实：>64 积压 Lagged 物理覆盖最旧命令（常为第一条 Play）；处置：Dart lagged 后 `_resync()` 回灌快照 + api.rs 过时注释修正。缺：压测复现与结构化错误枚举（A-3） | Batch A-1/A-3 |
| FFI-R04 | P1 | host_player.rs:41-62 / host_player_bridge.dart:158-185 | 已证实（A-1 未实施，依赖 DTO 变更）：仅 Play 带 generation，Seek/Pause/Resume/Stop 等无代次；lag 后旧命令直打当前曲目。处置：A-1b 引入 commandId/generation（codegen 本地可用）；重同步（R03 半边）缓解误执行面 | Batch A-1b |
| FFI-R05 | P2 | services/playback.rs:95,123 / service.rs:1692-1706 | 需设备验证：双 play 并发 generation 在 resolve 前自增，完成顺序不定可后点先播；并发结构静态成立 | Batch A-1 |
| FFI-R06 | P1 | host_player.rs:149-239 / host_player_bridge.dart:146-153,249-255 | 【2026-11-14 A-1 批次：Dart 侧两项闭环（命令异常分捕获不杀泵 + dispose 可等待/泵可终止），per-command ack 维持开放】已证实：无 per-command ack（send 结果全吞、play 恒 return true）；单命令异常杀死整条 pump；dispose fire-and-forget。处置：分捕获 + Future<void> dispose（pumpExitTimeout 兜底）+ _disposed 守卫。缺：ack 语义需 DTO 变更（A-1b） | Batch A-1/A-1b |
| FFI-R07 | P1 | host_player.rs:117-129,172-176 / service.rs:166-212 | 【2026-11-14 A-1 批次：代码+测试面闭环（存活看门狗），真机断连证据缺，维持开放】已证实（静态）：宿主断连后 watch 恒留最后值，状态永久冻结。处置：`last_report` 回流时间戳 + `liveness_tick`（宿主消失/冻结回落 Stopped，有挂起 Play 不回落）+ new_host 启动 std 线程看门狗（5s/20s），回落经观察者泵正常广播。缺：真机断连复验 | Batch A-1 |
| FFI-R08 | P2 | service.rs:1771-1780 / app_model.dart:272-336 | 已证实：Rust 每事件尾随全量 StateChanged 快照被 Dart 整体丢弃（无该分支）；一次性事件（Notification/二维码/Sync 10 个/Browse 应答/CustomPlaylistCreated）丢即丢，后者 Future 悬挂 | Batch A-2 |
| FFI-R09 | P1 | lib.rs:1217-1232 / app_model.dart:216-228,232-256 / runtime/src/lib.rs:408-421 | 已证实：attach 先拉快照后订阅有丢失窗口；_refreshState 并发无合并旧可覆盖新（无 revision）；state() 全量克隆含 local_songs，活跃下载期间每 500ms 一次全量曲库克隆；卡顿幅度需设备验证 | Batch A-2/A-3 |
| FFI-R10 | P2 | state.rs:91-107 / lib.rs:1069-1077 / service.rs:342,373 | 已证实：播放状态串两处重复定义；取消语义编码在 message 文本「同步已取消」；错误全 String 无结构化错误码 | Batch A-3 |
| FFI-R11 | P3 | pubspec.yaml:37 / ffi/Cargo.toml:12 | 已排除（当前一致）：codegen 双侧 2.13.0 + smoke 测试断言；遗留 pubspec caret 范围风险，建议 CI 加生成一致性检查 | Batch A-3 |
| FFI-R12 | P3 | runtime/src/lib.rs:22-50 / service.rs:191 / player/src/engine.rs:1096-1098 | 已证实（有意设计）：进程级 Runtime 无任务取消/优雅关停；播放泵与 downloads_bridge 永不退出；MpvEngine Drop 因 Arc 持有不执行，依赖 OS 回收；登记观察 | 观察态 |

