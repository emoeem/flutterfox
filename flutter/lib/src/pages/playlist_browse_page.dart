/// 歌单浏览页：音源 + 分类切换 + 歌单网格 + 翻页，点卡片进入现有详情页。
///
/// 分类能力按音源真实声明呈现：`playlist_categories` 为 false 的音源只显示
/// 「推荐」一个入口，并在分类行下方如实说明原因，不伪造分类项。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/sync_dialog.dart';
import 'playlist_detail_page.dart';

class PlaylistBrowsePage extends StatefulWidget {
  final AppModel model;
  final String? initialSource;

  const PlaylistBrowsePage(this.model, {super.key, this.initialSource});

  @override
  State<PlaylistBrowsePage> createState() => _PlaylistBrowsePageState();
}

class _PlaylistBrowsePageState extends State<PlaylistBrowsePage> {
  static const _categoriesKind = 'playlist_categories';
  static const _playlistsKind = 'playlists';

  String? _source;
  String _category = '';
  String? _categoriesRequested;
  String? _playlistsRequested;
  bool _account = false;
  String? _accountRequested;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 选源与加载挂在模型监听里；调度 defer 到帧后执行——模型通知可能
    // 发生在 build 期，直接触发会让祖先在 build 中被标脏。
    _model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant PlaylistBrowsePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_maybeLoad);
      widget.model.addListener(_maybeLoad);
      _maybeLoad();
    }
  }

  @override
  void dispose() {
    _model.removeListener(_maybeLoad);
    super.dispose();
  }

  bool _loadScheduled = false;

  void _maybeLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      _loadNow();
    });
  }

  /// 按当前选源/范围/分类补拉缺失的数据；重复调用由 *_requested 去重。
  void _loadNow() {
    final capable = _model.state.sources
        .where((source) => source.playlists)
        .toList();
    if (capable.isEmpty) return;
    if (widget.initialSource != null &&
        capable.any((item) => item.id == widget.initialSource)) {
      _source ??= widget.initialSource;
    }
    _source ??= capable.first.id;
    final source = _source!;
    final mirrorable = _mirrorable(source);
    final accountScope = _account && mirrorable;
    if (accountScope) {
      if (_accountRequested != source) {
        _accountRequested = source;
        _model.loadAccountPlaylists(source);
      }
      return;
    }
    if (_categoriesRequested != source) {
      _categoriesRequested = source;
      _model.loadPlaylistCategories(source);
    }
    final key = '$source|$_category';
    if (_playlistsRequested != key) {
      _playlistsRequested = key;
      _model.loadPlaylists(source: source, category: _category);
    }
  }

  /// 「我的歌单」镜像缓存只有网易云 / QQ 音乐两平台（Rust 侧 remote_cache
  /// 只实现这两个 provider），此为数据事实而非能力位可查。
  static bool _mirrorable(String source) => source == 'wy' || source == 'tx';

  void _selectSource(String id) {
    if (_source == id) return;
    setState(() {
      _source = id;
      _category = '';
      _categoriesRequested = null;
      _playlistsRequested = null;
      _accountRequested = null;
      // 「我的歌单」只对网易云 / QQ 音乐有镜像缓存。
      if (!_mirrorable(id)) _account = false;
    });
  }

  void _selectScope({required bool account}) {
    if (_account == account) return;
    setState(() => _account = account);
    _maybeLoad();
  }

  void _selectCategory(String id) {
    if (_category == id) return;
    setState(() => _category = id);
    _maybeLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歌单浏览')),
      body: ListenableBuilder(
        listenable: _model,
        builder: (context, _) {
          final capable = _model.state.sources
              .where((source) => source.playlists)
              .toList();
          if (capable.isEmpty) {
            return const EmptyState(
              icon: Icons.queue_music_outlined,
              title: '没有支持歌单的音源',
              subtitle: '可在设置中启用支持歌单的音源',
            );
          }
          final source = _source ?? capable.first.id;
          final mirrorable = _mirrorable(source);
          final accountScope = _account && mirrorable;

          if (accountScope) {
            final accountResult = _model.accountPlaylists(source);
            return Column(
              children: [
                _sourceChips(context, capable, source),
                _scopeChips(context, mirrorable),
                _accountToolbar(context, source, accountResult),
                Expanded(child: _accountBody(context, source, accountResult)),
              ],
            );
          }

          final categoriesResult = _model.browse(_categoriesKind, source, '');
          final playlistsResult = _model.browse(
            _playlistsKind,
            source,
            _category,
          );
          return Column(
            children: [
              _sourceChips(context, capable, source),
              _scopeChips(context, mirrorable),
              _categoryChips(context, source, categoriesResult),
              Expanded(
                child: _playlistBody(
                  context,
                  source,
                  categoriesResult,
                  playlistsResult,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 「推荐歌单 / 我的歌单」切换。没有镜像槽位的音源禁用后者。
  Widget _scopeChips(BuildContext context, bool mirrorable) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('推荐歌单'),
              selected: !_account,
              onSelected: (_) => _selectScope(account: false),
            ),
            ChoiceChip(
              label: const Text('我的歌单'),
              selected: _account && mirrorable,
              onSelected: mirrorable
                  ? (_) => _selectScope(account: true)
                  : null,
            ),
            if (!mirrorable)
              Text(
                '账号歌单仅支持网易云 / QQ 音乐',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _accountToolbar(
    BuildContext context,
    String source,
    BrowseResult? result,
  ) {
    final count = result?.playlists.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '镜像缓存 · 共 $count 个歌单',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: () => showSyncDialog(context, _model, source),
            icon: const Icon(Icons.cloud_sync_outlined, size: 20),
            label: const Text('同步'),
          ),
        ],
      ),
    );
  }

  Widget _accountBody(
    BuildContext context,
    String source,
    BrowseResult? result,
  ) {
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];
    if (result == null || (result.loading && playlists.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('账号歌单加载中…'),
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
            title: '账号歌单读取失败',
            subtitle: result.error,
          ),
          TextButton(
            onPressed: () => _model.loadAccountPlaylists(source),
            child: const Text('重试'),
          ),
        ],
      );
    }
    if (playlists.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_sync_outlined,
        title: result.notice ?? '还没有账号歌单',
        subtitle: result.notice == null ? '先扫码登录，再点「同步」把远端歌单拉到本地镜像' : null,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 232,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) =>
          _playlistCard(context, playlists[index], account: true),
    );
  }

  Widget _sourceChips(
    BuildContext context,
    List<bridge.SourceCapabilitiesDto> capable,
    String selected,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final source in capable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(source.name),
                selected: source.id == selected,
                onSelected: (_) => _selectSource(source.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChips(
    BuildContext context,
    String source,
    BrowseResult? categoriesResult,
  ) {
    final categories =
        categoriesResult?.categories ?? const <bridge.PlaylistCategoryDto>[];
    final unsupported =
        _model.supportsPlaylists(source) &&
        !_model.supportsPlaylistCategories(source);
    final list = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('推荐'),
              selected: _category.isEmpty,
              onSelected: (_) => _selectCategory(''),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.name),
                tooltip: category.group,
                selected: _category == category.id,
                onSelected: (_) => _selectCategory(category.id),
              ),
            ),
        ],
      ),
    );
    if (!unsupported) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        list,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            categoriesResult?.notice ?? '该音源不提供歌单分类，仅可浏览推荐歌单',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _playlistBody(
    BuildContext context,
    String source,
    BrowseResult? categoriesResult,
    BrowseResult? result,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];
    if (result == null || (result.loading && playlists.isEmpty)) {
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
          TextButton(
            onPressed: () =>
                _model.loadPlaylists(source: source, category: _category),
            child: const Text('重试'),
          ),
        ],
      );
    }
    if (playlists.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_outlined,
        title:
            result.notice ??
            categoriesResult?.notice ??
            (_category.isEmpty ? '暂无推荐歌单' : '该分类暂无歌单'),
        subtitle: result.notice == null && categoriesResult?.notice == null
            ? '换一个分类试试'
            : null,
      );
    }
    return Column(
      children: [
        if (result.loading && playlists.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 232,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) =>
                _playlistCard(context, playlists[index]),
          ),
        ),
        SizedBox(
          height: 40,
          child: result.hasMore
              ? Center(
                  child: result.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _model.loadPlaylists(
                            source: source,
                            category: _category,
                            page: result.page + 1,
                          ),
                          child: const Text('加载更多'),
                        ),
                )
              : Center(
                  child: Text(
                    '共 ${playlists.length} 个歌单',
                    style: textTheme.bodySmall,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _playlistCard(
    BuildContext context,
    bridge.PlaylistDto playlist, {
    bool account = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlaylistDetailPage(_model, playlist, account: account),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CoverImage.expand(
                url: playlist.coverUrl,
                radius: 0,
                icon: Icons.queue_music,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // 部分音源的列表接口不返回曲目数（恒 0）：此时只显示
                    // 音源名，不渲染误导性的「0 首」。
                    playlist.songCount > 0
                        ? '${playlist.songCount} 首 · ${_sourceName(playlist.source)}'
                        : _sourceName(playlist.source),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceName(String source) =>
      _model.capability(source)?.name ?? source;
}
