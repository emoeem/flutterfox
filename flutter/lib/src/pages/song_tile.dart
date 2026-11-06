/// 歌曲行组件（Phase 5 统一曲目视图）：
///
/// - [SongTile]：旧版 ListTile 行（队列/自建歌单详情仍在用）；
/// - [SongTrackRow]：全局 [VxTrackRow] 封装——单击选中、双击播放、右键
///   上下文菜单（§9），专辑/歌手/歌单详情与我的音乐共用；
/// - [showSongMenu]：右键菜单本体，操作顺序固定（§9：高频在前、
///   危险操作在分隔线后），命令不存在的条目禁用并注明原因。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_track_row.dart';
import '../widgets/cover_image.dart';
import '../widgets/custom_playlist_dialogs.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';

/// 音源展示名：能力位名称优先；本地音源固定「本地音乐」，未知 id 原样展示。
String songSourceLabel(AppModel model, String source) {
  if (source == 'local') return '本地音乐';
  return model.capability(source)?.name ?? source;
}

/// 歌手的可下钻目标；音源不支持歌手页或歌手名为空时为 null。
bridge.ArtistDto? artistOfSong(AppModel model, bridge.SongDto song) {
  final name = song.singer.trim();
  if (name.isEmpty || !model.supportsArtist(song.source)) return null;
  final id = song.artistId?.trim();
  return bridge.ArtistDto(
    id: (id != null && id.isNotEmpty) ? id : name,
    name: name,
    source: song.source,
    coverUrl: null,
  );
}

/// 专辑的可下钻目标；音源不支持专辑页或专辑名为空时为 null。
bridge.AlbumDto? albumOfSong(AppModel model, bridge.SongDto song) {
  final name = song.albumName.trim();
  if (name.isEmpty || !model.supportsAlbum(song.source)) return null;
  final id = song.albumId?.trim();
  return bridge.AlbumDto(
    id: (id != null && id.isNotEmpty) ? id : name,
    name: name,
    source: song.source,
    coverUrl: song.coverUrl,
    artist: song.singer,
  );
}

/// 打开「查看歌手/查看专辑」详情路由；优先专辑（菜单语义一致），无目标不动作。
void openSongDetail(BuildContext context, AppModel model, bridge.SongDto song) {
  final artist = artistOfSong(model, song);
  final album = albumOfSong(model, song);
  if (album != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlbumSongsPage(model, album)),
    );
    return;
  }
  if (artist != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArtistDetailPage(model, artist)),
    );
  }
}

/// 歌曲右键 / 更多菜单。返回是否展示了菜单（overlay 缺失时为 false）。
bool showSongMenu(
  BuildContext context,
  AppModel model,
  bridge.SongDto song, {
  Offset? position,
  VoidCallback? onRemove,
}) {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return false;
  final anchor = position ?? const Offset(120, 120);
  final scheme = Theme.of(context).colorScheme;
  final favorite = model.isFavorite(song);
  final artist = artistOfSong(model, song);
  final album = albumOfSong(model, song);
  showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(anchor, anchor.translate(1, 1)),
      Offset.zero & overlay.size,
    ),
    color: scheme.surfaceContainerHigh,
    items: [
      const PopupMenuItem(value: 'play', child: Text('立即播放')),
      const PopupMenuItem(value: 'next', child: Text('下一首播放')),
      const PopupMenuItem(value: 'queue', child: Text('加入队列')),
      const PopupMenuItem(value: 'playlist', child: Text('加入歌单')),
      PopupMenuItem(value: 'like', child: Text(favorite ? '取消收藏' : '收藏')),
      const PopupMenuItem(value: 'download', child: Text('下载')),
      PopupMenuItem(
        value: 'artist',
        enabled: artist != null,
        child: Text(artist != null ? '查看歌手' : '查看歌手（该音源不支持）'),
      ),
      PopupMenuItem(
        value: 'album',
        enabled: album != null,
        child: Text(album != null ? '查看专辑' : '查看专辑（该音源不支持）'),
      ),
      if (onRemove != null) ...[
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remove', child: Text('从歌单移除')),
      ],
    ],
  ).then((action) {
    if (action == null) return;
    switch (action) {
      case 'play':
        fireAndForget(model.playSong(song));
      case 'next':
        fireAndForget(
          model.dispatch(bridge.FfiCommand.queueAdd(song: song, next: true)),
        );
      case 'queue':
        fireAndForget(model.queueAdd(song));
      case 'playlist':
        if (context.mounted) {
          showAddToCustomPlaylistSheet(context, model, [song]);
        }
      case 'like':
        fireAndForget(model.toggleFavorite(song));
      case 'download':
        fireAndForget(model.download(song));
      case 'artist':
      case 'album':
        if (context.mounted) {
          openSongDetail(context, model, song);
        }
      case 'remove':
        onRemove?.call();
    }
  });
  return true;
}

/// 菜单回调上下文是同步的：触发命令但不 await，错误由 AppModel 统一上报。
void fireAndForget(Future<void> future) {
  unawaited(future);
}

void unawaited(Future<void> future) {
  future.catchError((Object _) {});
}

/// Ctrl/⌘ 按住检测（§9 多选；完整多选交互在 Phase 6 扩展）。
bool isCtrlPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.controlLeft) ||
      pressed.contains(LogicalKeyboardKey.controlRight) ||
      pressed.contains(LogicalKeyboardKey.metaLeft) ||
      pressed.contains(LogicalKeyboardKey.metaRight);
}

/// 全局 TrackRow 封装：单击选中、双击播放、右键菜单（§9）。
///
/// 选中态由外层 [VxSongTable] 管理；单独使用时单击即播放（无选择语义）。
class SongTrackRow extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto song;

  /// 序号（1 起）；null 显示空序号位。
  final int? index;

  /// 单击回调（null 时单击即播放——单独使用的回退语义）。
  final VoidCallback? onTap;

  /// 从歌单移除回调；非空时右键菜单多一项「从歌单移除」。
  final VoidCallback? onRemove;

  /// 是否显示专辑列。
  final bool showAlbum;

  /// 是否显示音源列。
  final bool showSource;

  const SongTrackRow(
    this.model,
    this.song, {
    super.key,
    this.index,
    this.onTap,
    this.onRemove,
    this.showAlbum = true,
    this.showSource = true,
  });

  bool get _isCurrent {
    final current = model.state.playback.song;
    return current != null &&
        current.id == song.id &&
        current.source == song.source;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 单击仍落在行内（选中）；双击窗口内单击会被取消、改触发播放。
      onDoubleTap: () => fireAndForget(model.playSong(song)),
      onSecondaryTapUp: (details) {
        showSongMenu(
          context,
          model,
          song,
          position: details.globalPosition,
          onRemove: onRemove,
        );
      },
      child: VxTrackRow(
        title: song.name,
        artist: song.singer,
        album: showAlbum && song.albumName.isNotEmpty ? song.albumName : null,
        source: showSource ? songSourceLabel(model, song.source) : null,
        duration: song.durationMs.toInt() > 0
            ? Duration(milliseconds: song.durationMs.toInt())
            : null,
        index: index,
        isPlaying: _isCurrent,
        isLiked: model.isFavorite(song),
        cover: CoverImage(url: song.coverUrl, size: 40, radius: 6),
        showAlbum: showAlbum,
        onTap: onTap ?? () => fireAndForget(model.playSong(song)),
        onPlay: () => fireAndForget(model.playSong(song)),
        onAddToQueue: () => fireAndForget(model.queueAdd(song)),
        onLike: () => fireAndForget(model.toggleFavorite(song)),
        onMore: () {
          final box = context.findRenderObject() as RenderBox?;
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox?;
          Offset? anchor;
          if (box != null && overlay != null) {
            anchor = box.localToGlobal(
              Offset(box.size.width - 40, box.size.height / 2),
            );
          }
          showSongMenu(
            context,
            model,
            song,
            position: anchor,
            onRemove: onRemove,
          );
        },
      ),
    );
  }
}

/// 旧版 ListTile 歌曲行（队列 / 自建歌单详情页仍在用）。
class SongTile extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto song;
  final int index;

  /// 非空时在菜单里多一项「从歌单移除」（自建歌单详情页传入）。
  final VoidCallback? onRemove;

  /// 当前正在播放的行：填充 primaryContainer（spec §2 选中态）。
  final bool selected;

  const SongTile(
    this.model,
    this.song, {
    super.key,
    this.index = -1,
    this.onRemove,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final favorite = model.isFavorite(song);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CoverImage(url: song.coverUrl, size: 48),
      title: Text(
        index >= 0 ? '${index + 1}. ${song.name}' : song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${song.singer} · ${songSourceLabel(model, song.source)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: favorite ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => model.toggleFavorite(song),
          ),
          IconButton(
            tooltip: '下载',
            icon: const Icon(Icons.download_outlined, size: 20),
            onPressed: () => model.download(song),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) {
              if (action == 'queue') model.queueAdd(song);
              if (action == 'play') model.playSong(song);
              if (action == 'playlist') {
                showAddToCustomPlaylistSheet(context, model, [song]);
              }
              if (action == 'remove') onRemove?.call();
              if (action == 'artist') {
                final artist = artistOfSong(model, song);
                if (artist != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailPage(model, artist),
                    ),
                  );
                }
              }
              if (action == 'album') {
                final album = albumOfSong(model, song);
                if (album != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumSongsPage(model, album),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'queue', child: Text('加入队列')),
              const PopupMenuItem(value: 'playlist', child: Text('加入歌单')),
              const PopupMenuItem(value: 'play', child: Text('立即播放')),
              if (artistOfSong(model, song) != null)
                const PopupMenuItem(value: 'artist', child: Text('查看歌手')),
              if (albumOfSong(model, song) != null)
                const PopupMenuItem(value: 'album', child: Text('查看专辑')),
              if (onRemove != null)
                const PopupMenuItem(value: 'remove', child: Text('从歌单移除')),
            ],
          ),
        ],
      ),
      onTap: () => model.playSong(song),
      ),
    );
  }
}
