/// 首页共享内容件（Phase 2 从 home_page.dart 提取）：桌面 HomePage 与
/// 手机 MobileHomePage 同一实现，不复制逻辑。
///
/// - [homeGreeting] / [homeDateLabel]：问候语与日期纯函数（原
///   home_page.dart 私有方法）；
/// - [RecentShelf]：最近播放封面书架，封面/卡宽参数化（桌面 156，手机
///   72 ∈ §5.2「封面 64–76dp」）；播放逻辑（历史作队列起点）单一出处；
/// - [LeaderboardSection]：排行榜精选四态（§9），手机档 compact 尺寸
///   （去掉桌面 480px 定宽骨架，避免 360dp 视口溢出）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_hover.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../design_system/components/vx_artwork.dart';
import 'leaderboard_page.dart';

/// 按当前时段返回问候语（§4.1 / §5.2 问候区）。
String homeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 5) return '夜深了';
  if (hour < 12) return '早上好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

/// 形如「11 月 11 日 · 周二」的日期页签。
String homeDateLabel() {
  final now = DateTime.now();
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${now.month} 月 ${now.day} 日 · ${weekdays[now.weekday - 1]}';
}

/// 最近播放封面书架：VxAlbumCard 横向（桌面封面 156px ∈ 148-168；
/// 手机 72px ∈ §5.2 64-76），hover/点按播放钮 + 双击播放，
/// 播放以整段 history 为队列起点（单一出处）。
class RecentShelf extends StatelessWidget {
  const RecentShelf({
    super.key,
    required this.model,
    required this.history,
    this.coverSize = 156,
  });

  final AppModel model;
  final List<bridge.SongDto> history;

  /// 封面边长（=卡片宽度）；桌面缺省 156，手机传 72。
  final double coverSize;

  void _play(bridge.SongDto song) {
    final queue = List<bridge.SongDto>.of(model.state.history);
    final index = queue.indexWhere(
      (item) => item.id == song.id && item.source == song.source,
    );
    model.playSongs(queue, index: index < 0 ? 0 : index);
  }

  @override
  Widget build(BuildContext context) {
    final cards = history.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(title: '最近播放', onViewAll: () => navRequest.value = 2),
        const SizedBox(height: VxSpacing.md),
        SizedBox(
          // 卡片高 = 封面 + 文案区（与桌面 156/244 的 88px 文案区同构）。
          height: coverSize + 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: VxSpacing.md),
            itemBuilder: (context, index) {
              final song = cards[index];
              return GestureDetector(
                onDoubleTap: () => _play(song),
                child: VxAlbumCard(
                  title: song.name,
                  subtitle: song.singer,
                  width: coverSize,
                  cover: VxArtwork(
                    url: song.coverUrl,
                    source: song.source,
                    entityType: 'song',
                    entityId: song.id,
                    entityName: song.name,
                    size: coverSize,
                    radius: 0,
                    allowRetry: false,
                  ),
                  onTap: () => _play(song),
                  onPlay: () => _play(song),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 排行榜精选：真实 leaderboard 榜单行卡（概念稿 `.chart` 形态），
/// 不是统计卡片。数据取首个支持榜单的音源；四态齐备（§9）。
///
/// [compact] 为手机档：加载骨架不再用桌面 480px 定宽（360dp 视口放不下），
/// 空/错态高度收窄；卡片宽 300 在 360dp 视口（内容区 ≥320）仍可单列放下。
class LeaderboardSection extends StatefulWidget {
  const LeaderboardSection({
    super.key,
    required this.model,
    this.compact = false,
  });

  final AppModel model;

  /// 手机档尺寸（避免桌面定尺寸在窄视口 RenderFlex overflow）。
  final bool compact;

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {
  String? _requestedSource;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 加载触发挂在模型监听里；调度 defer 到帧后执行——模型通知可能发生在
    // build 期，直接触发会让祖先 AnimatedBuilder 在 build 中被标脏。
    _model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant LeaderboardSection oldWidget) {
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
    final capable = _model.state.sources
        .where((source) => source.leaderboard)
        .toList();
    if (capable.isEmpty) return;
    final source = capable.first.id;
    if (_requestedSource == source) return;
    _requestedSource = source;
    _model.loadLeaderboardBoards(source);
  }

  void _openBoard(String sourceId) {
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

  @override
  Widget build(BuildContext context) {
    final capable = _model.state.sources
        .where((source) => source.leaderboard)
        .toList();
    final source = capable.isEmpty ? null : capable.first;
    final result = source == null
        ? null
        : _model.browse('leaderboard_boards', source.id, '');
    final boards = result?.boards ?? const <bridge.LeaderboardDto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: '热门榜单',
          actions: source == null
              ? const <Widget>[]
              : [
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
          onViewAll: source == null ? null : () => _openBoard(source.id),
        ),
        const SizedBox(height: VxSpacing.md),
        _body(context, source, result, boards),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    bridge.SourceCapabilitiesDto? source,
    BrowseResult? result,
    List<bridge.LeaderboardDto> boards,
  ) {
    final compact = widget.compact;
    if (source == null) {
      return SizedBox(
        height: compact ? 200 : 260,
        child: VxEmptyState(
          icon: Icons.leaderboard_outlined,
          title: '没有支持排行榜的音源',
          message: '可在设置中启用支持排行榜的音源，榜单会显示在这里。',
        ),
      );
    }
    if (result == null || (result.loading && boards.isEmpty)) {
      return Align(
        alignment: Alignment.centerLeft,
        // 桌面 480 定宽是桌面网格语义；手机档铺满可用宽度。
        child: SizedBox(
          height: compact ? 160 : 200,
          width: compact ? double.infinity : 480,
          child: const VxLoadingSkeleton.tracks(rows: 3),
        ),
      );
    }
    if (result.error != null) {
      return Container(
        // 固定高在长错误文案下会 overflow；minHeight 保证四态占位且随内容生长。
        constraints: BoxConstraints(minHeight: compact ? 200 : 320),
        alignment: Alignment.center,
        child: VxErrorState(
          title: '榜单加载失败',
          message: '无法读取「${source.name}」的排行榜目录。',
          detail: result.error,
          icon: Icons.cloud_off,
          onRetry: () {
            _requestedSource = null;
            _maybeLoad();
          },
        ),
      );
    }
    if (boards.isEmpty) {
      return SizedBox(
        height: compact ? 200 : 260,
        child: VxEmptyState(
          icon: Icons.leaderboard_outlined,
          title: result.notice ?? '暂无榜单数据',
          message: '该音源没有返回可用榜单。',
        ),
      );
    }
    return Wrap(
      spacing: VxSpacing.md,
      runSpacing: VxSpacing.md,
      children: [
        for (final board in boards.take(8)) _chartCard(context, board),
      ],
    );
  }

  /// 榜单行卡：渐变封面 + 榜单名 + 更新说明（概念稿 `.chart`）。
  Widget _chartCard(BuildContext context, bridge.LeaderboardDto board) {
    final scheme = Theme.of(context).colorScheme;
    return VxHoverBuilder(
      onTap: () => _openBoard(board.source),
      builder: (context, hovering) => AnimatedContainer(
        duration: VxMotion.hoverFade,
        curve: VxMotion.standard,
        width: 300,
        padding: const EdgeInsets.all(VxSpacing.md),
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
                    [_sourceName(board.source), ?board.update].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VxTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _sourceName(String source) =>
      widget.model.capability(source)?.name ?? source;
}
