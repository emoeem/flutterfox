/// 专辑详情：专辑头信息 + 曲目列表 + 播放全部。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/browse_songs_view.dart';
import '../widgets/cover_image.dart';

class AlbumSongsPage extends StatefulWidget {
  final AppModel model;
  final bridge.AlbumDto album;

  const AlbumSongsPage(this.model, this.album, {super.key});

  @override
  State<AlbumSongsPage> createState() => _AlbumSongsPageState();
}

class _AlbumSongsPageState extends State<AlbumSongsPage> {
  static const _kind = 'album_songs';

  AppModel get _model => widget.model;
  bridge.AlbumDto get _album => widget.album;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _model.loadAlbumSongs(_album);
    });
  }

  BrowseResult? get _result => _model.browse(_kind, _album.source, _album.id);

  void _reload() => _model.loadAlbumSongs(_album);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(_album.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final header = _header(context, songs);
              final list = BrowseSongsView(
                model: _model,
                result: result,
                onRetry: _reload,
                onLoadMore: () => _model.loadAlbumSongs(
                  _album,
                  page: (result?.page ?? 0) + 1,
                ),
                emptyTitle: '专辑暂无曲目',
              );
              if (!wide) {
                return Column(
                  children: [
                    header,
                    const Divider(height: 1),
                    Expanded(child: list),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: SingleChildScrollView(child: header),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: list),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, List<bridge.SongDto> songs) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CoverImage(
              url: _album.coverUrl,
              size: 160,
              radius: 16,
              icon: Icons.album,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _album.name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_album.artist.trim().isNotEmpty)
                _badge(context, _album.artist),
              _badge(context, _album.source.toUpperCase()),
              if (songs.isNotEmpty) _badge(context, '已载入 ${songs.length}'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: songs.isEmpty ? null : () => _model.playSongs(songs),
              icon: const Icon(Icons.play_arrow),
              label: Text(songs.isEmpty ? '暂无可播放曲目' : '播放全部'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '单曲可在右侧列表的更多菜单中入队',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}
