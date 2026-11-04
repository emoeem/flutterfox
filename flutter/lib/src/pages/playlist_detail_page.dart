/// 歌单详情页：头信息 + 曲目列表 + 播放全部。
///
/// 独立路由，必须自行订阅 [AppModel]；播放只走现有 `playSongs`/`queueAdd`，
/// 不新建播放控制。数据结果按 `browseKind + source + id` 从 AppModel 读取。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import 'song_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
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
                tooltip: '刷新',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final header = _Header(
                playlist: _playlist,
                songs: songs,
                account: _account,
                onPlayAll: songs.isEmpty ? null : () => _model.playSongs(songs),
              );
              final list = _buildBody(result, songs);
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

  Widget _buildBody(BrowseResult? result, List<bridge.SongDto> songs) {
    if (result == null || (result.loading && songs.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('歌单加载中…'),
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
            title: '歌单加载失败',
            subtitle: result.error,
          ),
          TextButton(onPressed: _reload, child: const Text('重试')),
        ],
      );
    }
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_outlined,
        title: result.notice ?? '歌单暂无曲目',
        subtitle: result.notice == null ? '换一个歌单试试' : null,
      );
    }
    final hasMore = result.hasMore;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: songs.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= songs.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: result.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(onPressed: _loadMore, child: const Text('加载更多')),
            ),
          );
        }
        return SongTile(_model, songs[index], index: index);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final bridge.PlaylistDto playlist;
  final List<bridge.SongDto> songs;
  final VoidCallback? onPlayAll;
  final bool account;

  const _Header({
    required this.playlist,
    required this.songs,
    required this.onPlayAll,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = playlist.description?.trim();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CoverImage(
              url: playlist.coverUrl,
              size: 160,
              radius: 16,
              icon: Icons.queue_music,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            playlist.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge(context, playlist.source.toUpperCase()),
              if (account) _badge(context, '账号镜像'),
              _badge(context, '${playlist.songCount} 首'),
              if (songs.isNotEmpty) _badge(context, '已载入 ${songs.length}'),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow),
              label: Text(songs.isEmpty ? '暂无可播放曲目' : '播放全部'),
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
