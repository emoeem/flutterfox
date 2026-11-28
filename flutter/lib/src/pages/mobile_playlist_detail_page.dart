/// 歌单详情手机页（Batch C-C C-04 / R6，SR-03 手机 8 页复用桌面收敛）。
///
/// 布局（V2 spec 语言，`docs/redesign/ui-redesign-v2/design-spec.md` §4）：
/// - Shape B 推入路由：自带 Scaffold + AppBar（推入路由自担系统 inset，
///   契约同 `mobile_local_music_page.dart`）；
/// - 沉浸头部：封面（VxArtwork 120）+ 名称（最多 2 行）+ 来源徽标 + N 首 +
///   播放全部（accent 主钮）/ 随播放全部（幽灵钮）；
/// - 曲目列表 VxTrackRow comfortable，点按整列播放（C-A 既有口径），
///   长按/更多开共享桌面菜单 showSongMenu（一套动作，触屏适配）；
/// - 四态齐全：加载骨架 / 空歌单 / 加载失败（错误 + 重试）/ 完成。
///
/// 数据：直接消费 AppModel browse 槽（与桌面 PlaylistDetailPage 同一链路）
/// ——PlaylistKey(kind, source, id) 隔离语义实现在 AppModel 槽层
/// （playlist_detail_isolation_test 锁定），手机页复用同一 prepare→load→
/// browse 调用序，业务零复制：不重建第二份隔离协议。
/// 收藏歌单走真实 favoritePlaylistAdd/Remove 命令 + 乐观翻转与失败回滚
/// （语义照搬桌面页，无超时假成功）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_track_row.dart';
import '../design_system/design_tokens.dart';
import 'song_tile.dart' show showSongMenu, songSourceLabel;

/// 歌单详情手机页。
class MobilePlaylistDetailPage extends StatefulWidget {
  const MobilePlaylistDetailPage(
    this.model,
    this.playlist, {
    super.key,
    this.account = false,
  });

  final AppModel model;
  final bridge.PlaylistDto playlist;

  /// true = 账号歌单镜像（读远程缓存），false = 在线音源公开歌单。
  final bool account;

  @override
  State<MobilePlaylistDetailPage> createState() =>
      _MobilePlaylistDetailPageState();
}

class _MobilePlaylistDetailPageState extends State<MobilePlaylistDetailPage> {
  bool _favPending = false;
  bool? _favOverride;

  @override
  void initState() {
    super.initState();
    // §8.1：同步预清槽（不通知），首帧即加载态；请求派发 defer 到帧后。
    _model.prepareBrowseLoad(_kind, _playlist.source, _playlist.id);
    _model.addListener(_onModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    super.dispose();
  }

  void _onModelChanged() {
    if (!mounted || !_favPending || _favOverride == null) return;
    // 'library' 事件刷新的真实快照与乐观值一致 = 服务端确认，清 pending。
    if (_isFavoritePlaylist == _favOverride) {
      setState(() {
        _favPending = false;
        _favOverride = null;
      });
    }
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

  void _loadMore() {
    if (_account) return;
    final result = _result;
    if (result == null || result.loading) return;
    _model.loadPlaylistDetail(_playlist, page: result.page + 1);
  }

  bool get _isFavoritePlaylist => _model.state.favoritePlaylists.any(
    (item) => item.id == _playlist.id && item.source == _playlist.source,
  );

  bool get _favDisplayed => _favOverride ?? _isFavoritePlaylist;

  Future<void> _toggleFavoritePlaylist() async {
    if (_favPending) return;
    final target = !_isFavoritePlaylist;
    setState(() {
      _favPending = true;
      _favOverride = target;
    });
    final command = target
        ? bridge.FfiCommand.favoritePlaylistAdd(playlist: _playlist)
        : bridge.FfiCommand.favoritePlaylistRemove(playlist: _playlist);
    final error = await _model.dispatchWithError(command);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _favPending = false;
        _favOverride = null;
      });
      return;
    }
  }

  /// 随机播放：从已载入曲目随机选一首开始（顺序继续）。
  void _playShuffled(List<bridge.SongDto> songs) {
    if (songs.length <= 1) {
      _model.playSongs(songs);
      return;
    }
    final index = math.Random().nextInt(songs.length);
    _model.playSongs(songs, index: index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
        final scheme = Theme.of(context).colorScheme;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: _favDisplayed ? '取消收藏歌单' : '收藏歌单',
                onPressed: _favPending ? null : _toggleFavoritePlaylist,
                icon: Icon(
                  _favDisplayed ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: _favDisplayed ? scheme.primary : null,
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                _Hero(
                  model: _model,
                  playlist: _playlist,
                  songCount: songs.length,
                  account: _account,
                  onPlayAll: songs.isEmpty
                      ? null
                      : () => _model.playSongs(songs),
                  onShuffle: songs.isEmpty ? null : () => _playShuffled(songs),
                ),
                Expanded(child: _listBody(context, result, songs)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _listBody(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    // 四态（spec §1.5：加载/空/错误/成功真实反馈，骨架屏优先）。
    if (result == null || (result.loading && result.songs.isEmpty)) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [VxLoadingSkeleton.tracks(rows: 8)],
      );
    }
    if (result.error != null) {
      return VxEmptyState(
        icon: Icons.cloud_off_outlined,
        title: '歌单加载失败',
        message: result.error!,
        actionLabel: '重试',
        onAction: _reload,
      );
    }
    if (songs.isEmpty) {
      return VxEmptyState(
        icon: Icons.queue_music_outlined,
        title: '空歌单',
        message: result.notice ?? '这个歌单还没有歌曲。',
        actionLabel: '刷新',
        onAction: _reload,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemCount: songs.length + (result.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= songs.length) {
          // 分页加载尾项；账号歌单无分页（hasMore 恒 false）。
          _loadMore();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final song = songs[index];
        final playingSong = _model.state.playback.song;
        final isPlaying =
            playingSong != null &&
            playingSong.id == song.id &&
            playingSong.source == song.source;
        return VxTrackRow(
          title: song.name,
          artist: song.singer,
          source: songSourceLabel(_model, song.source),
          isPlaying: isPlaying,
          isLiked: _model.isFavorite(song),
          density: VxTrackRowDensity.comfortable,
          showIndex: false,
          showAlbum: false,
          cover: VxArtwork(
            url: song.coverUrl,
            source: song.source,
            entityType: 'song',
            entityId: song.id,
            entityName: song.name,
            size: 44,
            allowRetry: false,
          ),
          onTap: () => _model.playSongs(songs, index: index),
          onLongPressStart: (details) => showSongMenu(
            context,
            _model,
            song,
            position: details.globalPosition,
          ),
          onMore: () => showSongMenu(context, _model, song),
        );
      },
    );
  }
}

/// 沉浸头部：封面 + 名称/来源/N 首 + 播放全部 / 随机。
class _Hero extends StatelessWidget {
  const _Hero({
    required this.model,
    required this.playlist,
    required this.songCount,
    required this.account,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final AppModel model;
  final bridge.PlaylistDto playlist;
  final int songCount;
  final bool account;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(VxRadius.md),
            child: SizedBox(
              width: 112,
              height: 112,
              child: VxArtwork(
                url: playlist.coverUrl,
                source: playlist.source,
                entityType: 'playlist',
                entityId: playlist.id,
                entityName: playlist.name,
                size: 112,
                radius: 0,
                icon: Icons.queue_music,
                allowRetry: false,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VxTypography.h2.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (account) '账号歌单',
                    if (playlist.songCount > 0) '${playlist.songCount} 首',
                  ].join(' · '),
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // Wrap：窄宽（360）下自动换行不溢出（与桌面 ActionRow 同口径）。
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlayAll,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放全部'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onShuffle,
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('随机'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
