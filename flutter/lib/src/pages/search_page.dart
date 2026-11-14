/// 全局搜索页（指南 §5.4）。
///
/// 布局：固定顶部搜索框（带清除钮）→ 类型 Segmented（全部/歌曲/专辑/歌手/
/// 歌单）→ 音源筛选 chips 行（横向滚动，提供「全部」，可多选）→ 结果计数行
/// → 结果区。
/// - 歌曲结果统一 VxTrackRow 行表（与曲库同一歌曲行）；hover 操作：
///   播放 / 加入队列 / 收藏 / 更多；
/// - 双击播放、单击选中、Ctrl 切换、Shift 范围多选、Enter 播放选中项；
/// - 输入 300ms 防抖；分页加载带 in-flight 锁与「加载中 / 没有更多 /
///   失败重试」三态，不会出现永久 spinner 或重复分页；
/// - 空关键词态展示本地搜索历史（shared_preferences，最新在前去重，单项
///   删除 + 清空确认；仅存本机不跨端同步，如实标注）；回车提交/点击历史项
///   / Shell 种子才记史，防抖中间态不入库；
/// - 专辑 / 歌手 Tab 由歌曲结果真实聚合（同专辑/同歌手去重），卡片带来源标识；
///   聚合搜索不返回歌单数据，歌单 Tab 如实解释。
///
/// 业务编排（防抖、request_id 守卫、分页 in-flight 锁、音源筛选、聚合派生）
/// 单一出处 [SearchPageController]（search_shared.dart，Batch C-02 提炼）：本页
/// 与手机 MobileSearchPage 共用，桌面 UI 行为不变。
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
import '../design_system/components/vx_artwork.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';
import 'search_shared.dart';

/// 手机页/测试仍从本文件消费类型枚举与共享件（迁移自本文件的公开面）。
export 'search_shared.dart'
    show
        SearchType,
        searchTypeLabel,
        SearchPageController,
        SearchResultFooter,
        confirmClearSearchHistory,
        searchSnapshotSignature;

class SearchPage extends StatefulWidget {
  final AppModel model;

  /// Shell 全局搜索框（Ctrl+K）提交的关键字种子：构造时填入输入框并触发搜索。
  final String seedKeyword;

  const SearchPage(this.model, {super.key, this.seedKeyword = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _fieldFocus = FocusNode();
  final _tableFocus = FocusNode();
  late SearchPageController _ctrl;

  /// 行选中索引（相对过滤后的展示列表）；Shift 选区锚点。
  final Set<int> _selectedRows = {};
  int _anchorRow = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = SearchPageController(widget.model);
    _ctrl.attach();
    final seed = widget.seedKeyword.trim();
    if (seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(record: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _ctrl
        ..detach()
        ..dispose();
      _ctrl = SearchPageController(widget.model);
      _ctrl.attach();
    }
  }

  @override
  void dispose() {
    _ctrl
      ..detach()
      ..dispose();
    _controller.dispose();
    _scrollController.dispose();
    _fieldFocus.dispose();
    _tableFocus.dispose();
    super.dispose();
  }

  // ── 数据/命令 ──

  /// 显式/防抖统一的搜索出口：空关键词只取消在途防抖（不派发、不清选中，
  /// 与提炼前语义一致）；非空清行选中后派发。
  void _runSearch({bool record = false}) {
    if (_controller.text.trim().isEmpty) {
      _ctrl.runSearch(_controller.text, record: record);
      return;
    }
    setState(() {
      _selectedRows.clear();
      _anchorRow = -1;
    });
    _ctrl.runSearch(_controller.text, record: record);
  }

  void _onSearchTextChanged(String text) => _ctrl.onSearchTextChanged(text);

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
    final items = _ctrl.items();
    if (index < 0 || index >= items.length) return;
    unawaited(widget.model.playSongs(items, index: index));
  }

  void _playSelection() {
    if (_selectedRows.isEmpty) return;
    final items = _ctrl.items();
    final songs = [
      for (final i in _selectedRows.toList()..sort())
        if (i >= 0 && i < items.length) items[i],
    ];
    if (songs.isEmpty) return;
    unawaited(widget.model.playSongs(songs, index: 0));
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      // 只挂控制器：request_id 守卫（§8.1）在控制器通知层——直接挂模型会让
      // 过期快照（requestId 回退）未经守卫刷进树（提炼前页面语义不变）。
      listenable: _ctrl,
      builder: (context, _) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _typeSegment(context),
                  const SizedBox(height: VxSpacing.sm),
                  _sourceChips(context),
                ],
              ),
            ),
            const SizedBox(height: VxSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VxSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ctrl.countLine(),
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(child: _resultArea(context)),
          ],
        );
      },
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _fieldFocus,
      autofocus: widget.seedKeyword.isEmpty,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(record: true),
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
                    _ctrl.onSearchTextChanged('');
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
          ButtonSegment(value: type, label: Text(searchTypeLabel(type))),
      ],
      selected: {_ctrl.type},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _selectedRows.clear();
          _anchorRow = -1;
        });
        _ctrl.selectType(selection.first);
      },
    );
  }

  /// 音源筛选 chips 行（指南 §5.4「音源筛选 chips 横向滚动，提供『全部』」；
  /// 此前实现的下拉引用 §4.3 属误引——§4.3 是状态与导航规则，与筛选形态
  /// 无关，Phase 3 实施时按指南裁决改回 chips）。多选语义保留：恰选 1 个
  /// 走后端过滤，多选聚合搜索 + 本地过滤展示。
  Widget _sourceChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.model.state.sources;
    if (sources.isEmpty) return const SizedBox.shrink();
    Widget chip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: VxSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VxSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: VxTypography.caption.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            '全部音源',
            selected: _ctrl.selectedSources.isEmpty,
            onTap: () {
              _ctrl.clearSources();
              // 换筛选重搜，保证数据与新筛选一致（不记史）。
              _runSearch();
            },
          ),
          for (final source in sources)
            chip(
              source.name,
              selected: _ctrl.selectedSources.contains(source.id),
              onTap: () {
                _ctrl.toggleSource(source.id);
                _runSearch();
              },
            ),
        ],
      ),
    );
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
      // P1-07 同类缺口（QA 2026-11-11）：state.search.error 是 Rust 快照
      // 字段，不经 lastError 净化链路；渲染前必须净化，原始 URL/异常不得
      // 直出 UI（§9）。原始异常已在命令/事件层写 stderr 日志。
      return VxErrorState(
        title: '搜索失败',
        message: '无法完成「${state.keyword}」的搜索。',
        detail: AppModel.sanitizeUserFacingMessage(state.error!),
        icon: Icons.cloud_off,
        onRetry: _runSearch,
      );
    }
    if (keyword.isEmpty) return _historyArea(context);
    if (state.items.isEmpty) {
      return VxEmptyState(
        icon: Icons.search_off,
        title: '没有结果',
        message: '没有找到与「${state.keyword}」匹配的内容，换个关键词试试。',
      );
    }

    return switch (_ctrl.type) {
      SearchType.all || SearchType.songs => _trackTable(context),
      SearchType.albums => _albumGrid(context),
      SearchType.artists => _artistGrid(context),
      SearchType.playlists => VxEmptyState(
        icon: Icons.queue_music_outlined,
        title: '聚合搜索不返回歌单结果',
        message: _ctrl.playlistsExplain(),
      ),
    };
  }

  // ── 搜索历史（空关键词态，§5.4）──

  /// 空关键词态：展示本地搜索历史（点击回填即搜、单项删除、清空确认）；
  /// 无历史退回引导空态。历史仅存本机 shared_preferences，如实标注不跨端。
  Widget _historyArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = widget.model.searchHistory;
    if (history.isEmpty) {
      return VxEmptyState(
        icon: Icons.search,
        title: '搜索你想听的音乐',
        message: '支持歌曲、歌手、专辑名；聚合搜索会同时查询已启用的音源。',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.lg,
        VxSpacing.sm,
        VxSpacing.lg,
        VxSpacing.xl,
      ),
      children: [
        Row(
          children: [
            Text('搜索历史', style: VxTypography.sectionTitle),
            const Spacer(),
            IconButton(
              tooltip: '清空搜索历史',
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              onPressed: () => confirmClearSearchHistory(context, widget.model),
            ),
          ],
        ),
        for (final keyword in history)
          ListTile(
            dense: true,
            leading: Icon(
              Icons.history,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(keyword, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: '删除该条历史',
              icon: const Icon(Icons.close, size: 16),
              onPressed: () =>
                  unawaited(widget.model.removeSearchHistory(keyword)),
            ),
            onTap: () {
              _controller.text = keyword;
              // 点击历史项 = 显式提交：回填即搜并置顶该条。
              _runSearch(record: true);
            },
          ),
        const SizedBox(height: VxSpacing.md),
        Text(
          '历史仅保存在本机（shared_preferences），不会上传账号或跨设备同步。',
          style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _trackTable(BuildContext context) {
    final items = _ctrl.items();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          _ctrl.loadMoreIfNeeded();
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
            if (index >= items.length) return SearchResultFooter(_ctrl);
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
                    // P1-08：行封面走统一入口 VxArtwork（实体键隔离/负缓存/
                    // 限尺寸解码）；列表密集场景失败态只显示占位图标，
                    // 不给每行渲染可聚焦重试钮（allowRetry=false）。
                    cover: VxArtwork(
                      url: song.coverUrl,
                      source: song.source,
                      entityType: 'song',
                      entityId: song.id,
                      entityName: song.name,
                      size: 40,
                      radius: 6,
                      allowRetry: false,
                    ),
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
    final albums = _ctrl.albumRepresentatives();
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
            cover: VxArtwork(
              url: song.coverUrl,
              source: song.source,
              entityType: 'album',
              entityId: song.albumId?.trim() ?? song.albumName,
              entityName: song.albumName,
              size: 168,
              radius: 0,
              icon: Icons.album_outlined,
              allowRetry: false,
            ),
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
    final artists = _ctrl.artistRepresentatives();
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
            cover: VxArtwork(
              url: song.coverUrl,
              source: song.source,
              entityType: 'artist',
              entityId: song.artistId?.trim() ?? song.singer,
              entityName: song.singer,
              size: 168,
              radius: 0,
              icon: Icons.person_outline,
              allowRetry: false,
            ),
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

  String _sourceName(String source) =>
      widget.model.capability(source)?.name ?? source;
}
