# Flutter 前端审计报告（voicefox-gui/flutter）

- 审计对象：`/home/emo/code/voicefox-gui/flutter/`
- 审计方式：只读代码审阅 + 静态验证（`flutter analyze`、`flutter test`）；未修改任何源文件
- 规模：`lib/` 下 160 个 Dart 文件、54,568 行（`find … -name '*.dart' | wc -l` = 160）
- 审计日期：2026-11-05

---

## 1. 总体架构

```
main.dart
 ├─ windowManager 初始化（自绘标题栏，TitleBarStyle.hidden）
 ├─ AppModel() + attachVoicefoxAudioBackend(model)   ← myune 播放接缝
 ├─ model.bootstrapDesktop()  ← RustLib.init() + bridge.newDesktop()（FFI）
 └─ VoicefoxApp
     ├─ 未就绪：_BootstrapScreen 骨架屏（轻量标题栏 + spinner/错误）
     └─ 就绪：MyuneHost.attach(model) 挂 app 级 Provider 图
         └─ MultiProvider(5 × ChangeNotifierProvider)
             └─ VoicefoxAppShell（NavigationRail 九入口 + 底部 Playbar + 队列 Drawer）
```

- 引导失败路径：`main.dart:47-49` `bootstrapDesktop().catchError(model.reportBootstrapError)`，骨架屏持续显示错误（`main.dart:207-231`）。
- 事件流：Rust 控制器广播 → `AppModel._eventLoop`（`app_model.dart:154-176`，异常退避 1s 后重订阅并整份重拉快照）→ `_handleEvent`（`app_model.dart:178-235`）按 kind 分发（progress 4Hz 增量替换 / 其余整份 `_refreshState`）→ `notifyListeners()`。
- 命令流：页面 → `AppModel.dispatch/_sendCommand`（`app_model.dart:949-966`，异常统一写 `lastError`/`lastNotification`）→ FFI `bridge.dispatch`。
- 错误出口：`MyuneProjection._pumpToasts`（`myune_shell/projection.dart:105-124`）把 lastError/lastNotification 泵进 `NotificationService` → `ToastOverlay` 全局 toast。

## 2. 状态管理结论

**方案：`package:provider` 6.x + ChangeNotifier，无 Riverpod / Bloc / MobX。**

判据（以 import 为准）：`grep -rn "import" lib -h | grep -oE "package:[a-z_]+" | sort | uniq -c` 中 `package:provider` 52 处、`package:flutter_rust_bridge` 9 处；`riverpod`/`bloc`/`get` 为 0。pubspec.yaml（`flutter/pubspec.yaml:20`）仅声明 `provider: ^6.1.5`。

Provider 图（`main.dart:121-132`，五个常驻 ChangeNotifier）：

| Notifier | 来源 | 职责 |
|---|---|---|
| `AppModel` | `src/app_model.dart:39`（1029 行） | 唯一真源：Rust 控制器句柄 + VoicefoxState 快照 + browse 分槽缓存 + 同步/推送/扫码状态 |
| `SettingsProvider` | vendored `myune/page/setting/settings_provider.dart`（816 行） | myune 壳设置（SharedPreferences 持久化；主题真源仍在 Rust 配置，见 `projection.dart:76-77` 注释） |
| `ThemeProvider` | vendored `myune/theme/theme_provider.dart`（314 行） | M3 主题生成 |
| `NotificationService` | vendored `myune/services/notification_service.dart` | 全局 toast |
| `PlaylistContentNotifier` | vendored `myune/page/playlist/playlist_content_notifier.dart`（5032 行） | 投影接收方：播放页（歌词/队列/封面）+ 本地元数据读取（经 myune FRB `readAudioInfo`，`playlist_content_notifier.dart:1041` 等 4 处） |

桥接层：`MyuneProjection`（`myune_shell/projection.dart:27`）把 AppModel 快照常驻投影（播放状态/歌词/队列/封面/toast/主题 seed）；`AppModelAudioBackend`（`myune_seam/app_model_audio_backend.dart:17`）把 vendored UI 的播放命令经 shim 转发回 AppModel。

**架构决策有据可查**：`app_model.dart:3-5` 注释明说「单 Rust 控制器广播事件 → 单一快照，ChangeNotifier 足够；页面复杂化后再引入 riverpod（届时二选一，不混用）」。

**FFI 存在性**：两套 flutter_rust_bridge 生成代码——主桥 `lib/src/bridge/`（FRB 2.13.0，`bridge_smoke_test.dart` 断言 codegenVersion=2.13.0）与 vendored myune 桥 `lib/src/myune/src/rust/`（FRB 2.10.0，仅 `api/audio_info.dart`，被 playlist_content_notifier / lyrics_handler 引用）。完成度判定因此全部按「是否触达 FFI（直接或经 AppModel）」执行。

## 3. 导航结构（路由表）

**无命名路由、无 go_router。** 两种导航并存：

1. **主导航**：`VoicefoxAppShell` 内 `NavigationRail` 九项（`myune_shell/app_shell.dart:113-168`）+ `AnimatedSwitcher`/`KeyedSubtree(ValueKey(_index))` 切页（`app_shell.dart:218-236`）——切页即重建，页面状态不保留（非 IndexedStack）。
2. **二级路由**：各页 `Navigator.push(MaterialPageRoute)`。
3. **跨页导航总线**：`src/nav_bus.dart:8` `ValueNotifier<int?> navRequest`，shell 消费（`app_shell.dart:101-105`）；首页快捷入口/书架「查看全部」写索引（`home_page.dart:50,56,62,163,520`）。

主导航索引表：0 首页 / 1 搜索 / 2 曲库 / 3 在线歌单 / 4 排行榜 / 5 本地音乐 / 6 下载 / 7 设置 / 8 帮助（与 `_QuickAccess` 硬编码索引一致，`home_page.dart:505-512`）。

## 4. 页面/组件清单与完成度

完成度判据（按 ask 要求）：**完整 = 触达 FFI（直接 dispatch 或经 AppModel 命令）且处理了加载/错误态；半成品 = 有 UI 但部分交互未接 FFI；空壳 = 无任何 FFI 调用。**

### 4.1 主导航页（9）

| # | 页面 | 文件 | FFI 触点（摘） | 完成度 |
|---|---|---|---|---|
| 1 | 首页 | `src/pages/home_page.dart`（581 行） | `model.toggle/seekMs`（:222,:258）、`loadPlaylists`（:377）、`playSongs`（经 SongCard）、navRequest 导航、push 播放页/歌单详情 | **完整** |
| 2 | 搜索 | `src/pages/search_page.dart`（182 行） | `FfiCommand.search`（300ms 防抖 :38-42）、`searchMore` 触底翻页（:68-80）、失败重试（:168-172） | **完整** |
| 3 | 曲库 | `src/pages/library_page.dart`（325 行） | `loadAccountFavorites`（:179）、`FfiCommand.historyClear`（:306）、推送收藏 dialog | **完整** |
| 4 | 在线歌单 | `src/pages/playlist_browse_page.dart`（541 行） | `loadPlaylistCategories/loadPlaylists/loadAccountPlaylists`、分页（:464-468）、同步 dialog | **完整** |
| 5 | 排行榜 | `src/pages/leaderboard_page.dart`（380 行） | `loadLeaderboardBoards/loadLeaderboardSongs`、`playSongs`（:259）、加载更多 | **完整** |
| 6 | 本地音乐 | `src/pages/local_music_page.dart`（331 行） | `scanLocal`（:267,:274）、file_picker 选目录 + 手输回退（:277-299）、`updateConfig`、`playSongs` | **完整** |
| 7 | 下载 | `src/pages/downloads_page.dart`（162 行） | `downloadCancel`（:135）、`downloadClearFinished`（:48）、`downloadEnqueue` 重试（:143） | **完整** |
| 8 | 设置 | `src/pages/settings_page.dart`（680 行） | `updateConfig` ×12（音量/播放模式/历史条数/默认音源/JS 源/启用源/下载目录/音质/并发/歌词/主题/动态取色/代理/超时）、`setTheme`、扫码登录/帮助入口 | **完整** |
| 9 | 帮助 | `src/pages/help_page.dart`（123 行） | 无（纯静态信息页，设计如此：功能地图 + 版本） | 完整（静态页，非空壳——无交互承诺） |

### 4.2 二级路由页（5）

| 页面 | 文件 | FFI 触点 | 完成度 |
|---|---|---|---|
| 歌单详情 | `src/pages/playlist_detail_page.dart`（267 行） | `loadPlaylistDetail/loadAccountPlaylistDetail` + 分页 + `playSongs` | **完整** |
| 歌手详情 | `src/pages/artist_detail_page.dart`（282 行） | `loadArtistSongs/loadArtistAlbums` + 分页 + `playSongs` | **完整** |
| 专辑曲目 | `src/pages/album_songs_page.dart`（164 行） | `loadAlbumSongs` + 分页 | **完整** |
| 自建歌单（section + 详情） | `src/pages/custom_playlists_page.dart`（456 行） | `createCustomPlaylist/rename/delete/addTo/removeFrom/loadCustomPlaylist/playSongs`、推送 dialog | **完整** |
| 扫码登录 | `src/pages/qr_login_page.dart`（151 行） | `FfiCommand.qrLoginStart/qrLoginCancel`（:37-39,:89）、base64 PNG 或 qr_flutter 本地渲染 | **完整** |

### 4.3 播放页（3）

| 页面 | 文件 | 状态 |
|---|---|---|
| MyunePlayerPage（现役全屏播放页） | `src/myune_shell/myune_player_page.dart` → vendored `myune/page/song_detail_page.dart`（821 行） | **完整**：消费 Provider 图 + 投影；空态有专门处理（:28-38）。首页 hero 与 Playbar 点击进入（`home_page.dart:176-180`、`voicefox_playbar.dart:163-167`） |
| PlayerPage（**遗留死代码**） | `src/pages/player_page.dart`（331 行） | 实现本身完整（toggle/seek/歌词点击跳转/4 快捷键），但 **lib/ 内零引用**（grep 全库仅 `test/player_page_test.dart` 引用）；被 MyunePlayerPage 取代 |
| _BootstrapScreen（引导骨架） | `main.dart:161-238` | 完整（窗口按钮可关窗、错误回显） |

### 4.4 壳级组件（4）

| 组件 | 文件 | 接线 |
|---|---|---|
| VoicefoxAppShell | `myune_shell/app_shell.dart:28` | CallbackShortcuts 4 键（Space/←/→/Esc，:176-188）+ NavigationRail |
| VoicefoxWindowTitleBar | `myune_shell/app_shell.dart:259-320` | 最小化（`minimizeToTray` 时 hide，:301-309）、关闭 |
| VoicefoxPlaybar | `myune_shell/voicefox_playbar.dart:21` | toggle/prev/next/seek（拖动会话 :241-270）、播放模式循环（:289-294）、音量悬停滑条（:352-383）、队列 Drawer |
| VoicefoxQueueDrawer | `myune_shell/voicefox_queue_drawer.dart:12` | 当前曲高亮、滑动/按钮移除（:99,:104）、清空带确认（:15-36） |

### 4.5 弹窗层（3）

| 弹窗 | 文件 | 接线 |
|---|---|---|
| SyncDialog（账号歌单同步） | `src/widgets/sync_dialog.dart`（360 行） | `startSyncPreview/startSyncRun/cancelSync/resetSync` 全相位 UI（preview/running/done/failed/cancelled） |
| PushDialog（本地→远端推送） | `src/widgets/push_dialog.dart`（307 行） | `startPushTargets/createPushTarget/previewPush/runPush/cancelPush`，追加 diff 预览 + 确认 |
| CustomPlaylistDialogs | `src/widgets/custom_playlist_dialogs.dart`（164 行） | 名称输入 + 「加入歌单」sheet，就地新建→等 id→立即加歌（:147-157） |

### 4.6 通用组件（7）

`SongTile`（播放/收藏/下载/入队/加歌单/下钻歌手专辑，`song_tile.dart:55-118`）、`SongCard`（点击播放，`song_card.dart:21`）、`LyricsView`（本地二分推导当前行 + 点击行 seek，`lyrics_view.dart:17-35,:147-150`）、`LivePlayback`（500ms 插值走带，`live_progress.dart:50-59`）、`BrowseSongsView`（统一加载/空/错误/翻页）、`CoverImage`、`EmptyState(+pageTitle)`。**全部接线，无空壳。**

### 4.7 完成度汇总

- **完整：30/31 个 UI 条目**（9 主导航 + 5 二级 + 现役播放页 + 4 壳级 + 3 弹窗 + 7 通用组件 + 骨架屏；帮助页为设计内静态页）。
- **空壳：0。** 主路径上不存在「有按钮无逻辑」的页面。
- **半成品：0**（按 FFI 判据）；但存在下述遗留/降级项。

## 5. 事件接线现状

- **FFI 调用点统计**：`grep -rn "FfiCommand\.|model.dispatch|_model.dispatch" lib/src/{pages,widgets,myune_shell,myune_seam}` = **22 处**；`grep -rn "model.toggle|next|previous|seekMs|playSong|playSongs|queueAdd|queueRemove|download|toggleFavorite|setVolume"` = **43 处**。另有大量 `loadXxx` 语义封装（AppModel 内 13 个 load* 方法，`app_model.dart:448-517,610-629`）。
- **空回调扫描**：`grep "onPressed: () {}|onTap: () {}|onPressed: null|onTap: null"` 命中 `lib/src/myune/page/setting/theme_selection_screen.dart:142,150` 两处 `onPressed: () {}` —— 该文件在**不可达死树**内（见 §6），现役代码零空回调。显式 `onPressed: null` 均为合法禁用态（如扫描中禁用刷新、空列表禁用播放全部）。
- **键盘事件**：GUI 侧全部快捷键 = Shell 层 4 键（`app_shell.dart:176-188`）+ 遗留 PlayerPage 内 4 键（`player_page.dart:36-46`）。无键位配置机制。
- **错误与反馈**：命令错误 → `lastError` → toast（`projection.dart:105-124`）；页面内错误态（搜索/榜单/歌单/账号歌单）都有重试按钮且重试接同一 FFI 命令。

## 6. vendored myune 树与 stub 包

### 6.1 可达性（grep 交叉引用核实）

- **可达（现役）**：`myune/page/song_detail_page.dart`（播放页）、`myune/page/playlist/playlist_content_notifier.dart`、`myune/page/setting/settings_provider.dart`、`myune/theme/*`、`myune/services/{notification_service,…}`、`myune/widgets/{custom_background_layer,toast_overlay,lyrics_widget,song_detail_page/*,…}`（经 song_detail_page 引用）、`myune_seam/{mpv_audio_kit_shim,app_model_audio_backend,cover_loader}`。
- **不可达（死树，仅内部互相引用，无 lib 现役入口）**：`myune/layout/{app_shell,main_view}.dart`（308 行）、`myune/page/pages/*`（all_songs/statistics/setting.dart 等 8 个薄壳，含 audio_analysis_page）、`myune/page/setting/setting_page.dart` 与全部 `setting/tabs/*`（general/personalization/hotkeys/advanced/playback_settings/custom_background 等）、`myune/page/{all_songs,song_list,statistics_page,song_details}`、`myune/lyrics/*`（除被死树引用外仅有 lyrics_handler 引 myune 桥）。唯一外部入口 `lib/myune_preview.dart` 是 dev 预览（`flutter run -t lib/myune_preview.dart`，只挂 MyunePlayerPage，不进这些页面）。

### 6.2 stub 包（pubspec dependency_overrides，`pubspec.yaml:39-44`）

| 包 | 位置 | 实况 |
|---|---|---|
| `hotkey_manager` | `packages/hotkey_manager/lib/hotkey_manager.dart` | 纯 Dart 空实现：`register/unregister/unregisterAll` 均为 `{}`。注释明说「全局热键是 P1，不引入 keybinder 原生钩子」。**后果**：vendored `global_hotkey_manager.dart` / settings_provider 的热键注册全部 no-op，GUI 无任何全局热键 |
| `system_fonts` | `packages/system_fonts/lib/system_fonts.dart` | `getFontMap() => {}`、`loadFont => null`。字体选择器退回内置字体列表 |

### 6.3 其他发现

- `myune_seam/app_model_audio_backend.dart:14-15` 类注释仍写「`setVolume` is a no-op: voicefox FFI has no volume command yet」，但实现已在 :178-181 接了 `model.setVolume` —— **过期注释**，应更新。
- `AppModelAudioBackend` 的 pcm/fft 可视化流为空流（:45-47），音效/变调/重放增益等 12 个 setter 均为显式 no-op（:184-228）——vendored 音频分析页因此不可用（该页本身也在死树中）。
- `README.md`（flutter/，583 字节）与 `KEYBINDINGS.md` 不在 flutter/ 内（见 §7）。

## 7. KEYBINDINGS.md 核对

- **存在**：`/home/emo/code/voicefox-gui/KEYBINDINGS.md`（259 行，仓库根目录）；`flutter/` 目录内**没有**键位文档。
- **内容**：标题「voicefox 0.8.0 快捷键完整参考」，开头自述对应「`voicefox-old` 旧版 TUI + 新功能整合线」——即这是 **TUI（终端版）的键位参考**（`1~8` 切页、`Ctrl+↑/↓` 音量、`?` 帮助、可配置 `[keybindings]` TOML 等），**不是 Flutter GUI 的键位文档**。
- **GUI 实况对照**：Flutter 侧仅实现 Space（播放/暂停）、←/→（±5s）、Esc（返回/pop）4 个全局键 + 播放页同 4 键；`help_page.dart:23` 也只列这 3 条（Space/←→/Esc）。TUI 文档中的 n/b/m/Ctrl+L/Ctrl+S/数字切页等均**未**在 GUI 实现，且 GUI 无键位自定义。

## 8. 验证记录

| 检查 | 命令 | 结果 |
|---|---|---|
| 静态分析 | `cd /home/emo/code/voicefox-gui/flutter && flutter analyze` | `No issues found! (ran in 2.8s)`（Flutter 3.47.9 stable） |
| 测试套件 | `cd /home/emo/code/voicefox-gui/flutter && flutter test` | **53 个测试全部通过**（15 个测试文件：页面冒烟、导航总线、同步/推送对话框、收藏/推送流、本地扫描、bridge codegen 版本冒烟） |
| 死树核实 | `grep -rln "myune/page/pages|myune/layout|setting/setting_page|song_list|all_songs|statistics_page|song_details" lib` | 无现役引用（仅死树内部互引） |
| 空回调扫描 | `grep -rn "onPressed: () {}\|onTap: () {}\|onPressed: null\|onTap: null" lib` | 仅死树 2 处 `onPressed: () {}`（theme_selection_screen.dart:142,150） |

说明：analyze/test 仅写 `.dart_tool`/`build` 缓存，未修改任何源文件，符合只读约束。

## 9. 结论与建议

**结论**：Flutter 前端不是骨架/演示品——9 个主导航页、5 个二级页、现役播放页、底栏/抽屉/三套对话框全部真实触达 FFI 并处理了加载/空/错误/重试态，事件泵与错误出口是统一收口的；`flutter analyze` 0 问题、53 测试全绿。状态管理是 Provider + ChangeNotifier 单快照架构（决策注释在案），无 Riverpod/Bloc。

**遗留项（按影响排序）**：
1. `src/pages/player_page.dart`（331 行）是 lib 内零引用的遗留实现，仅测试在保——建议删除或明确标注 deprecated，`useMyunePlayer` 常量（`myune_player_page.dart:10`）当前并无 false 分支，属文档性摆设。
2. vendored myune 死树约数千行（layout、page/pages、setting_page+tabs、song_list/statistics/all_songs、lyrics 处理器）无现役入口，其中 theme_selection_screen 还带着仅有的两处空回调——建议随下次 vendor 同步裁剪。
3. 全局热键（hotkey_manager stub）与系统字体枚举（system_fonts stub）是显式降级点，KEYBINDINGS.md 描述的键位能力 GUI 仅覆盖 4 键且不可配置——如 GUI 要对齐 TUI 键位，需先落原生热键通道与键位文档（GUI 侧现无 KEYBINDINGS）。
4. `app_model_audio_backend.dart:14-15` 过期注释（setVolume 已实现）建议修正。
