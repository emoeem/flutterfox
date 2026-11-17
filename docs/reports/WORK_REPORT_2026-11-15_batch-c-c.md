# 工作报告：Batch C-C（C-04 歌单详情手机页 + C-08 曲库核验收口 + C-07 帮助页手机形态）

> 日期：2026-11-15 · 执行环境：Windows 10（Git Bash）· 分支 feat/ui-redesign · 基线 HEAD `7e2efb2`（交接文档入库提交）
> 上游：第三轮计划书 §6.3 C-04/C-07/C-08 · 交接 SESSION-HANDOFF-2026-11-14 §四.1 · UI 唯一规格 §5.6/§5.5/§6.3

## 基线

- 分支/HEAD：feat/ui-redesign @ `7e2efb2`，开工时工作区干净（仅本批新增改动）。
- Flutter：3.47.9 stable（c197ca519）· Dart 3.13.7（与 CI/handoff 完全一致）。
- Rust：本机新装 rustup stable **1.100.0**（x86_64-pc-windows-gnu 宿主工具链；交接记录的原执行机为 1.99.0，CI ubuntu runner 同为跟随 stable，clippy 命令口径不变，版本差异如实登记）。
- FRB / Codegen：未触碰（本批零 FFI 面）。pubspec.lock 未动（`flutter pub get` 幂等）。
- CI Run：未推送，本批不产生新 run；推送后以 draft PR #12 最新 run 为准（flutter-analyze / flutter-test / Lint / 平台构建）。

## 审计结论（Step 1-2 现状矩阵）

| 项 | 状态 | 证据（HEAD 7e2efb2 实测） |
|---|---|---|
| C-04 歌单详情手机页 | 未实现 | 无 MobilePlaylistDetailPage；手机端 4 处 push 全部推桌面页（mobile_home_page.dart:450/:455、mobile_discover_page.dart:430、library_page.dart:967） |
| C-04 业务编排 | 桌面页私有实现 | playlist_detail_page.dart:44-175（prepareBrowseLoad 首帧清槽 / fav pending-override-确认回滚 / awaitBrowseResponse+15s 兜底 / _playShuffled 已载入域随机） |
| §8.1 PlaylistKey 隔离 | 已有（AppModel browse 槽 + prepareBrowseLoad） | playlist_detail_isolation_test 13 用例（widget 层） |
| C-08 `<512` 补丁 | 已实现且 360/390/430 三档已有部分回归 | library_page.dart _header compact(:81-117)/entryCard FittedBox(:219 P2-15)/_tools compact(:461-467)；mobile_library_page_test 既有 4 用例 |
| C-08 缺口 | 四 tab 主体窄视口渲染、网格/列表双形态、镜像视图切换、push 落点形态无用例；**实施轮新发现 1 处真缺陷** | 见下 |
| **C-08 实施轮新发现（真缺陷，已修复）** | 歌手档列表行 leading 无尺寸约束 | library_page.dart `_artistListRow` 的 leading `VxCoverFallback(title:, radius: 999)` 无尺寸参数——ListTile leading 不受约束时占满整行宽，布局断言必挂（「Leading widget consumes the entire tile width」，widget 层 4 次异常实锤）。该行此前几乎不可达：手机档（<512）与桌面网格↔列表切换后的歌手列表档均会触发崩溃级断言（桌面缺省网格视图不渲染该行，故从未在测试/实机中暴露）。修复 = SizedBox(44,44) 包裹（与专辑行 CoverImage(size:44) 同口径）；桌面既有测试面（desktop_three_column/desktop_queue/shell 等 41+8+15+19 项）全绿佐证零回归 |
| C-07 帮助页手机形态 | 未实现 | help_page.dart 无形态参数；app_shell.dart:840 help 槽不分叉；「播放页快捷键」（空格/←→/Esc）触屏不适用 |
| library 入口卡「本地音乐」 | 复用桌面 push（C-B 接线未覆盖面，C-08 审计发现） | library_page.dart:991-995 推桌面 LocalMusicPage；同页 mobile_home/drawer 已推手机版（C-B 批次登记的「快捷入口」不含曲库入口卡） |
| Rust/FFI 面 | 零改动需求 | C-C 全部为 Dart UI 层 + 1 条 clippy 1.100 版本漂移机械修复（见「契约/行为变化」） |

## 修改清单

| 文件 | 修改 | 根因 / 必要性 |
|---|---|---|
| `flutter/lib/src/pages/playlist_detail_shared.dart`（新增） | PlaylistDetailController + playlistDetailKind：桌面页私有业务编排提炼为共享控制器（attach 同步 prepareBrowseLoad+帧后首载、reload/loadMore/refresh、收藏乐观态、playShuffled、totalDuration） | 照 discover_shared.dart 模式（交接指定）：业务单一实现，桌面/手机两页只做布局；禁止第二份业务 |
| `flutter/lib/src/pages/playlist_detail_page.dart` | 消费共享控制器；新增 didUpdateWidget 输入变化重建（§8.1 切歌单先 loading）；布局/文案/断言口径零变化 | 同上；既有测试（playlist_detail_page/isolation/phase5_detail_hero/push_and_favorites）全绿未改断言 |
| `flutter/lib/src/pages/mobile_playlist_detail_page.dart`（新增） | §5.6 手机歌单详情：AppBar（返回/歌单名/更多：刷新·推送远端·账号同步）→ Hero（封面 160–220dp 随宽自适应 `(w*0.6).clamp(160,220)`、名称 2 行、来源徽章、曲目数/已载入/总时长、描述 3 行）→ 主操作（播放全部主钮+随机次钮+收藏 pending spinner）→ 移动行（VxTrackRow comfortable：单击播整列、长按 showSongMenu、更多按钮）→ 触底分页尾态 + RefreshIndicator 下拉刷新 + 四态（骨架/错误净化+重试/空态/notice） | C-04 主体；推入路由自带 Scaffold+AppBar（照 MobileLocalMusicPage 模式，android_insets 分层契约） |
| `flutter/lib/src/pages/help_page.dart` | 新增 `showDesktopShortcuts` 参数（缺省 true 零变化）；false 时「播放页快捷键」段替换为「触屏操作」段（长按歌曲行/下拉刷新/横滑封面/抽屉——全部已上线真实能力） | C-07；§6.3「按移动端能力过滤」 |
| `flutter/lib/src/shell/app_shell.dart` | help 槽 form 分叉（mobile→过滤版）；library 槽向 LibraryPage 传 `mobileForm` 位 | C-07 + C-04 接线的形态感知唯一出处 |
| `flutter/lib/src/pages/library_page.dart` | 新增 `mobileForm` 参数（缺省 false）；_favoritePlaylistRow 的歌单 push 分叉（mobile→MobilePlaylistDetailPage）；_openLocalMusic 分叉（mobile→MobileLocalMusicPage，C-B 同域收口） | C-04「push 入口全部改推手机版」+ C-08 审计发现的 C-B 接线残余 |
| `flutter/lib/src/pages/mobile_home_page.dart` | 推荐/最近歌单卡 onTap+onPlay → MobilePlaylistDetailPage；内嵌 LibraryPage(喜欢的歌曲落点) 传 mobileForm: true | C-04 |
| `flutter/lib/src/pages/mobile_discover_page.dart` | 歌单卡 onTap → MobilePlaylistDetailPage；import 收敛 | C-04 |
| `flutter/test/mobile_playlist_detail_page_test.dart`（新增） | 13 用例：首帧加载态不闪旧歌单 / A-B 槽位隔离 / 同 ID 异 source / 账号 kind 分命名空间+同步入口 / 错误+重试真实命令 / 空歌单+播放禁用 / notice 非错误 / 播放全部 index0+随机场 / 收藏失败回滚 / 收藏成功快照确认 / 触底分页 page2 / 下拉刷新 page1 / 360-390-430 无溢出 | §12.3 MobilePlaylistDetail 隔离与四态契约 |
| `flutter/test/mobile_library_page_test.dart` | +4 用例：360/390/430 四 tab 主体+网格列表双形态无溢出 / 360 镜像切换回落 / 手机形态 push 落点（歌单行→手机版详情、入口卡→手机版本地音乐）/ 桌面缺省仍推桌面版（零变化守卫） | C-08 完整性核验收口 |
| `flutter/test/mobile_shell_test.dart` | 「设置与帮助可达」用例补 C-07 断言（无播放页快捷键段、有触屏操作段） | C-07 壳内接线 |
| `flutter/test/mobile_help_page_test.dart`（新增） | 3 用例：桌面缺省守卫 / 手机形态过滤+触屏段 / buildShellPage help 槽分叉 | C-07 |
| `app/src/notification.rs` | collapsible_if：嵌套 if let 折叠为 let-chain（零行为变化，clippy 建议 diff 原样套用） | clippy 1.100 版本漂移：HEAD 在 1.100 新 lint 下必挂 CI 同款命令（rust-1.100.0#collapsible_if 支持 let-chain 检测），1.99 基线无此 lint；按「不得放宽门禁」机械修复并如实登记 |

## 契约 / 行为变化

- Rust API / DTO / Command / Event：无（notification.rs 仅语法折叠）。
- Dart Adapter：无新命令；页面消费面不变。
- 平台行为：手机壳内歌单详情、library 歌单行/本地音乐入口、help 槽共 4 处行为变化（均为 C-A/C-B 既有收敛方向的延续）；桌面/平板全部路径零变化（desktop 缺省 + 平板显式缺省）。
- 兼容策略：LibraryPage/HelpPage 新参数均带缺省值，既有调用点（myune_shell 遗留、测试直泵）零改动即桌面行为。

## 验证

| 命令 / 操作 | 平台与环境 | 退出码 | 通过 / 失败 | 备注 |
|---|---|---:|---|---|
| `flutter analyze --fatal-infos` | Windows / Flutter 3.47.9 | 0 | No issues found | 全仓 |
| `dart format --output=none --set-exit-if-changed lib test` | 同上 | 0 | 270 files 0 changed | 含 HEAD 上既存不合规的 app_theme.dart/app_theme_test.dart（本机 3.13.7 复检重排，语义零变化，随批恢复门禁绿，见「如实登记」） |
| `cargo fmt --all -- --check` | Windows / rustc 1.100.0 gnu | 0 | OK | |
| `cargo clippy --workspace --all-targets --features lx-player/build_libmpv -- -D warnings -A clippy::double_must_use` | 同上 | 0 | 0 error | CI 同款命令 + build_libmpv feature（Windows 链接 MPV_SOURCE 需要；CI Linux 用系统 libmpv-dev 不需要该 feature，命令主体一致）；1.100 collapsible_if 漂移已修 |
| `cargo test --workspace --locked --features lx-player/build_libmpv --no-fail-fast` | 同上 | 101（因 4 个平台环境失败） | **835 passed / 4 env-limited** | lx-core 47 / lx-lyric 19 / lx-player 12 / lx-source 226+3 env / source integration 4 / app 331+1 env / application 77 / download 71 / ffi 8 / runtime 40。**838 Linux 基线 = 835 + 3**（lx-source 3 例为 Windows 专有夹具失败，见下）；app 1 例为时序敏感 flaky（单独复跑 332/332 全过）。Rust 业务面零改动（git diff application/core/source/runtime/ffi/download/lyric/player/app 开工时为空；唯一 Rust diff = notification.rs lint 折叠） |
| flutter 全量 test | Windows / Flutter 3.47.9（VS Build Tools 2022 MSVC 14.44 + SDK 26100 已由用户装好，native assets 可编译） | 0（逐文件） | **483 passed / 0 failed** | 全仓 59 个测试文件逐文件顺序实跑（每个文件以 flutter test 退出码判定，瞬时抖动文件重跑复验）：第一轮 34 文件 303 项 + mobile_now_playing 复跑 14 项 + 第二轮 24 文件 180 项。基线 466 + 本批新增（mobile_playlist_detail 13 + mobile_help 3 + mobile_library 4）= 486 口径吻合（mobile_shell/shell 为既有用例内增断言不增数）。**如实登记**：`flutter test` 全仓单命令模式在本 Windows 机存在 flutter-tester 进程级瞬时挂起（"did not complete"，挂起文件集合逐轮漂移、单文件复跑全绿），属本机环境抖动非测试缺陷，故以逐文件顺序实跑为等效全量口径；Linux CI 的 `flutter test` 单命令不受影响 |
| 定向新测试 | 同上 | 0 | mobile_playlist_detail_page_test 13/13、mobile_library_page_test 9/9（含新增 4）、mobile_help_page_test 3/3、mobile_shell_test 9/9（C-07 断言入册） | 实跑 `00:03 +25: All tests passed!`（三新文件合计） |

**4 个 cargo 平台环境失败（非代码缺陷，如实登记）**：
1. `local::scanner::tests::snapshot_includes_opus_files_and_ignores_unknown_extensions`、`local::tests::forced_scan_bypasses_the_unchanged_directory_fast_path`、`local::tests::incremental_reuse_keeps_every_song_from_the_same_source_file`：测试用 `temp_dir().join("voicefox-…-{pid}-{thread_name}")` 且线程名含 `tests::`——`::` 在 Windows 文件名非法（Os code 123），Linux 合法。夹具平台不兼容，不构成代码缺陷；不修改测试（不削弱），留 Linux CI 为准。
2. `app visualizer::capture::tests::silence_watch_does_not_publish_while_data_flows`：5/10/50ms 线程时序假设 vs Windows 默认 15.6ms 调度粒度，本机首次挂、单独复跑全过——flaky 登记不修。

## 运行时证据

- 本批为 widget 层批次：真机（Android）与桌面运行时截图维持 P1-06 / 环境 口径未验证，不因测试全绿改判。
- 360/390/430 视口覆盖 = widget 层矩阵断言（mobile_playlist_detail_page_test + mobile_library_page_test + 既有 viewport_matrix_test）。
- 未覆盖：真实歌单大数据分页性能（属 Batch A 性能基准范围）、平板形态下 library 歌单行 push（平板显式桌面缺省，行为不变故无新增覆盖）。

## 缺陷矩阵更新

- SR-03 手机复用桌面收敛：**7/8**（新增 C-04 歌单详情手机页 + C-07 帮助页手机形态；曲库 C-08 以「既有 <512 补丁 + 用例补全」收口、不强建第二页面；剩余 Settings 归 C-D）。
- C-B 接线残余（library 入口卡本地音乐）随批收口。
- 无既有矩阵项状态变化（P2-15/P2-10 等关闭项未回归——mobile_library_page_test 既有断言全保留且全绿）。

## Git 状态

- 修改：10 个既有文件（7 lib + 3 test，含 app_theme 2 文件 format 对账 + notification.rs lint 折叠）。
- 新增：5 个文件（2 lib + 3 test）。
- 未跟踪清理：无（本批产物全部纳入）。
- generated_plugin_registrant 等行尾噪声：pub get 副作用，内容零 diff，提交时自动归一。
- 是否提交：**待用户授权**（§0.4.9）。是否推送：**待用户授权**。

## 下一批次建议

- Batch C-D：Settings 手机分组列表（桌面 208 双栏不照搬）+ 全部手机页滚动底部 padding 单一出处化（现状 VxSpacing.xl/24 散落 mobile_home_page.dart:51、library_page.dart:726,741,825,840、mobile_search/local/discover/downloads 的 VxSpacing.xl——android_insets.dart 分层契约已保证内容不被底栏遮挡，「统一」落点为单一出处常量 + 360/390/430 矩阵断言）+ viewport_matrix_test 扩充。
- 工具链登记（Windows 会话交接）：flutter test 需 VS Build Tools（VCTools 工作负载）；Rust 用 gnu 宿主工具链 + w64devkit（PATH 提供 gcc/dlltool）+ MPV_SOURCE 指向 libmpv-audio 预编译件 + `--features lx-player/build_libmpv`；cargo 命令注意 Git Bash `/usr/bin/link.exe` 遮蔽问题（gnu 宿主工具链不受影响）。
