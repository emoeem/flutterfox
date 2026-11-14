# 第二轮实现盘点与差距审计（Phase 0）

> 状态：已完成 · 日期：2026-11-14 · 适用版本：feat/ui-redesign @ `eb1afc3` · 相关：`docs/redesign/04-defect-matrix.md`、`docs/redesign/second-round/baseline/BASELINE-MANIFEST.md`、执行计划书 `flutterfox-ui-ux-second-round-execution-plan.md`（仓库外，/home/emo/Downloads/）

## 一、结论（先读这里）

1. **第一轮交付的骨架是健康的**：桌面壳三栏、PlayerBar 常驻、详情页内嵌 Navigator、手机壳 5 入口、平板三档断点均有代码与测试在位，不需要推倒重写。
2. **HEAD 当前不是绿的**，两处硬阻断：(a) CI analyze 门禁红，根因已定位（CI `channel: stable` 未固定版本，拉到 `v3.47.0-0.0.pre` 之后的 stable，`package:flutter/material.dart` 被整体标记弃用，115 个 import 各产一条 `deprecated_member_use` info，`--fatal-infos` 即失败；本地 Flutter 3.47.9 复现为零问题）；(b) `flutter test test/now_playing_test.dart` 挂 1 例（旧空态断言与 P2-18 新布局分支冲突），41 用例 40 过 1 挂（实测 2026-11-14，输出存 /tmp）。
3. **第二轮最大差距是移动端**：10 个页面里只有 首页/全屏播放页/壳 是独立 mobile 实现，Discover/Search/Library/PlaylistDetail/LocalMusic/Downloads/Settings/Help 共 8 页仍直接复用桌面页面（部分零适配，`app_shell.dart:802-826` 只有 home 槽按形态分叉）。
4. **主题是双真源**：运行时 MaterialApp 吃 ThemeProvider 的 `ColorScheme.fromSeed`，壳层与自绘组件吃另一套写死的 Vx token，两者零引用（详见 §三）。
5. **WIP 批次（eb1afc3）四项修复代码层完成度不一**：P1-20 闭环最好；P2-16 停在 Rust 单元层；P2-17 链路纸面闭环但按钮态/测试/调试残留欠账；P2-18 造成上述测试红。均缺运行时证据，矩阵 4 条均维持开放。

## 二、基线信息（计划书 §2.1）

| 项 | 实测值 | 来源 |
|---|---|---|
| 分支/HEAD | feat/ui-redesign @ `eb1afc3`（WIP 快照，2026-11-14 10:34 +0800） | git log |
| 工作区 | 干净，仅新增未跟踪 `docs/redesign/second-round/`（本文档与基线清单） | git status |
| 与 main 差异 | 413 files，+21019/-3726 | git diff main...HEAD --stat |
| 关键提交链 | 30ad0a8(P0)→b7246ee(P1)→86a1866/c512914(P2)→610d6d8/f36681f(P3)→da6e9e8(P4)→57db10b(P5)→128df2f(P6)→ec42a50(P7)→15c7c13(L1)→5ec550a(L2)→eb1afc3(WIP) | git log -20 |
| 本地 Flutter | 3.47.9 stable（c197ca519，2026-10-29） | flutter --version |
| CI Flutter | `channel: stable` 未固定（ci.yml:355-358），实际解析到带 material.dart 弃用的新 stable | CI 日志 43547105433 |
| Rust | rustc 1.99.0；cargo clippy 基线 30 条告警（不进 all 门禁，维持） | rustc --version、旧台账 |
| 桌面环境 | niri Wayland（niri-session 进程在跑），DISPLAY=:1（xwayland-satellite），无 Xvfb 常驻 | ps 实测 |
| Android | 无 JDK、无 AVD；用户 2026-11-10 明确搁置（禁 APK/Gradle/AVD），一切真机项保持「未验证」 | 环境记忆+用户令 |
| CI 最新结论 | run `43547105433`（2026-11-14T02:34Z）：仅 Flutter(analyze) job 失败于「Analyze (zero warnings)」，Test 步骤被跳过；Build Linux/macOS/Windows/Android、Lint(fmt+clippy) 全绿 | gh run view |

### 2.1 CI 失败根因（已复现定位）

CI 日志样例：`info • 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. ... deprecated_member_use`，按 115 个文件的 import 各计 1 条。本地同仓 `flutter analyze --fatal-infos`（3.47.9）exit 0、`No issues found!`。即：**代码没变坏，是 CI 的 SDK 漂移**。修复方向（留给门禁恢复批次，Phase 0 不动代码）：最小可靠方案是把 ci.yml 的 flutter-action 固定 `flutter-version: 3.47.9`（与全部 375+ 测试的验证版本一致）；`material_ui` 迁移涉及 115+ import 与新包成熟度/平台兼容核实，属独立大批次，不作为解锁手段。同时按计划书 §10.1.6 将 analyze 与 test 证据改为独立收集（analyze 挂时仍能拿到测试失败信息）。禁止删除 `--fatal-infos`。

## 三、全局与设计系统盘点

| 模块 | 状态 | 关键证据 | 具体差距 |
|---|---|---|---|
| 运行时主题真源 | **部分实现（双真源脱节）** | main.dart:461-465 用 ThemeProvider；theme_provider.dart:64-82 用 `ColorScheme.fromSeed`+misansTextTheme；VxColors/VxLightColors/VxChrome（design_tokens.dart:15-157）只被 shell 5 文件直接消费（chrome_theme_test 锁定）；两套零互相引用 | 运行时 M3 scheme 与页面自绘 Vx 色不联动；换主题预设后 Vx 壳层颜色不跟随 |
| 44 主题预设 | **部分实现** | registry.dart:46-91（16 TUI+FlClash+27 flex）；仅 16 套经 projection.dart:97+ 投影种子，**其余 28 套选中后运行时回退 Mocha 种子** | 设置页可见 44 个选项但 28 个无效 |
| 动态取色 | 部分实现（双开关） | main.dart:453-459 DynamicColorBuilder→Rust config.dynamicColor（app_model.dart:110,331）；另 myune settings_provider.dart:31,84 有平行 prefs 开关（默认值还不一致 false/true） | 需合并单源 |
| 自定义 seed/字体/深浅色/持久化 | 已实现，验证不足 | theme_provider.dart:122-129,144-178,207-234；持久化 SharedPreferences+Rust config 双写；**ThemeProvider 零行为测试**（test/ 全目录无） | 补行为测试 |
| 主题护栏测试 | 有洞 | theme_source_guard_test.dart:20-37 只封 import 通道；main.dart:397-403,426-432 内联 `fromSeed(0xFF89B4FA)`（uiOnly/引导骨架）对 guard 不可见 | 补断言或接入同一构建入口 |
| 字体链 | 部分实现 | typography.dart 平台 CJK fallback+JetBrainsMono 仅被预览构建器消费（theme/voicefox_theme.dart:81）；运行时 misansTextTheme 全 w400（theme_provider.dart:11-29）与 VxTypography「禁止全 w400」（design_tokens.dart:279-281）冲突 | 字级层级+CJK fallback 进运行时 |
| 数字等宽 | 已实现（局部） | FontFeature.tabularFigures 在 vx_seek_bar.dart:40、vx_track_row.dart:164,241、progress_control.dart:92,140、myune playbar.dart:373 | 非全局 token，逐步扩面 |
| 硬编码色 | 干净 | pages/+player/ 仅 3 处 `Color(0xCCFFFFFF)` 横幅叠字（mobile_home_page.dart:131、home_shared.dart:331、discover_page.dart:890） | token 化即可 |
| 公共组件 | 已实现 | design_system/components 17 个组件无零引用死组件；高频：VxEmptyState 10 文件、VxSectionHeader 7、VxArtwork 6；Gallery 无 lib 内路由入口（纯测试预览） | 低频单点组件（VxHero/VxArtistBanner/VxTimeLabel）评估并轨 |
| 状态组件 | 已实现 | VxEmptyState/VxErrorState/VxLoadingSkeleton 覆盖主要页面；**空态双轨残留**：downloads_page.dart:20 仍用旧 widgets/empty_state.dart | 收敛到 Vx 族 |

## 四、桌面盘点（计划书 §2.2 桌面节）

壳层四组件（app_shell/app_header/app_sidebar/context_panel）与 player_bar 均有测试且 P1-14/P2-11/P1-18 已关闭，不重述。逐页矩阵：

| 页面 | 状态 | 已有功能/测试 | 具体差距（file:line 实证） |
|---|---|---|---|
| 首页 home_page | **部分实现** | home_page_test.dart；Hero/书架/榜单四态在 home_shared.dart:245-291 齐备可重试 | (1) 「导入本地」= navRequest.value=5 落曲库（home_page.dart:118→app_shell.dart:78），文案与行为错位，不经真实导入链（计划书点名）；(2) 我的歌单卡全部只跳曲库不进详情（home_page.dart:214）；(3) 1920 无限拉伸（pagePadding 28 无最大宽） |
| 发现 discover | 已完成并验证（WIP 增量待复验） | discover_page_test.dart；组级 Loading/错误/空/加载更多 齐备（507-570）；P1-20 哨兵修复见 §七 | 1920 拉伸；无右键/键盘焦点 |
| 搜索 search | 已完成并验证 | search_page_test+pagination_test；四态+历史+分页尾三态齐备（495-942）；Ctrl/Shift 多选、Enter 播放在位 | Header 全局搜索与页内输入**单向同步**（app_shell.dart:392-401→search_page.dart:96-102，页内换词不回写 Header）；1920 拉伸 |
| 曲库 library | 代码已实现，验证不足 | phase5_library_test；<512 compact 两处补丁；网格列数 clamp(2,8) | 侧栏歌单区无 Loading（app_sidebar.dart:503-512）；镜像态 spinner 在位（580-591）；1920 拉伸 |
| 歌单/专辑/歌手详情 | 已完成并验证 | isolation/push_and_favorites/artist_album 测试；prepareBrowseLoad 首帧 Loading（playlist_detail:54-62）；收藏乐观+回滚（116-138）；内嵌 Navigator+PlayerBar 常驻（app_shell.dart:642-662,566-580） | 长错误文案直出（artist_detail_page.dart:268）与 search sanitize 链不一致 |
| 本地音乐 local_music | 已完成并验证 | local_music 三测试文件；扫描可取消/警告横幅/空库引导在位 | 无错误终态（失败只进 scanWarnings） |
| 下载 downloads | **已实现但存在缺陷（P3-09 开放确认）** | phase5_downloads_test；操作钮按状态映射+删除确认+打开/定位如实禁用 | 百分比不夹取可超 100（downloads_page.dart:465-473）；体积直出（442-444）；状态行非 Flexible 文本致 560 溢出（449-483）；无窄窗降级 |
| 设置 settings | 部分实现 | phase5_settings_test；<640 分类转横向胶囊行（98-118） | config==null 仅文字「配置加载中」，**失败无错误/重试态**（54-58）；胶囊行不记忆滚动位置 |
| 全屏播放 now_playing | **代码已实现，验证不足+测试红** | now_playing_test 40/41；空态 VxEmptyState（96-105）；内容 maxWidth 1320 全仓唯一限宽页 | P2-18 分支已实现（347-392）但旧测试断言未同步（§七）；歌词无独立 Loading 骨架 |
| 队列 queue_panel | 已完成并验证 | desktop_queue_interaction_test+queue_interaction_test 8 用例；P2-09 拖拽如实禁用 | Loading 缺（本地快照，可接受） |
| playlist_browse | 死代码候选 | 仍被 account_playlist_page_test 测试，但新壳不路由（仅退役 myune_shell 引用） | 评估退役或重接 |

桌面全局差距（新增登记 SR 清单）：全部一级页 1920 无限拉伸（除 now_playing 1320）；右键菜单（2026-11-14 Phase 0 复核裁决：本行原「整体缺失」口径有误，song_tile.dart:76 showSongMenu 真实存在且 song_tile 未退役，playlist_detail/album_songs/artist_detail/library/browse/custom_playlists/queue_drawer 均经 SongTile 渲染并接线 onSecondaryTapUp + 触屏长按共 4 处触发面（song_tile.dart:217,242,263,393），myune playlist_content_widget 另有 onSecondaryTap 接线；残余缺口收窄为「网格卡面（专辑/歌手/歌单卡）与个别视图的右键覆盖」，待 Batch D 精查）；键盘焦点漫游无规划（仅搜索表 639-643 与壳快捷键有显式 Focus）；ContextPanel 注释漂移（320/280-420 vs 实际 340/300-420）。

## 五、手机盘点

### 5.1 独立实现 vs 复用桌面（本轮最重要结论）

| 页面 | 形态 | 证据 |
|---|---|---|
| 壳 MobileShell | 独立（5 入口+endDrawer+MiniPlayer+NavigationBar） | mobile_shell.dart:594-609；inset 契约 android_insets.dart:7-14（状态栏/导航条各消费一次，bodyHeightFor 公式有测试锁定） |
| 首页 | 独立 MobileHomePage | mobile_home_page.dart:36-72 |
| 全屏播放页 | 独立 MobileNowPlayingPage | mobile_now_playing_page.dart:45 |
| **发现** | **复用桌面，零适配**（无 LayoutBuilder/MediaQuery） | app_shell.dart:814 |
| **搜索** | **复用桌面，零适配** | app_shell.dart:815-818 |
| 曲库 | 复用桌面+两处 <512 补丁 | app_shell.dart:819；library_page.dart:85-95,130-139 |
| **歌单详情** | **复用桌面，整页路由推入**（丢 MiniPlayer/导航） | mobile_home_page.dart:443-452 |
| **本地音乐** | **复用桌面，整页路由推入** | mobile_shell.dart:330-342；local_music_page.dart:42 |
| **下载** | **复用桌面，零适配**（桌面表格形态） | app_shell.dart:820 |
| **设置/帮助** | **复用桌面**（桌面 208 双栏假设） | app_shell.dart:821-825 |

### 5.2 已验证项与差距

已验证：mobile_shell_test(9)/mobile_home_page_test(8)/mobile_library_page_test(4)/mobile_now_playing_test(14)+layout(9)/tablet_shell_test(8)/android_insets_layout_test(7)/mini_player 两文件(8)/viewport_matrix_test(10)/touch_longpress_test(4)。

差距：首页快捷入口三卡片「喜欢的歌曲」在 360dp 且 textScaler≥1.1 时省略号截断（mobile_home_page.dart:257-261，卡文本区约 74.7px vs 5 字约 78px；320dp 下 1.0 即截断；现有测试只锁 430 视口）；滚动底部 padding 固定 24dp 未联动 MiniPlayer/NavBar/inset（mobile_home_page.dart:50、library_page.dart:726,741,825,840）；整页路由推入的页面丢失全局播放控制；mobile 专项测试只覆盖 4 页，Discover/Search/Downloads/PlaylistDetail/LocalMusic/Settings 零手机视口回归。

## 六、平板盘点

断点与形态已有测试锁定（tablet_shell_test 8 项，含 1199/1200 边界对照）：触屏 <600 手机壳；600-839 图标 rail（ContextPanel 覆盖浮层 mobile_shell.dart:832-865）；840-1199 extended rail 双栏（ContextPanel 内嵌 820-828）；≥1200 triple+内嵌；非触屏恒 desktop（responsive_shell.dart:61-113）。

差距：**平板全部槽位复用桌面页面**（TabletShell 不传 form，home 槽仍是桌面 HomePage，mobile_shell.dart:796-811 注释自认偏差待 §6.3 裁决）；右栏固定 340 不可拖（桌面 300-420 拖宽语义未带过来，mobile_shell.dart:637-638）；600-839 档 ContextPanel 覆盖式与 ≥840 内嵌式体验不对称；平板 Now Playing 用移动版页面（封面+歌词层），未利用 840+ 宽度做并排。

## 七、WIP 批次（eb1afc3）核验

| 项 | 代码闭环 | 测试层 | 运行时证据 | 待补 |
|---|---|---|---|---|
| P1-20 全部音源哨兵 | **闭环**：哨兵 `''`（discover_page.dart:92）解 PopupMenu null 走 onCanceled 的根因；`_selectSource` 真实清缓存重拉聚合（205-219→_loadAggregated:141-175） | widget 测试断言标签回「全部」+ 命令流 containsAll(['wy','tx'])（discover_page_test.dart:296-326），实跑通过 | 无 | leaderboard/categories Tab 切回聚合路径未覆盖；运行时复验后方可关矩阵 |
| P2-16 Soda 组合封面 URL | Rust 层闭环：`{urls[0]}{uri}` 或模板 `{base}{uri}~{t}-image.jpeg`，缺一即 None（soda/api.rs:107-130） | 2 用例实跑通过（assembles_cover_from_composite_url_cover、keeps_cover_empty_without_uri） | 无（注释引 curl 人工实锤） | HTTP 200/图片解码/UI 灰占位恢复链无自动化证据；「无 uri 但 urls[0] 为完整 URL」形态是否存在于真实数据待查 |
| P2-17 歌词重取链 | **纸面闭环**：新命令 FfiCommand::LoadLyrics（ffi/lib.rs:1428-1432→1610-1613）；根因是代次校验恒 0 vs 递增永不相等，改用 lyrics.prepare() 代次（service.rs:467,1722；lyrics.rs:26-29；lyric/service.rs:38-50）；事件回填 LyricsChanged→app_model.dart:285→UI | **零测试**（Rust/Dart 侧均无 LoadLyrics 路径测试） | 无 | 按钮无 loading/禁用/防重复态（lyrics_panel.dart:162）；`service.rs:1732` 遗留 `[DIAG-lyric]` eprintln；lyrics_panel.dart:13 文件头注释已过时 |
| P2-18 hasLyrics 布局 | 分支完成：无歌词单列居中（now_playing_page.dart:359-369），有歌词双栏 46/54，异步回填平滑切换（375-392） | **now_playing_test.dart:286 挂**（实测 40/41）：旧断言「暂无歌词 findsOneWidget + 不伪造重取按钮」的立意被 P2-17/P2-18 直接推翻，本提交未同步 | 无 | 测试按新行为重写（保留业务行为断言，更新过时视觉断言，计划书 §0.1.14 允许）；矩阵 4 条待运行时证据后同步 |

frb_generated.rs/.dart/.freezed.dart 共 657 行变动确认为 codegen 再生成（sse_decode 变体号顺移、content hash 更新），无手工逻辑。bridge/api.dart:57 的 commandLoadLyrics 构造器目前无 Dart 调用方（app_model 直构 freezed 值），去留待定。

**结论：eb1afc3 是自洽的中间快照，但没有一张截图/一次实机运行证据；HEAD flutter test 因 P2-18 挂 1 例。WIP 批次不能就此关闭。**

## 八、计划书 §2.5 线索逐条核验

| 线索 | 核验结论 |
|---|---|
| P0-01 主 isolate 概率性卡死 | 开放维持。矩阵登记「本轮未复现」，本轮无新复现证据，不宣称修复 |
| P1-05/P2-08 GL timeout 后进程消失 | 开放维持。L1 轮已接 panic/Flutter 异常取证面，引擎级 GL abort 无 unwind 仍无取证 |
| P1-06 Android 真机 | 未验证维持（环境无 JDK/AVD+用户 2026-11-10 搁置令） |
| P2-04 niri 窗口尺寸契约 | 开放维持。基线/验收截图必须读真实可用宽高，不能信窗口请求值 |
| P2-05 GUI MPRIS | 开放维持（2026-11-13 busctl 实跑零命中证据在案）；本轮不伪造系统集成 |
| P2-09 队列拖动排序 | 开放维持（UI 如实禁用+说明，queue_interaction_test 8 用例锁定） |
| P3-09 下载窄窗 overflow/字节倒挂/错误截断 | **开放确认**（downloads_page.dart:465-473,442-444,449-483 实证，无修复痕迹） |
| P1-20 | 代码+widget 测试闭环，缺 leaderboard/categories 路径与运行时复验，矩阵暂维持开放 |
| P2-16 | Rust 单元闭环实跑通过，缺 HTTP/解码/UI 层证据，矩阵维持开放 |
| P2-17 | 链路纸面闭环，缺按钮态/测试/运行时证据+DIAG 残留，矩阵维持开放 |
| P2-18 | 代码分支完成但 1 测试挂，矩阵维持开放 |
| 手机首页快捷入口截断 | **风险确认**（360dp+textScaler≥1.1 截断推演+测试缺口） |
| 桌面首页导入按钮 | **语义错位确认**（navRequest 5→曲库，非真实导入） |
| 主题体系 | **双真源确认**（ThemeProvider 与 Vx token 零引用） |

## 九、第二轮差距登记（SR 编号，仅登记；并入 04 矩阵时按计划书 §10.4 更新原条目、新缺陷续新号）

> 状态更新（2026-11-15 Batch B 后）：SR-03 主题双真源已收敛（B1 buildAppTheme 显式 ColorScheme + B3 chrome 全部切 scheme/VxPalette，VxChrome 删除）；SR-04 dynamicColor 单源（B4 useCoverDynamicColor 改名迁移+默认对齐 Rust+死壳 tile 退役）；SR-05 44 预设投影失效已修（B1 projection 推 themeKey + flex 亮度 bug 修复，44×2 亮度全可构建有测试锁定）；SR-07 ThemeProvider/guard 补洞（B2 main 内联主题移除+字面量禁令断言，B5 misansTextTheme 删除）；SR-08 字级层级+CJK fallback 进运行时（B1 textTheme 按 VxTypography 映射）。SR-02 已关闭（CI pin+双绿）；SR-01 已关闭（CI run 43556931399 8/8 绿）。Batch B 视觉走查未做（无截图证据，待运行时验证批次/Golden）。原 SR-01..08 处置记录见下（门禁恢复批次后快照）。
> 状态更新（2026-11-14 门禁恢复批次后）：SR-01 已关闭（CI 6 处 pin 3.47.9 + analyze/test 拆独立 job + 版本输出；推送后 run 43556931399 实测 8/8 job 全绿，analyze 1m11s 修复直接生效，日志确认 Flutter 3.47.9/Dart 3.13.7）；SR-02 已处置（now_playing_test 按 P2-17/P2-18 新行为重写 6 用例，18 项全绿）；SR-12 已处置（LyricsRetryButton 在途/失败/超时态 + DIAG 清除 + 过时注释更新 + Dart widget 6 用例 + Rust 侧 service.rs LoadLyrics 成功/失败两路径回归测试，mock LyricFetcher 注入）。详见 04 缺陷矩阵同日更新行。

| 编号 | 级别 | 内容 | 证据 |
|---|---|---|---|
| SR-01 | P1 | CI analyze 门禁红：stable 未固定+material.dart 整体弃用 115 infos；修复=pin 3.47.9+analyze/test 证据独立 | ci.yml:355-358、CI 日志 43547105433 |
| SR-02 | P1 | HEAD flutter test 红：now_playing_test.dart:270-287 与 P2-18 分支冲突 | 实测 40/41（2026-11-14） |
| SR-03 | P1 | 手机 8 页复用桌面实现（Discover/Search/Downloads/PlaylistDetail/LocalMusic/Settings/Help 零适配+曲库半适配） | app_shell.dart:802-826 |
| SR-04 | P1 | 主题双真源：ThemeProvider fromSeed 与 Vx token 脱节，壳层颜色不随主题切换 | theme_provider.dart:64-82、design_tokens.dart:15-157 |
| SR-05 | P2 | 28/44 主题预设投影失效（回退 Mocha） | projection.dart:97+、registry.dart:51-91 |
| SR-06 | P2 | dynamicColor 双开关双真源（Rust config vs myune prefs，默认值不一致） | app_model.dart:110,331、settings_provider.dart:31,84 |
| SR-07 | P2 | ThemeProvider 零行为测试；guard 测试对 main.dart 内联 fromSeed 不可见 | theme_source_guard_test.dart:20-48、main.dart:397-432 |
| SR-08 | P2 | 运行时字级层级违规（misansTextTheme 全 w400）+ CJK/JetBrainsMono fallback 未进运行时 | theme_provider.dart:11-29、typography.dart:46-49 |
| SR-09 | P2 | 平板全部槽位复用桌面页面（home 偏差已在旧矩阵登记待裁决） | mobile_shell.dart:796-811 |
| SR-10 | P2 | 桌面全部一级页 1920 宽无限拉伸（无中心限宽容器） | 各页 pagePadding，仅 now_playing:355 有 1320 |
| SR-11 | P2 | 桌面右键菜单（口径修正 2026-11-14：SongTile 主行面 showSongMenu 已存在并接线 4 触发面，原「整体缺失」有误；残余缺口=网格卡面与个别视图） | song_tile.dart:76,217,242,263,393；playlist_content_widget.dart:255 |
| SR-12 | P2 | 歌词重取按钮无 loading/防重复态+DIAG eprintln 残留+过时注释+歌词链零测试 | lyrics_panel.dart:162,13、service.rs:1732 |
| SR-13 | P2 | 键盘焦点漫游无规划（FocusTraversalGroup 缺失） | 仅 search_page.dart:639-643 |
| SR-14 | P3 | Header 搜索与搜索页单向同步 | app_shell.dart:392-401 |
| SR-15 | P3 | 首页我的歌单卡全跳曲库不进详情 | home_page.dart:214 |
| SR-16 | P3 | 滚动底部 padding 固定 24 未联动 inset | mobile_home_page.dart:50、library_page.dart:726 |
| SR-17 | P3 | settings 配置失败无错误态；侧栏歌单无 Loading；空态组件双轨；ContextPanel 注释漂移；playlist_browse 死代码挂测试；bridge/api.dart:57 无调用方构造器 | 各 file:line 见 §四 |
| SR-18 | P3 | mobile 专项测试仅 4 页；平板右栏 340 固定不可拖；600-839 ContextPanel 体验降级 | §五/§六 |

## 十、Phase 0 退出条件对照（计划书 §2.6）

| 退出条件 | 结论 |
|---|---|
| 审计报告完整，每页有状态/证据/差距 | 达成（本文档 §三至§六） |
| 最新 CI 已复现，失败原因定位到 SDK/analyzer/lint | 达成（§2.1：stable 漂移+deprecated_member_use） |
| WIP 改动已理解，未覆盖用户工作区 | 达成（§七；工作区零生产代码改动） |
| 差距清单更新且不与旧矩阵重复登记 | 达成（§九 SR 清单只登记新发现；旧条目处理意见见 §八） |
| 未修改生产代码 | 达成（仅新增 second-round/ 两个 markdown） |

## 十一、下一阶段入口

1. **门禁恢复小批次（先于 Phase 1）**：SR-01（CI pin 3.47.9+证据独立）+ SR-02（now_playing_test 按新行为重写）+ SR-12 的 DIAG/注释清理。三者都小，合并一个批次，门禁回绿后再动 UI。
2. **Phase 1 主题真源统一**：按 SR-03/04/05/06/07/08 顺序收敛，先让运行时 ThemeData 从 Vx token 派生（或反向），再补 28 预设投影与 ThemeProvider 行为测试。
3. **WIP 批次收尾（可与 2 并行）**：P2-16 HTTP/解码/UI 证据、P2-17 按钮态+测试、P2-18 运行时截图、P1-20 运行时复验，证据齐后更新矩阵 4 条。
4. Android 真机、MPRIS、P0-01/P1-05 继续如实保持未验证/开放，不因 UI 进度改写。
