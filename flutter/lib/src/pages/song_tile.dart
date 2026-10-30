/// 歌曲行：封面占位 + 标题/歌手 + 尾随操作（播放/收藏/下载/加入队列）。
/// 规格见 docs/flutter_ui_spec.md §2/§9。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;

class SongTile extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto song;
  final int index;

  const SongTile(this.model, this.song, {super.key, this.index = -1});

  @override
  Widget build(BuildContext context) {
    final favorite = model.isFavorite(song);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.music_note_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'queue', child: Text('加入队列')),
              PopupMenuItem(value: 'play', child: Text('立即播放')),
            ],
          ),
        ],
      ),
      onTap: () => model.playSong(song),
    );
  }
}
