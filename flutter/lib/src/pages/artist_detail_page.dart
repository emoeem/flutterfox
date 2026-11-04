/// 歌手详情：歌曲 / 专辑两个页签；专辑可继续进入曲目页。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/browse_songs_view.dart';
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import 'album_songs_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final AppModel model;
  final bridge.ArtistDto artist;

  const ArtistDetailPage(this.model, this.artist, {super.key});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage>
    with SingleTickerProviderStateMixin {
  static const _songsKind = 'artist_songs';
  static const _albumsKind = 'artist_albums';

  late final TabController _tabs = TabController(length: 2, vsync: this);

  AppModel get _model => widget.model;
  bridge.ArtistDto get _artist => widget.artist;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _model.loadArtistSongs(_artist);
      _model.loadArtistAlbums(_artist);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  BrowseResult? get _songs => _model.browse(_songsKind, _artist.source, _artist.id);
  BrowseResult? get _albums =>
      _model.browse(_albumsKind, _artist.source, _artist.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final songs = _songs?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(_artist.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: () {
                  _model.loadArtistSongs(_artist);
                  _model.loadArtistAlbums(_artist);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: '歌曲'),
                Tab(text: '专辑'),
              ],
            ),
          ),
          body: Column(
            children: [
              _header(context),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  songs.isEmpty ? '暂无曲目' : '已载入 ${songs.length} 首',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: songs.isEmpty
                                    ? null
                                    : () => _model.playSongs(songs),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('播放全部'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: BrowseSongsView(
                            model: _model,
                            result: _songs,
                            onRetry: () => _model.loadArtistSongs(_artist),
                            onLoadMore: () => _model.loadArtistSongs(
                              _artist,
                              page: (_songs?.page ?? 0) + 1,
                            ),
                            emptyTitle: '歌手暂无歌曲',
                          ),
                        ),
                      ],
                    ),
                    _albumsTab(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CoverImage(
            url: _artist.coverUrl,
            size: 72,
            radius: 999,
            icon: Icons.person,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _artist.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _artist.source.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumsTab(BuildContext context) {
    final result = _albums;
    final albums = result?.albums ?? const <bridge.AlbumDto>[];
    if (result == null || (result.loading && albums.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('专辑加载中…'),
          ],
        ),
      );
    }
    if (result.error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '专辑加载失败',
            subtitle: result.error,
          ),
          TextButton(
            onPressed: () => _model.loadArtistAlbums(_artist),
            child: const Text('重试'),
          ),
        ],
      );
    }
    if (albums.isEmpty) {
      return EmptyState(
        icon: Icons.album_outlined,
        title: result.notice ?? '歌手暂无专辑',
      );
    }
    final hasMore = result.hasMore;
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          for (final album in albums) _albumTile(context, album),
          if (hasMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: result.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _model.loadArtistAlbums(
                          _artist,
                          page: result.page + 1,
                        ),
                        child: const Text('加载更多'),
                      ),
              ),
            ),
        ];
        if (constraints.maxWidth < 840) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: items,
          );
        }
        return GridView.count(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          crossAxisCount: 2,
          childAspectRatio: 5.4,
          children: items,
        );
      },
    );
  }

  Widget _albumTile(BuildContext context, bridge.AlbumDto album) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CoverImage(
          url: album.coverUrl,
          size: 48,
          radius: 8,
          icon: Icons.album,
        ),
        title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [album.artist, album.source.toUpperCase()]
              .where((part) => part.isNotEmpty)
              .join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlbumSongsPage(_model, album),
          ),
        ),
      ),
    );
  }
}
