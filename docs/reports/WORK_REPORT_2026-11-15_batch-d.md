# 工作报告：Batch D（桌面体验完善：SR-10 限宽 + SR-11 卡面右键残余收口 + SR-13 焦点漫游组 + SR-14 搜索双向同步 + SR-15 首页歌单入口）

> 日期：2026-11-16 · 执行环境：Windows 10（Git Bash）· 分支 feat/ui-redesign · 基线 HEAD `566ed42`（Batch C-D 提交）
> 上游：计划书 §7（7.1-7.5）+ 01 审计 SR-10/11/13/14/15 · UI 唯一规格 §7.1/§7.2/§7.4/§7.6

## 基线

- 分支/HEAD：feat/ui-redesign @ `566ed42`，工作区干净（仅本批改动）。
- Flutter 3.47.9 / Dart 3.13.7 / rustc 1.100.0（gnu）/ FRB 2.13.0——与前批一致。
- Rust 面：**零改动**（git diff Rust 目录为空），cargo 门禁沿用 Batch C 同代码实跑结果。

## 审计结论（Step 1-2）

| 项 | 状态 | 证据（HEAD 566ed42 实测） |
|---|---|---|
| SR-10 限宽 | 未实现（仅 now_playing 1320 唯一先例） | 各桌面页根级无 maxWidth；home 用 VxSpacing.pagePadding 28 仅内边距 |
| SR-11 残余 | 网格卡面无右键；**自建歌单域动作齐备可复用**（rename/delete/detail 命令与对话框均在 custom_playlists_page.dart:133/144/196） | grep 全卡面组件无 onSecondaryTapUp；VxHoverBuilder 无右键位 |
| SR-13 | 无 FocusTraversalGroup 规划（仅 search 表 639 与壳快捷键显式 Focus） | grep FocusTraversalGroup 全仓 0 命中 |
| SR-14 | Header→页单向（种子 KeyedSubtree 重建）；页内换词不回写 Header | app_shell.dart:396-405 _onSearchSubmit；search_page 无回写 |
| SR-15 | 首页歌单卡 onTap = navRequest.value = 2（全跳曲库） | home_page.dart:215 |
| **实施轮新发现（真缺陷，已修复）** | 卡片标题/副标题死区 | vx_card_shell.dart：VxHoverBuilder 仅包封面 AspectRatio，title/subtitle 在手势区外——用户点标题无响应（SR-15 测试实锤），全卡面组件族同源 |

## 修改清单

| 文件 | 修改 | 根因 / 必要性 |
|---|---|---|
| 新 `design_system/components/desktop_content_constraint.dart` | DesktopContentConstraint（Align topCenter + ConstrainedBox maxWidth 1320） | SR-10 §7.1：统一限宽组件不为每页硬编码；1320 与 now_playing 先例同源（§7.1.5）；窄窗零变化（§7.1.4 ConstrainedBox 语义） |
| 6 桌面页根级包裹 | home/discover/search/library/downloads/settings 各 `return DesktopContentConstraint(child: …)` | SR-10；页面 Material 背景全幅、内容列居中（Align 语义）；平板 <1320 不束缚 |
| `vx_hover.dart` | +onSecondaryTapUp（GestureTapUpCallback?）接入 GestureDetector | SR-11 手势位 |
| `vx_card_shell.dart` | +onSecondaryTapUp 参数链 + **外层 GestureDetector(opaque, onTap+onSecondaryTapUp) 整卡承接（真缺陷修复：标题/副标题死区）**；封面内 VxHoverBuilder 保留 hover 视觉/手型光标，命中竞态由手势竞技场就近解析（单次触发） | SR-11 + §7.6 交互一致性 |
| `vx_playlist_card.dart` | 参数透传 | SR-11 接线 |
| `custom_playlists_page.dart` | 新顶层 `showCustomPlaylistCardMenu`（showMenu 形态与 showSongMenu 同源：打开详情/重命名/删除，复用 promptCustomPlaylistName + rename/delete 命令 + 删除确认与 snackbar）；`_PlaylistTile` 外包 GestureDetector 接右键 | SR-11：同一动作集不另建菜单体系（§7.2.5）；专辑/歌手/远端歌单卡无域动作如实不加（§7.2.7） |
| `home_page.dart` | 我的歌单卡 onTap → CustomPlaylistDetailPage（SR-15）；onSecondaryTapUp → 卡面菜单（SR-11）；import 扩展 | SR-15/11 |
| `nav_bus.dart` | +`searchKeyword` ValueNotifier\<String\>（单一状态流） | SR-14 §7.4 单一流 |
| `search_page.dart` | initState/dispose 流监听；`_onSearchTextChanged` 权威写入流（同文本 ValueNotifier 不通知防循环）；新增 `_onStreamKeywordChanged`（Header 回流 → 输入框同步 + 同一防抖链）；种子分支同步流 | SR-14 |
| `app_header.dart` | +searchController 参数 + TextField controller/onChanged 写流 | SR-14 |
| `app_shell.dart` | `_headerSearchController` + `_onStreamKeywordChanged` 同步（文本相同跳过防循环）+ initState/dispose 接线 + _onSearchSubmit 写流 + 侧栏/中央内容/右栏内嵌/PlayerBar 四个 FocusTraversalGroup | SR-13/14 |
| 新 `test/desktop_batch_d_test.dart` | 7 用例（SR-10×2 mechanics / SR-13 结构 ≥4 组 / SR-14 双向+防循环+恰一次派发 / SR-15 推入 / SR-11 右键菜单含动作真实推入） | 各项机制锁定 |

## 契约 / 行为变化

- Rust API / DTO / Command / Event：无（Dart-only）。
- 卡面族行为变化：全卡可点（原封面区外死区）——VxAlbumCard/VxArtistCard/VxPlaylistCard 及全部 VxCardShell 消费面同源生效；既有 tap 语义不变（命中竞技场单次触发）。
- 自建歌单卡面新增右键动作集（域动作既有）；专辑/歌手/远端歌单卡无域动作如实不加。
- Header 搜索框由非受控变受控（controller 由壳层持有）；Header 输入实时回流搜索页（防抖派发）；提交/种子语义不变。
- 桌面 Tab 漫游分组化（侧栏→内容→右栏→PlayerBar）；组内默认阅读序。
- 桌面六页 1920+ 内容限宽 1320 居中（背景全幅）；<1320 零变化。

## 验证

| 命令 / 操作 | 平台与环境 | 退出码 | 通过 / 失败 | 备注 |
|---|---|---:|---|---|
| `flutter analyze --fatal-infos` | Windows / Flutter 3.47.9 | 0 | No issues found | 全仓 |
| `dart format --output=none --set-exit-if-changed lib test` | 同上 | 0 | 274 files 0 changed | |
| `flutter test test/desktop_batch_d_test.dart` | 同上 | 0 | 7/7 | SR-10/13/14/15/11 全链 |
| 卡面消费面回归 | 同上 | 0 | desktop_batch_d + custom_playlist 7 + discover 14 + search 14 + artist_album 4 + home 6 = 46 项全绿 | VxCardShell 行为变化回归面 |
| `flutter test` 逐文件 sweep（退出码判定） | 同上 | 0 | **501 passed / 0 failed（61 文件全绿）** | 基线 494（C-D 时点）+ desktop_batch_d 7 + 计数口径（now_playing 全量 18） |
| cargo fmt / clippy / test | Windows / rustc 1.100.0 gnu | 0 / 0 / — | 沿用 Batch C 实跑（本批 Rust 零改动） | |

**如实登记**：
- §7.1.5「最大宽度值必须根据视觉证据确定」：1320 取自仓内唯一先例（now_playing 既有视觉决策）而非新证据；1920 布局截图属 Linux 运行时验证项，Windows 会话如实标「未验证」，widget 层 mechanics（1920→1320 恰宽 / 1150 零变化）已测试锁定。
- §7.3「实际桌面键盘走查」：FocusTraversalGroup 结构在树已断言；真实 Tab 走查（方向键/快捷键冲突优先级矩阵）需桌面运行时，标「未验证」。
- SR-14「快速输入和过期请求」测试覆盖防抖在途锁与防循环；Header 侧实体键入的运行时走查未做（widget 层 enterText 等价已锁）。
- SR-11 触屏长按未接卡面（桌面右键已收口；长按语义留后续，song_tile 先例可循）。

## 缺陷矩阵更新

- SR-10 关闭（DesktopContentConstraint 单源；1920 视觉证据留 Linux 运行时——matrix 行如实登记）。
- SR-11 关闭（残余=网格卡面 → 自建歌单卡面右键收口；其余卡面如实不加假入口）。
- SR-13 关闭（四区域漫游组在树；键盘走查留运行时）。
- SR-14 关闭（单一状态流双向 + 防循环 + 防抖单发）。
- SR-15 关闭（首页卡进详情）。
- 新登记 minor：**卡面标题死区**（实施轮发现并修复，见修改清单——记入 matrix 作为已关闭条目）。

## Git 状态

- 修改：14 个文件；新增：2 个（desktop_content_constraint.dart + desktop_batch_d_test.dart）。
- 是否提交：**待用户授权**（§0.4.9）。是否推送：**待用户授权**。

## 下一批次建议

- Batch E（下载可靠性 §8）：Rust 下载状态机审计（Content-Length/Range 口径、P3-09 字节倒挂收口）、downloads_page 百分比夹取与状态机测试、窄窗收纳。Rust 面将首次在 Windows 会话改动——cargo 门禁命令见 SESSION-HANDOFF-2026-11-16.md §二陷阱 2/3。
