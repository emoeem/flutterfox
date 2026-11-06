# 桌面 UI 现状审计（UI_AUDIT_DESKTOP，2026-11-06）

- 计划依据：`flutterfox-ui-redesign-plan.md` v1.0（Phase 0：现状重审与基线冻结）
- 代码基线：`main @ 32b1f37`（与计划书检查基线一致，工作区仅新增本文档等审计文件）
- 构建与运行：`flutter build linux --release` 通过（Flutter 3.47.9 stable）；实机运行正常，
  首页/曲库真实数据加载成功（详见截图索引）
- 审计方式：实机截图 + 三份 2026-11-05 代码审计（`audit-flutter.md` / `audit-ffi.md` /
  `audit-rust.md` / `audit-gaps.md`）交叉核对，所有状态标注均回源码取证
- 结论口径：`已修复` / `仍存在` / `被架构替代` / `已修(待实机确认)` / `未验证`

---

## 1. 实机截图索引（`docs/shots/20261106/`）

> 由用户手动截图归档；占位清单如下，归档后填充文件名。

已归档（用户提供 + 自动化 1 张）：

| 文件 | 内容 |
|---|---|
| `20261106-m1-home-1440-dark.png` | 首页 1440（自动化） |
| `20261106-m1-home-500-dark-playing.png` | 首页 ~500px 窄窗，**播放中**（Hero：Hong Kong/The Weeknd，进度 0:00/0:00，暂停键可用） |
| `20261106-m1-playbar-playing-dark.png` | 全局播放栏播放中：**位置 00:21 / 总时长 00:00**（P0-A2 关键证据） |
| `20261106-m1-help-1904-dark.png` | 帮助页（快捷键/功能地图/自建歌单/关于 0.8.1） |
| `20261106-m1-settings-1904-dark.png` | 设置：播放器组（音量 95%/播放模式四态/历史条数）+ 音源组（默认源哔哩哔哩/8 源开关） |
| `20261106-m1-settings-theme-1904-dark.png` | 设置主题区：明暗三态、seed 16 卡 + flex 28 卡 = **44 套确认**、动态取色开关、网络组（代理/超时） |
| `20261106-m1-playlist-browse-1904-dark.png` | 在线歌单：11 音源 chips、推荐/我的歌单、分类 chips、真实封面网格、加载更多 |
| `20261106-m1-library-favorites-1904-dark.png` | 曲库收藏：四 tab 真实计数、本地/网易云/QQ 源分段、9 首仅 1 封面（P2-V3） |

未覆盖（接受缺口，后续批次补）：搜索页、排行榜详情、本地音乐、下载页、歌单详情、全屏播放页、
队列抽屉、浅色主题组、1280/1024 尺寸扫描。依赖这些页面的结论保持「待实机确认」。

实机已确认的行为（2026-11-06 00:00-00:04 自动化会话）：

- 应用启动正常，Rust 引导完成后进入主壳；首页加载「最近在听 / 热门歌单 / 排行榜入口」均为真实数据。
- 曲库「收藏 9 / 收藏歌单 0 / 历史 200 / 自建歌单 0」四 tab 真实计数；收藏源分段「本地/网易云/QQ」可用。
- 窗口标题栏仅一套（31px 自绘，最小化+关闭）；侧栏为图标轨（无文字标签）。
- 系统面板 MPRIS 小组件显示「暂无播放内容」，即应用无 MPRIS（见 P1-D4）。
- 运行日志有两处非致命告警：resize 时 OpenGL 帧超时（`Timed out waiting for OpenGL frame of size 948x1010`）、
  ATK `atk_socket_embed` 断言失败（无障碍桥）。

---

## 2. 旧审计（UI_AUDIT_2026-11-04）逐条状态

### 2.1 P0 阻断级（9 条）

| ID | 问题 | 状态 | 证据 |
|---|---|---|---|
| P0-01 | 播放器 watcher 无消费，进度/时长恒 0 | **部分修复(实机)** | position 已实时（播放栏 00:21 走动）；**duration 恒 0**（播放栏 00:21/00:00、Hero 0:00/0:00），Rust 泵已接（`service.rs:163-233`）Dart 已接（`app_model.dart:252`），断点在 engine duration watcher 或特定音源流；转 P0-A2 |
| P0-02 | Toggle 不写快照不发事件 | 已修复 | `application/src/service.rs` toggle 后经状态广播回环（audit-flutter §1 事件流核验） |
| P0-03 | `PlayerEvent::Ended` 无消费者 | 已修复 | `application/src/service.rs:240` 处理 Ended |
| P0-04 | 播放模式后端无消费者 | 已修复 | `service.rs:275,399,412` 按 `play_mode`（含 random）选择 next/previous |
| P0-05 | 无 SetVolume 通路 | 已修复 | `ffi/src/lib.rs:1201,1377` `SetVolume` 命令并映射；seam `:178` 接 `model.setVolume` |
| P0-06 | ConfigDto 往返损坏（config 膨胀 134MB） | 已修复(实测) | `~/.config/voicefox/config.toml` 现 9.6KB；`play_mode` 单行合法 token；无超长行 |
| P0-07 | 错误全部静默 | 已修复 | `app_model.dart:949-966` 命令异常写 lastError/lastNotification → `projection.dart:105-124` 泵入全局 Toast |
| P0-08 | 播放页无数据投影（封面黑块/歌词空/队列空） | 被架构替代(待实机确认) | `PlaylistContentNotifier` 为投影接收方（封面/歌词/队列）；seam `positionStream`（`app_model_audio_backend.dart:25-60`）驱动歌词推进 |
| P0-09 | seed 主题 alpha=0x00 页面透明 | 已修复 | `theme/seed_colors.dart:40-41` `hexOf = 0xFF000000 \| …`；实机页面底色为主题表面色非纯黑 |

### 2.2 P1 功能缺口（13 条）

| ID | 问题 | 状态 | 证据 |
|---|---|---|---|
| P1-01 | 设置仅 4 组 | 部分修复(实机) | 分组已有（播放器/音源/主题/网络等，实机截图确认），但仍为单列长页，非计划 §3.6 的左侧分类导航（Phase 3 重做） |
| P1-02 | 明暗三态缺失 | 已修复 | `theme_provider.dart:39-41,146-152` `ThemeMode.system` 默认 + light/dark/system 循环切换 |
| P1-03 | 搜索无音源筛选/无状态组件/末尾永久 spinner | 已修复 | `search_page.dart:25-51` 音源筛选（聚合+按启用源能力位）、防抖、重试；触底 searchMore 保留（但见新 P1-C3 丢 source 缺陷） |
| P1-04 | 队列无高亮/移除/清空确认 | 已修复 | `voicefox_queue_drawer.dart:43` 读 `state.queueIndex` 高亮；单曲移除；`:19-28` 清空带确认 |
| P1-05 | 缺「收藏歌单」tab | 已修复 | `library_page.dart:48` 收藏歌单 tab（实机可见四 tab） |
| P1-06 | 历史无时间分组、清空无确认 | 仍存在（分组） | `library_page.dart` 无日期分组逻辑；清空确认已有 |
| P1-07 | 下载缺暂停/重试/状态翻译 | 部分修复 | 状态已翻译（`downloads_page.dart:157-159`）、取消/重试/清除已完成已有；仍缺：暂停/继续、打开文件位置、下载历史、速度展示 |
| P1-08 | 扫码登录桌面不可达 | 已修复 | 设置页含扫码登录入口（audit-flutter §4.1-8） |
| P1-09 | 歌词位置不推进 | 被架构替代(待实机确认) | myune 投影链路：seam `positionStream` 由 AppModel progress 事件驱动（`app_model_audio_backend.dart:60`） |
| P1-10 | 本地音乐手输路径、无扫描状态 | 已修复 | `local_music_page.dart` file_picker 选目录 + 手输兜底 + 扫描状态/禁用态 |
| P1-11 | 事件流 lag 不重拉快照 | 已修复 | `app_model.dart` 退避 1s 重订阅并整份重拉快照 |
| P1-12 | 首页假统计卡 | 已修复 | `home_page.dart:3` 注释明确移除仪表盘；实机首页为音乐内容结构 |
| P1-13 | 桌面集成全缺（MPRIS/托盘/媒体键/通知/会话恢复） | 仍存在 | 归入 Phase 5 系统集成子任务（计划 §9.11 禁止提前混入）；Rust 侧能力已在 `app/src/mpris.rs` 等就绪（audit-gaps B13） |

### 2.3 UI/UX 偏差（U-01…U-19）

| ID | 状态 | 备注 |
|---|---|---|
| U-01 侧栏宽度/展开收起 | 仍存在 | 图标轨固定宽度，无文字展开态（图标有 Tooltip）；Phase 2 重做 Sidebar 时处理 |
| U-02 桌面入口数 | 已符合旧规格 | 现 9 入口；Phase 2 将收敛为 5（Home/Discover/Library/Downloads/Settings） |
| U-03/04 手机底栏/更多 | 未验证 | 本批仅桌面 |
| U-05 导航项 ≥48dp | 仍存在 | 实测 rail 项间距 ~44px |
| U-06 桌面水平边距 24 | 接近(待实机确认) | 实测约 20px |
| U-07 内容最大宽度 | 仍存在 | 首页横向 Shelf 右缘溢出窗口被裁切（实机可见） |
| U-08 详情封面 200dp | 待实机确认 | |
| U-09 行密度两档 | 仍存在 | 无密度设置 |
| U-10 规格化字号 | 部分修复 | 主题注入 TextTheme 有限，标题/正文层级未完全对齐 `flutter_ui_spec.md` |
| U-11 reduce-motion | 仍存在 | 全项目无 `disableAnimations` 处理 |
| U-12 无障碍 tooltip/对比度 | 部分修复 | rail 图标有 Tooltip；其余待走查（Phase 5） |
| U-13 页面标题统一 | 仍存在 | 首页自绘 Hero 标题、其余 pageTitle、队列抽屉各自实现（Phase 1 PageHeader 统一） |
| U-14 播放页双 chrome | 仍存在 | 播放页自带 myune `AppWindowTitleBar`（`song_detail_page.dart:405`）+ 内嵌播放栏；进入播放页=第二套壳（见 §4 重复清单） |
| U-15 sync dialog/收藏历史独立页 | 仍存在（低优） | 同步仍为 Dialog |
| U-16 主题数量 | 已确认(实机) | seed 16 卡 + flex 28 卡 = 44 套（`settings-theme` 截图）；超出计划「不扩充」基线，Phase 1 决定去留 |
| U-17 主题预览性能 | 已修复 | 设置页不再逐卡构建完整 ThemeData（`settings_page.dart:511` 仅一处 `buildVoicefoxTheme`） |
| U-18 主题乐观更新 | 待实机确认 | |
| U-19 帮助文案不实 | 部分修复(实机) | 快捷键/队列/搜索描述已属实；但功能地图仍写首页含「曲库统计、快捷开关」，与现首页（音乐内容结构）不符，属陈旧文案 |

---

## 3. 当前仍需处理的问题清单（重构前现状）

### P0（阻断级）

| ID | 问题 | 证据 | 影响 |
|---|---|---|---|
| P0-A1 | **myune 桥 `readAudioInfo` 悬空**：播放页/歌词兜底 7 处调用必然抛错（myune RustLib 从未 init、dylib 无符号导出） | audit-gaps ①-1（`playlist_content_notifier.dart:1041` 等 7 处；`nm -D` 实测 0 导出） | 本地文件元数据/歌词兜底路径触发即崩或报错，是现役最高风险链路 |
| P0-A2 | **播放中总时长恒 0**：播放栏 00:21/00:00、首页 Hero 0:00/0:00（实机截图），进度比例与 seek 目标时间不可算 | 实机 `playbar-playing-dark.png`；Rust 泵已接（`application/src/service.rs:163-233`）、Dart 已接（`app_model.dart:252`），断点在 engine duration watcher（`player/src/engine.rs:848`）或特定音源流无 duration | Phase 4 第一修复项；修复前 LivePlayback 插值与进度条比例失效 |

### P1（功能缺口，UI 可见）

| ID | 问题 | 证据 |
|---|---|---|
| P1-C1 | 播放页音效面板空转：变调/倍速/EQ/ReplayGain/响度/可视化滑杆只写 SharedPreferences，seam 全 no-op | audit-gaps ①-2（`app_model_audio_backend.dart:46-47,185-228`） |
| P1-C2 | 全局热键默认开启但 stub 注册永远 no-op | audit-gaps ①-3（`pubspec.yaml:39-44` overrides；`settings_provider.dart:118` 默认 true） |
| P1-C3 | 搜索「加载更多」丢音源过滤：FFI 层 `source: None` 硬编码，第 2 页起回落默认源 | audit-gaps ①-4（`ffi/src/lib.rs:1401-1405`） |
| P1-D1 | 下载页缺：暂停/继续、打开文件位置、下载历史、速度展示 | `downloads_page.dart`（162 行） |
| P1-D2 | 历史无日期分组 | `library_page.dart` |
| P1-D3 | 死树与遗留：`myune/layout`、`myune/page/pages/*`、`song_list` 等数千行无现役入口；`pages/player_page.dart` 331 行零引用 | audit-flutter §6.1、§4.3 |
| P1-D4 | 桌面系统集成缺失：MPRIS/SMTC/媒体键/托盘/系统通知/会话恢复（Rust 能力已备，未接 GUI） | audit-gaps B13/B10 |
| P1-D5 | 过期注释误导：`app_model_audio_backend.dart:14-15` 仍称 setVolume no-op（实已接通） | audit-gaps 附注 4 |

### P2（视觉/结构债，Phase 1-3 处理）

| ID | 问题 |
|---|---|
| P2-V1 | 侧栏为纯图标轨，无文字标签/展开收起（计划 §2.2 要求分组+展开态） |
| P2-V2 | 首页横向 Shelf 溢出右缘裁切、无内容最大宽度约束 |
| P2-V3 | 收藏歌曲封面大量缺失（实机 9 首仅 1 有封面，`cover_url` 未回填） |
| P2-V4 | TrackRow/MediaCard/EmptyState 等基础组件各自页面实现，无统一组件层（Phase 1 主题） |
| P2-V5 | reduce-motion 未处理；动效时长未走 Motion Tokens |
| P2-V6 | KEYBINDINGS.md 是 TUI 文档；GUI 仅 Space/←/→/Esc 4 键且无键位文档 |
| P2-V7 | 同步/推送为 Dialog 而非页面；设置分组未按计划 §3.6 的 8 组结构组织 |
| P2-V8 | 帮助页功能地图陈旧：仍描述首页含「曲库统计、快捷开关」（实机 `help-1904-dark.png`） |
| P2-V9 | ~500px 窄窗仍是桌面壳（图标轨 + 压缩内容，实机 `home-500-dark-playing.png`）；计划 §2.3 要求 <700dp 切 MobileShell（Phase 6） |

---

## 4. 重复实现清单（P0-C 对照表：保留 / 退出运行路径）

### 4.1 播放栏（3 套实现，2 套现役）

| 实现 | 位置 | 行数 | 可达性 | 处置建议 |
|---|---|---|---|---|
| VoicefoxPlaybar（全局底栏） | `myune_shell/voicefox_playbar.dart` | 391 | **现役**（Shell 底部唯一全局播放栏） | **保留**，Phase 4 改造为唯一 Global Player Bar |
| 播放页内嵌 Playbar（含 BalanceRateControl 音效滑杆） | `myune/widgets/song_detail_page/playbar.dart` | 未知 | **现役**（仅播放页内） | Phase 4 重做 NowPlayingView 时以自有控制区替换；音效滑杆在 P1-C1 接通前禁用或移除 |
| myune 独立 Playbar | `myune/widgets/playbar.dart` | 441 | 死树（仅 `myune/layout/app_shell.dart`、`song_list_detail_page.dart` 引用，均不可达） | 随 vendor 裁剪移除 |

### 4.2 队列（2 套实现，均现役，重构重点）

| 实现 | 位置 | 行数 | 可达性 | 处置建议 |
|---|---|---|---|---|
| VoicefoxQueueDrawer | `myune_shell/voicefox_queue_drawer.dart` | 115 | **现役**（Shell endDrawer，全局播放栏唤出） | **保留**为唯一 QueuePanel 基底（fork 自 myune 版，已带高亮/移除/清空确认） |
| myune PlayingQueueDrawer | `myune/widgets/playing_queue_drawer.dart` | 256 | **现役**（播放页 `song_detail_page.dart:393` endDrawer） | Phase 4 合并进唯一 QueuePanel 后退出播放页；上游文件冻结不修改 |

### 4.3 窗口标题栏（2 套实现，均现役）

| 实现 | 位置 | 可达性 | 处置建议 |
|---|---|---|---|
| VoicefoxWindowTitleBar | `myune_shell/app_shell.dart:259` | **现役**（主壳顶部，最小化+关闭） | **保留**，Phase 2 重做 AppHeader（补最大化/还原、返回前进、全局搜索入口） |
| myune AppWindowTitleBar | `myune/widgets/song_detail_page/app_window_title_bar.dart` | **现役**（播放页 `song_detail_page.dart:405`，带设置按钮） | Phase 4 播放页去 chrome 时移除引用；上游文件冻结 |

### 4.4 主题管线（2 套构建路径，1 套运行时）

| 实现 | 位置 | 可达性 | 处置建议 |
|---|---|---|---|
| ThemeProvider（运行时真源） | `myune/theme/theme_provider.dart`（314 行） | **现役**（MaterialApp theme/darkTheme/themeMode 唯一来源） | **保留**；Phase 1 收敛进 DesignSystem（token 化） |
| buildVoicefoxTheme（旧主题管线残余） | `theme/voicefox_theme.dart`（171 行） | 设置页 1 处（`settings_page.dart:511`）+ dev 预览 `myune_preview.dart` | Phase 1 迁移为纯 ThemePreview（token 采样），不再保留第二套 ThemeData 构建管线 |

---

## 5. 桌面结构设计确认稿（P0-B：进入 Phase 1/2 的基线）

以下确认计划书 §2 的目标结构为本轮重构基线，并标注与现状的差距：

1. **主导航 5 入口**：Home / Discover / Library / Downloads / Settings。
   现状 9 平级入口（首页/搜索/曲库/在线歌单/排行榜/本地音乐/下载/设置/帮助）；
   搜索+在线歌单+排行榜+歌手专辑探索并入 Discover；本地音乐并入 Library；帮助并入 Settings/关于；
   队列只经播放栏/播放页/快捷键唤出（现状已是 endDrawer，方向一致）。
2. **主窗口结构**：AppHeader（唯一）+ Sidebar（分组、可展开收起）+ MainContent + Context Panel（Overlay，默认不占位）
   + Global Player Bar（唯一，Shell 最底）。现状差距：无 AppHeader 概念（标题栏仅窗口按钮）、
   Sidebar 无展开态、播放页自带第二套标题栏/播放栏/队列（§4.2-4.3）。
3. **断点**：≥1440 展开侧栏 / 1200-1439 展开或窄侧栏 / 900-1199 图标轨 / 700-899 紧凑 / <700 MobileShell。
   禁止按 1150×620 固定画布缩放（现状 `main.dart:32` 默认 1150×720 仅为窗口初值，页面本身响应式，符合方向）。
4. **播放器结构**：NowPlaying 左封面+控制 / 右歌词，窄窗上下或 Tab；队列右侧面板；
   进入播放页时全局播放栏隐藏或精简，不得出现第二套窗口标题栏与队列实现。
5. **真源约束**：播放状态唯一真源 AppModel 快照（现状已满足：单控制器广播→单快照→Provider 投影），
   系统媒体会话（Phase 5/7）只从该快照投影。

---

## 6. 复现步骤

```bash
cd ~/code/voicefox-gui/flutter
flutter build linux --release
./build/linux/x64/release/bundle/voicefox_flutter

# P0-06 配置损坏回归检查
ls -lh ~/.config/voicefox/config.toml          # 期望 KB 级
awk 'length($0)>1000 {print NR, length($0)}' ~/.config/voicefox/config.toml  # 期望无输出

# P0-A1 悬空桥（播放本地文件/歌词兜底时触发）
grep -rn "readAudioInfo" flutter/lib --include=*.dart | grep -v src/rust
nm -D target/release/libvoicefox_ffi.so | grep -ci audio_info   # = 0
```

---

## 7. 遗留与下一步

- 待用户实机截图归档后：回填 §1 截图索引，并把 §2 中 `待实机确认` 项改为终态。
- Phase 0 交付齐备后进入 Phase 1（Design System：Tokens + 统一组件 + 组件画廊），第一批按计划 §10 P0-D 执行。
- 禁止在 Phase 1 混入：播放页重做（Phase 4）、导航收敛（Phase 2）、系统集成（Phase 5）、移动端（Phase 6/7）。
