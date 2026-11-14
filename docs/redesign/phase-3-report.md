# Phase 3 Report（手机 Library、搜索、发现和详情）：已完成（2026-11-11 收口轮）

> 分支：`feat/ui-redesign`　模板：指南 §14
> 覆盖批次：①**实施轮**（前轮已登记 §17/04 矩阵）：搜索音源 chips 化 + 搜索历史、曲库来源筛选、三详情页下拉刷新、收藏 pending 乐观回滚、P2-10 关闭、P2-03 代码修复；②**收口轮**：定向 10 文件 72 项测试全绿（报告员复跑）+ release 构建 Xvfb 实跑真实后端 4 视口截图 + 逐张 QA + P2-03 关闭；③**2026-11-12 复验轮 → QA1 修复轮 → QA 复查轮（修复验证与重截，本报告最新覆盖）**：防抖 fake-time 用例 + P0 四态证据缺口补 6 条 widget 断言（79 项全绿）+ QA 复查双关闭确认 + release 重建 + 受影响视口（曲库/发现/专辑）重截 3 张（含专辑真实错误态实拍）。
> 状态口径：§13 Phase 3 退出条件三条现均以契约证据形态成立（widget 测试 + 桌面真实运行截图层）；**Android 真机项本批不适用（P1-06 环境阻断维持）、浅色主题、交互式运行时手操、专辑详情成功态实机画面维持「未验证」**，如实披露。

## 范围

§13 Phase 3 工作项 → 本批实现映射：

1. **重建 Library**：曲库窄视口收口（P2-10：入口卡两行卡 + 同域两处）；来源筛选 chips 从 favorites+history+localSongs 实际派生（组合规则登记于 `library_page.dart` 注释与 `mobile_library_page_test`）。
2. **搜索筛选、分页和状态**：音源筛选 chips 行（§5.4:355 裁决，横向 ListView）、搜索历史本地持久化（容错降级）、防抖 + requestId in-flight 锁、载/错/空/成功四态。
3. **发现页音源与分类**：切源重载当前分类、按音源分组真实歌单卡、P2-03 末尾 right padding。
4. **歌单/专辑/歌手详情**：三详情页下拉刷新（完成判据 = page1 响应或错误落槽，15s 超时兜底，preset 页不接）；歌单标题/计数绑定 `_playlist` 真值。
5. **收藏、排序、更多菜单**：收藏 pending 双击在途忽略 + 失败回滚（`playlist_detail_isolation_test.dart:480/:522`）；排序与更多菜单为既有实现随页面收口（`library_page.dart:464-468` 排序弹单、`playlist_detail_page.dart:315` 更多操作），本批无专项改动。

## 修改文件

工作区实测（`git status --short` + `git diff --stat`，累计实施轮 + 收口轮，未提交）：

- **lib 11 文件**：`app_model.dart`（+140：awaitBrowseResponse/收藏 pending/历史）、`design_system/components/vx_empty_state.dart`、`vx_track_row.dart`（P2-10 同域）、`pages/album_songs_page.dart`（+11）、`artist_detail_page.dart`（+69）、`custom_playlists_page.dart`（+25）、`discover_page.dart`（+3：P2-03 padding，:530-535）、`library_page.dart`（+280：来源筛选 chips/入口卡两行）、`playlist_detail_page.dart`（+81：下拉刷新/标题绑定）、`search_page.dart`（+271：chips/历史/四态）、`widgets/song_table_view.dart`（+17：四态）。
- **test 6 改 1 新**：`discover_page_test.dart`（+31 切源重载）、`phase5_library_test.dart`、`playlist_detail_isolation_test.dart`（+181：下拉刷新/收藏 pending/回滚/账号歌单不分页）、`search_page_test.dart`、`search_pagination_test.dart`（+176：requestId 锁/音源 chips/历史/四态/窄视口不溢出）、`mobile_library_page_test.dart`（**新**，2 项：360/390/430 无溢出 + 来源筛选四档过滤）。
- **docs/截图**：指南 §17、`04-defect-matrix.md`（P2-10/P2-03 关闭）、本报告、`docs/redesign/screenshots/phase-2-library/` 新增 4 张（目录名沿用 Phase 2 批次命名）。
- **Rust 侧零改动**（FavoritePlaylistAdd/Remove 为既有命令，bridge/lib.dart:328-333）。
- **2026-11-12 增量（复验轮 + QA1 修复轮 + QA 复查轮，仅 test/docs/截图）**：`search_page_test.dart` +1 用例（防抖窗口紧界 fake-time 250/300/350ms，复验轮）；4 测试文件补 6 条四态断言（mobile_library +1 空态、push_and_favorites +2 红心镜像载入/错误+重试、discover +2 骨架/歌单错误+重试、artist_album +1 专辑错误+重试，QA1 修复轮，报告员 `git diff` 逐名核对）；lib 与 Rust 零改动（`git diff HEAD -- flutter/lib` 实测为空）；截图目录累计 5 文件（QA 复查轮新增专辑错误态 1 张 + 重截曲库/发现 2 张）。

## 关键设计决策

1. **音源筛选走 chips 行而非下拉**（§5.4:355 裁决；实施轮已判定原下拉引 §4.3 属误引）：`search_page.dart:443-444` 横向 ListView，多音源横向滚动收容，右缘裁切属横滑设计行为（本轮 QA 甄别确认，测试「chips 行窄视口（430/360）不溢出」锁定）。
2. **来源筛选组合规则从实际数据派生**：favorites+history+localSongs 出现过的源才出 chip，杜绝假数据；规则登记于代码注释与 `mobile_library_page_test.dart:160`。
3. **下拉刷新完成判据**：`AppModel.awaitBrowseResponse` = page1 响应或错误落槽；迟到旧页经 PlaylistKey appendArmed 丢弃（与 §8.1 隔离同链路）。
4. **收藏 pending 三态**：乐观翻转 → 成功确认走 `library` 事件真实快照（不伪造成功）、失败 `dispatchWithError` 回滚、pending 在途忽略再击；错误呈现仅全局 toast 一处（§9）。
5. **桌面验收钩子复用**：`main.dart:134-197` VOICEFOX_START_SIZE/PAGE/TAB/DETAIL/SOURCE 注入起始页/详情/来源；本轮为允许 390 宽窗口**临时**把 `main.dart:163` `minimumSize` 560,480 改 300,400，截图后精确还原（报告员 `git diff flutter/lib/main.dart` 实测为空）。

## 数据流/交互变化

- 搜索：结果区四态互斥（骨架/净化错误+重试/历史空态/无结果/成功），计数 = `_items().length`（search_page.dart:485）；历史读写 shared_preferences 容错降级，记录点 = 回车/点历史项/Shell 种子。
- 曲库：分类 chips 计数按来源过滤（library_page.dart:250-264）；歌曲 0 与「喜欢的歌曲 0」自洽，最近播放 19 为独立统计。
- 详情页：下拉清槽重置 page1 → spinner 至 page1 落槽；收藏即时乐观态 + 真实快照确认/回滚。
- 发现页：切音源清 `_requestedPlaylistKeys` 重发 PlaylistList（discover_page_test 新增用例锁定）；书架末尾 padding 消除末卡贴边。

## 执行命令与退出码

| 命令 | 退出码 | 结果 | 执行者 |
|---|---|---|---|
| `flutter test test/mobile_library_page_test.dart test/phase5_library_test.dart test/discover_page_test.dart test/search_page_test.dart test/search_pagination_test.dart test/playlist_detail_isolation_test.dart test/playlist_detail_page_test.dart test/artist_album_page_test.dart test/custom_playlist_page_test.dart test/push_and_favorites_test.dart`（flutter/，/home/emo/flutter/bin/flutter 3.47.9） | **0** | **`00:09 +72: All tests passed!`** | 报告员本轮实跑 |
| `flutter test test/playlist_detail_isolation_test.dart` | **0** | **`00:03 +13: All tests passed!`** | 报告员本轮实跑 |
| `flutter build linux --release` | 0 | bundle `build/linux/x64/release/bundle/`（07:54，voicefox_flutter + data/lib 在位，报告员 `ls` 佐证；截图 07:55-07:58 时间线衔接） | 收口轮 ask 记录 + 报告员佐证 |
| Xvfb :99 实跑 `build/linux/x64/release/bundle/voicefox_flutter`（`env -u WAYLAND_DISPLAY LIBGL_ALWAYS_SOFTWARE=1` + VOICEFOX_START_* 钩子）→ `import -window <winid>` + magick 裁剪 | 0 | 4 张精确视口 PNG（07:55-07:58） | 收口轮 ask 记录 |
| `git diff flutter/lib/main.dart` | 空 | minimumSize 临时改动已精确还原 | 报告员本轮实跑 |
| dart analyze / dart format | 0 / 0 | 实施轮记录（analyze 0、6 文件规范化） | 实施轮记录（ask 提供） |
| `flutter test`（同上定向 10 文件，flutter/，/home/emo/flutter/bin/flutter 3.47.9）2026-11-12 复验轮 | **0** | 基线复跑 **`00:11 +72: All tests passed!`**；`search_page_test.dart` 新增 1 用例（防抖窗口紧界 fake-time 250/300/350ms）后复跑 **`00:11 +73: All tests passed!`**（expanded 单跑该文件 +14 逐名核对） | 实施者本轮实跑 |
| `dart format test/search_page_test.dart` + `dart analyze`（2026-11-12 复验轮） | 0 / 0 | format 1 文件规范化；analyze `No issues found!` | 实施者本轮实跑 |
| `flutter test`（同上定向 10 文件）2026-11-12 Phase3-QA1 修复轮 | **0** | P0 四态证据缺口补 6 条 widget 断言（4 文件，4 文件单跑 `00:05 +24` 全绿）后复跑定向 10 文件 **`00:12 +79: All tests passed!`**（基线 73 + 新增 6） | 实施者本轮实跑 |
| `dart format`（4 个测试文件）+ `dart analyze`（2026-11-12 Phase3-QA1 修复轮） | 0 / 0 | format `Formatted 4 files (1 changed)`；analyze `No issues found!` | 实施者本轮实跑 |
| `flutter test test/mobile_library_page_test.dart test/discover_page_test.dart test/artist_album_page_test.dart test/push_and_favorites_test.dart`（2026-11-12 QA1 修复轮） | **0** | **`00:02 +24: All tests passed!`**（6 条新用例在册） | 实施者本轮实跑（ask 记录） |
| 同上 4 文件（2026-11-12 QA 复查轮独立复跑） | **0** | **`00:05 +24: All tests passed!`** | 报告员本轮实跑 |
| `flutter test`（定向 10 文件，2026-11-12 QA 复查轮） | **0** | **`00:14 +79: All tests passed!`**（QA 独立实跑在先 `00:10 +79` exit 0，ask 记录） | 报告员本轮实跑 |
| `flutter build linux --release`（2026-11-12 QA 复查轮重建） | 0 | `✓ Built bundle/voicefox_flutter`（03:52:19 在位，报告员 `ls` 佐证；lib/ 零改动 → 内容等价重建） | 实施者本轮实跑 + 报告员佐证 |
| Xvfb :99 重截受影响视口 3 张（VOICEFOX_START_PAGE/TAB/DETAIL/KEYWORD/SOURCE 钩子 + GDK_BACKEND=x11 + LIBGL_ALWAYS_SOFTWARE=1 + Xlib 外部调窗 +264 阴影 gutter 补偿 + import 内容锚定裁剪） | 0 | library 03:52:44 / discover 03:53:09 / album 03:56:16（报告员 `stat` 佐证）；search/playlist 03:24 版本未动 | 实施者本轮实跑（ask 记录）+ 报告员 stat 佐证 |
| `pgrep -af "Xvfb\|voicefox"`（QA 复查轮清理复核） | 0 | 无 :99/voicefox 残留（仅存并行会话 actor_11_3 的 Xvfb :3，非本轮产物） | 报告员本轮实跑 |
| 全量 flutter test / cargo test / clippy | n/a | **未跑**（外部门禁统一执行，本轮已知事实「门禁全绿」；报告员未复跑全量） | 未执行 |

## 测试结果（通过/失败/跳过）

| 套件 | 通过 | 失败 | 跳过 | 说明 |
|---|---|---|---|---|
| 定向 10 文件 | **72** | 0 | 0 | 报告员本轮实跑（上表第 1 条命令），与门禁已知事实一致 |
| 定向 10 文件（2026-11-12 复验轮） | **73** | 0 | 0 | 实施者本轮实跑：基线复跑 72/72 全绿 → `search_page_test.dart` 新增 1 用例（防抖窗口紧界 fake-time 250/300/350ms，锁定 search_page.dart:60 `debounceMs=300` 硬编码耦合）→ 复跑 73/73 全绿；实机毫秒计时仍归 Phase 7 |
| 定向 10 文件（2026-11-12 Phase3-QA1 修复轮） | **79** | 0 | 0 | 实施者本轮实跑：P0 四态证据缺口补 6 条 widget 断言：曲库本地收藏空态（mobile_library_page_test +1）、红心镜像载入态/错误态+重试（push_and_favorites_test +2）、发现页骨架/歌单错误+重试（discover_page_test +2）、专辑页错误+重试（artist_album_page_test +1）；复跑 79/79 全绿（`00:12 +79` exit 0），改动文件 expanded 逐名核对通过 |
| 定向 10 文件（2026-11-12 QA 复查轮） | **79** | 0 | 0 | QA 独立实跑 `00:10 +79`（ask 记录）+ 报告员复跑 `00:14 +79` exit 0；4 改动文件 24 项双实跑（实施者 `00:02 +24`、报告员 `00:05 +24`），6 条新用例 diff 逐名核对 |
| 其中 playlist_detail_isolation | **13** | 0 | 0 | 单独复跑 +13 全过；含 A/B 槽隔离、同 ID 异源隔离、迟到页丢弃、错误归属、下拉刷新清槽、收藏 pending 双击忽略（:480）、失败回滚（:522），测试名逐一核对 |
| 覆盖点（按测试名核对） | n/a | n/a | n/a | 快捷卡/分类 chips/来源筛选 + 本地收藏空态（mobile_library_page_test 3 项）；防抖 + 分页 in-flight 锁（requestId）+ 音源 chips + 历史 + 四态 + chips 窄视口不溢出（search_pagination_test）；切源重载 + 载入骨架/歌单错误+重试（discover_page_test）；P2-10 视口回归（mobile_library_page_test:114）；红心镜像成功/载入/错误+重试（push_and_favorites_test 4 项）；专辑页载/空/错误+重试（artist_album_page_test 4 项） |

## 构建结果

| 目标 | 结果 |
|---|---|
| Linux release（`flutter build linux --release`） | exit 0：收口轮 bundle 07:54（ask 记录）；2026-11-12 QA 复查轮重建 `✓ Built bundle/voicefox_flutter`（03:52:19 在位，报告员 `ls` 佐证，lib/ 零改动 → 内容等价重建，时间线衔接 03:52-03:56 重截批次） |
| Android APK | **未构建**：本环境无 JDK/模拟器，ask 明确禁止 APK/Gradle 构建与 AVD 创建（P1-06 环境阻断维持）；本批 Android 项不适用（linux 截图批次） |

## 设备和视口

- **Xvfb :99 无 WM 受控采集**：390×844（library / search / playlist）+ 360×800（discover），`import -window` + magick 裁剪得精确视口。
- **后端为真实 Rust 数据源**（`~/.config/voicefox/config.toml`，kw/酷狗/酷我真实联网数据，非 mock）：搜索 love 256 结果（2026-11-12 重截图口径，原 07:55-07:58 批次为「周杰伦」217 结果，见勘误节）、酷我歌单《古风戏腔》104 首、发现页按源分组真实歌单与封面均为真实链路数据。
- Android 真机/模拟器（§12.6 真机 13 项）：**未验证**（P1-06 维持）。
- **QA 复查轮重截（2026-11-12）**：同 Xvfb :99 无 WM 受控采集 + `GDK_BACKEND=x11` + `LIBGL_ALWAYS_SOFTWARE=1` + VOICEFOX_START_PAGE/TAB/DETAIL/KEYWORD/SOURCE 验收钩子 + Xlib 外部调窗（+264 阴影 gutter 补偿）+ import 内容锚定裁剪；数据全真实（曲库 专辑 20/歌手 17/最近播放 22 首；发现页 酷我/酷狗 真实分类与封面）；新增专辑详情 390×844 视口（真实错误态实拍）。移动端 TouchShell 底部导航形态实机画面未取得：390×844 截图为桌面壳（AppHeader）+ 移动视口内容，与既有基线同口径（如实披露）。

## 截图路径

`docs/redesign/screenshots/phase-2-library/`（目录名沿用 Phase 2 批次命名，实测 5 文件，全部深色主题；mtime 见勘误节）：

- `linux-library-390x844-songs.png`：我的音乐（快捷卡 22/0/0、分类 chips、本地/网易云/QQ 分段、来源筛选 chips、真实空态）。
- `linux-search-390x844-results.png`：搜索「love」256 结果（类型/音源 chips、行来源徽标与时长）。
- `linux-playlist-390x844-detail.png`：酷我歌单《古风戏腔》详情（104 首·总时长 400 分钟、曲目列表）。
- `linux-discover-360x800-default.png`：发现页按源分组（酷我/酷狗真实歌单卡与封面）。
- `linux-album-390x844-detail.png`（QA 复查轮新增）：专辑详情「九点九」（千千音乐徽标、Aling贝多、真实封面）**错误态实拍**：曲目列表「加载失败 not found」+ 重试按钮，操作钮明确禁用（§9）。
- `linux-search-390x844-results.png` / `linux-playlist-390x844-detail.png`：非受影响页面，维持 03:24 批次版本未动（mtime 实测 03:24:25 / 03:24:56）。

## 视觉 QA 结果

**QA 结论（收口轮 ask 记录）+ 报告员本轮 Read 目检 4 张 PNG 复核一致：**

1. **4 张均正常渲染**：无白屏 / overflow / 遮挡 / 封面错图（逐张 + 局部放大复核）。
2. **跨页一致**：discover「古风戏腔 104 首歌曲·酷我」↔ playlist 详情同封面同来源；返回条完整显示全标题「古风戏腔丨一曲舞霓裳清影醉红颜」（报告员目检确认，Hero 大标题截断为设计内 maxLines）。
3. **search「网易云」chip 右缘裁切**：经 `search_page.dart:443-444` 确认为横向滚动 ListView 属设计行为（library 来源 chips 同理）。
4. **library 空态**：图标放大复核为 `Icons.music_off_outlined` 正常渲染（`song_table_view.dart:181`），文案「在搜索页点击心形把歌曲收进来」与 `library_page.dart:569` 逐字一致。
5. **数据抽查 3 处全部一致**（代码行报告员实读核实）：① 歌单详情标题绑定 `_playlist.name` +「104 首·总时长 400 分钟」只计已载入曲目（playlist_detail_page.dart:234-241,253-258）；② 曲库 tab 计数按来源过滤（library_page.dart:250-264）；③「找到 256 个结果」= `_items().length`（search_page.dart:485），四态齐全（search_page.dart:495-519 骨架/净化错误+重试/空态/成功；歌单详情经 song_table_view.dart:155-185）。
6. 报告员目检备注：search 390 行封面为占位形态（5sing 行），属无封面 URL 时的 fallback，非错图，不影响 QA 结论。

**QA 复查轮（2026-11-12）逐张 Read 目检 3 张新/重截图（报告员本轮实看）：**

7. **library/discover 与登记口径一致**：快捷卡 22/0/0、分类 chips 专辑 20/歌手 17、104 首·酷我跨页一致；无白屏/overflow/遮挡，深色对比度可读；与上轮画面一致（同色数）属预期（lib/ 零改动、同数据源）。
8. **专辑详情错误态实拍渲染正常**：真实封面 + 千千音乐徽标 + Aling贝多，「加载失败 not found」+ 重试按钮，操作钮明确禁用，§9 错误态 + 重试 + 禁用语义均符合。

## 新增/关闭缺陷

- **关闭（本批累计）**：P2-10（实施轮：入口卡两行卡 + vx_track_row/vx_empty_state 同域两处）、**P2-03（收口轮：代码 diff discover_page.dart:530-535 + 实机 linux-discover-360x800-default.png 复验 + QA 逐张复核；横滑到末尾的末态未单独手势演练，由末尾 padding 语义结构性保证，04 矩阵如实标注）**、**QA1 修复轮登记 P0（四态证据缺口），QA 复查轮确认关闭**：6 条断言全部在位（报告员 `git diff` 逐名核对）+ 定向 10 文件 79 项全绿双实跑（QA 独立 `00:10 +79`、报告员复跑 `00:14 +79` exit 0）+ §13「四态齐全」证据面扩展至曲库/发现/专辑；**QA1 轮登记 P1（4 张证据截图重截未登记），QA 复查轮确认关闭**：勘误节登记（mtime/归属/非劣化判定）+ 四处口径同步（love/256、快捷卡 22/0/0）+ 04 矩阵与 §17 同步。
- **仍开放**：P0-01（概率性未复现未定位）、P1-05、P1-06（Android 环境阻断）、P2-02/04/05/08/09/11、P1-14（Phase 6 归属）、P3-02/04/05/06/07/08。
- **残留 minor 4 条（QA 复查轮登记，不阻塞）**：①专辑错误态截图（目录第 5 张证据图）上轮未登记且「仅此 4 文件」口径失实（本报告本轮补登记并同步口径）；②上节勘误 mtime 对 library/discover 2 张过期（本轮重截 03:52:44/03:53:09 所致，search/playlist 2 张仍准确）；③专辑错误态直出原始「not found」串（可读性 minor，未判 P1-11 回归）；④底部安全区 bottom inset 未断言。

## 未解决问题和原因

1. **Android 真机/模拟器**：未验证（无 JDK，按 ask 禁止 APK/Gradle 构建与 AVD 创建；P1-06 维持）。以 72 项针对性 widget 测试 + 桌面窗口移动视口为证据。
2. **交互式运行时手操未逐一演练**（桌面实跑仅验证静态画面状态）：搜索防抖 250-350ms 实际毫秒计时（2026-11-12 复验轮口径更新：防抖常量 300ms 已由 `search_page_test.dart` fake-time 窗口用例锁定，即 250ms 未派发、300ms 恰好一次、350ms 无二次派发；fake-time 只锁常量值，**实机毫秒计时仍归 Phase 7 手操，本项维持未做**）、触底分页/下拉刷新手势、音源切换即时重载、收藏 pending 回滚的桌面手动操作；由针对性测试覆盖（playlist_detail_isolation_test / search_pagination_test / discover_page_test 用例名核对）。
3. **浅色主题**：本批 4 张全部深色，浅色对比度无本批素材（归 Phase 7）。
4. **「总时长 400 分钟」**：真实酷我数据，仅验证计算路径（playlist_detail_page.dart:253-258）未逐曲重算。
5. **golden 基线比对未执行**：本批未跑 golden 变更，仅确认现有断言通过。
6. **全量门禁未由报告员复跑**：外部门禁统一执行（已知事实「门禁全绿」）。
7. **操作事件披露**：调试 niri IPC 时误触发一次系统截图交互选区 UI（`{"Action":"Screenshot"}`），如残留在用户屏幕请按 Esc 关闭。
8. **专辑详情成功态（曲目列表渲染）实机画面未取得（QA 复查轮新增）**：种子路径实机 5 次尝试均未取得成功态（登记在案返回：kw 源曲目列表真实「加载失败 not found」×2、wy 落汽水音乐「该音源不支持专辑」×1），疑真实音源数据缺口或种子源映射问题；保持真实错误态+重试画面为证，该状态即本轮新增断言的对象（widget 层已锁定错误+重试回载入态）。
9. **VOICEFOX_START_SOURCE 对专辑种子疑似未生效（QA 复查轮新增观察）**：SOURCE=kw → 徽标千千音乐、SOURCE=wy → 徽标汽水音乐；仅登记观察，未验证为缺陷，未修。
10. **手操交互与重建口径（QA 复查轮）**：手操项（下拉刷新、收藏 pending 回滚、触底加载手动触发）本轮未手操，以定向 widget 测试为证据（同第 2 条）；lib/ 本轮零改动，release 重建为内容等价重建；曲库/发现重截画面与上轮一致（同色数）属预期。

## 下一阶段进入条件

§13 Phase 3 退出条件逐条核对：

| 条件 | 状态 |
|---|---|
| 每个详情对应正确数据 | ✅ 数据抽查 3 处（标题/计数/时长绑定真实 `_playlist` 值）+ 实机 4 视口真实后端截图 |
| 不同歌单切换测试全通过 | ✅ `playlist_detail_isolation_test.dart` **13/13**（报告员本轮实跑 `00:03 +13: All tests passed!`） |
| 空/错/载/成功四态齐全 | ✅ search_page.dart:495-519 + song_table_view.dart:155-185 + search_pagination_test 四态用例；2026-11-12 Phase3-QA1 修复轮补齐其余页面证据面 6 条 widget 断言：曲库本地收藏空态、红心镜像载入/错误+重试、发现页载入骨架/歌单错误+重试、专辑页错误+重试（定向 10 文件 79 项全绿；QA 复查轮双实跑确认 `00:10 +79`/`00:14 +79` exit 0 + 专辑错误态实拍 linux-album-390x844-detail.png） |

- **Phase 4（播放器和移动端系统媒体体验）可进入。**
- 跨阶段遗留不阻塞：P0-01 定位（长时间会话验收前必须）、P1-05 同域跟进、P1-06 环境补齐、浅色主题走查归 Phase 7。

## 勘误（2026-11-12 Phase 2 QA 修复轮补充，历史正文不动）

本报告「截图路径」与「修改文件」均未提及的 `docs/redesign/screenshots/phase-1-mobile/fluttertest-library-430x932-dark-default.png` 随本阶段提交 610d6d8 被无声替换为「页面级 pump LibraryPage + 未注入 CJK 字体」版本（18496B，mtime 11-11 07:29：全部文字空心方框、无底栏与「我的音乐」高亮，规格 golden 要素不可核对）；04 矩阵对本文件的既有目检结论对该版本不成立。已按 06:34 批次口径复截（真实 MobileShell 进树 + 底栏第四入口切库页 + MiSans/JetBrainsMono/MaterialIcons 注入 + 深色主题 + debug banner 关闭），现文件 61983B（mtime 11-12 01:53），逐项目检通过；同轮 fluttertest-home-390x844-dark-emptyhero.png（06:04 批次）亦随当前代码复截为竖排全宽单行 CTA 形态（100843B）。事实链详见 04 矩阵 P1-12/P1-13/P2-10 与 phase-2-report.md 勘误节。

## 勘误（2026-11-12 Phase3-QA1 修复轮补充，历史正文不动）

本报告「截图路径」4 张证据截图（linux-library-390x844-songs / linux-search-390x844-results / linux-playlist-390x844-detail / linux-discover-360x800-default.png）在 2026-11-12 复验轮被重截而上轮文档 diff 未登记（QA 视觉轮发现）。重截登记：mtime `stat` 实测 2026-11-12 03:23:45 / 03:24:25 / 03:24:56 / 03:25:31（+0800），归属 2026-11-12 复验轮批次；QA 轮判定与 04 矩阵 04:107 先例（无声替换判 P0）对照：本批非证据质量劣化，同管道同状态、仅真实数据源漂移（搜索词「周杰伦」217 结果 → love 256 结果、快捷卡 19/0/0 → 22/0/0），判 P1 登记即关闭。本轮（Phase3-QA1 修复轮）逐张 Read 目检复核 4 张：无白屏/overflow/遮挡，playlist 104 首·总时长 400 分钟·酷我与 discover 分组跨页一致仍成立，library 空态文案仍逐字一致；正文四处口径已同步现文件（设备视口节、截图路径节、视觉 QA 第 5 条、勘误本节）。

## 勘误（2026-11-12 QA 复查轮补充，历史正文不动）

「截图路径」节原口径「实测仅此 4 文件」失实：目录现 **5 张**，新增 `linux-album-390x844-detail.png`（mtime `stat` 实测 2026-11-12 03:56:16 +0800，未跟踪新文件，专辑详情真实错误态+重试实拍），正文截图路径/视觉 QA 节已补登记。上节勘误所载 4 张 mtime 中 library/discover 两张因本轮重截过期（现 03:52:44/03:53:09，归属 QA 复查轮重截批次），search/playlist 两张（03:24:25/03:24:56）仍准确、非受影响页面维持未动。本轮 lib/ 零改动（`git diff HEAD -- flutter/lib` 实测空），release bundle 03:52:19 重建为内容等价重建；受影响视口（曲库/发现/专辑，对应四个被改测试文件的页面）重截 3 张、数据全真实（曲库 专辑 20/歌手 17/最近播放 22 首、发现页酷我/酷狗真实分类与封面）；全部进程与 Xvfb :99 已清理（报告员 `pgrep` 复核，现存并行会话 actor_11_3 的 Xvfb :3 非本轮产物）。
