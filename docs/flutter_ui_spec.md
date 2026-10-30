# voicefox Flutter UI 设计规范（flutter_ui_spec）

> 版本：v1（2026-10-31）· 视觉基准：FlClash（github.com/chen08209/FlClash，v0.9.x 重构后 UI）
> 实现时对照本文件执行，禁止「看着办」。每个借鉴点注明参考 FlClash 的哪个部分。

## 0. 设计基调

FlClash 的可借鉴内核：**零阴影卡片 + 药丸形控件 + 自适应导航 chrome + 「页面为底、卡片浮起」的双主题表面系统**。
voicefox 是内容密集型音乐播放器，采纳其结构语言，密度按音乐列表调整。

## 1. 导航结构（参考 FlClash `lib/views/navigation.dart` + `lib/ui/sidebar.dart`）

- **手机（宽 ≤600）**：底部 NavigationBar，5 个固定项：首页(队列)、搜索、收藏、下载、更多。
  「更多」页收纳：历史 / 歌单 / 本地音乐 / 排行榜 / 设置 / 扫码登录 / 跨源同步（参考 FlClash
  把设置收进 Tools 视图、tab 数自适应的做法）。
- **平板/桌面（>840）**：左侧 NavigationRail（FlClash 用自绘 sidebar，voicefox 用标准
  NavigationRail + 扩展态：图标+文字标签，宽 80→200px 动画过渡 250ms）。
  桌面额外暴露全部 9 个入口，不折叠进「更多」。
- **600–840（平板竖屏）**：底栏 + 更多项，或 rail 收缩态，运行时按可用宽度取整列数决定。
- 断点常量与 FlClash 对齐：`≤600 mobile / ≤840 laptop / else desktop`。

## 2. 卡片与列表密度（参考 FlClash `CommonCard`/`CommonSwitch`/`ListHeader`）

- 列表容器：**Card elevation=0 无阴影**，圆角 16，浅色页面底=surfaceContainer、卡片=更浅；
  深色页面底=surface、卡片=surfaceContainer（参考 FlClash 4 级表面系统，两种主题下卡片都
  「浮」在页面之上）。
- 歌曲行：ListTile，horizontal padding 16，主标题 titleMedium、副标题 bodySmall
  （歌手 · 音源 · 时长），trailing 为溢出菜单（加入队列/下载/收藏/换源）。
  高度紧凑档 56dp、舒适档 72dp，设置里可切。
- 分组头：ListHeader 风格——纯文字 titleMedium 加粗 + 可选尾随文字按钮，不装箱。
- 封面网格（歌单/排行榜/专辑）：GridView，交叉轴间距 8（参考 FlClash proxy 卡片网格），
  圆角 12，最小列宽 120dp。
- 选中态：行/卡片选中时填充 primaryContainer（参考 FlClash 选中填充 primary 的做法）。

## 3. 留白与节奏（参考 FlClash `lib/common/layout.dart` 自适应间距）

- 页面水平边距：手机 12 / 桌面 24（FlClash 是 8/16，音乐列表行高更大，取大一档）。
- 卡片间距：手机 8 / 平板 12 / 桌面 16（同 FlClash 自适应档位）。
- 8dp 节奏：所有间距取 4/8/12/16/24/32/48。
- 列表底部预留 96dp，避免被 mini-player 遮挡（FlClash 的 scroll/fixed 共存原则）。

## 4. 暗色模式（参考 FlClash `lib/ui/color.dart` + `lib/ui/surface.dart`）

- 跟随系统 / 浅色 / 深色三态切换（设置页带迷你预览，参考 FlClash theme 视图）。
- 不做纯黑选项（voicefox 主题源自命名色板，保持色板一致性优先）。
- 表面系统按 §2 的双主题规则落地；分割线用 outlineVariant，两主题下都必须可见。

## 5. Material You 动态配色与 16 主题色板（铁律：与 TUI 同源不分叉）

- **唯一 seed 来源**：`app/examples/theme_dump.rs`（从 ratatui-themes 导出，TUI 与 Flutter
  消费同一份导出）。Flutter 侧常量表在 `flutter/lib/src/theme/seed_colors.dart`。
- **dynamic_color 包**：Android 12+ 默认取系统动态色；设置里可关（关掉后走下面的命名色板）。
  其他平台直接走命名色板。
- **命名色板 → M3**：`ColorScheme.fromSeed(seedColor: accent, brightness: dark/light)`，
  light/dark 各一套；surface 系列以主题 bg 做覆盖（保住各主题的底色个性，如 Dracula 的
  #282A36），具体覆盖 `surface/surfaceContainer/surfaceContainerHighest` 三档。
- 16 主题 seed 表（name|bg|accent|dark）：

| seed | bg | accent | dark |
|---|---|---|---|
| Dracula | #282A36 | #BD93F9 | ✓ |
| OneDarkPro | #282C34 | #61AFEF | ✓ |
| Nord | #2E3440 | #88C0D0 | ✓ |
| CatppuccinMocha | #1E1E2E | #89B4FA | ✓ |
| CatppuccinLatte | #EFF1F5 | #1E66F5 | ✗ |
| GruvboxDark | #282828 | #FABD2F | ✓ |
| GruvboxLight | #FBF1C7 | #B57614 | ✗ |
| TokyoNight | #1A1B26 | #7AA2F7 | ✓ |
| SolarizedDark | #002B36 | #268BD2 | ✓ |
| SolarizedLight | #FDF6E3 | #268BD2 | ✗ |
| MonokaiPro | #2D2A2E | #FFD866 | ✓ |
| RosePine | #191724 | #EBBCBA | ✓ |
| Kanagawa | #1F1F28 | #7FB4CA | ✓ |
| Everforest | #2F3537 | #83C178 | ✓ |
| Cyberpunk | #0D0221 | #00FFFF | ✓ |
| MidnightCommander | #0000AA | #00AAAA | ✓ |

- 主题选择 UI：预览色卡网格（每卡显示 bg+accent 双色块 + 名称），点击即换，
  参考FlClash theme 视图的即时预览交互。

## 6. 控件与动效（参考 FlClash `lib/ui/shape.dart`/`theme.dart`）

- 按钮：全部药丸形（StadiumBorder）；主操作 FilledButton，次级 Tonal，文字按钮 tertiary。
- Chips 圆角 8（音源筛选、排序模式用 FilterChip/ChoiceChip）。
- Dialog 圆角 28；BottomSheet 顶部圆角 28；Snackbar 圆角 4。
- 开关：行级点击翻转（整行可点，参考 CommonSwitch）。
- 动效时长：页面切换 250ms / 控件状态 150ms / 展开折叠 200ms，曲线默认
  `Curves.easeOutCubic`（进入）与 `Curves.easeInCubic`（退出）；
  尊重系统 reduce-motion（MediaQuery.disableAnimations 时全部退化为直切）。
- 无 FAB：主操作放 AppBar（参考 FlClash dashboard）；「全部播放」用 AppBar 文字按钮。

## 7. 语义色映射（参考 FlClash 延迟→语义色）

- 播放状态：播放中=primary、暂停=secondary、缓冲=tertiary、错误=error。
- 音质标签：标准=outline、320k=primaryContainer、FLAC=primary、24bit=tertiaryContainer。
- 下载状态：排队/进行=primary、完成=success(绿)、跳过=outline、取消/失败=error。
- 状态色只用语义 token，禁止页面内硬编码 hex。

## 8. 字体与字号

- 系统默认字体栈（Android: Roboto/思源黑体自动回退），不内置字体文件。
- 页头 titleLarge(22/w600)、列表标题 titleMedium(16/w500)、正文 bodyMedium(14)、
  辅助 bodySmall(12/w400 onSurfaceVariant)、歌词全屏 displaySmall(32/w600)。
- 长文本行宽上限 640dp（桌面歌词/说明文字）。

## 9. 页面级规格（对照 TUI app/src/pages/ 全集）

| 页面 | 布局 | 关键控件 |
|---|---|---|
| queue/main | 桌面=左封面+右队列分栏；手机=列表+顶部 hero 封面卡 | 进度条 Slider(gapped track 参考 FlClash)、播放模式 ChoiceChip |
| search | 搜索框+音源 FilterChip 行+结果列表 | 防抖 300ms、SearchMore 触底加载 |
| leaderboard | 音源 tabs+榜单列表 | TabBar secondary 样式 |
| playlists | 远程歌单网格+本地自定义歌单分区 | ListHeader 分区、卡片网格 |
| favorites | 收藏歌曲列表+收藏歌单 tab | 排序菜单 |
| history | 按时间分组列表 | 清空按钮（确认 dialog） |
| downloads | 活跃任务卡+完成记录列表 | 进度条+暂停/取消、CLEAR_FINISHED |
| local_music | 目录卡+歌曲列表+扫描按钮 | 扫描进度用 LinearProgress |
| settings | 分组列表（播放器/音源/下载/歌词/主题/网络/集成） | 行级开关/子页 |
| qr_login | 二维码大卡+状态文本 | url 用 qr_flutter 渲染，image base64 直接显示 |
| sync | diff 双列预览+确认按钮 | diff 行=添加(绿)/删除(红)/保留 |
| details | 歌手/专辑：头图+歌曲列表 | 封面横幅 200dp |
| help | 静态说明页 | — |
| mini_player | 底部固定 72dp 卡：封面+标题+播放/下一首 | 点击展开全屏播放页（OpenContainer 容器变换，参考 FlClash 移动端详情转场） |

## 10. 无障碍底线（来自 ui-ux-pro-max 检查表，App 语义）

- 触控目标 ≥48dp；图标按钮必须带 tooltip/semanticLabel。
- 正文对比度 ≥4.5:1（两主题分别验证）。
- 色彩不是唯一状态指示（下载失败=error 色+图标+文字标签）。
- 长列表使用 ListView.builder 虚拟化；封面图 fadeIn 200ms。
