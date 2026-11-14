/// Phase 7 触屏壳：手机 MobileShell（底部导航）与平板 TabletShell 三态。
///
/// 作用域（与 responsive_shell.dart 的设备形态选择同一口径）：
/// - 桌面平台（非触屏）永远走现行 VoicefoxShell，本文件不参与；
/// - 触屏平台 <600 → MobileShell（底部 NavigationBar 五主入口）；
/// - 触屏平台 ≥600 → TabletShell（NavigationRail / 双栏 / 三栏，见
///   [resolveTabletLayout]）。
///
/// 与桌面壳共享的语义（不复制实现）：
/// - 页面构造用 app_shell.dart 的 [buildShellPage] + [kShellDestinationOrder]，
///   IndexedStack 常驻，切页不重置播放（§9）；
/// - `navRequest` / `nowPlayingRequest` 导航总线同样被消费（nav_bus.dart）；
/// - 设置/帮助/音源管理经顶栏「更多」抽屉进入，抽屉为手机原生次级
///   导航（§5.9：不复制桌面完整侧栏，见 [_ShellNavDrawer]）；
/// - 全屏播放页复用 [MobileNowPlayingPage]（封面/歌词/队列分层），打开时
///   迷你播放栏/导航随壳隐藏（§5.1
///   防双重控制），Android 系统返回先退出全屏再走默认路由。
///
/// 不引入任何原生媒体能力（计划书 §11.4：audio_service/just_audio 属
/// Phase 8）；无 Rust（VOICEFOX_UI_ONLY）时页面呈现真实空/错误态。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import '../myune/widgets/toast_overlay.dart';
import '../nav_bus.dart';
import '../pages/local_music_page.dart';
import '../pages/settings_page.dart' show SettingsSection;
import '../pages/help_page.dart' show appVersion;
import '../player/mini_player_bar.dart';
import '../player/mobile_now_playing_page.dart';
import 'app_sidebar.dart' show ShellDestination, shellDestinationIcon;
import 'android_insets.dart';
import 'app_shell.dart'
    show
        buildShellPage,
        kShellDestinationOrder,
        kShellPrimaryDestinations,
        mapLegacyNavIndex,
        ShellFormFactor;
import 'context_panel.dart';
import 'responsive_shell.dart';

/// 触屏壳跨档共享状态（Phase 7 第二批）：断点穿越（旋转/拖窗跨 600 档
/// 手机↔平板）时导航目的地与全屏播放页开关不丢；播放真源在 AppModel
/// （app 级），切页/跨档天然不重置。TouchShell 持有一份，两档壳受控读写；
/// 单独 pump MobileShell/TabletShell（既有测试）不传 session 时各壳自建。
class TouchShellSession {
  /// 当前目的地。
  ShellDestination destination = ShellDestination.home;

  /// 底部导航/Rail 高亮：settings/help（抽屉二级页）时保持最后一个
  /// 一级入口。
  int primaryIndex = 0;

  /// 全屏播放页开关。
  bool nowPlayingOpen = false;

  /// 设置页初始分组种子（Phase 2：抽屉「音源管理」→ sources 分组；
  /// 抽屉「设置」清空回根）。共享给两档壳，跨档不丢。
  SettingsSection? settingsSection;
}

/// 触屏壳入口：按宽度在手机/平板壳间切换。
///
/// 只应挂在触屏平台（VoicefoxApp 已按 [isTouchPlatform] 路由）；桌面平台
/// 的壳选择不经过这里（零变化铁律）。测试直接 pump [MobileShell]/
/// [TabletShell] 或对纯函数显式注入平台布尔值。
class TouchShell extends StatefulWidget {
  const TouchShell({
    super.key,
    required this.model,
    this.session,
    this.touchPlatformOverride,
  });

  final AppModel model;

  /// 跨档共享状态（TouchShell 自持一份；测试可显式注入）。
  final TouchShellSession? session;

  /// 触屏平台判定显式 override（仅测试注入用；生产缺省走 dart:io 的
  /// [isTouchPlatform]，FLUTTER_TEST 下宿主恒 false，配合平台隔离断言
  /// 「非触屏平台任何宽度不进移动壳」）。
  final bool? touchPlatformOverride;

  @override
  State<TouchShell> createState() => _TouchShellState();
}

class _TouchShellState extends State<TouchShell> {
  TouchShellSession get _session => widget.session ?? _ownSession;
  final TouchShellSession _ownSession = TouchShellSession();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = resolveDeviceFormFactor(
          constraints.maxWidth,
          isTouch: widget.touchPlatformOverride ?? isTouchPlatform,
        );
        // 平台隔离：桌面平台任何宽度不进移动/平板壳（正常路由根本不会
        // 挂 TouchShell；此处兜底防御，误挂时渲染空而不是移动壳）。
        return AndroidInsetsLayer(
          child: switch (factor) {
            DeviceFormFactor.tablet => TabletShell(
              model: widget.model,
              session: _session,
            ),
            DeviceFormFactor.handset => MobileShell(
              model: widget.model,
              session: _session,
            ),
            DeviceFormFactor.desktop => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

/// 全屏播放页 ↔ 壳的切换转场（与桌面 VoicefoxShell 同一规格：§6.5）。
Widget _fullscreenTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
      child: child,
    ),
  );
}

Widget _fullscreenLayoutBuilder(Widget? currentChild, List<Widget> previous) =>
    Stack(alignment: Alignment.center, children: [...previous, ?currentChild]);

/// 触屏壳自持顶栏（不复用桌面 AppHeader：其窗控/DragToMoveArea 已按平台
/// 安全引导限定桌面）。品牌 + 可选右栏面板开关（平板档）+ 更多按钮
/// （Builder 在 Scaffold 之下，能 openEndDrawer）。
class _ShellTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellTopBar({this.panelToggles});

  /// 平板档右栏面板开关规格（正在播放/歌词/队列）；手机档为空。
  final List<
    ({IconData icon, String tooltip, bool active, VoidCallback onTap})
  >?
  panelToggles;

  @override
  Size get preferredSize =>
      const Size.fromHeight(ShellBreakpoints.headerHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: ShellBreakpoints.headerHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      title: const _BrandMark(),
      actions: [
        for (final toggle in panelToggles ?? const [])
          IconButton(
            tooltip: toggle.tooltip,
            onPressed: toggle.onTap,
            icon: Icon(
              toggle.icon,
              size: 19,
              color: toggle.active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        Builder(
          builder: (context) => IconButton(
            tooltip: '更多',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// 品牌字标（与桌面 AppHeader 同构的渐变 V 方块 + 字标）。
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            // B3：品牌渐变随主题（primary/secondary = Vx accent/accentDeep）。
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.secondary],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'V',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: scheme.onPrimary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'VOICEFOX',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 手机原生导航抽屉（指南 §5.9）：只作次级入口，**不复制桌面完整侧栏**
/// （桌面 AppSidebar 的我的歌单列表/降级浮层语义不再搬进手机）。
///
/// 项目（§5.9 清单）：品牌 + 音源状态 / 首页·发现·搜索·我的音乐 /
/// 本地音乐·在线歌单·排行榜 / 下载·音源管理·设置·帮助 / 底部版本信息。
///
/// 落点语义（真实目的地，无占位）：
/// - 本地音乐 → 推入真实 [LocalMusicPage]（与桌面「本地音乐仍由曲库页/
///   抽屉入口进入」一致）；在线歌单·排行榜 → 发现（mapLegacyNavIndex
///   3/4 同语义）；音源管理 → 设置页 sources 分组（真实音源开关所在，
///   settings_page.dart SettingsSection.sources）。
///
/// 高亮塌缩规则：只有规范目的地行（首页/发现/搜索/我的音乐/下载/设置/
/// 帮助）在 current == dest 时高亮；塌缩次级行（本地音乐/在线歌单/
/// 排行榜/音源管理）永不高亮——避免 dest=library 时「我的音乐/本地音乐」、
/// dest=discover 时三行同时匹配的多重高亮歧义。
///
/// 规格：宽 ≤88% 屏宽且 ≤360dp；行触控目标 ≥48dp；点选自动关闭；
/// 抽屉本体由 Material Drawer 承担系统 inset（不覆盖状态栏内容）。
class _ShellNavDrawer extends StatelessWidget {
  const _ShellNavDrawer({
    required this.model,
    required this.current,
    required this.onSelect,
  });

  final AppModel model;
  final ShellDestination current;

  /// 选中回调：[ShellDestination] 目的地 + 设置页分组种子
  /// （仅「音源管理」传 SettingsSection.sources，其余 null）。
  final void Function(ShellDestination dest, SettingsSection? seed) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources = model.state.sources;
    final sourceStatus = sources.isEmpty
        ? '未启用音源'
        : '${sources.length} 个音源可用 · '
              '${sources.map((s) => s.name).join('、')}';
    return Drawer(
      // §5.9：宽度不超过屏幕 88%，最大约 360dp。
      width: math.min(MediaQuery.sizeOf(context).width * 0.88, 360),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 品牌 + 音源状态（真实 state.sources）。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BrandMark(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                sourceStatus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _drawerGroupLabel(context, '导航'),
                  for (final dest in const [
                    ShellDestination.home,
                    ShellDestination.discover,
                    ShellDestination.search,
                    ShellDestination.library,
                  ])
                    _drawerRow(
                      context,
                      icon: shellDestinationIcon(dest),
                      label: dest.label,
                      active: current == dest,
                      onTap: () => onSelect(dest, null),
                    ),
                  _drawerGroupLabel(context, '内容'),
                  // 塌缩次级行：永不高亮（见类文档高亮塌缩规则）。
                  _drawerRow(
                    context,
                    icon: Icons.speaker_outlined,
                    label: '本地音乐',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LocalMusicPage(model),
                        ),
                      );
                    },
                  ),
                  _drawerRow(
                    context,
                    icon: Icons.cloud_queue_outlined,
                    label: '在线歌单',
                    onTap: () => onSelect(ShellDestination.discover, null),
                  ),
                  _drawerRow(
                    context,
                    icon: Icons.leaderboard_outlined,
                    label: '排行榜',
                    onTap: () => onSelect(ShellDestination.discover, null),
                  ),
                  _drawerGroupLabel(context, '更多'),
                  _drawerRow(
                    context,
                    icon: shellDestinationIcon(ShellDestination.downloads),
                    label: ShellDestination.downloads.label,
                    active: current == ShellDestination.downloads,
                    onTap: () => onSelect(ShellDestination.downloads, null),
                  ),
                  _drawerRow(
                    context,
                    icon: Icons.source_outlined,
                    label: '音源管理',
                    onTap: () => onSelect(
                      ShellDestination.settings,
                      SettingsSection.sources,
                    ),
                  ),
                  _drawerRow(
                    context,
                    icon: shellDestinationIcon(ShellDestination.settings),
                    label: ShellDestination.settings.label,
                    active: current == ShellDestination.settings,
                    onTap: () => onSelect(ShellDestination.settings, null),
                  ),
                  _drawerRow(
                    context,
                    icon: shellDestinationIcon(ShellDestination.help),
                    label: ShellDestination.help.label,
                    active: current == ShellDestination.help,
                    onTap: () => onSelect(ShellDestination.help, null),
                  ),
                ],
              ),
            ),
            // 底部版本信息（真实 appVersion，与帮助页同源）。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'voicefox $appVersion',
                style: VxTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerGroupLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        text,
        style: VxTypography.caption.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 抽屉行：触控目标 ≥48dp；active 用低饱和容器 + 主色（§5.9 当前目的地
  /// 高亮；塌缩次级行不传 active）。
  Widget _drawerRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? scheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(VxRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(VxRadius.sm),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: VxTypography.body.copyWith(
                      color: active ? scheme.primary : scheme.onSurface,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 手机壳（<600 或 [DeviceFormFactor.handset]）。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.model, this.session});

  final AppModel model;

  /// 跨档共享状态（TouchShell 传入）；null 时自建（单独使用）。
  final TouchShellSession? session;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  /// 跨档共享状态（不传则自建，字段语义见 [TouchShellSession]）。
  late final TouchShellSession _s = widget.session ?? TouchShellSession();

  @override
  void initState() {
    super.initState();
    navRequest.addListener(_onNavRequest);
    nowPlayingRequest.addListener(_onNowPlayingRequest);
  }

  @override
  void dispose() {
    navRequest.removeListener(_onNavRequest);
    nowPlayingRequest.removeListener(_onNowPlayingRequest);
    super.dispose();
  }

  void _onNavRequest() {
    final index = navRequest.value;
    if (index == null) return;
    navRequest.value = null;
    final dest = mapLegacyNavIndex(index);
    if (dest == null) return;
    _navigate(dest);
  }

  void _onNowPlayingRequest() {
    if (!nowPlayingRequest.value) return;
    nowPlayingRequest.value = false;
    setState(() => _s.nowPlayingOpen = true);
  }

  void _navigate(ShellDestination dest) {
    setState(() {
      _s.destination = dest;
      final primary = kShellPrimaryDestinations.indexOf(dest);
      if (primary >= 0) _s.primaryIndex = primary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 全屏播放页打开时系统返回先退全屏（§5.1），其余走默认路由。
      canPop: !_s.nowPlayingOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _s.nowPlayingOpen) {
          setState(() => _s.nowPlayingOpen = false);
        }
      },
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : VxMotion.fullscreenOpen,
        switchInCurve: VxMotion.emphasized,
        switchOutCurve: VxMotion.emphasized.flipped,
        transitionBuilder: _fullscreenTransition,
        layoutBuilder: _fullscreenLayoutBuilder,
        child: _s.nowPlayingOpen
            ? MobileNowPlayingPage(
                key: const ValueKey('mobile-now-playing'),
                model: widget.model,
                onClose: () => setState(() => _s.nowPlayingOpen = false),
              )
            : KeyedSubtree(
                key: const ValueKey('mobile-shell-main'),
                child: Scaffold(
                  appBar: const _ShellTopBar(),
                  endDrawer: _ShellNavDrawer(
                    model: widget.model,
                    current: _s.destination,
                    onSelect: (dest, seed) {
                      _s.settingsSection = seed;
                      _navigate(dest);
                    },
                  ),
                  body: IndexedStack(
                    index: kShellDestinationOrder.indexOf(_s.destination),
                    children: [
                      for (final dest in kShellDestinationOrder)
                        if (dest == ShellDestination.settings)
                          // 音源管理种子变化时重建设置页（其余目的地常驻）。
                          KeyedSubtree(
                            key: ValueKey(
                              'mobile-settings:${_s.settingsSection?.name ?? 'root'}',
                            ),
                            child: buildShellPage(
                              widget.model,
                              dest,
                              form: ShellFormFactor.mobile,
                              settingsSection: _s.settingsSection,
                            ),
                          )
                        else
                          // §5.2：手机 home 槽产 MobileHomePage。
                          buildShellPage(
                            widget.model,
                            dest,
                            form: ShellFormFactor.mobile,
                          ),
                    ],
                  ),
                  // 迷你播放栏（无歌不进树）+ 底部导航五主入口。
                  bottomNavigationBar: AnimatedBuilder(
                    animation: widget.model,
                    builder: (context, _) {
                      final hasSong = widget.model.state.playback.song != null;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasSong) MiniPlayerBar(model: widget.model),
                          NavigationBar(
                            selectedIndex: _s.primaryIndex,
                            onDestinationSelected: (index) =>
                                _navigate(kShellPrimaryDestinations[index]),
                            destinations: [
                              for (final dest in kShellPrimaryDestinations)
                                NavigationDestination(
                                  icon: Icon(shellDestinationIcon(dest)),
                                  label: dest.label,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

/// 平板壳（≥600 或 [DeviceFormFactor.tablet]）：三态布局。
class TabletShell extends StatefulWidget {
  const TabletShell({super.key, required this.model, this.session});

  final AppModel model;

  /// 跨档共享状态（TouchShell 传入）；null 时自建（单独使用）。
  final TouchShellSession? session;

  @override
  State<TabletShell> createState() => _TabletShellState();
}

class _TabletShellState extends State<TabletShell> {
  /// 跨档共享状态（不传则自建，字段语义见 [TouchShellSession]）。
  late final TouchShellSession _s = widget.session ?? TouchShellSession();

  bool _contextOpen = false;
  ContextTab _contextTab = ContextTab.nowPlaying;

  /// 平板右栏固定宽度（300–420 拖宽是桌面语义，平板先固定缺省值 340）。
  static const double _contextWidth = ShellBreakpoints.contextDefaultWidth;

  @override
  void initState() {
    super.initState();
    navRequest.addListener(_onNavRequest);
    nowPlayingRequest.addListener(_onNowPlayingRequest);
  }

  @override
  void dispose() {
    navRequest.removeListener(_onNavRequest);
    nowPlayingRequest.removeListener(_onNowPlayingRequest);
    super.dispose();
  }

  void _onNavRequest() {
    final index = navRequest.value;
    if (index == null) return;
    navRequest.value = null;
    final dest = mapLegacyNavIndex(index);
    if (dest == null) return;
    _navigate(dest);
  }

  void _onNowPlayingRequest() {
    if (!nowPlayingRequest.value) return;
    nowPlayingRequest.value = false;
    setState(() => _s.nowPlayingOpen = true);
  }

  void _navigate(ShellDestination dest) {
    setState(() {
      _s.destination = dest;
      final primary = kShellPrimaryDestinations.indexOf(dest);
      if (primary >= 0) _s.primaryIndex = primary;
    });
  }

  void _togglePanel(ContextTab tab) {
    setState(() {
      if (_contextOpen && _contextTab == tab) {
        _contextOpen = false;
      } else {
        _contextOpen = true;
        _contextTab = tab;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_s.nowPlayingOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _s.nowPlayingOpen) {
          setState(() => _s.nowPlayingOpen = false);
        }
      },
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : VxMotion.fullscreenOpen,
        switchInCurve: VxMotion.emphasized,
        switchOutCurve: VxMotion.emphasized.flipped,
        transitionBuilder: _fullscreenTransition,
        layoutBuilder: _fullscreenLayoutBuilder,
        child: _s.nowPlayingOpen
            ? MobileNowPlayingPage(
                key: const ValueKey('tablet-now-playing'),
                model: widget.model,
                onClose: () => setState(() => _s.nowPlayingOpen = false),
              )
            : KeyedSubtree(
                key: const ValueKey('tablet-shell-main'),
                child: Scaffold(
                  appBar: _ShellTopBar(
                    panelToggles: [
                      (
                        icon: Icons.album_outlined,
                        tooltip: '正在播放面板',
                        active:
                            _contextOpen &&
                            _contextTab == ContextTab.nowPlaying,
                        onTap: () => _togglePanel(ContextTab.nowPlaying),
                      ),
                      (
                        icon: Icons.lyrics_outlined,
                        tooltip: '歌词面板',
                        active:
                            _contextOpen && _contextTab == ContextTab.lyrics,
                        onTap: () => _togglePanel(ContextTab.lyrics),
                      ),
                      (
                        icon: Icons.queue_music_outlined,
                        tooltip: '队列面板',
                        active: _contextOpen && _contextTab == ContextTab.queue,
                        onTap: () => _togglePanel(ContextTab.queue),
                      ),
                    ],
                  ),
                  endDrawer: _ShellNavDrawer(
                    model: widget.model,
                    current: _s.destination,
                    onSelect: (dest, seed) {
                      _s.settingsSection = seed;
                      _navigate(dest);
                    },
                  ),
                  // 平板底部迷你播放栏（有歌常驻；全屏打开时随壳隐藏）。
                  bottomNavigationBar: AnimatedBuilder(
                    animation: widget.model,
                    builder: (context, _) =>
                        widget.model.state.playback.song != null
                        ? MiniPlayerBar(model: widget.model)
                        : const SizedBox.shrink(),
                  ),
                  body: LayoutBuilder(
                    builder: (context, constraints) =>
                        _buildBody(context, constraints.maxWidth),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, double width) {
    final layout = resolveTabletLayout(width);
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 600–839 图标 rail；840–1199 展开带标签（双栏「Rail+内容」；
            // 断点在 resolveTabletLayout：840/1200，注释数值已对齐）。
            NavigationRail(
              selectedIndex: _s.primaryIndex,
              onDestinationSelected: (index) =>
                  _navigate(kShellPrimaryDestinations[index]),
              extended: layout != TabletLayout.rail,
              labelType: NavigationRailLabelType.none,
              minExtendedWidth: 200,
              leading: const SizedBox(height: 8),
              destinations: [
                for (final dest in kShellPrimaryDestinations)
                  NavigationRailDestination(
                    icon: Icon(shellDestinationIcon(dest)),
                    label: Text(dest.label),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(layout == TabletLayout.rail ? 16 : 20),
                child: IndexedStack(
                  index: kShellDestinationOrder.indexOf(_s.destination),
                  children: [
                    // 平板显式维持桌面缺省形态（home 槽仍是桌面 HomePage；
                    // 偏差登记 04-defect-matrix，待平板阶段 §6.3 裁决）。
                    for (final dest in kShellDestinationOrder)
                      if (dest == ShellDestination.settings)
                        KeyedSubtree(
                          key: ValueKey(
                            'tablet-settings:${_s.settingsSection?.name ?? 'root'}',
                          ),
                          child: buildShellPage(
                            widget.model,
                            dest,
                            settingsSection: _s.settingsSection,
                          ),
                        )
                      else
                        buildShellPage(widget.model, dest),
                  ],
                ),
              ),
            ),
            // ≥840（dual/triple）：右栏 end panel 内嵌在行内（Phase 6，
            // §6.2:546「overlay 或 end panel」取 end panel——中央内容仍可
            // 操作，§6.3:554；≥1200 triple 同形态）。600–839 rail 档维持
            // 覆盖式浮层（§6.1:539 Modal/Overlay 语义）。
            if (layout != TabletLayout.rail && _contextOpen)
              ContextPanel(
                key: const ValueKey('tablet-context-inline'),
                model: widget.model,
                tab: _contextTab,
                onTabChanged: (tab) => setState(() => _contextTab = tab),
                onClose: () => setState(() => _contextOpen = false),
                width: _contextWidth,
              ),
          ],
        ),
        // 600–839 rail 档：右栏覆盖式浮层（§6.1 Modal/Overlay 语义）。
        if (layout == TabletLayout.rail && _contextOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _contextOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            bottom: 10,
            width: _contextWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: ContextPanel(
                key: const ValueKey('tablet-context-overlay'),
                model: widget.model,
                tab: _contextTab,
                onTabChanged: (tab) => setState(() => _contextTab = tab),
                onClose: () => setState(() => _contextOpen = false),
                width: _contextWidth,
              ),
            ),
          ),
        ],
        // 全局 toast（与桌面壳同一出口）。
        const ToastOverlay(),
      ],
    );
  }
}
