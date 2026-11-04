/// 库页：收藏歌曲 / 历史 两个 tab，封面网格（spec §2：最小列宽 120dp）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/push_dialog.dart';
import '../widgets/song_card.dart';
import 'custom_playlists_page.dart';
import 'local_music_page.dart';
import 'playlist_detail_page.dart';

class LibraryPage extends StatelessWidget {
  final AppModel model;

  const LibraryPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(child: pageTitle(context, '曲库')),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LocalMusicPage(model),
                    ),
                  ),
                  icon: const Icon(Icons.folder_outlined, size: 20),
                  label: const Text('本地音乐'),
                ),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: '收藏 ${model.state.favorites.length}'),
              Tab(text: '收藏歌单 ${model.state.favoritePlaylists.length}'),
              Tab(text: '历史 ${model.state.history.length}'),
              Tab(text: '自建歌单 ${model.state.customPlaylists.length}'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Favorites(model),
                _FavoritePlaylists(model),
                _History(model),
                CustomPlaylistsSection(model),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏的歌单（远端歌单收藏到本地库）。点击进入在线歌单详情。
class _FavoritePlaylists extends StatelessWidget {
  final AppModel model;

  const _FavoritePlaylists(this.model);

  @override
  Widget build(BuildContext context) {
    final playlists = model.state.favoritePlaylists;
    if (playlists.isEmpty) {
      return const EmptyState(
        icon: Icons.playlist_add_check,
        title: '还没有收藏歌单',
        subtitle: '在歌单详情页点收藏把远端歌单存进本地库',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: _gridDelegate,
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _PlaylistCard(model, playlist);
      },
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final AppModel model;
  final bridge.PlaylistDto playlist;

  const _PlaylistCard(this.model, this.playlist);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaylistDetailPage(model, playlist),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: CoverImage.expand(url: playlist.coverUrl),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// spec §2 封面网格：最小列宽 120、圆角 12、间距 8。
const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 150,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  childAspectRatio: 0.72,
);

class _Favorites extends StatefulWidget {
  final AppModel model;

  const _Favorites(this.model);

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> {
  String _view = 'local';

  AppModel get _model => widget.model;

  /// 有红心镜像缓存的平台。镜像读的是本地缓存（Rust remote_cache 只实现
  /// wy/tx），与音源当前是否启用无关，因此保持静态列出。
  static const _mirrorPlatforms = [('wy', '网易云'), ('tx', 'QQ')];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'local', label: Text('本地')),
                  for (final (id, label) in _mirrorPlatforms)
                    ButtonSegment(value: id, label: Text(label)),
                ],
                selected: {_view},
                onSelectionChanged: (value) {
                  setState(() => _view = value.first);
                  if (_view != 'local') _model.loadAccountFavorites(_view);
                },
              ),
            ),
            Expanded(
              child: _view == 'local'
                  ? _localFavorites(context)
                  : _accountFavorites(context, _view),
            ),
          ],
        );
      },
    );
  }

  Widget _localFavorites(BuildContext context) {
    final favorites = _model.state.favorites;
    if (favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: '还没有收藏',
        subtitle: '搜索页点击心形添加',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => showPushDialog(
                context,
                _model,
                localName: '收藏',
                songs: favorites,
                isFavorites: true,
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('推送收藏'),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            gridDelegate: _gridDelegate,
            itemCount: favorites.length,
            itemBuilder: (context, index) =>
                SongCard(_model, favorites[index]),
          ),
        ),
      ],
    );
  }

  Widget _accountFavorites(BuildContext context, String source) {
    final result = _model.accountFavorites(source);
    if (result == null || result.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '红心镜像读取失败',
        subtitle: result.error,
      );
    }
    if (result.songs.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_border,
        title: result.notice ?? '暂无账号红心镜像',
        subtitle: '请先在「我的歌单」中同步账号歌单',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: _gridDelegate,
      itemCount: result.songs.length,
      itemBuilder: (context, index) => SongCard(_model, result.songs[index]),
    );
  }
}

class _History extends StatelessWidget {
  final AppModel model;

  const _History(this.model);

  @override
  Widget build(BuildContext context) {
    final history = model.state.history;
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: '播放记录为空',
        subtitle: '播放的歌曲会出现在这里',
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空播放历史'),
                    content: const Text('将删除全部播放记录，无法恢复。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await model.dispatch(
                    const bridge.FfiCommand.historyClear(),
                  );
                }
              },
              child: const Text('清空历史'),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            gridDelegate: _gridDelegate,
            itemCount: history.length,
            itemBuilder: (context, index) => SongCard(model, history[index]),
          ),
        ),
      ],
    );
  }
}
