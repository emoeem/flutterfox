/// 发现页（计划书 §4.2：探索在线音乐，承接多音源能力）。
///
/// 结构：页头（标题 + 音源筛选器 + 刷新）→ 子 Tab（精选歌单 / 排行榜 /
/// 歌手 / 专辑 / 分类）→ 内容区。
/// - 每个 Tab 只在对应音源真实 capabilities 支持时启用；禁用 Tab 带 tooltip；
///   「全部音源」时按各音源能力并集判定（数据按音源分组展示，卡片带来源标识）。
/// - 音源/接口不支持的类型不伪造数据：显示解释文案与可用操作。
/// - 数据通道复用 AppModel browse 分槽（loadPlaylists / loadPlaylistCategories /
///   loadLeaderboardBoards），代码新写于 pages/，不引用 myune 逻辑。
///
/// 业务编排（选择状态、请求键去重、聚合补拉、四态重试）单一出处
/// [DiscoverController]（discover_shared.dart，Batch C-01 提炼）：本页与
/// 手机 MobileDiscoverPage 共用，桌面 UI 行为不变。
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
import '../design_system/components/vx_artwork.dart';
import 'discover_shared.dart';
import 'leaderboard_page.dart';
import 'playlist_detail_page.dart';
import 'search_page.dart';

/// 手机页/测试仍从本文件消费 Tab 能力 API（迁移自本文件的公开面）。
export 'discover_shared.dart'
    show
        DiscoverTab,
        discoverTabLabel,
        discoverTabEnabled,
        discoverTabDisabledReason,
        DiscoverController,
        DiscoverUnsupportedBody;

class DiscoverPage extends StatefulWidget {
  final AppModel model;

  /// 预选音源 id；null 由页面自行选首个可用音源。
  final String? initialSource;

  const DiscoverPage(this.model, {super.key, this.initialSource});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late DiscoverController _ctrl;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    _ctrl = DiscoverController(widget.model);
    _ctrl.attach();
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _ctrl
        ..detach()
        ..dispose();
      _ctrl = DiscoverController(widget.model);
      _ctrl.attach();
    }
  }

  @override
  void dispose() {
    _ctrl
      ..detach()
      ..dispose();
    super.dispose();
  }

  List<bridge.SourceCapabilitiesDto> get _playlistSources =>
      _model.state.sources.where((s) => s.playlists).toList();

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.model, _ctrl]),
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
    final selected = _ctrl.source != null
        ? _model.capability(_ctrl.source!)
        : null;
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
            onPressed: _ctrl.refresh,
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
      // 「全部音源」用哨兵值参与高亮；null 仍表示聚合（P1-20，见
      // DiscoverController.allSourcesSentinel）。
      initialValue: _ctrl.source ?? DiscoverController.allSourcesSentinel,
      onSelected: (id) => _ctrl.selectSource(
        id == DiscoverController.allSourcesSentinel ? null : id,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(
          value: DiscoverController.allSourcesSentinel,
          child: Text('全部音源'),
        ),
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
              _ctrl.source == null
                  ? '音源：全部'
                  : '音源：${discoverSourceName(_model, _ctrl.source!)}',
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
    final enabled = discoverTabEnabled(tab, sources, source: _ctrl.source);
    final selected = tab == _ctrl.tab && enabled;
    return Tooltip(
      message: enabled ? discoverTabLabel(tab) : discoverTabDisabledReason(tab),
      child: GestureDetector(
        onTap: enabled ? () => _ctrl.selectTab(tab) : null,
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
    switch (_ctrl.tab) {
      case DiscoverTab.playlists:
        return _playlistsBody(context);
      case DiscoverTab.leaderboard:
        return _leaderboardBody(context);
      case DiscoverTab.categories:
        return _categoriesBody(context);
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        return DiscoverUnsupportedBody(tab: _ctrl.tab, onSearch: _openSearch);
    }
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
    final scoped = _ctrl.source == null
        ? sources
        : sources.where((s) => s.id == _ctrl.source).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      children: [for (final source in scoped) _playlistGroup(context, source)],
    );
  }

  Widget _playlistGroup(
    BuildContext context,
    bridge.SourceCapabilitiesDto source,
  ) {
    final result = _ctrl.playlistsResult(source.id);
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];
    final multiSource = _ctrl.source == null;

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
          onRetry: () => _ctrl.retryPlaylists(source.id),
        ),
      );
    } else if (playlists.isEmpty) {
      content = SizedBox(
        height: 280,
        child: VxEmptyState(
          icon: Icons.queue_music_outlined,
          title: result.notice ?? '暂无歌单数据',
          message: _ctrl.category.isEmpty
              ? '该音源没有返回推荐歌单。'
              : '该分类下没有返回歌单，可以换一个分类。',
        ),
      );
    } else {
      content = SizedBox(
        height: 252,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // 末尾补 right padding（P2-03）：无内边距时最后一张卡贴住窗口
          // 右缘被裁切；与左缘（与区块标题对齐）保持非对称是设计原样。
          padding: const EdgeInsets.only(right: VxSpacing.lg),
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
                onPressed: () =>
                    _ctrl.loadNextPlaylistsPage(source.id, result!),
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
      source: discoverSourceName(_model, playlist.source),
      width: 168,
      cover: VxArtwork(
        url: playlist.coverUrl,
        source: playlist.source,
        entityType: 'playlist',
        entityId: playlist.id,
        entityName: playlist.name,
        size: 168,
        radius: 0,
        icon: Icons.queue_music,
        allowRetry: false,
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
    final scoped = _ctrl.source == null
        ? capable
        : capable.where((s) => s.id == _ctrl.source).toList();
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
    final result = _ctrl.boardsResult(source.id);
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
          onRetry: () => _ctrl.retryBoards(source.id),
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
    final scoped = _ctrl.source == null
        ? capable
        : capable.where((s) => s.id == _ctrl.source).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      children: [for (final source in scoped) _categoryGroup(context, source)],
    );
  }

  Widget _categoryGroup(
    BuildContext context,
    bridge.SourceCapabilitiesDto source,
  ) {
    final result = _ctrl.categoriesResult(source.id);
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
          onRetry: _ctrl.retryCategories,
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
              onPressed: () => _ctrl.selectCategory(source.id, category.id),
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
    final sourceName = discoverSourceName(model, board.source);
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
