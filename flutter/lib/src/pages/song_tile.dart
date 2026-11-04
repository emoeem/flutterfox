/// 歌曲行：封面占位 + 标题/歌手 + 尾随操作（播放/收藏/下载/加入队列）。
/// 规格见 docs/flutter_ui_spec.md §2/§9。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/cover_image.dart';
import '../widgets/custom_playlist_dialogs.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';

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
        '${song.singer} · ${song.source}',
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
                final artist = _artist();
                if (artist != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailPage(model, artist),
                    ),
                  );
                }
              }
              if (action == 'album') {
                final album = _album();
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
              if (_artist() != null)
                const PopupMenuItem(value: 'artist', child: Text('查看歌手')),
              if (_album() != null)
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

  /// 优先使用音源提供的稳定 ID；缺失或为空时回退到展示名。
  bridge.ArtistDto? _artist() {
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

  bridge.AlbumDto? _album() {
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
}
