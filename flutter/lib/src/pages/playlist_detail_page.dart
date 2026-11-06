/// 歌单详情页：DetailHero + 操作区 + 曲目表（§4.7）。
///
/// - 顶部横向 Hero：封面 224px、名称、来源徽章、歌曲数 / 总时长、描述；
/// - 主按钮「播放全部」、次按钮「随机播放」；收藏 / 同步 / 更多在次级
///   操作区（同步 Diff、推送等流程都在对话框内收口，不占主页面）；
/// - 在线歌单展示音源来源；账号歌单（远程镜像）与公开歌单以徽章区分；
/// - 数据结果按 `browseKind + source + id` 从 AppModel 读取，播放只走
///   现有 `playSongs` / `queueAdd`，不新建播放控制。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_detail_hero.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/push_dialog.dart';
import '../widgets/song_table_view.dart';
import '../widgets/sync_dialog.dart';
import 'song_tile.dart' show songSourceLabel;

class PlaylistDetailPage extends StatefulWidget {
  final AppModel model;
  final bridge.PlaylistDto playlist;

  /// true = 账号歌单镜像（读远程缓存），false = 在线音源公开歌单。
  final bool account;

  const PlaylistDetailPage(
    this.model,
    this.playlist, {
    super.key,
    this.account = false,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  AppModel get _model => widget.model;
  bridge.PlaylistDto get _playlist => widget.playlist;
  bool get _account => widget.account;

  String get _kind => _account ? 'account_playlist_detail' : 'playlist_detail';

  BrowseResult? get _result =>
      _model.browse(_kind, _playlist.source, _playlist.id);

  void _reload() {
    if (_account) {
      _model.loadAccountPlaylistDetail(_playlist.source, _playlist.id);
    } else {
      _model.loadPlaylistDetail(_playlist);
    }
  }

  /// 账号歌单没有分页；在线歌单继续加载下一页。
  void _loadMore() {
    if (_account) return;
    final result = _result;
    if (result == null || result.loading) return;
    _model.loadPlaylistDetail(_playlist, page: result.page + 1);
  }

  /// 歌单是否已在本地收藏（收藏歌单镜像里按 source + id 匹配）。
  bool get _isFavoritePlaylist => _model.state.favoritePlaylists.any(
        (item) => item.id == _playlist.id && item.source == _playlist.source,
      );

  void _toggleFavoritePlaylist() {
    _model.dispatch(
      _isFavoritePlaylist
          ? bridge.FfiCommand.favoritePlaylistRemove(playlist: _playlist)
          : bridge.FfiCommand.favoritePlaylistAdd(playlist: _playlist),
    );
  }

  /// 随机播放：从已载入曲目随机选一首开始（顺序继续）。
  void _playShuffled(List<bridge.SongDto> songs) {
    if (songs.length <= 1) {
      _model.playSongs(songs);
      return;
    }
    final index = Random().nextInt(songs.length);
    _model.playSongs(songs, index: index);
  }

  /// 已载入曲目总时长（缺时长的曲目不计入）。
  Duration _totalDuration(List<bridge.SongDto> songs) {
    var ms = 0;
    for (final song in songs) {
      final d = song.durationMs.toInt();
      if (d > 0) ms += d;
    }
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _backBar(context),
              _hero(context, result, songs),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VxSpacing.xl,
                  VxSpacing.lg,
                  VxSpacing.xl,
                  0,
                ),
                child: VxSectionHeader(title: '曲目列表'),
              ),
              Expanded(
                child: VxSongTable(
                  model: _model,
                  songs: songs,
                  loading: result == null || (result.loading && songs.isEmpty),
                  error: result?.error,
                  notice: result?.notice,
                  emptyTitle: '歌单暂无曲目',
                  emptySubtitle: '换一个歌单试试',
                  onRetry: _reload,
                  hasMore: result?.hasMore ?? false,
                  onLoadMore: _loadMore,
                ),
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
              _playlist.name,
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

  Widget _hero(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    final duration = _totalDuration(songs);
    final meta = <String>[
      '${_playlist.songCount} 首',
      if (songs.isNotEmpty && songs.length != _playlist.songCount)
        '已载入 ${songs.length}',
      if (duration.inSeconds > 0) '总时长 ${duration.inMinutes} 分钟',
    ];
    final description = _playlist.description?.trim();
    return VxDetailHero(
      eyebrow: _account ? '账号歌单' : '歌单',
      title: _playlist.name,
      meta: meta,
      badges: [
        songSourceLabel(_model, _playlist.source),
        if (_account) '账号镜像',
      ],
      description: (description == null || description.isEmpty)
          ? null
          : description,
      cover: (_playlist.coverUrl == null || _playlist.coverUrl!.isEmpty)
          ? null
          : CoverImage(
              url: _playlist.coverUrl,
              size: 224,
              radius: 12,
              icon: Icons.queue_music_outlined,
            ),
      fallbackSeed: _playlist.name,
      actions: [
        VxDetailAction(
          icon: Icons.play_arrow,
          label: songs.isEmpty ? '暂无可播放曲目' : '播放全部',
          primary: true,
          onPressed: songs.isEmpty ? null : () => _model.playSongs(songs),
        ),
        VxDetailAction(
          icon: Icons.shuffle,
          label: '随机播放',
          tooltip: songs.isEmpty
              ? '曲目加载后可用'
              : '从已载入曲目随机一首开始（顺序继续）',
          onPressed: songs.isEmpty ? null : () => _playShuffled(songs),
        ),
        VxDetailAction(
          icon: _isFavoritePlaylist ? Icons.favorite : Icons.favorite_border,
          label: _isFavoritePlaylist ? '取消收藏' : '收藏',
          onPressed: _toggleFavoritePlaylist,
        ),
        // 同步只对账号歌单有意义：Diff 预览/写入都在对话框内收口。
        if (_account)
          VxDetailAction(
            icon: Icons.sync_outlined,
            label: '同步',
            tooltip: '预览远端与本地镜像差异并同步（对话框内完成）',
            onPressed: () =>
                showSyncDialog(context, _model, _playlist.source),
          ),
      ],
      trailingActions: [
        PopupMenuButton<String>(
          tooltip: '更多操作',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == 'refresh') _reload();
            if (action == 'push') {
              showPushDialog(
                context,
                _model,
                localName: _playlist.name,
                songs: songs,
                isFavorites: false,
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'refresh', child: Text('刷新')),
            PopupMenuItem(
              value: 'push',
              enabled: songs.isNotEmpty,
              child: Text(
                songs.isNotEmpty ? '推送到远端' : '推送到远端（曲目加载后可用）',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
