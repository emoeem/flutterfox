/// 歌手详情：Banner + 热门歌曲 + 专辑网格（§4.6）。
///
/// - Banner 高 240（220-260 区间）：有照片用整幅照片，没有照片（或加载
///   失败）用封面渐变色板生成背景，不显示破图；
/// - 「收藏歌手」后端无对应命令：按钮禁用并说明，不伪造；
/// - 相关歌手区域：后端无数据来源，直接隐藏（不造假数据）；
/// - `presetSongs`：本地歌手等无后端详情命令的场景直接展示本地曲目。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artist_banner.dart';
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_cover_fallback.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_table_view.dart';
import 'album_songs_page.dart';
import 'song_tile.dart' show songSourceLabel;

class ArtistDetailPage extends StatefulWidget {
  final AppModel model;
  final bridge.ArtistDto artist;

  /// 本地歌手等场景：直接展示的曲目（来自本地曲库快照）。
  final List<bridge.SongDto>? presetSongs;

  const ArtistDetailPage(
    this.model,
    this.artist, {
    super.key,
    this.presetSongs,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  static const _songsKind = 'artist_songs';
  static const _albumsKind = 'artist_albums';

  AppModel get _model => widget.model;
  bridge.ArtistDto get _artist => widget.artist;

  bool get _preset => widget.presetSongs != null;

  @override
  void initState() {
    super.initState();
    if (_preset) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _model.loadArtistSongs(_artist);
      _model.loadArtistAlbums(_artist);
    });
  }

  BrowseResult? get _songs =>
      _preset ? null : _model.browse(_songsKind, _artist.source, _artist.id);
  BrowseResult? get _albums =>
      _preset ? null : _model.browse(_albumsKind, _artist.source, _artist.id);

  void _reloadSongs() {
    if (_preset) return;
    _model.loadArtistSongs(_artist);
  }

  /// 下拉刷新（§5.6）：只刷新热门歌曲（与既有「刷新」按钮同语义）。
  /// 完成 Future = 本代次 page=1 响应或错误落槽；preset（本地歌手）无
  /// 后端命令，不接下拉（build 分支传 null）。
  Future<void> _refresh() async {
    if (_preset) return;
    final wait = _model.awaitBrowseResponse(
      _songsKind,
      _artist.source,
      _artist.id,
    );
    final error = await _model.loadArtistSongs(_artist);
    if (error != null) return;
    await wait.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// 随机播放：从热门歌曲随机一首开始（顺序继续）。
  void _playShuffled(List<bridge.SongDto> songs) {
    if (songs.length <= 1) {
      _model.playSongs(songs);
      return;
    }
    final index = Random().nextInt(songs.length);
    _model.playSongs(songs, index: index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final songsResult = _songs;
        final hotSongs = _preset
            ? widget.presetSongs!
            : (songsResult?.songs ?? const <bridge.SongDto>[]);
        final body = ListView(
          // preset（本地歌手）无刷新命令，保持默认物理；在线歌手放开
          // AlwaysScrollable 让内容不满一屏也可下拉。
          physics: _preset ? null : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.xl,
            0,
            VxSpacing.xl,
            VxSpacing.xl,
          ),
          children: [
            VxArtistBanner(
              name: _artist.name,
              photoUrl: _artist.coverUrl,
              sourceLabel: songSourceLabel(_model, _artist.source),
              subtitle: hotSongs.isEmpty ? null : '热门歌曲 ${hotSongs.length} 首',
            ),
            const SizedBox(height: VxSpacing.lg),
            _actionRow(context, hotSongs),
            const SizedBox(height: VxSpacing.sectionGap),
            _hotSongs(context, songsResult, hotSongs),
            const SizedBox(height: VxSpacing.sectionGap),
            if (!_preset) _albumsSection(context),
          ],
        );
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _backBar(context),
              Expanded(
                // preset（本地歌手）无刷新命令不接下拉：否则 spinner 永不
                // 完成（§9 不允许永久悬挂）。
                child: _preset
                    ? body
                    : RefreshIndicator(onRefresh: _refresh, child: body),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _backBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: VxSpacing.md),
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          Expanded(
            child: Text(
              _artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VxTypography.titleSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, List<bridge.SongDto> songs) {
    return Wrap(
      spacing: VxSpacing.sm,
      runSpacing: VxSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: songs.isEmpty ? null : () => _model.playSongs(songs),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(songs.isEmpty ? '暂无可播放曲目' : '播放'),
        ),
        OutlinedButton.icon(
          onPressed: songs.isEmpty ? null : () => _playShuffled(songs),
          icon: const Icon(Icons.shuffle, size: 18),
          label: const Text('随机播放'),
        ),
        // 后端没有「关注/收藏歌手」命令：按钮保持可见但禁用并说明原因。
        Tooltip(
          message: '后端暂不支持收藏歌手',
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.favorite_border, size: 18),
            label: const Text('收藏歌手'),
          ),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: _reloadSongs,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }

  Widget _hotSongs(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(title: '热门歌曲'),
        const SizedBox(height: VxSpacing.sm),
        SizedBox(
          height: _tableHeight(context, songs.length, result),
          child: VxSongTable(
            model: _model,
            songs: songs,
            loading: !_preset && (result == null || result.loading),
            error: result?.error,
            notice: result?.notice,
            emptyTitle: '歌手暂无歌曲',
            onRetry: _reloadSongs,
            hasMore: result?.hasMore ?? false,
            onLoadMore: () {
              if (result == null || result.loading) return;
              _model.loadArtistSongs(_artist, page: result.page + 1);
            },
          ),
        ),
      ],
    );
  }

  double _tableHeight(BuildContext context, int count, BrowseResult? result) {
    if (result?.hasMore ?? false) return 400;
    // 全部载入时按行数给高度（每行 58px），至少占位两行。
    return (count * 58.0 + 8).clamp(120.0, 640.0);
  }

  Widget _albumsSection(BuildContext context) {
    final result = _albums;
    final albums = result?.albums ?? const <bridge.AlbumDto>[];
    if (result == null || (result.loading && albums.isEmpty)) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (result.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VxSectionHeader(title: '专辑'),
          const SizedBox(height: VxSpacing.sm),
          VxEmptyState(
            icon: Icons.album_outlined,
            title: '专辑加载失败',
            message: result.error!,
            actionLabel: '重试',
            onAction: () => _model.loadArtistAlbums(_artist),
          ),
        ],
      );
    }
    if (albums.isEmpty) {
      // 没有专辑数据就整块收起标题，只留一句说明；不伪造占位专辑。
      return VxEmptyState(
        icon: Icons.album_outlined,
        title: result.notice ?? '暂无专辑数据',
        message: '该音源未返回歌手的专辑列表。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: '专辑',
          onViewAll: result.hasMore
              ? () => _model.loadArtistAlbums(_artist, page: result.page + 1)
              : null,
          viewAllLabel: result.hasMore ? '加载更多' : '查看全部',
        ),
        const SizedBox(height: VxSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            const minCard = 156;
            final columns = (constraints.maxWidth ~/ minCard).clamp(2, 6);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: VxSpacing.lg,
                crossAxisSpacing: VxSpacing.lg,
                // VxCardShell 内容高 ≈ 宽+60（两行标题），0.72 留余量。
                childAspectRatio: 0.72,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) =>
                  _albumCard(context, albums[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _albumCard(BuildContext context, bridge.AlbumDto album) {
    final url = album.coverUrl;
    return Center(
      child: VxAlbumCard(
        title: album.name,
        subtitle: album.artist.trim().isEmpty ? null : album.artist,
        cover: (url == null || url.isEmpty)
            // 无封面：渐变首字母占位，不用灰音符块。
            ? VxCoverFallback(title: album.name, radius: VxRadius.lg)
            : CoverImage.expand(
                url: url,
                radius: VxRadius.lg,
                icon: Icons.album_outlined,
              ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AlbumSongsPage(_model, album),
            ),
          );
        },
      ),
    );
  }
}
