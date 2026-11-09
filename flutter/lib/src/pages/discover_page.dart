/// 发现页（计划书 §4.2：探索在线音乐，承接多音源能力）。
///
/// 结构：页头（标题 + 音源筛选器 + 刷新）→ 子 Tab（精选歌单 / 排行榜 /
/// 歌手 / 专辑 / 分类）→ 内容区。
/// - 每个 Tab 只在对应音源真实 capabilities 支持时启用；禁用 Tab 带 tooltip；
///   「全部音源」时按各音源能力并集判定（数据按音源分组展示，卡片带来源标识）。
/// - 音源/接口不支持的类型不伪造数据：显示解释文案与可用操作。
/// - 数据通道复用 AppModel browse 分槽（loadPlaylists / loadPlaylistCategories /
///   loadLeaderboardBoards），代码新写于 pages/，不引用 myune 逻辑。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_hover.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_playlist_card.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import 'leaderboard_page.dart';
import 'playlist_detail_page.dart';
import 'search_page.dart';

/// 发现页子 Tab。
enum DiscoverTab { playlists, leaderboard, artists, albums, categories }

/// Tab 标题（与计划书 §4.2 子导航一致）。
String discoverTabLabel(DiscoverTab tab) => switch (tab) {
  DiscoverTab.playlists => '精选歌单',
  DiscoverTab.leaderboard => '排行榜',
  DiscoverTab.artists => '歌手',
  DiscoverTab.albums => '专辑',
  DiscoverTab.categories => '分类',
};

/// Tab 是否可用（真实 SourceCapabilitiesDto）。
///
/// [source] 为 null 表示「全部音源」：按已启用音源的能力并集判定。
/// 纯函数，便于单测禁用逻辑。
bool discoverTabEnabled(
  DiscoverTab tab,
  List<bridge.SourceCapabilitiesDto> sources, {
  String? source,
}) {
  final pool = source == null
      ? sources
      : sources.where((item) => item.id == source);
  return switch (tab) {
    DiscoverTab.playlists => pool.any((item) => item.playlists),
    DiscoverTab.leaderboard => pool.any((item) => item.leaderboard),
    DiscoverTab.artists => pool.any((item) => item.artist),
    DiscoverTab.albums => pool.any((item) => item.album),
    DiscoverTab.categories => pool.any((item) => item.playlistCategories),
  };
}

/// Tab 禁用时的解释文案。
String discoverTabDisabledReason(DiscoverTab tab) => switch (tab) {
  DiscoverTab.playlists => '当前音源不支持浏览歌单',
  DiscoverTab.leaderboard => '当前音源不支持排行榜',
  DiscoverTab.artists => '当前音源不支持歌手浏览',
  DiscoverTab.albums => '当前音源不支持专辑浏览',
  DiscoverTab.categories => '当前音源不提供歌单分类',
};

class DiscoverPage extends StatefulWidget {
  final AppModel model;

  /// 预选音源 id；null 由页面自行选首个可用音源。
  final String? initialSource;

  const DiscoverPage(this.model, {super.key, this.initialSource});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _categoriesKind = 'playlist_categories';
  static const _playlistsKind = 'playlists';
  static const _boardsKind = 'leaderboard_boards';

  /// null = 全部音源（内容按音源分组）。
  String? _source;
  DiscoverTab _tab = DiscoverTab.playlists;
  String _category = '';
  final Set<String> _requestedBoards = {};
  final Set<String> _requestedPlaylistKeys = {};
  String? _categoriesRequested;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 选源与加载挂在模型监听里；调度 defer 到帧后执行——模型通知可能
    // 发生在 build 期，直接触发会让祖先在 build 中被标脏。
    _model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_maybeLoad);
      widget.model.addListener(_maybeLoad);
      _maybeLoad();
    }
  }

  @override
  void dispose() {
    _model.removeListener(_maybeLoad);
    super.dispose();
  }

  bool _loadScheduled = false;

  void _maybeLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      _loadNow();
    });
  }

  void _loadNow() {
    if (_source == null) {
      _loadAggregated();
      return;
    }
    _loadForSource(_source!);
  }

  /// 「全部音源」：给每个支持当前 Tab 数据类型的音源补拉数据。
  void _loadAggregated() {
    final sources = _model.state.sources;
    switch (_tab) {
      case DiscoverTab.playlists:
        for (final source in sources.where((s) => s.playlists)) {
          _ensurePlaylists(source.id, _category);
        }
      case DiscoverTab.leaderboard:
        for (final source in sources.where((s) => s.leaderboard)) {
          if (_requestedBoards.add(source.id)) {
            _model.loadLeaderboardBoards(source.id);
          }
        }
      case DiscoverTab.categories:
        for (final source in sources.where((s) => s.playlistCategories)) {
          _categoriesRequested ??= '';
          if (!_requestedBoards.contains('cat|${source.id}')) {
            _requestedBoards.add('cat|${source.id}');
            _model.loadPlaylistCategories(source.id);
          }
        }
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        break;
    }
  }

  void _loadForSource(String source) {
    switch (_tab) {
      case DiscoverTab.playlists:
        _ensurePlaylists(source, _category);
      case DiscoverTab.leaderboard:
        if (_requestedBoards.add(source)) {
          _model.loadLeaderboardBoards(source);
        }
      case DiscoverTab.categories:
        if (_categoriesRequested != source) {
          _categoriesRequested = source;
          _model.loadPlaylistCategories(source);
        }
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        break;
    }
  }

  void _ensurePlaylists(String source, String category) {
    final key = '$source|$category';
    if (_requestedPlaylistKeys.add(key)) {
      _model.loadPlaylists(source: source, category: category);
    }
  }

  // ── 交互 ──

  void _selectSource(String? id) {
    if (_source == id) return;
    setState(() {
      _source = id;
      _category = '';
      _requestedBoards.clear();
      _requestedPlaylistKeys.clear();
      _categoriesRequested = null;
      // 切源后当前 Tab 可能不再支持：回落到首个支持的 Tab。
      if (!discoverTabEnabled(_tab, _model.state.sources, source: id)) {
        _tab = _firstEnabledTab(id);
      }
    });
    _maybeLoad();
  }

  void _selectTab(DiscoverTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _maybeLoad();
  }

  DiscoverTab _firstEnabledTab(String? source) {
    for (final tab in DiscoverTab.values) {
      if (discoverTabEnabled(tab, _model.state.sources, source: source)) {
        return tab;
      }
    }
    return DiscoverTab.playlists;
  }

  String _sourceName(String source) =>
      _model.capability(source)?.name ?? source;

  List<bridge.SourceCapabilitiesDto> get _playlistSources =>
      _model.state.sources.where((s) => s.playlists).toList();

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final sources = _model.state.sources;
        if (sources.isEmpty) {
          return const VxEmptyState(
            icon: Icons.explore_off,
            title: '没有可用的音源',
            message: '请先在设置中启用至少一个在线音源，再回到发现页。',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pageHead(context),
            const SizedBox(height: VxSpacing.md),
            _tabBar(context, sources),
            const SizedBox(height: VxSpacing.md),
            Expanded(child: _body(context)),
          ],
        );
      },
    );
  }

  Widget _pageHead(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _source != null ? _model.capability(_source!) : null;
    return Padding(
      padding: const EdgeInsets.only(top: VxSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现音乐',
                  style: VxTypography.h1.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: VxSpacing.xs),
                Text(
                  selected == null ? '音源范围：全部音源' : '音源范围：${selected.name}',
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _sourceDropdown(context),
          const SizedBox(width: VxSpacing.sm),
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              _requestedBoards.clear();
              _requestedPlaylistKeys.clear();
              _categoriesRequested = null;
              _maybeLoad();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  /// 音源筛选器：全部音源 / 单源（真实 state.sources）。
  Widget _sourceDropdown(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: '选择音源范围',
      initialValue: _source,
      onSelected: _selectSource,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('全部音源')),
        const PopupMenuDivider(),
        for (final source in _model.state.sources)
          PopupMenuItem<String?>(value: source.id, child: Text(source.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VxSpacing.md,
          vertical: VxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(VxRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.source_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: VxSpacing.sm),
            Text(
              _source == null
                  ? '音源：全部'
                  : '音源：${_model.capability(_source!)?.name ?? _source}',
              style: VxTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: VxSpacing.xs),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _tabBar(
    BuildContext context,
    List<bridge.SourceCapabilitiesDto> sources,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          for (final tab in DiscoverTab.values)
            Padding(
              padding: const EdgeInsets.only(right: VxSpacing.sm),
              child: _tabChip(context, tab, sources, scheme),
            ),
        ],
      ),
    );
  }

  Widget _tabChip(
    BuildContext context,
    DiscoverTab tab,
    List<bridge.SourceCapabilitiesDto> sources,
    ColorScheme scheme,
  ) {
    final enabled = discoverTabEnabled(tab, sources, source: _source);
    final selected = tab == _tab && enabled;
    return Tooltip(
      message: enabled ? discoverTabLabel(tab) : discoverTabDisabledReason(tab),
      child: GestureDetector(
        onTap: enabled ? () => _selectTab(tab) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VxSpacing.lg,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                discoverTabLabel(tab),
                style: VxTypography.caption.copyWith(
                  color: !enabled
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                      : selected
                      ? scheme.primary
                      : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              if (!enabled) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.block_outlined,
                  size: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_tab) {
      case DiscoverTab.playlists:
        return _playlistsBody(context);
      case DiscoverTab.leaderboard:
        return _leaderboardBody(context);
      case DiscoverTab.categories:
        return _categoriesBody(context);
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        return _unsupportedBody(context);
    }
  }

  /// 歌手 / 专辑：后端没有「浏览全部歌手/专辑」的接口（只能从搜索结果或
  /// 歌单详情进入），如实解释，不伪造入口。
  Widget _unsupportedBody(BuildContext context) {
    return VxEmptyState(
      icon: _tab == DiscoverTab.artists
          ? Icons.person_search_outlined
          : Icons.album_outlined,
      title: _tab == DiscoverTab.artists ? '暂不支持浏览全部歌手' : '暂不支持浏览全部专辑',
      message: _tab == DiscoverTab.artists
          ? '在线音源未提供歌手浏览接口：可以在搜索页搜索歌手名，或从歌曲行的「更多」进入歌手页。'
          : '在线音源未提供专辑浏览接口：可以在搜索页搜索专辑名，或从歌曲行进入专辑页面。',
      actionLabel: '去搜索',
      onAction: () => _openSearch(),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('搜索')),
          body: SearchPage(_model),
        ),
      ),
    );
  }

  // ── 精选歌单 ──

  Widget _playlistsBody(BuildContext context) {
    final sources = _playlistSources;
    if (sources.isEmpty) {
      return const VxEmptyState(
        icon: Icons.queue_music_outlined,
        title: '没有支持歌单的音源',
        message: '可在设置中启用支持歌单的音源，推荐歌单会显示在这里。',
      );
    }
    final scoped = _source == null
        ? sources
        : sources.where((s) => s.id == _source).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      children: [for (final source in scoped) _playlistGroup(context, source)],
    );
  }

  Widget _playlistGroup(
    BuildContext context,
    bridge.SourceCapabilitiesDto source,
  ) {
    final result = _model.browse(_playlistsKind, source.id, _category);
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];
    final multiSource = _source == null;

    Widget content;
    if (result == null || (result.loading && playlists.isEmpty)) {
      content = const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 180,
          width: 620,
          child: VxLoadingSkeleton.tracks(rows: 2),
        ),
      );
    } else if (result.error != null) {
      content = SizedBox(
        height: 320,
        child: VxErrorState(
          title: '歌单加载失败',
          message: '无法读取「${source.name}」的推荐歌单。',
          detail: result.error,
          icon: Icons.cloud_off,
          onRetry: () {
            _requestedPlaylistKeys.remove('${source.id}|$_category');
            _ensurePlaylists(source.id, _category);
          },
        ),
      );
    } else if (playlists.isEmpty) {
      content = SizedBox(
        height: 280,
        child: VxEmptyState(
          icon: Icons.queue_music_outlined,
          title: result.notice ?? '暂无歌单数据',
          message: _category.isEmpty ? '该音源没有返回推荐歌单。' : '该分类下没有返回歌单，可以换一个分类。',
        ),
      );
    } else {
      content = SizedBox(
        height: 252,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: playlists.length.clamp(0, 12),
          separatorBuilder: (_, _) => const SizedBox(width: VxSpacing.md),
          itemBuilder: (context, index) =>
              _playlistCard(context, playlists[index]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: multiSource ? source.name : '今日精选',
          eyebrow: multiSource ? '热门歌单' : null,
          actions: [
            if (result?.hasMore ?? false)
              TextButton(
                onPressed: () => _model.loadPlaylists(
                  source: source.id,
                  category: _category,
                  page: (result?.page ?? 0) + 1,
                ),
                child: const Text('加载更多'),
              ),
          ],
        ),
        const SizedBox(height: VxSpacing.md),
        content,
        const SizedBox(height: VxSpacing.sectionGap),
      ],
    );
  }

  Widget _playlistCard(BuildContext context, bridge.PlaylistDto playlist) {
    return VxPlaylistCard(
      title: playlist.name,
      trackCount: playlist.songCount > 0 ? playlist.songCount : null,
      source: _sourceName(playlist.source),
      width: 168,
      cover: (playlist.coverUrl?.isNotEmpty ?? false)
          ? null
          : CoverImage(
              url: playlist.coverUrl,
              size: 168,
              radius: 0,
              icon: Icons.queue_music,
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaylistDetailPage(_model, playlist),
        ),
      ),
    );
  }

  // ── 排行榜 ──

  Widget _leaderboardBody(BuildContext context) {
    final capable = _model.state.sources.where((s) => s.leaderboard).toList();
    if (capable.isEmpty) {
      return const VxEmptyState(
        icon: Icons.leaderboard_outlined,
        title: '没有支持排行榜的音源',
        message: '可在设置中启用支持排行榜的音源，热门榜单会显示在这里。',
      );
    }
    final scoped = _source == null
        ? capable
        : capable.where((s) => s.id == _source).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      children: [
        for (final source in scoped) _leaderboardGroup(context, source),
      ],
    );
  }

  Widget _leaderboardGroup(
    BuildContext context,
    bridge.SourceCapabilitiesDto source,
  ) {
    final result = _model.browse(_boardsKind, source.id, '');
    final boards = result?.boards ?? const <bridge.LeaderboardDto>[];

    Widget content;
    if (result == null || (result.loading && boards.isEmpty)) {
      content = const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 200,
          width: 480,
          child: VxLoadingSkeleton.tracks(rows: 3),
        ),
      );
    } else if (result.error != null) {
      content = SizedBox(
        height: 320,
        child: VxErrorState(
          title: '榜单加载失败',
          message: '无法读取「${source.name}」的排行榜目录。',
          detail: result.error,
          icon: Icons.cloud_off,
          onRetry: () {
            _requestedBoards.remove(source.id);
            if (_requestedBoards.add(source.id)) {
              _model.loadLeaderboardBoards(source.id);
            }
          },
        ),
      );
    } else if (boards.isEmpty) {
      content = SizedBox(
        height: 280,
        child: VxEmptyState(
          icon: Icons.leaderboard_outlined,
          title: result.notice ?? '暂无榜单数据',
          message: '该音源没有返回可用榜单。',
        ),
      );
    } else {
      content = Column(
        children: [
          for (final board in boards.take(10)) _boardRow(context, board),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: '热门榜单',
          eyebrow: '排行榜',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: VxSpacing.sm),
              child: Text(
                source.name,
                style: VxTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          onViewAll: () => _openBoards(source.id),
        ),
        const SizedBox(height: VxSpacing.md),
        content,
        const SizedBox(height: VxSpacing.sectionGap),
      ],
    );
  }

  /// 榜单行：封面 + 名称 / 来源 / 更新说明（§4.2 wireframe 行卡）。
  Widget _boardRow(BuildContext context, bridge.LeaderboardDto board) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: VxSpacing.sm),
      child: _BoardRowCard(
        model: _model,
        board: board,
        scheme: scheme,
        onOpen: () => _openBoards(board.source),
      ),
    );
  }

  void _openBoards(String sourceId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: LeaderboardPage(
            _model,
            initialSource: sourceId,
            showChrome: false,
          ),
        ),
      ),
    );
  }

  // ── 分类 ──

  Widget _categoriesBody(BuildContext context) {
    final capable = _model.state.sources
        .where((s) => s.playlistCategories)
        .toList();
    if (capable.isEmpty) {
      return const VxEmptyState(
        icon: Icons.category_outlined,
        title: '没有提供歌单分类的音源',
        message: '当前启用的音源都不提供歌单分类，可改用「精选歌单」浏览。',
      );
    }
    final scoped = _source == null
        ? capable
        : capable.where((s) => s.id == _source).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      children: [for (final source in scoped) _categoryGroup(context, source)],
    );
  }

  Widget _categoryGroup(
    BuildContext context,
    bridge.SourceCapabilitiesDto source,
  ) {
    final result = _model.browse(_categoriesKind, source.id, '');
    final categories =
        result?.categories ?? const <bridge.PlaylistCategoryDto>[];

    Widget content;
    if (result == null || (result.loading && categories.isEmpty)) {
      content = const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 140,
          width: 480,
          child: VxLoadingSkeleton.tracks(rows: 2),
        ),
      );
    } else if (result.error != null) {
      content = SizedBox(
        height: 320,
        child: VxErrorState(
          title: '分类加载失败',
          message: '无法读取「${source.name}」的歌单分类。',
          detail: result.error,
          icon: Icons.cloud_off,
          onRetry: () {
            _categoriesRequested = null;
            _maybeLoad();
          },
        ),
      );
    } else if (categories.isEmpty) {
      content = SizedBox(
        height: 140,
        child: VxEmptyState(
          icon: Icons.category_outlined,
          title: result.notice ?? '暂无分类数据',
          message: '该音源没有返回歌单分类。',
        ),
      );
    } else {
      content = Wrap(
        spacing: VxSpacing.sm,
        runSpacing: VxSpacing.sm,
        children: [
          for (final category in categories)
            ActionChip(
              label: Text(category.name),
              tooltip: category.group,
              onPressed: () {
                // 点分类：切到单源并加载该分类的歌单。
                setState(() {
                  _source = source.id;
                  _category = category.id;
                  _tab = DiscoverTab.playlists;
                  _requestedBoards.clear();
                  _requestedPlaylistKeys.clear();
                });
                _ensurePlaylists(source.id, category.id);
              },
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: '按分类浏览',
          eyebrow: '分类',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: VxSpacing.sm),
              child: Text(
                source.name,
                style: VxTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: VxSpacing.md),
        content,
        const SizedBox(height: VxSpacing.sectionGap),
      ],
    );
  }
}

/// 榜单行卡（概念稿 `.chart` 的行形态）。
class _BoardRowCard extends StatelessWidget {
  final AppModel model;
  final bridge.LeaderboardDto board;
  final ColorScheme scheme;
  final VoidCallback onOpen;

  const _BoardRowCard({
    required this.model,
    required this.board,
    required this.scheme,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sourceName = model.capability(board.source)?.name ?? board.source;
    return VxHoverBuilder(
      onTap: onOpen,
      builder: (context, hovering) => AnimatedContainer(
        duration: VxMotion.hoverFade,
        curve: VxMotion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: VxSpacing.md,
          vertical: VxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: hovering
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(VxRadius.lg),
          border: Border.all(color: scheme.surfaceContainerHighest),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: VxCoverGradients.forSeed(board.name),
                borderRadius: BorderRadius.circular(VxRadius.sm),
              ),
              child: const Icon(
                Icons.leaderboard_outlined,
                size: 22,
                color: Color(0xCCFFFFFF),
              ),
            ),
            const SizedBox(width: VxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VxTypography.titleSm.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [sourceName, ?board.update].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VxTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.playlist_play, size: 18),
              label: const Text('查看榜单'),
            ),
          ],
        ),
      ),
    );
  }
}
