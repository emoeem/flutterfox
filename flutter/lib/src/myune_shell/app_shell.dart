// ignore_for_file: deprecated_member_use // window_manager 0.6 把 0.5.x API 移入 legacy.dart 桥接层(changelog 指定迁移路径), 后续大版本切 native API
// Voicefox app shell（旧壳）。
//
// RETIRED (Phase 2)：桌面外壳的唯一实现已迁移到 `src/shell/app_shell.dart`
// （VoicefoxShell：Header + Sidebar + MainContent + ContextPanel + PlayerBar，
// 导航收敛 5 一级入口）。main.dart 已不再挂载本壳；文件按计划书 §7.3 保留
// 不删，请勿在此继续添加功能。
//
// 历史：结构 fork 自 vendored myune/layout/{app_shell,main_view}.dart 与
// widgets/app_window_title_bar.dart（Apache-2.0），页面注册表换成 voicefox
// 的九入口；voicefox 特有逻辑在此文件内演化，不回写上游树。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import '../app_model.dart';
import '../nav_bus.dart';
import '../pages/downloads_page.dart';
import '../pages/help_page.dart';
import '../pages/home_page.dart';
import '../pages/leaderboard_page.dart';
import '../pages/library_page.dart';
import '../pages/local_music_page.dart';
import '../pages/playlist_browse_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../myune/page/setting/settings_provider.dart';
import '../myune/widgets/custom_background_layer.dart';
import '../myune/widgets/toast_overlay.dart';
import '../myune/utils/pixel_snap.dart';
import 'voicefox_playbar.dart';
import 'voicefox_queue_drawer.dart';

class VoicefoxAppShell extends StatelessWidget {
  const VoicefoxAppShell({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: const VoicefoxQueueDrawer(),
      body: Stack(
        children: [
          // 自定义背景图（未启用时为透明，不影响原有外观）
          const Positioned.fill(child: CustomBackgroundImageLayer()),
          // 背景遮罩：未启用自定义背景时提供不透明的主题底色。
          const Positioned.fill(child: CustomBackgroundMaskLayer()),
          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const VoicefoxWindowTitleBar(),
                Expanded(child: _MainView(model: model)),
                VoicefoxPlaybar(model: model),
              ],
            ),
          ),
          const ToastOverlay(),
        ],
      ),
    );
  }
}

class _PageEntry {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _PageEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

/// 桌面导航入口（九个）：队列由全局 endDrawer（PlayingQueueDrawer）承担，
/// 收藏/历史/自建歌单合并进「曲库」；扫码登录、同步从设置页进入。
class _MainView extends StatefulWidget {
  const _MainView({required this.model});

  final AppModel model;

  @override
  State<_MainView> createState() => _MainViewState();
}

class _MainViewState extends State<_MainView> {
  int _index = 0;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  @override
  void initState() {
    super.initState();
    // 页面内部（首页快捷入口/书架「查看全部」）请求切换主导航。
    navRequest.addListener(_onNavRequest);
  }

  void _onNavRequest() {
    final index = navRequest.value;
    if (index == null || index == _index) return;
    setState(() => _index = index);
  }

  @override
  void dispose() {
    navRequest.removeListener(_onNavRequest);
    super.dispose();
  }

  List<_PageEntry> get _entries => [
    _PageEntry(
      label: '首页',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      page: HomePage(widget.model),
    ),
    _PageEntry(
      label: '搜索',
      icon: Icons.search,
      selectedIcon: Icons.search,
      page: SearchPage(widget.model),
    ),
    _PageEntry(
      label: '曲库',
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
      page: LibraryPage(widget.model),
    ),
    _PageEntry(
      label: '在线歌单',
      icon: Icons.playlist_play_outlined,
      selectedIcon: Icons.playlist_play,
      page: PlaylistBrowsePage(widget.model),
    ),
    _PageEntry(
      label: '排行榜',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      page: LeaderboardPage(widget.model),
    ),
    _PageEntry(
      label: '本地音乐',
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
      page: LocalMusicPage(widget.model),
    ),
    _PageEntry(
      label: '下载',
      icon: Icons.download_outlined,
      selectedIcon: Icons.download,
      page: DownloadsPage(widget.model),
    ),
    _PageEntry(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      page: SettingsPage(widget.model),
    ),
    _PageEntry(
      label: '帮助',
      icon: Icons.help_outline,
      selectedIcon: Icons.help,
      page: const HelpPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return CallbackShortcuts(
      // 全局快捷键沿用旧壳：空格播放/暂停、←/→ ±5s、Esc 返回。
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): widget.model.toggle,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(const Duration(seconds: -5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(const Duration(seconds: 5)),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) navigator.pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                backgroundColor: CustomBackgroundSurfaces.railColor(
                  settings,
                  scheme.surfaceContainerHighest,
                ),
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                destinations: [
                  for (final entry in entries)
                    NavigationRailDestination(
                      icon: Tooltip(
                        message: entry.label,
                        child: Icon(entry.icon, color: scheme.onSurfaceVariant),
                      ),
                      selectedIcon: Icon(
                        entry.selectedIcon,
                        color: scheme.primary,
                      ),
                      label: Text(entry.label, style: _labelStyle),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    // 轻微缩放配合淡入，比纯 fade 有层次。
                    scale: Tween<double>(
                      begin: 0.985,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: entries[_index].page,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 全局快捷键：±5s。时长未知（0）时不夹紧上限，交给 seek 自己处理。
  void _seekBy(Duration delta) {
    final playback = widget.model.state.playback;
    final current = playback.positionMs.toInt();
    final duration = playback.durationMs.toInt();
    var target = current + delta.inMilliseconds;
    if (target < 0) target = 0;
    if (duration > 0 && target > duration) target = duration;
    widget.model.seekMs(BigInt.from(target));
  }
}

/// 自绘窗口标题栏：fork 自 myune AppWindowTitleBar，去掉上游的
/// icon.png 资产依赖（voicefox 未打包该图），改用主题色图标。
/// 依赖 main() 里 windowManager 的 TitleBarStyle.hidden。
class VoicefoxWindowTitleBar extends StatelessWidget {
  const VoicefoxWindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final background = CustomBackgroundSurfaces.transparentWhenEnabled(
      settings,
      scheme.surface,
    );
    final height = snapToDevicePixel(context, 31.0);
    return Container(
      height: height,
      color: background,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.graphic_eq, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'voicefox',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindowButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (settings.minimizeToTray) {
                      windowManager.hide();
                    } else {
                      windowManager.minimize();
                    }
                  },
                ),
                const SizedBox(width: 2),
                _WindowButton(
                  icon: Icons.close,
                  onPressed: windowManager.close,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _WindowButton({required this.icon, required this.onPressed});

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 40,
          height: 31,
          color: _hovering
              ? scheme.errorContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: scheme.onSurface),
        ),
      ),
    );
  }
}
