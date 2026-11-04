# voicefox Flutter UI 规范 v3(2026-11-04 · myune 基底实装)

> 变更:v3 以 **myune_music 的设计语言**为视觉基准(用户决策「换新视觉方向」),
> v2 的 FlClash 视觉基准归档(见 §11)。页面级规格(§9)与无障碍底线(§10)
> 延续 v2,按 v3 词汇更新。

## 0. 基底声明(v3)

- UI 基底:vendored **myune_music**(Apache-2.0,冻结于 `flutter/lib/src/myune/`,
  上游 commit 5188867b)。定制一律 fork 到 `flutter/lib/src/myune_shell/`,
  冻结树只允许既有 import 行白名单级别的改动。
- 数据层:voicefox `AppModel`(ChangeNotifier)+ FFI 命令/事件/快照三件套,
  经 `myune_shell/projection.dart` 常驻投影进 myune Provider 图
  (app 级单实例,由 `MyuneHost` 在 Rust 引导完成后挂载)。
- **单一 ThemeData 产源**:`myune/theme/theme_provider.dart`(M3 `ColorScheme.fromSeed`
  + 统一 w400 文字主题 + 桌面鼠标光标修正)。voicefox 侧 `voicefox_theme.dart`
  的 flex/FlClash 管线仅供设置页主题卡预览使用,不再喂 MaterialApp。

## 1. 视觉基调

- **Material 3 seed 配色**:全部界面色来自 `ColorScheme.fromSeed(seedColor)`,
  明暗各一份;组件默认 M3 形制(圆角随 M3 token,不自绘零阴影卡)。
- **封面取色动态 seed**(播放页):colorgram 提取 6 色 → HSL clamp
  (暗色 L 0.08–0.18 / S 0.18–0.35)→ 4 色喂 `mesh_gradient` 10s 往复动画
  (`song_detail_page.dart` 的 `BackgroundBlurWidget`);无封面回退 surface 纯色。
- **自定义背景层**(可选):`custom_background_layer.dart` 的图片+毛玻璃+
  遮罩;rail/面板透明度由 SettingsProvider 提供(`CustomBackgroundSurfaces`)。
- **滚动质感**:列表用 `silky_scroll`(时长 `theme/scroll_config.dart` 680ms
  emphasizedDecelerate)+ 像素吸附 `utils/pixel_snap.dart`。

## 2. Token 表(从 myune 实装提取,voicefox 侧新增组件一律引用)

| Token | 值 | 来源 |
|---|---|---|
| 窗口标题栏高 | 31dp | AppWindowTitleBar |
| 底部 Playbar 高 | 70dp | widgets/playbar.dart |
| 页面缩放基准 | 1150×620,`scale = min(w/1150, h/620)` | song_detail_page |
| 导航 rail | NavigationRail M3 默认(≈80dp,无扩展态) | layout/main_view |
| 队列抽屉宽 | 400dp | playing_queue_drawer |
| 列表行高 | `songTileExtentOf(context)`(随缩放) | playlist_content_widget |
| 页面切换动效 | 150ms easeInOut FadeTransition | main_view Navigator |
| 滚动动效 | 680ms emphasizedDecelerate | scroll_config |
| 封面圆角 | 8dp(网格)/12dp(CoverImage.expand) | widgets |
| 主题卡尺寸 | 108dp 宽,上 26 bg + 下 26 accent 双色块 | settings_page |
| Toast | 右下角浮层,info/error 两级,合并计数 | notification_service |

## 3. 导航结构

- **桌面(主形态)**:左 NavigationRail 九入口——首页/搜索/曲库/在线歌单/
  排行榜/本地音乐/下载/设置/帮助;页间 150ms 淡入切换
  (`myune_shell/app_shell.dart`,fork 自上游 MainView)。
- **播放队列 = 全局 endDrawer**(`VoicefoxQueueDrawer`,fork 自上游抽屉):
  当前曲高亮、单曲移除(滑动/按钮)、清空确认;Playbar 的队列按钮唤出。
- **底部 Playbar 常驻**(上游 `widgets/playbar.dart`):封面+标题+传输控制+
  进度条,点击推全屏播放页(`SongDetailPage`)。
- **自绘窗口标题栏**:31dp,`window_manager` 隐藏 OS 标题栏
  (`TitleBarStyle.hidden`);最小化到托盘跟随 SettingsProvider.minimizeToTray。
- **全局快捷键**:空格=播放/暂停、←/→=±5s、Esc=返回(与 TUI 一致)。

## 4. 主题体系(铁律:与 TUI 同源不分叉)

- 16 套命名 seed:唯一来源 `app/examples/theme_dump.rs` →
  `flutter/lib/src/theme/seed_colors.dart`;`hexOf` 强制不透明 alpha。
- 管线:ConfigDto(`theme`/`dynamic_color`/`theme_mode`)→ AppModel →
  `MyuneProjection` 桥接 → ThemeProvider.setSeedColor / setThemeMode →
  MaterialApp(theme/darkTheme/themeMode)。ThemeProvider 的
  SharedPreferences 持久化是无害回声,真源是 Rust 配置。
- **明暗三态**:`system`/`light`/`dark`,Rust `ThemeConfig.mode`(v3 新增)。
- **Material You 动态取色**:开关开时 main.dart 的 `DynamicColorBuilder`
  把系统调色板 primary 喂给 ThemeProvider(优先于手动 seed)。
- 主题矩阵:设置页 = 16 同源 + FlClash 紫 + 27 flex 内置扩展(44 套)。
- 设置页主题预览卡**不得在 build 内构造整套 ThemeData 超过每卡一次**
  (v2 审计 U-17 的教训)。

## 5. 组件词汇

- 播放页:`SongDetailPage`(横竖双布局,队列抽屉+歌词设置抽屉内建)。
- 歌词:`LyricsView` 弹性滚动 + `KaraokeLineText` 逐字;逐字数据缺失时降级逐行高亮。
- 列表行:voicefox `SongTile`(收藏心形/下载/右键菜单)+ myune
  `SongTileWidget`(队列抽屉内)。
- 空态/错误态:voicefox `EmptyState`(icon/title/subtitle/action),全站统一。
- 错误提示:统一走 `NotificationService` toast(右下角),AppModel 的
  `lastError`/`lastNotification` 由 `MyuneProjection` 泵入;不再用 SnackBar。
- 表单:设置页行内 Slider/DropdownButton/SwitchListTile;文本行提交才落配置。

## 6. 动效

- 页面切换 150ms easeInOut(上游 MainView 同款)。
- 播放页推入:淡入 + 0.92→1 缩放(300/240ms,easeOutCubic/easeInCubic)。
- mesh 渐变 10s 往复;封面 fadeIn;尊重 `MediaQuery.disableAnimations`。
- 进度广播 4Hz(Rust PROGRESS_INTERVAL 250ms),UI 侧 `LivePlayback` 插值补帧。

## 7. 语义色映射(延续 v2)

- 播放状态:播放中=primary、暂停=secondary、缓冲=tertiary、错误=error。
- 音质标签:标准=outline、320k=primaryContainer、FLAC=primary、24bit=tertiaryContainer。
- 下载状态:排队/进行=primary、完成=绿、跳过=outline、取消/失败=error;失败行有重试。
- 状态色只用语义 token,禁止页面内硬编码 hex。

## 8. 字体与字号

- myune 管线:`ThemeProvider.misansTextTheme` 全局 w400 + 用户自选字体
  (font_service);voicefox 打包 JetBrainsMono 用于数字(时间/计数)。
- 页头 titleLarge(22)、列表标题 titleMedium(16)、正文 bodyMedium(14)、
  辅助 bodySmall(12 onSurfaceVariant)、歌词全屏 displaySmall(32)。
- 长文本行宽上限 640dp。

## 9. 页面级规格(v3 词汇)

| 页面 | 实现 | 关键控件 |
|---|---|---|
| 播放页 | myune `SongDetailPage`(全屏) | 封面取色 mesh 背景、歌词、队列抽屉、音量/音效控件 |
| 队列 | 全局 endDrawer `VoicefoxQueueDrawer` | 当前高亮、滑动移除、清空确认、定位播放中 |
| 首页 | `home_page.dart` 仪表盘 8 卡 | hero 播放、模式、曲库统计、快捷开关、下载进度、热门歌单、排行榜入口、最近在听 |
| search | 搜索框+聚合/音源 FilterChip 行+结果列表 | 防抖 300ms、触底 SearchMore、空/错/载三态 |
| 曲库 | 4 tab:收藏(本地/账号镜像)/收藏歌单/历史/自建歌单 | 封面网格、推送收藏、历史清空确认 |
| 在线歌单 | `playlist_browse_page.dart` 三级 chips+网格 | 音源/范围/分类,账号镜像+同步对话框 |
| 排行榜 | 音源 chips+榜单 chips+榜内曲目 | 自动选首榜 |
| 本地音乐 | 目录卡+歌曲列表 | file_picker 选目录(手输兜底)、扫描警告横幅 |
| 下载 | 任务卡网格(活跃/完成) | 取消/重试(重新入队)、状态中文文案 |
| settings | 7 组:播放器/音源/下载/歌词/主题/网络/账号集成 | 明暗三态、44 主题卡、音源开关、代理/超时 |
| qr_login | 二维码大卡 | qr_flutter 渲染 URL,PNG base64 直接显示 |
| sync/push | 对话框 | diff 双列预览+确认 |
| help | 静态速查 | 版本与 Cargo 同步 |

## 10. 无障碍底线(延续 v2)

- 触控目标 ≥48dp;图标按钮必须带 tooltip/semanticLabel。
- 正文对比度 ≥4.5:1(明暗分别验证)。
- 色彩不是唯一状态指示(下载失败=error 色+图标+文字标签)。
- 长列表 `ListView.builder` 虚拟化;封面图 fadeIn。

## 11. 归档:v2 FlClash 基准(已被 §1 取代)

v2(2026-11-04 上午)以 FlClash v0.9.x 为视觉基准:零阴影卡片(elevation 0
圆角 16)、药丸控件(StadiumBorder)、56/72dp 行密度、80↔200px 可扩展侧栏。
该基准由自研壳+自研页面承载;v3 换 myune 基底后,上述规格随 `shell.dart`
自绘侧栏一并退役(主题 seed 同源铁律与无障碍底线不受影响)。
审计基线见 docs/UI_AUDIT_2026-11-04.md。
