/// Phase 2 桌面应用外壳（计划书 §3 / §7.1 AppShell）。
///
/// 唯一外壳：Header + Sidebar + MainContent + ContextPanel + PlayerBar。
/// - 导航收敛 5 个一级入口（首页/发现/搜索/我的音乐/下载），设置/帮助经
///   侧栏底部进入（§2.1）；
/// - 页面用 IndexedStack 常驻：切换页面不重建页面状态，播放真源在 app 级
///   AppModel，切页天然不重置播放（§9「页面切换不能重置播放器」）；
/// - Header 是唯一窗口标题栏；PlayerBar 是唯一常驻播放栏；中央内容区内嵌
///   Navigator（nav_bus.contentNavigatorKey）承接推入式详情页，推入页不再
///   整页覆盖壳层——PlayerBar/侧栏/右栏跨详情页常驻（§7.5，Phase 6 退出
///   条件「播放器跨页面保持」，2026-11-13 QA P1 修复）；
/// - 断点行为见 responsive_shell.dart；
/// - 兼容旧页面的 `navRequest`（旧九入口索引）映射到新目的地。
///
/// 取代 `myune_shell/app_shell.dart`（旧壳保留为退役文件，见其头部标记）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../pages/album_songs_page.dart';
import '../pages/artist_detail_page.dart';
import '../pages/discover_page.dart';
import '../pages/downloads_page.dart';
import '../pages/help_page.dart';
import '../pages/home_page.dart';
import '../pages/mobile_home_page.dart';
import '../pages/library_page.dart';
import '../pages/local_music_page.dart';
import '../pages/playlist_detail_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../myune/widgets/toast_overlay.dart';
import '../player/now_playing_page.dart';
import '../player/player_bar.dart';
import 'app_header.dart';
import 'app_sidebar.dart';
import 'context_panel.dart';
import 'responsive_shell.dart';

/// IndexedStack 中各目的地的固定顺序（settings/help 为侧栏底部二级页）。
/// 桌面 VoicefoxShell 与移动 MobileShell/TabletShell 共享（Phase 7）。
/// Phase 6 侧栏宽度/折叠记忆（§7.2）持久化键。
const _prefSidebarWidth = 'shell.sidebar.width';
const _prefSidebarCollapsed = 'shell.sidebar.collapsed';

const List<ShellDestination> kShellDestinationOrder = [
  ShellDestination.home,
  ShellDestination.discover,
  ShellDestination.search,
  ShellDestination.library,
  ShellDestination.downloads,
  ShellDestination.settings,
  ShellDestination.help,
];

/// 一级导航五主入口（§2.1；桌面侧栏与手机底部导航同源）。
const List<ShellDestination> kShellPrimaryDestinations = [
  ShellDestination.home,
  ShellDestination.discover,
  ShellDestination.search,
  ShellDestination.library,
  ShellDestination.downloads,
];

/// 旧页面 `navRequest`（旧九入口索引）→ 新目的地。
/// 1=搜索 2=曲库 3=在线歌单 4=排行榜 5=本地音乐 6=下载 7=设置。
/// 桌面与移动壳同样消费（Phase 7 提取共享）。
ShellDestination? mapLegacyNavIndex(int index) => switch (index) {
  1 => ShellDestination.search,
  2 => ShellDestination.library,
  3 || 4 => ShellDestination.discover,
  5 => ShellDestination.library,
  6 => ShellDestination.downloads,
  7 => ShellDestination.settings,
  _ => null,
};

/// 详情页自动下钻种子（VOICEFOX_START_DETAIL 联动，验收截图专用）。
///
/// `keyword` 非空时先发一次真实搜索，取首个结果下钻（真实数据链路）；
/// `kind = local` 直接打开本地音乐页；`kind = playlist` 用 [source]
/// 拉取真实歌单列表后进首个详情。仅影响设置了环境变量的启动，
/// 运行时行为不变。
class ShellDetailSeed {
  /// album | artist | playlist | local
  final String kind;

  /// 下钻搜索关键词（album/artist 用）。
  final String keyword;

  /// 歌单来源 id（playlist 用，默认 kw）。
  final String source;

  const ShellDetailSeed({
    required this.kind,
    this.keyword = '',
    this.source = 'kw',
  });
}

/// Voicefox 桌面 Shell（Phase 2 唯一顶层外壳）。
class VoicefoxShell extends StatefulWidget {
  const VoicefoxShell({
    super.key,
    required this.model,
    this.initialDestination,
    this.searchSeed = '',
    this.libraryTab,
    this.detailSeed,
    this.settingsSection,
  });

  final AppModel model;

  /// 初始目的地（验收截图等场景用）；null 从首页开始。
  final ShellDestination? initialDestination;

  /// 搜索页种子关键词（验收截图用）；空串不触发搜索。
  final String searchSeed;

  /// 我的音乐初始二级类别（验收截图用）；null 从歌曲开始。
  final String? libraryTab;

  /// 详情页自动下钻种子（验收截图用）；null 不下钻。
  final ShellDetailSeed? detailSeed;

  /// 设置页初始分组（验收截图用）；null 从播放开始。
  final String? settingsSection;

  @override
  State<VoicefoxShell> createState() => _VoicefoxShellState();
}

class _VoicefoxShellState extends State<VoicefoxShell> {
  ShellDestination _current = ShellDestination.home;
  final List<ShellDestination> _back = [];
  final List<ShellDestination> _forward = [];

  bool _contextOpen = false;
  ContextTab _contextTab = ContextTab.nowPlaying;
  double _contextWidth = ShellBreakpoints.contextDefaultWidth;

  /// Phase 6 §7.2 最小语义：用户拖调后的侧栏宽度与折叠开关（SharedPreferences
  /// 持久化）。null = 从未手动设置，走断点默认；非 null = 用户值覆盖断点
  /// 默认（<960 降级布局仍恒隐藏，不受用户值影响）。
  double? _sidebarWidth;
  bool? _sidebarCollapsed;

  /// 全屏播放页（Phase 3 NowPlayingPage）开关；打开时隐藏 PlayerBar，
  /// 由全屏页提供唯一播放控制（§5.1，防双重控制）。
  bool _nowPlayingOpen = false;

  /// 壳层快捷键焦点节点（CallbackShortcuts 直接包着本 Focus）：全屏播放页
  /// 切换伴随 shell-main（内含内容区内嵌 Navigator）整棵进出树，离树节点
  /// 的焦点回落到路由域（home ModalScope，快捷键子树之外），Esc/空格/
  /// 方向键全链失灵（2026-11-13 QA P1 修复过程中 widget 层实证）。转场帧
  /// 结束后由本节点收回 primary，§9 全局快捷键语义不变。
  final FocusNode _shellShortcutsFocus = FocusNode(
    debugLabel: 'shell-shortcuts-focus',
  );

  /// <960 降级布局下的侧栏浮层开关。
  bool _degradedSidebarOpen = false;

  /// 中央内容区内嵌 Navigator 的 key 在 nav_bus.dart（contentNavigatorKey），
  /// 侧栏等壳层兄弟子树的推入入口经同一 key 落内容区；详见 nav_bus.dart 注释。

  final FocusNode _searchFocus = FocusNode();

  /// Header 搜索框提交的关键字（搜索页种子）。
  String _searchSeed = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDestination;
    if (initial != null) _current = initial;
    _searchSeed = widget.searchSeed;
    navRequest.addListener(_onNavRequest);
    nowPlayingRequest.addListener(_onNowPlayingRequest);
    _loadSidebarPrefs();
    final seed = widget.detailSeed;
    if (seed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSeedDetail(seed);
      });
    }
  }

  /// 侧栏宽度/折叠记忆（Phase 6 §7.2）：重启恢复用户上次值。
  Future<void> _loadSidebarPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sidebarWidth = prefs.getDouble(_prefSidebarWidth);
      _sidebarCollapsed = prefs.getBool(_prefSidebarCollapsed);
    });
  }

  Future<void> _persistSidebar() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sidebarWidth != null) {
      await prefs.setDouble(_prefSidebarWidth, _sidebarWidth!);
    } else {
      await prefs.remove(_prefSidebarWidth);
    }
    if (_sidebarCollapsed != null) {
      await prefs.setBool(_prefSidebarCollapsed, _sidebarCollapsed!);
    } else {
      await prefs.remove(_prefSidebarCollapsed);
    }
  }

  /// 环境变量驱动的详情页下钻（验收截图专用，见 [ShellDetailSeed]）。
  ///
  /// 与页面内推入同源：落内容区内嵌 Navigator（§7.5 播放器跨页面保持），
  /// 不推根路由（根路由整页覆盖壳层，PlayerBar/侧栏全没）。
  Future<void> _openSeedDetail(ShellDetailSeed seed) async {
    final model = widget.model;
    // 推入目标：内容区内嵌 Navigator（壳层兄弟子树，须用 key 显式定位；
    // currentState 为 null 说明壳层已拆栈，静默放弃，种子仅验收截图用）。
    void pushDetail(WidgetBuilder builder) {
      contentNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: builder),
      );
    }

    switch (seed.kind) {
      case 'local':
        pushDetail((_) => LocalMusicPage(model));
      case 'album':
        final song = await _firstSearchResult(seed.keyword);
        if (song == null || !mounted) return;
        final albumName = song.albumName.trim();
        final albumId = song.albumId?.trim();
        pushDetail(
          (_) => AlbumSongsPage(
            model,
            bridge.AlbumDto(
              id: (albumId != null && albumId.isNotEmpty) ? albumId : albumName,
              name: albumName.isEmpty ? song.name : albumName,
              source: song.source,
              coverUrl: song.coverUrl,
              artist: song.singer,
            ),
          ),
        );
      case 'artist':
        final song = await _firstSearchResult(seed.keyword);
        if (song == null || !mounted) return;
        final name = song.singer.trim().isEmpty ? song.name : song.singer;
        final artistId = song.artistId?.trim();
        pushDetail(
          (_) => ArtistDetailPage(
            model,
            bridge.ArtistDto(
              id: (artistId != null && artistId.isNotEmpty) ? artistId : name,
              name: name,
              source: song.source,
              coverUrl: null,
            ),
          ),
        );
      case 'playlist':
        await model.loadPlaylists(source: seed.source, category: '', page: 1);
        final playlist = await _firstPlaylist(seed.source);
        if (playlist == null || !mounted) return;
        pushDetail((_) => PlaylistDetailPage(model, playlist));
      default:
        break;
    }
  }

  /// 发起真实搜索并等待首个结果（20s 超时放弃，不伪造数据）。
  Future<bridge.SongDto?> _firstSearchResult(String keyword) async {
    if (keyword.isEmpty) return null;
    final model = widget.model;
    final requestIdAtStart = model.state.search.requestId;
    await model.dispatch(bridge.FfiCommand.search(keyword: keyword));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return null;
      final search = model.state.search;
      if (search.requestId != requestIdAtStart &&
          !search.loading &&
          search.items.isNotEmpty) {
        return search.items.first;
      }
    }
    return null;
  }

  /// 等待歌单浏览结果首个条目（20s 超时放弃）。
  Future<bridge.PlaylistDto?> _firstPlaylist(String source) async {
    final model = widget.model;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return null;
      final result = model.browse('playlists', source, '');
      if (result != null && result.playlists.isNotEmpty) {
        return result.playlists.first;
      }
      if (result != null && result.error != null) return null;
    }
    return null;
  }

  @override
  void dispose() {
    navRequest.removeListener(_onNavRequest);
    nowPlayingRequest.removeListener(_onNowPlayingRequest);
    _searchFocus.dispose();
    _shellShortcutsFocus.dispose();
    super.dispose();
  }

  void _onNavRequest() {
    final index = navRequest.value;
    if (index == null) return;
    navRequest.value = null;
    final dest = mapLegacyNavIndex(index);
    if (dest == null || dest == _current) return;
    _navigate(dest);
  }

  void _onNowPlayingRequest() {
    if (!nowPlayingRequest.value) return;
    nowPlayingRequest.value = false;
    _setNowPlayingOpen(true);
  }

  /// 全屏播放页开关统一出口。除切状态外，在转场帧结束后让
  /// [_shellShortcutsFocus] 收回 primary：shell-main 进出树会拆掉其内的
  /// 焦点节点（含内容区内嵌 Navigator），焦点默认回落 home ModalScope
  /// （快捷键子树之外），§9 全局快捷键（Esc/空格/方向键/Cmd-K）会全链
  /// 失灵。收回后全屏页自身 Esc 绑定不依赖焦点——壳层 CallbackShortcuts
  /// 在祖先链上承接同一动作（§4.3 Esc 链第一档，Phase 3 双路径语义不变）。
  void _setNowPlayingOpen(bool open) {
    setState(() => _nowPlayingOpen = open);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_shellShortcutsFocus.hasPrimaryFocus) {
        _shellShortcutsFocus.requestFocus();
      }
    });
  }

  void _navigate(ShellDestination dest) {
    if (dest == _current) return;
    setState(() {
      _back.add(_current);
      _forward.clear();
      _current = dest;
      _degradedSidebarOpen = false;
    });
  }

  void _goBack() {
    if (_back.isEmpty) return;
    setState(() {
      _forward.add(_current);
      _current = _back.removeLast();
    });
  }

  void _goForward() {
    if (_forward.isEmpty) return;
    setState(() {
      _back.add(_current);
      _current = _forward.removeLast();
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

  void _onSearchSubmit(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) _searchSeed = trimmed;
    if (_current != ShellDestination.search) {
      _navigate(ShellDestination.search);
    } else {
      // 已在搜索页：换种子重建输入框内容。
      setState(() {});
    }
  }

  bool _isEditing() =>
      FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  void _seekBy(int deltaMs) {
    final playback = widget.model.state.playback;
    final duration = playback.durationMs.toInt();
    var target = playback.positionMs.toInt() + deltaMs;
    if (target < 0) target = 0;
    if (duration > 0 && target > duration) target = duration;
    widget.model.seekMs(BigInt.from(target));
  }

  /// 用户折叠开关（记忆值）仅在断点默认展开的档位（≥1200）生效：
  /// 960–1199 是规格硬带（§3.1 折叠 72，空间预算紧），不接受用户展开
  /// override（1024 展开态 Header 实测溢出 21px，2026-11-13 widget 层实证）；
  /// <960 降级布局恒隐藏不受影响。
  bool _effectiveCollapsed(ShellMetrics metrics) =>
      metrics.sidebar == SidebarMode.expanded
      ? (_sidebarCollapsed ?? false)
      : metrics.sidebar == SidebarMode.collapsed;

  /// 展开态宽度：未拖调走断点默认，拖调后记忆用户值（钳 §7.1 240–300）。
  double get _effectiveSidebarWidth {
    final w = _sidebarWidth;
    return w == null
        ? ShellBreakpoints.sidebarWidth
        : w.clamp(
            ShellBreakpoints.sidebarMinWidth,
            ShellBreakpoints.sidebarMaxWidth,
          );
  }

  /// Header 品牌区宽度（与侧栏 AnimatedContainer / 降级浮层同源同值，
  /// Phase 6：拖调/折叠后字标显隐跟随真实宽度，不再按断点拍死）。
  double _headerSidebarWidth(ShellMetrics metrics) {
    if (metrics.sidebar == SidebarMode.hidden) return 0;
    return _effectiveCollapsed(metrics)
        ? ShellBreakpoints.sidebarCollapsedWidth
        : _effectiveSidebarWidth;
  }

  void _toggleSidebarCollapsed() {
    setState(() {
      _sidebarCollapsed = !_effectiveCollapsed(
        resolveShellMetrics(
          MediaQuery.sizeOf(context).width,
          contextOpen: _contextOpen,
        ),
      );
    });
    _persistSidebar();
  }

  void _onSidebarWidthChanged(double w) {
    setState(() {
      _sidebarWidth = w.clamp(
        ShellBreakpoints.sidebarMinWidth,
        ShellBreakpoints.sidebarMaxWidth,
      );
      _sidebarCollapsed = false;
    });
    _persistSidebar();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = resolveShellMetrics(
      MediaQuery.sizeOf(context).width,
      contextOpen: _contextOpen,
    );
    return CallbackShortcuts(
      bindings: {
        // 空格 / 方向键在输入框聚焦时不拦截（§9）。
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (!_isEditing()) widget.model.toggle();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!_isEditing()) _seekBy(-5000);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!_isEditing()) _seekBy(5000);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          // Esc：先关最上层弹层/面板（§4.3「先关最上层弹层/面板」）——
          // 全屏播放页 > <960 降级侧栏浮层（Stack 最上层）> 右栏
          // ContextPanel（内嵌/浮层）> 路由返回（根 > 内容区内嵌；
          // 根路由恒渲染在内嵌 Navigator 之上，先关根）。
          if (_nowPlayingOpen) {
            _setNowPlayingOpen(false);
            return;
          }
          if (_degradedSidebarOpen) {
            setState(() => _degradedSidebarOpen = false);
            return;
          }
          if (_contextOpen) {
            setState(() => _contextOpen = false);
            return;
          }
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            // 根路由（home 壳层）不能 pop：退而关闭内容区内嵌 Navigator
            // 的推入式详情页（§7.5 推入路由收敛进内容区后对应 Esc 出口）。
            contentNavigatorKey.currentState?.maybePop();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        focusNode: _shellShortcutsFocus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: scheme.surface,
          // 全屏播放页进出转场（§6.5：280-360ms 淡入缩放；关闭减少动效直切）。
          body: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : VxMotion.fullscreenOpen,
            switchInCurve: VxMotion.emphasized,
            switchOutCurve: VxMotion.emphasized.flipped,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [...previousChildren, ?currentChild],
            ),
            child: _nowPlayingOpen
                ? NowPlayingPage(
                    key: const ValueKey('now-playing-fullscreen'),
                    model: widget.model,
                    onClose: () => _setNowPlayingOpen(false),
                  )
                : KeyedSubtree(
                    key: const ValueKey('shell-main'),
                    child: Column(
                      children: [
                        AppHeader(
                          model: widget.model,
                          sidebarWidth: _headerSidebarWidth(metrics),
                          canBack: _back.isNotEmpty,
                          canForward: _forward.isNotEmpty,
                          onBack: _goBack,
                          onForward: _goForward,
                          searchFocusNode: _searchFocus,
                          onSearchSubmit: _onSearchSubmit,
                          contextOpen: _contextOpen,
                          contextTab: _contextTab,
                          onTogglePanel: _togglePanel,
                          onOpenSidebar: () =>
                              setState(() => _degradedSidebarOpen = true),
                        ),
                        Expanded(child: _buildBody(context, metrics)),
                        // 全屏播放页打开时 PlayerBar 不进树（§5.1 防双重控制）。
                        if (!_nowPlayingOpen)
                          PlayerBar(
                            model: widget.model,
                            // Phase 3：封面点击进入全屏播放页。
                            onOpenNowPlaying: () => _setNowPlayingOpen(true),
                            onOpenLyrics: () => setState(() {
                              _contextOpen = true;
                              _contextTab = ContextTab.lyrics;
                            }),
                            onOpenQueue: () => setState(() {
                              _contextOpen = true;
                              _contextTab = ContextTab.queue;
                            }),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ShellMetrics metrics) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 侧栏（hidden 时不占位，由浮层承担）。宽度：未拖调走断点
            // 默认，拖调/折叠后记忆用户值（Phase 6 §7.2 最小语义）。
            if (metrics.sidebar != SidebarMode.hidden)
              AnimatedContainer(
                duration: VxMotion.panelExpand,
                curve: VxMotion.standard,
                // 折叠↔展开过渡期内容（240 全量态）会在动画中的窄容器里
                // 短暂溢出，裁剪掉避免报错/闪破图（2026-11-13 widget 层实证）。
                clipBehavior: Clip.hardEdge,
                width: _effectiveCollapsed(metrics)
                    ? ShellBreakpoints.sidebarCollapsedWidth
                    : _effectiveSidebarWidth,
                // P1-09：Chrome 底色/分隔线随主题亮暗取 token。
                decoration: BoxDecoration(
                  color: VxChrome.surface1(Theme.of(context).brightness),
                  border: Border(
                    right: BorderSide(
                      color: VxChrome.divider(Theme.of(context).brightness),
                    ),
                  ),
                ),
                child: AppSidebar(
                  model: widget.model,
                  current: _current,
                  onSelect: _navigate,
                  collapsed: _effectiveCollapsed(metrics),
                  width: _effectiveSidebarWidth,
                  onWidthChanged: metrics.sidebar == SidebarMode.expanded
                      ? _onSidebarWidthChanged
                      : null,
                  // 折叠开关只在展开档（≥1200）提供；960–1199 硬带无开关。
                  onToggleCollapsed: metrics.sidebar == SidebarMode.expanded
                      ? _toggleSidebarCollapsed
                      : null,
                ),
              ),
            // 中央内容区。内嵌 Navigator 的基页 = IndexedStack 壳页
            // （§7.5/Phase 6「播放器跨页面保持」）：推入式详情页渲染在
            // 内容区内，Header/侧栏/右栏/PlayerBar 不被覆盖。pages API
            // 让壳层 setState 的重建传导进基页（MaterialPage child 每次
            // build 更新，SDK _updateSettings→changedInternalState）。
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(metrics.contentPadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(VxRadius.lg),
                  child: Navigator(
                    key: contentNavigatorKey,
                    pages: [
                      MaterialPage<void>(
                        // 基页恒在（壳层 IndexedStack）：推入式详情页是
                        // pageless 路由（imperative MaterialPageRoute），
                        // pop 走 _RouteEntry.pop 不经本回调；基页自身的
                        // popDisposition 为 bubble（isFirst），maybePop
                        // 不会移除它（SDK navigator.dart:5611 bubble 直返
                        // false），故这里无事可做。
                        child: IndexedStack(
                          index: kShellDestinationOrder.indexOf(_current),
                          children: [
                            for (final dest in kShellDestinationOrder)
                              _pageFor(dest),
                          ],
                        ),
                      ),
                    ],
                    onDidRemovePage: (_) {},
                  ),
                ),
              ),
            ),
            // ≥1440：右栏内嵌。
            if (metrics.context == ContextPanelMode.inline && _contextOpen)
              ContextPanel(
                key: const ValueKey('context-inline'),
                model: widget.model,
                tab: _contextTab,
                onTabChanged: (tab) => setState(() => _contextTab = tab),
                onClose: () => setState(() => _contextOpen = false),
                width: _contextWidth,
                onWidthChanged: (w) => setState(() => _contextWidth = w),
              ),
          ],
        ),
        // <1440：右栏覆盖式浮层。
        if (metrics.context == ContextPanelMode.overlay && _contextOpen) ...[
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
                key: const ValueKey('context-overlay'),
                model: widget.model,
                tab: _contextTab,
                onTabChanged: (tab) => setState(() => _contextTab = tab),
                onClose: () => setState(() => _contextOpen = false),
                width: _contextWidth,
                onWidthChanged: (w) => setState(() => _contextWidth = w),
              ),
            ),
          ),
        ],
        // <960 降级布局：侧栏浮层。
        if (metrics.sidebar == SidebarMode.hidden && _degradedSidebarOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _degradedSidebarOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            // Phase 6：浮层同样跟随记忆的展开宽度（无把手/折叠钮，
            // 浮层是临时导航面，宽调语义归内嵌侧栏）。
            width: _effectiveSidebarWidth,
            child: DecoratedBox(
              // P1-09：浮层侧栏同样随主题亮暗取 token。
              decoration: BoxDecoration(
                color: VxChrome.surface1(Theme.of(context).brightness),
                border: Border(
                  right: BorderSide(
                    color: VxChrome.divider(Theme.of(context).brightness),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: AppSidebar(
                model: widget.model,
                current: _current,
                onSelect: _navigate,
                collapsed: false,
                width: _effectiveSidebarWidth,
              ),
            ),
          ),
        ],
        // 全局 toast（错误/通知统一出口，与旧壳一致）。
        const ToastOverlay(),
      ],
    );
  }

  Widget _pageFor(ShellDestination dest) => buildShellPage(
    widget.model,
    dest,
    searchSeed: _searchSeed,
    libraryTab: _libraryTabFromSeed(),
    settingsSection: _settingsSectionFromSeed(),
  );

  /// VOICEFOX_START_TAB → 我的音乐二级类别（验收截图用）。
  LibraryTab? _libraryTabFromSeed() => switch (widget.libraryTab) {
    'albums' => LibraryTab.albums,
    'artists' => LibraryTab.artists,
    'playlists' => LibraryTab.playlists,
    'songs' => LibraryTab.songs,
    _ => null,
  };

  /// VOICEFOX_START_SECTION → 设置初始分组（验收截图用）。
  SettingsSection? _settingsSectionFromSeed() {
    for (final section in SettingsSection.values) {
      if (section.name == widget.settingsSection) return section;
    }
    return null;
  }
}

/// Shell 页面形态（Phase 2）：同一目的地在不同壳形态下可使用不同页面
/// 实现。桌面缺省 [desktop]（零变化铁律）；MobileShell 传 [mobile]
/// （home 槽产 MobileHomePage，§5.2）；TabletShell 显式维持缺省 desktop
/// （平板 home 槽沿用桌面 HomePage，偏差已登记 04-defect-matrix，
/// 待平板阶段 §6.3 裁决）。
enum ShellFormFactor { desktop, mobile }

/// 构造目的地页面（Phase 7 从 _VoicefoxShellState._pageFor 提取共享）：
/// 桌面 VoicefoxShell 与移动 MobileShell/TabletShell 的 IndexedStack
/// 都用它建页，保证同一目的地在两种壳里是同一页面实现。
/// [searchSeed] 搜索页种子（桌面 Header 提交联动）；[libraryTab]/
/// [settingsSection] 为 VOICEFOX_START_* 验收种子（移动壳默认 null）；
/// [form] 选择壳形态（见 [ShellFormFactor]，缺省 desktop 桌面行为不变）。
Widget buildShellPage(
  AppModel model,
  ShellDestination dest, {
  String searchSeed = '',
  LibraryTab? libraryTab,
  SettingsSection? settingsSection,
  ShellFormFactor form = ShellFormFactor.desktop,
}) {
  return switch (dest) {
    ShellDestination.home =>
      form == ShellFormFactor.mobile ? MobileHomePage(model) : HomePage(model),
    ShellDestination.discover => DiscoverPage(model),
    ShellDestination.search => KeyedSubtree(
      key: ValueKey('search-page:$searchSeed'),
      child: SearchPage(model, seedKeyword: searchSeed),
    ),
    ShellDestination.library => LibraryPage(model, initialTab: libraryTab),
    ShellDestination.downloads => DownloadsPage(model),
    ShellDestination.settings => SettingsPage(
      model,
      initialSection: settingsSection,
    ),
    ShellDestination.help => const HelpPage(),
  };
}
