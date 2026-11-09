/// 全局搜索页（计划书 §4.3：搜索输入是主角）。
///
/// 布局：固定顶部搜索框（带清除钮）→ 类型 Segmented（全部/歌曲/专辑/歌手/
/// 歌单）→ 音源多选下拉筛选（可多选/全部）→ 结果计数行 → 结果区。
/// - 歌曲结果统一 VxTrackRow 行表（与曲库同一歌曲行）；hover 操作：
///   播放 / 加入队列 / 收藏 / 更多；
/// - 双击播放、单击选中、Ctrl 切换、Shift 范围多选、Enter 播放选中项；
/// - 输入 300ms 防抖；分页加载带 in-flight 锁与「加载中 / 没有更多 /
///   失败重试」三态，不会出现永久 spinner 或重复分页；
/// - 专辑 / 歌手 Tab 由歌曲结果真实聚合（同专辑/同歌手去重），卡片带来源标识；
///   聚合搜索不返回歌单数据，歌单 Tab 如实解释。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_artist_card.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_track_row.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';

/// 搜索结果类型 Tab。
enum SearchType { all, songs, albums, artists, playlists }

String _searchTypeLabel(SearchType type) => switch (type) {
  SearchType.all => '全部',
  SearchType.songs => '歌曲',
  SearchType.albums => '专辑',
  SearchType.artists => '歌手',
  SearchType.playlists => '歌单',
};

class SearchPage extends StatefulWidget {
  final AppModel model;

  /// Shell 全局搜索框（Ctrl+K）提交的关键字种子：构造时填入输入框并触发搜索。
  final String seedKeyword;

  const SearchPage(this.model, {super.key, this.seedKeyword = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const debounceMs = 300;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _fieldFocus = FocusNode();
  final _tableFocus = FocusNode();
  Timer? _debounce;

  /// 音源多选筛选；空集合 = 全部音源（聚合搜索）。
  /// 恰好选一个音源时下发给该音源过滤；多选时聚合搜索 + 本地过滤展示。
  final Set<String> _selectedSources = {};

  SearchType _type = SearchType.all;

  /// 行选中索引（相对过滤后的展示列表）；Shift 选区锚点。
  final Set<int> _selectedRows = {};
  int _anchorRow = -1;

  /// 分页 in-flight 锁：searchMore 已下发但还没看到新响应（requestId 未变）。
  bool _moreInFlight = false;
  BigInt _seenRequestId = BigInt.zero;
  String _seenSignature = '';

  @override
  void initState() {
    super.initState();
    _seenRequestId = widget.model.state.search.requestId;
    _seenSignature = _searchSignature(widget.model.state.search);
    widget.model.addListener(_onModelChanged);
    final seed = widget.seedKeyword.trim();
    if (seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch();
      });
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModelChanged);
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _fieldFocus.dispose();
    _tableFocus.dispose();
    super.dispose();
  }

  /// 搜索快照签名：响应/加载/错误任一变化都需要重绘结果区。
  String _searchSignature(bridge.SearchDto search) =>
      '${search.requestId}|${search.loading}|${search.error}|${search.page}|'
      '${search.hasMore}|${search.items.length}';

  /// 模型通知：新响应到达（requestId 变化）或出错时释放分页锁；
  /// 快照有变化时重绘。
  void _onModelChanged() {
    if (!mounted) return;
    final search = widget.model.state.search;
    final responseArrived =
        search.requestId != _seenRequestId || search.error != null;
    if (responseArrived && _moreInFlight) {
      _moreInFlight = false;
    }
    final signature = _searchSignature(search);
    if (!responseArrived && signature == _seenSignature) return;
    _seenRequestId = search.requestId;
    _seenSignature = signature;
    setState(() {});
  }

  // ── 数据/命令 ──

  /// FFI search 只支持单音源过滤；恰好选 1 个音源时走后端过滤，
  /// 否则聚合搜索（null），展示时再按多选过滤。
  String? get _dispatchSource =>
      _selectedSources.length == 1 ? _selectedSources.first : null;

  void _runSearch() {
    _debounce?.cancel();
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _selectedRows.clear();
      _anchorRow = -1;
      _moreInFlight = false;
    });
    unawaited(
      widget.model.dispatch(
        bridge.FfiCommand.search(keyword: keyword, source: _dispatchSource),
      ),
    );
  }

  void _onSearchTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: debounceMs), _runSearch);
  }

  /// 触底加载下一页；in-flight 锁防重复分页。
  void _loadMoreIfNeeded() {
    final state = widget.model.state.search;
    if (_moreInFlight || state.loading || !state.hasMore) return;
    if (state.keyword.isEmpty) return;
    _moreInFlight = true;
    if (mounted) setState(() {});
    unawaited(
      widget.model.dispatch(
        bridge.FfiCommand.searchMore(
          keyword: state.keyword,
          page: state.page + 1,
        ),
      ),
    );
  }

  // ── 选择 ──

  bool _isCtrlPressed() =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  void _onRowTap(int index) {
    setState(() {
      if (_isCtrlPressed()) {
        if (!_selectedRows.add(index)) _selectedRows.remove(index);
        _anchorRow = index;
      } else if (HardwareKeyboard.instance.isShiftPressed && _anchorRow >= 0) {
        _selectedRows
          ..clear()
          ..addAll(
            List<int>.generate(
              (index - _anchorRow).abs() + 1,
              (i) => _anchorRow <= index ? _anchorRow + i : index + i,
            ),
          );
      } else {
        _selectedRows
          ..clear()
          ..add(index);
        _anchorRow = index;
      }
    });
  }

  void _playRow(int index) {
    final items = _items();
    if (index < 0 || index >= items.length) return;
    unawaited(widget.model.playSongs(items, index: index));
  }

  void _playSelection() {
    if (_selectedRows.isEmpty) return;
    final items = _items();
    final songs = [
      for (final i in _selectedRows.toList()..sort())
        if (i >= 0 && i < items.length) items[i],
    ];
    if (songs.isEmpty) return;
    unawaited(widget.model.playSongs(songs, index: 0));
  }

  // ── 派生数据 ──

  /// 按音源多选过滤后的展示列表。
  /// 单选音源时后端已按该源过滤；多选时对聚合结果本地过滤。
  List<bridge.SongDto> _items() {
    final items = widget.model.state.search.items;
    if (_selectedSources.length <= 1) return List<bridge.SongDto>.of(items);
    return items.where((s) => _selectedSources.contains(s.source)).toList();
  }

  /// 从歌曲结果聚合专辑（同专辑+音源去重）。
  List<bridge.SongDto> _albumRepresentatives() {
    final seen = <String>{};
    final result = <bridge.SongDto>[];
    for (final song in _items()) {
      final name = song.albumName.trim();
      if (name.isEmpty) continue;
      final id = song.albumId?.trim();
      final key = '${(id != null && id.isNotEmpty) ? id : name}|${song.source}';
      if (!seen.add(key)) continue;
      result.add(song);
    }
    return result;
  }

  /// 从歌曲结果聚合歌手（同歌手+音源去重）。
  List<bridge.SongDto> _artistRepresentatives() {
    final seen = <String>{};
    final result = <bridge.SongDto>[];
    for (final song in _items()) {
      final name = song.singer.trim();
      if (name.isEmpty) continue;
      final id = song.artistId?.trim();
      final key = '${(id != null && id.isNotEmpty) ? id : name}|${song.source}';
      if (!seen.add(key)) continue;
      result.add(song);
    }
    return result;
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 搜索框固定顶部（§4.3），页面滚动时保持可访问。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.lg,
            VxSpacing.sm,
            VxSpacing.lg,
            0,
          ),
          child: _searchField(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.lg,
            VxSpacing.sm,
            VxSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(child: _typeSegment(context)),
              const SizedBox(width: VxSpacing.md),
              _sourceFilter(context),
            ],
          ),
        ),
        const SizedBox(height: VxSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: VxSpacing.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _countLine(),
              style: VxTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(child: _resultArea(context)),
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _fieldFocus,
      autofocus: widget.seedKeyword.isEmpty,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(),
      onChanged: _onSearchTextChanged,
      decoration: InputDecoration(
        hintText: '输入歌曲、歌手、专辑或歌单名称……',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _debounce?.cancel();
                    setState(() {});
                  },
                ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VxRadius.md),
        ),
      ),
    );
  }

  /// 类型紧凑 Segmented（§4.3）。
  Widget _typeSegment(BuildContext context) {
    return SegmentedButton<SearchType>(
      segments: [
        for (final type in SearchType.values)
          ButtonSegment(value: type, label: Text(_searchTypeLabel(type))),
      ],
      selected: {_type},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => setState(() {
        _type = selection.first;
        _selectedRows.clear();
        _anchorRow = -1;
      }),
    );
  }

  /// 音源多选下拉筛选（§4.3：可多选/全部，不横排占满一行）。
  Widget _sourceFilter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (_selectedSources.length) {
      0 => '来源：全部音源',
      1 => '来源：${_sourceName(_selectedSources.first)}',
      _ => '来源：已选 ${_selectedSources.length} 个',
    };
    return PopupMenuButton<String>(
      tooltip: '按音源筛选结果',
      onSelected: (id) {
        setState(() {
          if (id.isEmpty) {
            _selectedSources.clear();
          } else if (!_selectedSources.add(id)) {
            _selectedSources.remove(id);
          }
        });
        // 换源重搜，保证数据与新筛选一致。
        _runSearch();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          child: Row(
            children: [
              Icon(
                _selectedSources.isEmpty
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 16,
              ),
              const SizedBox(width: VxSpacing.sm),
              const Text('全部音源'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final source in widget.model.state.sources)
          PopupMenuItem<String>(
            value: source.id,
            child: Row(
              children: [
                Icon(
                  _selectedSources.contains(source.id)
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: 16,
                ),
                const SizedBox(width: VxSpacing.sm),
                Text(source.name),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VxSpacing.md,
          vertical: VxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(VxRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: VxTypography.caption.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(width: VxSpacing.xs),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  String _countLine() {
    final state = widget.model.state.search;
    switch (_type) {
      case SearchType.albums:
        return '聚合出 ${_albumRepresentatives().length} 张专辑';
      case SearchType.artists:
        return '聚合出 ${_artistRepresentatives().length} 位歌手';
      case SearchType.playlists:
        return '聚合搜索不返回歌单，请到「发现」页浏览';
      case SearchType.all:
      case SearchType.songs:
        if (state.keyword.isEmpty) return '输入关键词开始搜索';
        return '找到 ${_items().length} 个结果';
    }
  }

  // ── 结果区 ──

  Widget _resultArea(BuildContext context) {
    final state = widget.model.state.search;
    final keyword = _controller.text.trim();

    if (state.loading && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: VxSpacing.lg),
        child: VxLoadingSkeleton.tracks(rows: 8),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return VxErrorState(
        title: '搜索失败',
        message: '无法完成「${state.keyword}」的搜索。',
        detail: state.error,
        icon: Icons.cloud_off,
        onRetry: _runSearch,
      );
    }
    if (keyword.isEmpty) {
      return VxEmptyState(
        icon: Icons.search,
        title: '搜索你想听的音乐',
        message: '支持歌曲、歌手、专辑名；聚合搜索会同时查询已启用的音源。',
      );
    }
    if (state.items.isEmpty) {
      return VxEmptyState(
        icon: Icons.search_off,
        title: '没有结果',
        message: '没有找到与「${state.keyword}」匹配的内容，换个关键词试试。',
      );
    }

    return switch (_type) {
      SearchType.all || SearchType.songs => _trackTable(context),
      SearchType.albums => _albumGrid(context),
      SearchType.artists => _artistGrid(context),
      SearchType.playlists => VxEmptyState(
        icon: Icons.queue_music_outlined,
        title: '聚合搜索不返回歌单结果',
        message: _playlistsExplain(),
      ),
    };
  }

  String _playlistsExplain() {
    final capable = widget.model.state.sources
        .where((s) => s.playlistSearch)
        .map((s) => s.name)
        .toList();
    return capable.isEmpty
        ? '当前音源的搜索接口只返回歌曲；可以在「发现」页浏览精选歌单。'
        : '聚合搜索只返回歌曲；${capable.join('、')}支持歌单搜索，可到「发现」页浏览。';
  }

  Widget _trackTable(BuildContext context) {
    final items = _items();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          _loadMoreIfNeeded();
        }
        return false;
      },
      child: Focus(
        focusNode: _tableFocus,
        autofocus: widget.seedKeyword.isNotEmpty,
        onKeyEvent: _onKeyEvent,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: VxSpacing.xl),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index >= items.length) return _footer(context);
            final song = items[index];
            final selected = _selectedRows.contains(index);
            // 外层 GestureDetector 承接双击；单击仍落到行内（选中），
            // 双击窗口内单击会被取消、改触发播放。
            return Builder(
              builder: (rowContext) => GestureDetector(
                onDoubleTap: () => _playRow(index),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  child: VxTrackRow(
                    title: song.name,
                    artist: song.singer,
                    album: song.albumName.isEmpty ? null : song.albumName,
                    source: _sourceName(song.source),
                    duration: song.durationMs.toInt() > 0
                        ? Duration(milliseconds: song.durationMs.toInt())
                        : null,
                    index: selected ? null : index + 1,
                    isPlaying: _isCurrent(song),
                    isLiked: widget.model.isFavorite(song),
                    onTap: () => _onRowTap(index),
                    onPlay: () => _playRow(index),
                    onAddToQueue: () => unawaited(widget.model.queueAdd(song)),
                    onLike: () => unawaited(widget.model.toggleFavorite(song)),
                    onMore: () => _showRowMenu(rowContext, song),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isCurrent(bridge.SongDto song) {
    final current = widget.model.state.playback.song;
    return current != null &&
        current.id == song.id &&
        current.source == song.source;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _playSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showRowMenu(BuildContext rowContext, bridge.SongDto song) {
    final overlay =
        Overlay.of(rowContext).context.findRenderObject() as RenderBox;
    final row = rowContext.findRenderObject() as RenderBox?;
    final position = RelativeRect.fromSize(
      Rect.fromPoints(
        row == null
            ? overlay.localToGlobal(Offset(80, 80))
            : row.localToGlobal(
                Offset(row.size.width - 140, row.size.height / 2),
              ),
        overlay.size.bottomRight(Offset.zero),
      ),
      overlay.size,
    );
    showMenu<String>(
      context: rowContext,
      position: position,
      color: Theme.of(rowContext).colorScheme.surfaceContainerHigh,
      items: const [
        PopupMenuItem(value: 'artist', child: Text('查看歌手')),
        PopupMenuItem(value: 'album', child: Text('查看专辑')),
        PopupMenuItem(value: 'download', child: Text('下载')),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      switch (value) {
        case 'artist':
          _openArtist(context, song);
        case 'album':
          _openAlbum(context, song);
        case 'download':
          unawaited(widget.model.download(song));
      }
    });
  }

  Widget _albumGrid(BuildContext context) {
    final albums = _albumRepresentatives();
    if (albums.isEmpty) {
      return VxEmptyState(
        icon: Icons.album_outlined,
        title: '结果中没有专辑',
        message: '本次搜索结果没有携带专辑信息，试试搜索专辑名或换个关键词。',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(VxSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 252,
        crossAxisSpacing: VxSpacing.md,
        mainAxisSpacing: VxSpacing.md,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final song = albums[index];
        return Center(
          child: VxAlbumCard(
            title: song.albumName,
            subtitle: '${song.singer} · ${_sourceName(song.source)}',
            width: 168,
            cover: (song.coverUrl?.isNotEmpty ?? false)
                ? null
                : CoverImage(url: song.coverUrl, size: 168, radius: 0),
            onTap: () => _openAlbum(context, song),
          ),
        );
      },
    );
  }

  void _openAlbum(BuildContext context, bridge.SongDto song) {
    final name = song.albumName.trim();
    if (name.isEmpty || !widget.model.supportsAlbum(song.source)) return;
    final id = song.albumId?.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumSongsPage(
          widget.model,
          bridge.AlbumDto(
            id: (id != null && id.isNotEmpty) ? id : name,
            name: name,
            source: song.source,
            coverUrl: song.coverUrl,
            artist: song.singer,
          ),
        ),
      ),
    );
  }

  Widget _artistGrid(BuildContext context) {
    final artists = _artistRepresentatives();
    if (artists.isEmpty) {
      return VxEmptyState(
        icon: Icons.person_search_outlined,
        title: '结果中没有歌手',
        message: '本次搜索结果没有携带歌手信息，试试直接搜索歌手名。',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(VxSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 252,
        crossAxisSpacing: VxSpacing.md,
        mainAxisSpacing: VxSpacing.md,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final song = artists[index];
        return Center(
          child: VxArtistCard(
            title: song.singer,
            subtitle: _sourceName(song.source),
            width: 168,
            shape: VxArtistCardShape.square,
            cover: (song.coverUrl?.isNotEmpty ?? false)
                ? null
                : CoverImage(url: song.coverUrl, size: 168, radius: 0),
            onTap: () => _openArtist(context, song),
          ),
        );
      },
    );
  }

  void _openArtist(BuildContext context, bridge.SongDto song) {
    final name = song.singer.trim();
    if (name.isEmpty || !widget.model.supportsArtist(song.source)) return;
    final id = song.artistId?.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistDetailPage(
          widget.model,
          bridge.ArtistDto(
            id: (id != null && id.isNotEmpty) ? id : name,
            name: name,
            source: song.source,
            coverUrl: null,
          ),
        ),
      ),
    );
  }

  /// 分页三态尾行：加载中 / 失败重试 / 没有更多。
  Widget _footer(BuildContext context) {
    final state = widget.model.state.search;
    if (_moreInFlight || state.loading) {
      return const Padding(
        padding: EdgeInsets.all(VxSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.all(VxSpacing.md),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '加载更多失败',
                style: VxTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: VxSpacing.md),
              TextButton(onPressed: _loadMoreIfNeeded, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(VxSpacing.lg),
        child: Center(
          child: Text(
            '没有更多结果',
            style: VxTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(VxSpacing.md),
      child: Center(
        child: Text(
          '继续滚动加载更多…',
          style: VxTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _sourceName(String source) =>
      widget.model.capability(source)?.name ?? source;
}
