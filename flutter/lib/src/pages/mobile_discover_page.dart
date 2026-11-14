/// 手机发现页（计划书 C-01，指南 §5.3：探索在线音乐的手机档布局）。
///
/// 布局顺序：页首标题「发现」（含刷新）→ 音源筛选 chips（单行横滚，
/// 「全部音源」↔ 单源可往返，P1-20 语义与桌面同一出处 [DiscoverController]）
/// → 子 Tab chips（单行横滚，能力不支持的 Tab 如实禁用并给原因）→ 内容区。
///
/// - 内容按 Tab：精选歌单（按音源分组、两列网格卡：封面 1:1、标题两行、
///   来源/曲目数小字、组内加载更多）/ 排行榜（榜单行卡）/ 分类（chips，
///   点选切到该源该分类的歌单）/ 歌手·专辑（无浏览接口如实解释）；
/// - 组级四态齐备（§9）：Loading 骨架 / 错误+重试 / 空态 / 加载更多；
///   单一源失败不隐藏其他源内容（部分成功：分组各自渲染各自状态）；
/// - 数据编排全部走共享 [DiscoverController]（discover_shared.dart）与
///   AppModel browse 分槽，业务与桌面页同一实现，本页只做布局与交互；
/// - 无自带 Scaffold：直接作为 MobileShell body（inset 契约见
///   shell/android_insets.dart——状态栏由 AppBar 消费、导航条由
///   bottomNavigationBar 消费，滚动区不加第二份）；
/// - 触控目标 ≥48dp（chips 行含上下触控余量、行卡 ≥56dp）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_playlist_card.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import 'discover_shared.dart';
import 'leaderboard_page.dart';
import 'playlist_detail_page.dart';

class MobileDiscoverPage extends StatefulWidget {
  final AppModel model;

  const MobileDiscoverPage(this.model, {super.key});

  @override
  State<MobileDiscoverPage> createState() => _MobileDiscoverPageState();
}

class _MobileDiscoverPageState extends State<MobileDiscoverPage> {
  late DiscoverController _ctrl;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    _ctrl = DiscoverController(widget.model);
    _ctrl.attach();
  }

  @override
  void didUpdateWidget(covariant MobileDiscoverPage oldWidget) {
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _head(context),
            const SizedBox(height: VxSpacing.md),
            _sourceChips(context, sources),
            const SizedBox(height: VxSpacing.xs),
            _tabChips(context, sources),
            const SizedBox(height: VxSpacing.md),
            ..._body(),
          ],
        );
      },
    );
  }

  // ── 页首与筛选 ──

  Widget _head(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _ctrl.source != null
        ? _model.capability(_ctrl.source!)
        : null;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发现',
                style: VxTypography.h2.copyWith(color: scheme.onSurface),
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
        IconButton(
          tooltip: '刷新',
          onPressed: _ctrl.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  /// 音源筛选 chips：全部音源 / 单源。P1-20 语义与桌面同一出处：chips 无
  /// PopupMenu null 吞没问题，但「单源 → 全部音源」必须真实回到聚合视图并
  /// 重载（selectSource(null) 清请求键重发），测试锁定该往返。
  Widget _sourceChips(
    BuildContext context,
    List<bridge.SourceCapabilitiesDto> sources,
  ) {
    return SizedBox(
      key: const ValueKey('mobile-discover-sources'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            context,
            label: '全部音源',
            selected: _ctrl.source == null,
            onTap: () => _ctrl.selectSource(null),
          ),
          for (final source in sources)
            _chip(
              context,
              label: source.name,
              selected: _ctrl.source == source.id,
              onTap: () => _ctrl.selectSource(source.id),
            ),
        ],
      ),
    );
  }

  /// 子 Tab chips：能力不支持的 Tab 如实禁用（弱化 + 阻断图标 + 原因 tooltip），
  /// 判定复用桌面页同一实现（discoverTabEnabled，全部音源按能力并集）。
  Widget _tabChips(
    BuildContext context,
    List<bridge.SourceCapabilitiesDto> sources,
  ) {
    return SizedBox(
      key: const ValueKey('mobile-discover-tabs'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final tab in DiscoverTab.values)
            _chip(
              context,
              label: discoverTabLabel(tab),
              selected:
                  tab == _ctrl.tab &&
                  discoverTabEnabled(tab, sources, source: _ctrl.source),
              onTap: discoverTabEnabled(tab, sources, source: _ctrl.source)
                  ? () => _ctrl.selectTab(tab)
                  : null,
              tooltip: discoverTabEnabled(tab, sources, source: _ctrl.source)
                  ? discoverTabLabel(tab)
                  : discoverTabDisabledReason(tab),
              disabled: !discoverTabEnabled(tab, sources, source: _ctrl.source),
            ),
        ],
      ),
    );
  }

  /// 紧凑 chips：视觉胶囊 32dp + 上下触控余量各 8dp = 触控目标 48dp（§5.9）。
  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    VoidCallback? onTap,
    String? tooltip,
    bool disabled = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final pill = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
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
            label,
            style: VxTypography.caption.copyWith(
              color: disabled
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : selected
                  ? scheme.primary
                  : scheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (disabled) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.block_outlined,
              size: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: VxSpacing.sm),
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: pill,
          ),
        ),
      ),
    );
  }

  // ── 内容区 ──

  List<Widget> _body() {
    switch (_ctrl.tab) {
      case DiscoverTab.playlists:
        return _playlistsBody();
      case DiscoverTab.leaderboard:
        return _leaderboardBody();
      case DiscoverTab.categories:
        return _categoriesBody();
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        // 歌手/专辑无浏览接口：如实解释（桌面页同一文案），「去搜索」切
        // 搜索目的地（手机壳消费 navRequest）。VxEmptyState 的居中滚动
        // 结构需要有界高（ListView 子项无界），给固定槽高。
        return [
          SizedBox(
            height: 280,
            child: DiscoverUnsupportedBody(
              tab: _ctrl.tab,
              onSearch: () => navRequest.value = 1,
            ),
          ),
        ];
    }
  }

  // ── 精选歌单 ──

  List<Widget> _playlistsBody() {
    final capable = _model.state.sources.where((s) => s.playlists).toList();
    if (capable.isEmpty) {
      return const [
        SizedBox(
          height: 200,
          child: VxEmptyState(
            icon: Icons.queue_music_outlined,
            title: '没有支持歌单的音源',
            message: '可在设置中启用支持歌单的音源，推荐歌单会显示在这里。',
          ),
        ),
      ];
    }
    final scoped = _ctrl.source == null
        ? capable
        : capable.where((s) => s.id == _ctrl.source).toList();
    return [for (final source in scoped) _playlistGroup(source)];
  }

  /// 歌单组：组级四态（载入骨架 / 错误+重试 / 空态 / 两列网格 + 加载更多）。
  /// 组与组相互独立：单一源失败不隐藏其他源内容（部分成功）。
  Widget _playlistGroup(bridge.SourceCapabilitiesDto source) {
    final result = _ctrl.playlistsResult(source.id);
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];
    final multiSource = _ctrl.source == null;

    Widget content;
    if (result == null || (result.loading && playlists.isEmpty)) {
      content = const SizedBox(
        height: 160,
        width: double.infinity,
        child: VxLoadingSkeleton.tracks(rows: 2),
      );
    } else if (result.error != null) {
      content = Container(
        // 固定高在长错误文案下会 overflow；minHeight 随内容生长。
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
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
        height: 200,
        child: VxEmptyState(
          icon: Icons.queue_music_outlined,
          title: result.notice ?? '暂无歌单数据',
          message: _ctrl.category.isEmpty
              ? '该音源没有返回推荐歌单。'
              : '该分类下没有返回歌单，可以换一个分类。',
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _playlistGrid(playlists),
          if (result.hasMore) ...[
            const SizedBox(height: VxSpacing.md),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _ctrl.loadNextPlaylistsPage(source.id, result),
                child: const Text('加载更多'),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: multiSource ? source.name : '今日精选',
          eyebrow: multiSource ? '热门歌单' : null,
        ),
        const SizedBox(height: VxSpacing.md),
        content,
        const SizedBox(height: VxSpacing.sectionGap),
      ],
    );
  }

  /// 两列网格卡：封面 1:1、标题两行、来源/曲目数小字（VxPlaylistCard 与
  /// 桌面同一卡片基座；宽度随视口两等分，触控目标 ≥48dp 由卡面保证）。
  Widget _playlistGrid(List<bridge.PlaylistDto> playlists) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = VxSpacing.md;
        final cardWidth = (width - spacing) / 2;
        // 封面(1:1) + 间距 + 标题两行 + 副标题一行（VxCardShell 文案区）。
        final cellHeight = cardWidth + 72;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cellHeight,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return VxPlaylistCard(
              title: playlist.name,
              trackCount: playlist.songCount > 0 ? playlist.songCount : null,
              source: discoverSourceName(_model, playlist.source),
              width: cardWidth,
              cover: VxArtwork(
                url: playlist.coverUrl,
                source: playlist.source,
                entityType: 'playlist',
                entityId: playlist.id,
                entityName: playlist.name,
                size: cardWidth,
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
          },
        );
      },
    );
  }

  // ── 排行榜 ──

  List<Widget> _leaderboardBody() {
    final capable = _model.state.sources.where((s) => s.leaderboard).toList();
    if (capable.isEmpty) {
      return const [
        SizedBox(
          height: 200,
          child: VxEmptyState(
            icon: Icons.leaderboard_outlined,
            title: '没有支持排行榜的音源',
            message: '可在设置中启用支持排行榜的音源，热门榜单会显示在这里。',
          ),
        ),
      ];
    }
    final scoped = _ctrl.source == null
        ? capable
        : capable.where((s) => s.id == _ctrl.source).toList();
    return [for (final source in scoped) _leaderboardGroup(source)];
  }

  Widget _leaderboardGroup(bridge.SourceCapabilitiesDto source) {
    final result = _ctrl.boardsResult(source.id);
    final boards = result?.boards ?? const <bridge.LeaderboardDto>[];

    Widget content;
    if (result == null || (result.loading && boards.isEmpty)) {
      // rows:3 骨架自然高 58×3+8×2 = 190，槽高取 200 不裁切。
      content = const SizedBox(
        height: 200,
        width: double.infinity,
        child: VxLoadingSkeleton.tracks(rows: 3),
      );
    } else if (result.error != null) {
      content = Container(
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
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
        height: 200,
        child: VxEmptyState(
          icon: Icons.leaderboard_outlined,
          title: result.notice ?? '暂无榜单数据',
          message: '该音源没有返回可用榜单。',
        ),
      );
    } else {
      content = Column(
        children: [
          for (final board in boards.take(10)) _boardTile(context, board),
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

  /// 榜单行卡：触控目标 ≥56dp；封面 + 名称 / 来源·更新说明 + 查看入口。
  Widget _boardTile(BuildContext context, bridge.LeaderboardDto board) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: VxSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        onTap: () => _openBoards(board.source),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: VxSpacing.md,
            vertical: VxSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
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
                      [
                        discoverSourceName(_model, board.source),
                        ?board.update,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VxTypography.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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

  List<Widget> _categoriesBody() {
    final capable = _model.state.sources
        .where((s) => s.playlistCategories)
        .toList();
    if (capable.isEmpty) {
      return const [
        SizedBox(
          height: 200,
          child: VxEmptyState(
            icon: Icons.category_outlined,
            title: '没有提供歌单分类的音源',
            message: '当前启用的音源都不提供歌单分类，可改用「精选歌单」浏览。',
          ),
        ),
      ];
    }
    final scoped = _ctrl.source == null
        ? capable
        : capable.where((s) => s.id == _ctrl.source).toList();
    return [for (final source in scoped) _categoryGroup(source)];
  }

  Widget _categoryGroup(bridge.SourceCapabilitiesDto source) {
    final result = _ctrl.categoriesResult(source.id);
    final categories =
        result?.categories ?? const <bridge.PlaylistCategoryDto>[];

    Widget content;
    if (result == null || (result.loading && categories.isEmpty)) {
      content = const SizedBox(
        height: 140,
        width: double.infinity,
        child: VxLoadingSkeleton.tracks(rows: 2),
      );
    } else if (result.error != null) {
      content = Container(
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
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
        height: 160,
        child: VxEmptyState(
          icon: Icons.category_outlined,
          title: result.notice ?? '暂无分类数据',
          message: '该音源没有返回歌单分类。',
        ),
      );
    } else {
      content = Wrap(
        spacing: VxSpacing.sm,
        runSpacing: VxSpacing.xs,
        children: [
          for (final category in categories)
            _chip(
              context,
              label: category.name,
              selected: false,
              tooltip: category.group,
              // 点分类：切到单源并加载该分类的歌单（桌面页同一编排）。
              onTap: () => _ctrl.selectCategory(source.id, category.id),
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
