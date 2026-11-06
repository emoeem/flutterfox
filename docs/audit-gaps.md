# 对接缺口清单（audit-gaps）

- 日期：2026-11-05
- 方法：交叉分析 `docs/audit-flutter.md` / `docs/audit-ffi.md` / `docs/audit-rust.md`，并对每一条回源码抽查（命令与结论见 §4 验证记录）。只读，未修改任何源文件。
- 口径：
  - **清单①「UI 写了但功能没接上」**：UI 侧存在可达的交互/调用路径，但背后的功能链路断裂（调用了不存在的实现、seam no-op、FFI 映射收窄）。每条标注 UI 文件、应接通的 FFI 方法、缺失原因。
  - **清单②「Rust 有能力但 UI 完全没用」**：Rust 侧已实现、GUI 完全未触达的能力。分 A（FFI 已暴露、Dart 零调用）与 B（FFI 从未暴露）两组，每条标注 Rust 位置与建议的 FFI 暴露方法。
- 宁缺毋滥：死树专用、纯预留、仅注释性问题一律放 §3 附注，不计入条数。

---

## 1. 清单①：UI 写了但功能没接上（4 条）

### ①-1 vendored myune 本地元数据读取悬空：`readAudioInfo` 7 处调用点必然失败

- **UI 文件**（全部在现役路径，`playlist_content_notifier` 是投影接收方）：
  - `flutter/lib/src/myune/page/playlist/playlist_content_notifier.dart:1041, 1100, 1138, 1363, 1526, 4410`
  - `flutter/lib/src/myune/lyrics/lyrics_handler.dart:296`
  - import 证据：`playlist_content_notifier.dart:30` → `import '../../src/rust/api/audio_info.dart';`（myune 桥，期望 dylib `rust_lib_myune_music`）
- **应调用的 FFI 方法**：myune 桥 `readAudioInfo(path, options)`（`flutter/lib/src/myune/src/rust/api/audio_info.dart:16`）
- **缺失原因**（本次实测）：
  1. myune 桥的 `RustLib.init()` 全库零调用——`grep -rn "RustLib.init" flutter/lib` 仅命中 `app_model.dart:127,134`，均为 voicefox 主桥；
  2. 本仓库构建的 `libvoicefox_ffi.so` 无 audio_info 导出：`nm -D target/release/libvoicefox_ffi.so | grep -ci audio_info` = **0**；全表唯一命中是 `lx_player::engine::MpvEngine::PlayerBackend::audio_info_watcher`（本地 `t` 符号，非 FRB 导出）；`ffi/src` 源码 0 处引用 audio_info。
- **后果**：播放页/歌词链路一旦执行到这些调用点（本地文件元数据、歌词兜底读取），即抛桥未初始化/符号缺失错误。这是三份审计共同指出的最高实际故障风险点（audit-ffi §6 发现 5），本次逐点核实成立。

### ①-2 现役播放页音效面板全部空转：变调 / 倍速 / 均衡器 / ReplayGain / 响度 / 可视化

- **UI 文件**：
  - `flutter/lib/src/myune/page/song_detail_page.dart:18`（现役播放页引入 `widgets/song_detail_page/playbar.dart`）、`myune/widgets/song_detail_page/playbar.dart:255` 与 `myune/widgets/playbar.dart:401`：`BalanceRateControl`（变调/倍速滑杆）；
  - `flutter/lib/src/myune/page/playlist/playlist_content_notifier.dart:623-624`（每次恢复 `setPitch/setRate`）、`:681` 起的 `_updateLoudnessSubscription`（`setVolumeGain/setReplayGain`）、`_applyEqualizer`；
  - `flutter/lib/src/myune/services/audio/audio_service.dart:215-233`：`applyEqualizer` 组装 lavfi 滤镜串后调 `_player.updateAudioEffects`。
- **应接通的 seam 方法**：`AudioBackend` → `AppModelAudioBackend.setPitch / setRate / setReplayGain / setVolumeGain / updateAudioEffects / setSpectrum / pcmStream / fftStream` —— 全部为空实现或空流（`flutter/lib/src/myune_seam/app_model_audio_backend.dart:46-47` pcm/fft `Stream.empty()`，`:185-228` 系列 `async {}`）。
- **缺失原因**：voicefox FFI 的 55 个 `FfiCommand` 变体（`ffi/src/lib.rs:1194-1367`）中没有任何音频增强命令（ffi 源码 grep equalizer/replaygain/balance/ab_loop/audio_device 全部 0 命中）——而 Rust 引擎**已实现**：`player/src/engine.rs:36`（EQ 滤镜 `@voicefox-eq`）、`:155-163`（replaygain / -preamp / -clip 三属性）、`core/src/traits/player.rs:158-243`（完整扩展控制面）。
- **后果**：用户调滑杆/均衡器只写入 SharedPreferences（`playlist_content_notifier.dart` `_saveAudioControlSettings` 持久化 pitch/rate/eq/效果开关），声音无任何变化。倍速也到不了 `ConfigDto.playback_speed`：`flutter/lib/src/config_ext.dart:34` 该字段未参数化（copyWith 恒传原值），`settings_page.dart` 无该控件——`ConfigDto.playback_speed`（`ffi/src/lib.rs:150`）成了 GUI 永不写入的字段。与 ②-B1 是同一缺口的两侧。

### ①-3 全局热键默认开启、注册永远 no-op

- **UI 文件**：`flutter/lib/src/myune/page/playlist/playlist_content_notifier.dart:392`（可达初始化路径上 `GlobalHotkeyManager().init(this, _settingsProvider)`）；`flutter/lib/src/myune/services/global_hotkey_manager.dart:39-88`（`registerAll` → `hotKeyManager.register(...)`，含播放/暂停、上下曲、音量加减五组）。
- **应调用的 FFI/插件方法**：`package:hotkey_manager` 的 `register/unregister/unregisterAll`。
- **缺失原因**：该包被 `dependency_overrides` 指到本地 stub（`flutter/pubspec.yaml:39-44`）：`flutter/packages/hotkey_manager/lib/hotkey_manager.dart` 的三个方法均为空实现，注释自述「全局热键是 P1，不引入 keybinder 原生钩子」。而 `settings_provider.dart:118` 默认 `_enableGlobalHotkeys = true`（`:312` 从 prefs 载入默认仍 true）——即**默认配置下注册路径每次启动都执行、每次都无效**；`settings_provider.dart:21-25` 持久化的键位偏好永远不生效。GUI 实际可用快捷键只剩 shell 层 4 键（`app_shell.dart:176-188`）。

### ①-4 搜索「加载更多」丢失音源过滤（FFI 映射收窄）

- **UI 文件**：`flutter/lib/src/pages/search_page.dart:75` —— 触底翻页 `widget.model.dispatch(bridge.FfiCommand.searchMore(...))`（Dart 工厂只有 keyword/page 两参，`bridge/lib.dart:312`）。
- **应调用的 FFI 方法**：`FfiCommand.searchMore` 应携带可选 `source` 并透传。
- **缺失原因**：映射层硬编码丢弃——`ffi/src/lib.rs:1401-1405` 将 `source: None` 写死；而下层 `ApplicationCommand::SearchMore` 本身支持指定源（`application/src/event.rs:14-18`），`FfiCommand::Search`（首页搜索）也支持。一行映射 + 一个可选参数即可修复。
- **后果**：用户选定音源搜索后，第 2 页起回落默认源，结果列表语义漂移（前 1 页与后续页来源不一致）。

---

## 2. 清单②：Rust 有能力但 UI 完全没用（19 条）

### 2.A FFI 已暴露、Dart 全库零调用（4 条）

调用点判定：`grep -rn "FfiCommand\.<v>("` 在 `flutter/lib` + `flutter/test` 仅命中生成物（`bridge/lib.dart`、`lib.freezed.dart`），无任何业务代码调用（本次复核）。

| # | 能力（Rust 位置） | 建议接线 |
|---|---|---|
| A1 | **收藏/取消收藏远端歌单** `FavoritePlaylistAdd/Remove`（`ffi/src/lib.rs:1234, :1237`） | 无需改 FFI。在歌单详情页（`src/pages/playlist_detail_page.dart`）或在线歌单列表加「收藏歌单」动作 → AppModel 封装 dispatch；数据面经 `state` 库快照回读 |
| A2 | **单曲历史删除** `HistoryRemove{song}`（`ffi/src/lib.rs:1240`） | UI 目前只有整表清空（`library_page.dart:306` `HistoryClear`）。曲库历史列表 `SongTile` 菜单加「从历史移除」 |
| A3 | **精确暂停/恢复** `Pause/Resume`（`ffi/src/lib.rs:1195-1196`） | 与 toggle 语义重叠故未用；更实际的用法：`myune_seam/app_model_audio_backend.dart:170-176` 现在用「读 state 再 toggle」模拟 pause/play，可直接改派 `FfiCommand.pause()/resume()`，消除竞态 |
| A4 | **移动端引导** `setDataDir`（`ffi/src/api.rs:70`）+ `AppModel.attach`（`app_model.dart:133-137`） | 零调用方，Android 宿主预留面。维持预留即可，非 GUI 缺陷 |

### 2.B Rust 已实现、FFI 从未暴露（15 条）

FFI 判定均经本次复核：`grep -c "logout|parse_link|health_check|export_data|import_data|JsSource|SleepTimer" ffi/src/lib.rs` = 0。

| # | 能力（Rust 位置） | 建议的 FFI 暴露方法 |
|---|---|---|
| B1 | **播放器音频增强全套**：EQ 滤镜（`player/src/engine.rs:36` `@voicefox-eq`）、ReplayGain（`engine.rs:155-163`）、倍速/平衡/AB 循环/输出设备/fade（`core/src/traits/player.rs:158-243`） | `FfiCommand` 新增 `SetPlaybackSpeed{f64}`、`SetEqBands{Vec<(u32,f64)>}`、`SetReplayGain{mode,preamp,clip}`、`SetBalance{f64}`、`SetAbLoop{Option<(u64,u64)>}`、`SetAudioDevice{String}`，并把 ①-2 的 seam no-op 逐个接上——这是 GUI 播放页音效面板的唯一通路 |
| B2 | **登录态管理** `is_logged_in`/`logout`（`source/src/manager.rs:695, :702`；`is_vip_account` 同族） | `FfiCommand::Logout{source}` + `SourceCapabilitiesDto`（`ffi/src/lib.rs:419`）增 `logged_in/vip` 字段；GUI 在扫码登录页（`qr_login_page.dart`）与设置页加「退出登录/登录态」。TUI 已有对应动作（`core/src/events.rs:146` `QrLogout`） |
| B3 | **JS 音源导入/卸载**：`source/src/js/loader.rs:356`（代次令牌式安装/缓存判断）、`source/src/manager.rs:153-284`（注册族） | `FfiCommand::JsSourceImport{path}`（读文件→校验→安装→事件）、`JsSourceRemove{id}`。GUI 设置页现在只能开关内置源（`settings_page.dart` 的 enabled_sources/js_sources_first），无法导入新 JS 源；TUI 有 `ImportSource`（`core/src/events.rs:118`） |
| B4 | **链接直解** `parse_link`（`source/src/manager.rs:320`，单曲/歌单/专辑链接→内容） | `FfiCommand::ParseLink{link}` → 结果事件/返回 DTO；GUI 加「粘贴链接播放/导入」入口 |
| B5 | **音源健康检查** `health_check`（`source/src/manager.rs:352` → `Vec<SourceHealth>`） | `FfiCommand::CheckSourceHealth` + 健康度入 `SourceCapabilitiesDto` 或独立事件；GUI 设置页「启用源」列表显示各源健康状态。TUI 有 `CheckSourceHealth`（`core/src/events.rs:127`） |
| B6 | **歌单关键词搜索** `search_playlists`（`source/src/manager.rs:710`；trait 默认实现 `core/src/traits/source.rs:148`） | `FfiCommand::PlaylistSearch{source,keyword,page}`；GUI 在线歌单页（`playlist_browse_page.dart`）加搜索框 |
| B7 | **本地曲库管理**：`remove_by_path`（`source/src/local/mod.rs:359`）、`edit_metadata`（`:424`）、诊断三件套 `corrupt_files/missing_songs/duplicate_groups`（`:468/:473/:497`）、文件监视 `start_watcher`（`:528`） | `FfiCommand::LocalEditMetadata{path,edit}`、`LocalRemoveSong{path}`、`LocalDiagnostics` + 事件。GUI 本地音乐页只有扫描+播放（`local_music_page.dart:267,274`）；TUI 有本地诊断页 |
| B8 | **歌词逐字数据**：`YrcLine/YrcWord`（`core/src/model/lyric.rs:32, :39`，word 级时间轴） | `LyricLineDto`（`ffi/src/lib.rs:296-300`，现仅 text+时间戳+时长）增 `words: Option<Vec<LyricWordDto>>`；GUI 播放页可做逐字卡拉OK（vendored 歌词组件有渲染基础） |
| B9 | **数据导出/导入/外部歌单导入**：`export_data/import_data/export_custom_playlist/import_external_playlist`（`runtime/src/storage.rs:228, :248, :276, :311`；支持 M3U/LX Music/网易云） | `FfiCommand::ExportData{path}`、`ImportData{path}`、`ImportPlaylist{path}` + 报告事件。现仅 TUI CLI 可用（`app/src/cli.rs:17-44`）；GUI 设置页加导入导出（`file_picker` 已在依赖中，`local_music_page.dart:277` 已在用） |
| B10 | **播放会话恢复** `RestorePlayback`（`application/src/event.rs:46`；`ApplicationCommand` 61 变体中 6 个未映射进 `FfiCommand`，此为 GUI 价值最高者） | `FfiCommand::RestorePlayback` + `bootstrapDesktop` 成功后调用；GUI 当前每次启动队列为空、无「继续上次播放」 |
| B11 | **下载历史与已下载复用**：`DownloadRecords`（`download/src/records.rs:109`；`recent :192`、`clear :207`）、`existing_download`（`download/src/manager.rs:287`）、`progress_summary`（`:331`） | `FfiCommand::DownloadHistory{limit}`、`DownloadRecordsClear` + 事件/状态；GUI 下载页（`downloads_page.dart`）加「历史」页签，重试入队前可先查 `existing_download` 避免重复下载 |
| B12 | **镜像缓存维护**：`cache_file_size`（`application/src/remote_cache.rs:79`）、`clear`（`:95`）、`summary_counts`（`:221`） | `FfiCommand::RemoteCacheClear`（可附带 size 入 `VoicefoxState`）；GUI 设置页加「清理缓存」 |
| B13 | **平台媒体会话 + 桌面通知**：统一层 `media_session`（`app/src/media_session.rs:37`）、Linux MPRIS（`app/src/mpris.rs`）、Windows SMTC（`app/src/smtc.rs:21`）、`DesktopNotifier`（`app/src/notification.rs:16-30`） | 先把 media_session/通知逻辑从 TUI 二进制下沉到 runtime/application，再经 FFI 开关启用（对应 Config 集成字段也未镜像，见 B15）；GUI 桌面版同样需要系统媒体控件与通知 |
| B14 | **睡眠定时器** `SleepTimerState`（`app/src/sleep_timer.rs:39-119`，arm/cancel/poll） | 下沉至 application 后 `FfiCommand::SleepTimerArm{minutes}/SleepTimerCancel` + 到期事件；GUI 播放页/播放栏加定时入口 |
| B15 | **ConfigDto 未镜像配置面**：键位/UI/通知/集成（MPRIS/SMTC/ListenBrainz）/WebDAV/源策略（auto-prefer-only）在 `core/src/model/config.rs:642-837` 有完整定义，`ConfigDto` 只镜像 v1 设置页字段（`ffi/src/lib.rs:142-143` 注释自述未镜像字段「原样保留」） | 按需扩镜像或开专用命令；对 GUI 直接有用的是**源策略**（换源行为设置）与**集成开关**；WebDAV 同步实现（`download/src/webdav.rs:104`）同样被挡在此之外 |

---

## 3. 附注（不计入条数）

1. **system_fonts stub 只影响死树**：`FontSelectorRow`（`myune/widgets/font_selector_row.dart:26`）唯一调用方是 `myune/page/setting/tabs/personalization_tab.dart:63`（死树）；`theme_provider.dart:229 loadCurrentFont` 无现役调用方。现役 GUI 本就无字体选择入口，故不列为缺口。
2. **12 个 `command_*` 构造助手是死代码**（`ffi/src/api.rs:11-46`）：Dart 全部直接构造 `FfiCommand`，助手零引用（audit-ffi §2 复核成立）。
3. **遗留播放页**：`flutter/lib/src/pages/player_page.dart` lib 内零引用，仅测试在保（audit-flutter §4.3）。
4. **过期注释**：`myune_seam/app_model_audio_backend.dart:14-15` 仍写「setVolume is a no-op: voicefox FFI has no volume command yet」，与同文件 `:178-181` 已接 `model.setVolume` 的实现矛盾。
5. **KEYBINDINGS.md 是 TUI 文档**（仓库根，259 行）：GUI 仅 Space/←/→/Esc 4 键且不可配置；键位系统能力（`core/src/keybinding/mod.rs`）与 B15 键位镜像缺失相关。
6. 其余 TUI 专属能力（ListenBrainz 上报 `app/src/listenbrainz.rs:24`、频谱可视化 `app/src/visualizer/`、实例锁 `app/src/instance_lock.rs:20`、封面本地缓存 `runtime/src/cover.rs:20-107`）对 GUI 价值较低或属进程管理，未单列，需要时按 audit-rust §汇总扩展。
7. `writeReplayGainTags`（myune 桥 `api/audio_info.dart:24`）零引用且与 ①-1 同属悬空桥——并入 ①-1 计，不单列。

## 4. 验证记录（本次实际执行的抽查）

| 检查 | 命令（节选） | 结果 |
|---|---|---|
| readAudioInfo 调用点 | `grep -rn "readAudioInfo" flutter/lib --include="*.dart"`（排除生成物） | 7 处：playlist_content_notifier ×6 + lyrics_handler ×1 |
| myune 桥初始化 | `grep -rn "RustLib.init" flutter/lib` | 仅 `app_model.dart:127,134`（voicefox 桥） |
| dylib 符号 | `nm -D target/release/libvoicefox_ffi.so \| grep -ci audio_info`；`nm … \| grep -i audio_info` | dynsym **0**；全表唯一命中 `MpvEngine::audio_info_watcher`（本地 t 符号） |
| seam no-op | `sed -n '150,230p' flutter/lib/src/myune_seam/app_model_audio_backend.dart` | setVolumeGain/setPitch/setRate/setReplayGain/setAudioDevice/updateAudioEffects/setSpectrum… 全部 `async {}`；pcm/fft `Stream.empty()`（:46-47） |
| 音效 UI 链路 | `grep -rn "BalanceRateControl"`；`sed -n '610,700p' playlist_content_notifier.dart`；`sed -n '215,240p' audio_service.dart` | 现役播放页 playbar.dart:255 挂滑杆；notifier 每曲恢复 setPitch/setRate；applyEqualizer→updateAudioEffects |
| 全局热键 | `sed -n '1,80p' global_hotkey_manager.dart`；`grep -n enableGlobalHotkeys settings_provider.dart` | :392 可达 init；stub register 空实现；默认 `_enableGlobalHotkeys = true`（:118、:312） |
| 未引用命令变体 | `grep -rn "favoritePlaylistAdd\|historyRemove\|FfiCommand.pause()\|FfiCommand.resume()" flutter/lib flutter/test` | 仅 bridge/lib.dart + lib.freezed.dart（生成物），零业务调用 |
| SearchMore 收窄 | `sed -n '1395,1410p' ffi/src/lib.rs`；`grep -rn searchMore flutter/lib` | :1401-1405 `source: None` 硬编码；唯一调用点 search_page.dart:75 |
| Rust 能力行号 | grep manager.rs（parse_link :320 / health_check :352 / is_logged_in :695 / logout :702 / search_playlists :710）、local/mod.rs（remove_by_path :359 / edit_metadata :424 / :468-528）、storage.rs（:228/:248/:276/:311）、remote_cache.rs（:79/:95/:221）、records.rs（:109/:192/:207）、download/manager.rs（:287/:331）、engine.rs（:36/:155-163）、lyric.rs（:32/:39）、application/event.rs（:23-58 未映射变体） | 全部与 audit-rust 标注一致 |
| FFI 无这些命令 | `grep -c "logout\|parse_link\|health_check\|export_data\|import_data\|JsSource\|SleepTimer" ffi/src/lib.rs` | **0** |
| playback_speed 无人写 | `grep -n playback_speed ffi/src/lib.rs`；`sed -n '20,50p' config_ext.dart`；grep settings_page.dart | ConfigDto :150 有字段；config_ext.dart:34 未参数化；settings_page 无控件 |

## 5. 计数

- 清单①（UI 写了但没接上）：**4 条**
- 清单②（Rust 有能力但 UI 未用）：**19 条**（A 组 FFI 已暴露零调用 4 条 + B 组 FFI 未暴露 15 条）
- 附注（不计入）：7 条
