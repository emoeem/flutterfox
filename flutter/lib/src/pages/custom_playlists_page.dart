/// 自建歌单：曲库 tab 列表 + 详情页（本地数据，复用 browse 分槽）。
///
/// 数据来源：
/// - 列表 = `state.customPlaylists`（LibraryChanged 后自动刷新）；
/// - 详情 = `model.customPlaylist(id)`，由 `CustomPlaylistDetail` 命令回填。
/// 增删改与加歌都走 application 层命令，本地存储持久化。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/cover_image.dart';
import '../widgets/custom_playlist_dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/push_dialog.dart';
import 'song_tile.dart';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

/// 曲库页「自建歌单」区块；`query` 非空时按名称过滤（我的音乐搜索框用）。
class CustomPlaylistsSection extends StatelessWidget {
  final AppModel model;

  /// 名称过滤关键词；null / 空串不过滤。
  final String? query;

  /// 来源筛选（曲库来源 chips）：自建歌单是本地数据、无音源字段，仅在
  /// 未选来源或所选为本地（source == 'local'）时展示；其余来源如实过滤
  /// 为空（§5.5 来源过滤后标题和计数同步变化）。
  final String? source;

  const CustomPlaylistsSection(
    this.model, {
    super.key,
    this.query,
    this.source,
  });

  Future<void> _create(BuildContext context) async {
    final name = await promptCustomPlaylistName(context);
    if (name == null || !context.mounted) return;
    final id = await model.createCustomPlaylist(name);
    if (!context.mounted) return;
    if (id == null) {
      _snack(context, model.lastNotification ?? '新建歌单失败');
      return;
    }
    _snack(context, '已新建「$name」');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final keyword = query?.trim().toLowerCase() ?? '';
        final sourceOk = source == null || source == 'local';
        final playlists = !sourceOk
            ? const []
            : keyword.isEmpty
            ? model.state.customPlaylists
            : model.state.customPlaylists
                  .where((p) => p.name.toLowerCase().contains(keyword))
                  .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      playlists.isEmpty
                          ? '本地自建歌单'
                          : '共 ${playlists.length} 个歌单',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('新建歌单'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: playlists.isEmpty
                  ? EmptyState(
                      icon: Icons.playlist_add,
                      title: sourceOk && keyword.isEmpty
                          ? '还没有自建歌单'
                          : '没有匹配的歌单',
                      subtitle: !sourceOk
                          ? '自建歌单是本地数据，选「全部来源」或「本地音乐」时展示'
                          : keyword.isEmpty
                          ? '点「新建歌单」，或在歌曲菜单里选择「加入歌单」'
                          : '换个关键词试试',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) => _PlaylistTile(
                        model: model,
                        playlist: playlists[index],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final AppModel model;
  final bridge.CustomPlaylistSummaryDto playlist;

  const _PlaylistTile({required this.model, required this.playlist});

  Future<void> _rename(BuildContext context) async {
    final name = await promptCustomPlaylistName(
      context,
      title: '重命名歌单',
      initialName: playlist.name,
    );
    if (name == null || name == playlist.name || !context.mounted) return;
    await model.renameCustomPlaylist(playlist.id, name);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定删除「${playlist.name}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await model.deleteCustomPlaylist(playlist.id);
    if (!context.mounted) return;
    _snack(context, '已删除「${playlist.name}」');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CoverImage(
          url: playlist.coverUrl,
          size: 48,
          icon: Icons.queue_music,
        ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text('${playlist.songCount} 首 · 本地'),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (action) {
            if (action == 'rename') _rename(context);
            if (action == 'delete') _delete(context);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CustomPlaylistDetailPage(model, playlist),
          ),
        ),
      ),
    );
  }
}

/// 自建歌单详情：播放全部 / 单曲播放 / 移除歌曲 / 重命名 / 删除。
class CustomPlaylistDetailPage extends StatefulWidget {
  final AppModel model;
  final bridge.CustomPlaylistSummaryDto playlist;

  const CustomPlaylistDetailPage(this.model, this.playlist, {super.key});

  @override
  State<CustomPlaylistDetailPage> createState() =>
      _CustomPlaylistDetailPageState();
}

class _CustomPlaylistDetailPageState extends State<CustomPlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.model.loadCustomPlaylist(widget.playlist.id);
    });
  }

  AppModel get _model => widget.model;
  String get _id => widget.playlist.id;

  /// 摘要以快照为准（重命名/加歌后数量即时更新）；被删时回退到入口参数。
  bridge.CustomPlaylistSummaryDto get _summary {
    for (final item in _model.state.customPlaylists) {
      if (item.id == _id) return item;
    }
    return widget.playlist;
  }

  Future<void> _rename() async {
    final name = await promptCustomPlaylistName(
      context,
      title: '重命名歌单',
      initialName: _summary.name,
    );
    if (name == null || name == _summary.name || !mounted) return;
    await _model.renameCustomPlaylist(_id, name);
  }

  Future<void> _delete() async {
    final name = _summary.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定删除「$name」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    await _model.deleteCustomPlaylist(_id);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final summary = _summary;
        final result = _model.customPlaylist(_id);
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              summary.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: '推送到远端',
                onPressed: songs.isEmpty
                    ? null
                    : () => showPushDialog(
                        context,
                        _model,
                        localName: summary.name,
                        songs: songs,
                        isFavorites: false,
                      ),
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: '歌单操作',
                onSelected: (action) {
                  if (action == 'rename') _rename();
                  if (action == 'delete') _delete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'delete', child: Text('删除歌单')),
                ],
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final header = _Header(
                name: summary.name,
                coverUrl: summary.coverUrl,
                songCount: summary.songCount,
                loaded: songs.length,
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
            icon: Icons.error_outline,
            title: '歌单读取失败',
            subtitle: result.error,
          ),
          TextButton(
            onPressed: () => _model.loadCustomPlaylist(_id),
            child: const Text('重试'),
          ),
        ],
      );
    }
    if (songs.isEmpty) {
      return const EmptyState(
        icon: Icons.music_note_outlined,
        title: '歌单还没有歌曲',
        subtitle: '在歌曲的更多菜单里选择「加入歌单」',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongTile(
          _model,
          song,
          index: index,
          onRemove: () => _model.removeFromCustomPlaylist(_id, song),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? coverUrl;
  final int songCount;
  final int loaded;
  final VoidCallback? onPlayAll;

  const _Header({
    required this.name,
    required this.coverUrl,
    required this.songCount,
    required this.loaded,
    required this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CoverImage(
              url: coverUrl,
              size: 160,
              radius: 16,
              icon: Icons.queue_music,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
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
              _badge(context, '本地'),
              _badge(context, '$songCount 首'),
              if (loaded != songCount) _badge(context, '已载入 $loaded'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow),
              label: Text(loaded == 0 ? '暂无可播放曲目' : '播放全部'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在任意歌曲的「更多」菜单里选择「加入歌单」，即可把歌收进来。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
