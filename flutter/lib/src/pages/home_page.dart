/// 首页（计划书 §4.1：音乐内容首页，不是统计仪表盘）。
///
/// 结构：问候 + 日期页头 → Continue Listening Hero（真实 `state.history` /
/// 当前播放曲目；无历史时切换「导入本地音乐 / 搜索在线音乐」引导）→
/// 最近播放封面书架（VxAlbumCard 横向）→ 我的歌单（VxPlaylistCard，
/// 真实 `state.customPlaylists`）→ 排行榜精选（真实 leaderboard 榜单行卡）。
///
/// Phase 0 S1：旧版底部 6 大卡片快捷导航与工具统计卡片已删除；
/// 空态 / 加载态统一走 design_system 三态组件。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_hero.dart';
import '../design_system/components/vx_hover.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_playlist_card.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../design_system/components/vx_artwork.dart';
import 'leaderboard_page.dart';

class HomePage extends StatelessWidget {
  final AppModel model;

  const HomePage(this.model, {super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month} 月 ${now.day} 日 · ${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final history = model.state.history;
        final greeting = _greeting();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.pagePadding,
            VxSpacing.lg,
            VxSpacing.pagePadding,
            VxSpacing.xxl,
          ),
          children: [
            _PageHead(greeting: greeting, dateLabel: _dateLabel()),
            const SizedBox(height: VxSpacing.lg),
            _ContinueHero(model: model, greeting: greeting),
            const SizedBox(height: VxSpacing.sectionGap),
            if (history.isNotEmpty) ...[
              _RecentShelf(model: model, history: history),
              const SizedBox(height: VxSpacing.sectionGap),
            ],
            _MyPlaylistsSection(model: model),
            const SizedBox(height: VxSpacing.sectionGap),
            _LeaderboardSection(model: model),
          ],
        );
      },
    );
  }
}

/// 页头：问候语（H1）+ 日期（弱色 caption），右侧不放工具开关（§4.1）。
class _PageHead extends StatelessWidget {
  final String greeting;
  final String dateLabel;

  const _PageHead({required this.greeting, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: VxTypography.h1.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: VxSpacing.xs),
        Text(
          dateLabel,
          style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Continue Listening Hero：有内容时展示最近曲目，无历史时展示引导（§4.1）。
class _ContinueHero extends StatelessWidget {
  final AppModel model;
  final String greeting;

  const _ContinueHero({required this.model, required this.greeting});

  @override
  Widget build(BuildContext context) {
    final playbackSong = model.state.playback.song;
    final history = model.state.history;
    final bridge.SongDto? song =
        playbackSong ?? (history.isEmpty ? null : history.first);

    if (song == null) {
      return VxHero(
        eyebrow: '开始使用',
        title: greeting,
        description: '曲库还是空的：导入本地音乐，或搜索在线音乐开始收听。',
        // Hero 固定 178px 大封面：窄窗（<960）下文案区只有 ~260px，
        // 按钮用短文案避免溢出；完整引导写在说明行。
        primaryLabel: '搜索音乐',
        onPrimary: () => navRequest.value = 1,
        secondaryLabel: '导入本地',
        onSecondary: () => navRequest.value = 5,
        fallbackSeed: greeting,
      );
    }

    final playing = model.state.playback.state == 'playing';
    final album = song.albumName;
    final description = album.isEmpty ? song.singer : '${song.singer} · $album';
    return VxHero(
      eyebrow: 'CONTINUE LISTENING',
      title: song.name,
      description: description,
      // 正在播 ⇒ 暂停；否则继续播放（恢复当前曲目或播放最近一首）。
      primaryLabel: playing ? '暂停' : '继续播放',
      onPrimary: () => _resume(model, song, playing),
      cover: VxArtwork(
        url: song.coverUrl,
        source: song.source,
        entityType: 'song',
        entityId: song.id,
        entityName: song.name,
        size: 178,
        radius: 0,
        icon: Icons.music_note_outlined,
        allowRetry: false,
      ),
      fallbackSeed: song.name,
    );
  }

  void _resume(AppModel model, bridge.SongDto song, bool playing) {
    if (playing || model.state.playback.song != null) {
      model.toggle();
      return;
    }
    // 无播放上下文：把最近播放（含这首）作为队列起点。
    final queue = List<bridge.SongDto>.of(model.state.history);
    if (queue.isEmpty) {
      model.playSong(song);
      return;
    }
    model.playSongs(queue, index: 0);
  }
}

/// 最近播放封面书架：VxAlbumCard 横向（封面 156px ∈ 148-168），
/// hover 播放钮 + 双击播放。
class _RecentShelf extends StatelessWidget {
  final AppModel model;
  final List<bridge.SongDto> history;

  const _RecentShelf({required this.model, required this.history});

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
          height: 244,
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
                  width: 156,
                  cover: VxArtwork(
                    url: song.coverUrl,
                    source: song.source,
                    entityType: 'song',
                    entityId: song.id,
                    entityName: song.name,
                    size: 156,
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

/// 我的歌单：真实 `state.customPlaylists`（本地自建歌单），点卡片进曲库。
class _MyPlaylistsSection extends StatelessWidget {
  final AppModel model;

  const _MyPlaylistsSection({required this.model});

  @override
  Widget build(BuildContext context) {
    final playlists = model.state.customPlaylists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(title: '我的歌单', onViewAll: () => navRequest.value = 2),
        const SizedBox(height: VxSpacing.md),
        if (playlists.isEmpty)
          SizedBox(
            height: 280,
            child: VxEmptyState(
              icon: Icons.playlist_add,
              title: '还没有自建歌单',
              message: '在曲库页点「新建歌单」，或把喜欢的歌曲加入歌单。',
              actionLabel: '去曲库',
              onAction: () => navRequest.value = 2,
            ),
          )
        else
          SizedBox(
            height: 244,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length.clamp(0, 12),
              separatorBuilder: (_, _) => const SizedBox(width: VxSpacing.md),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return VxPlaylistCard(
                  title: playlist.name,
                  trackCount: playlist.songCount,
                  width: 156,
                  cover: VxArtwork(
                    url: playlist.coverUrl,
                    // 自建歌单是本地实体（CustomPlaylistSummaryDto 无 source
                    // 字段），缓存键固定 local 命名空间。
                    source: 'local',
                    entityType: 'playlist',
                    entityId: playlist.id,
                    entityName: playlist.name,
                    size: 156,
                    radius: 0,
                    icon: Icons.queue_music,
                    allowRetry: false,
                  ),
                  onTap: () => navRequest.value = 2,
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 排行榜精选：真实 leaderboard 榜单行卡（概念稿 `.chart` 形态），
/// 不是统计卡片。数据取首个支持榜单的音源。
class _LeaderboardSection extends StatefulWidget {
  final AppModel model;

  const _LeaderboardSection({required this.model});

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
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
  void didUpdateWidget(covariant _LeaderboardSection oldWidget) {
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
    if (source == null) {
      return SizedBox(
        height: 260,
        child: VxEmptyState(
          icon: Icons.leaderboard_outlined,
          title: '没有支持排行榜的音源',
          message: '可在设置中启用支持排行榜的音源，榜单会显示在这里。',
        ),
      );
    }
    if (result == null || (result.loading && boards.isEmpty)) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 200,
          width: 480,
          child: VxLoadingSkeleton.tracks(rows: 3),
        ),
      );
    }
    if (result.error != null) {
      return SizedBox(
        height: 320,
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
        height: 260,
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
