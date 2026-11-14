/// 手机搜索页（计划书 C-02，指南 §5.4：全局搜索的手机档布局）。
///
/// 布局顺序（全部在内容首部，滚动区之上；Scaffold resizeToAvoidBottomInset
/// 默认 true，键盘弹出不遮挡输入框，inset 契约见 shell/android_insets.dart）：
/// 搜索框（输入/清除/提交）→ 类型切换 chips（单行横滚）→ 音源筛选 chips
/// （单行横滚，「全部音源」↔ 单源可往返，恰选 1 个走后端过滤）→ 结果区。
///
/// - 结果：歌曲用移动行（VxTrackRow comfortable：封面/标题/歌手/来源/时长，
///   单击即播整列、长按 = 完整歌曲菜单 showSongMenu 与桌面同一动作集）；
///   专辑/歌手两列网格（同专辑/同歌手去重聚合，卡片带来源标识）；
///   歌单 Tab 如实解释（聚合搜索不返回歌单）；
/// - 空关键词态展示本地搜索历史（点击回填即搜、单项删除、清空确认 §9）；
/// - 分页尾三态（加载中 / 失败重试 / 没有更多）与触底自动续载，in-flight
///   锁防重复分页；request_id 守卫（新关键词使旧请求过期）沿用
///   [SearchPageController] 单一实现；
/// - 业务编排全部走共享 [SearchPageController]（search_shared.dart）与
///   AppModel，业务与桌面页同一实现，本页只做布局与交互；
/// - 触控目标 ≥48dp（chips 含触控余量、行高 66dp、历史行 56dp）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_artist_card.dart';
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_track_row.dart';
import '../design_system/design_tokens.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';
import 'search_shared.dart';
import 'song_tile.dart'
    show albumOfSong, artistOfSong, showSongMenu, songSourceLabel;

class MobileSearchPage extends StatefulWidget {
  final AppModel model;

  /// 壳层搜索种子：构造时填入输入框并触发搜索（与桌面 SearchPage 同语义）。
  final String seedKeyword;

  const MobileSearchPage(this.model, {super.key, this.seedKeyword = ''});

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _fieldFocus = FocusNode();
  late SearchPageController _ctrl;

  AppModel get _model => widget.model;

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
  void didUpdateWidget(covariant MobileSearchPage oldWidget) {
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
    super.dispose();
  }

  void _runSearch({bool record = false}) =>
      _ctrl.runSearch(_controller.text, record: record);

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    // 只挂控制器：request_id 守卫（§8.1）在控制器通知层，与桌面页同口径。
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _searchField(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, VxSpacing.sm, 20, 0),
              child: _typeChips(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, VxSpacing.xs, 20, 0),
              child: _sourceChips(context),
            ),
            const SizedBox(height: VxSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ctrl.countLine(),
                  style: VxTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      onChanged: _ctrl.onSearchTextChanged,
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

  /// 类型切换 chips（单行横滚，紧凑化：Segmented 五档在 360dp 视口溢出）。
  Widget _typeChips(BuildContext context) {
    return SizedBox(
      key: const ValueKey('mobile-search-types'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final type in SearchType.values)
            _chip(
              context,
              label: searchTypeLabel(type),
              selected: _ctrl.type == type,
              onTap: () => _ctrl.selectType(type),
            ),
        ],
      ),
    );
  }

  /// 音源筛选 chips（单行横滚；多选语义与桌面一致：恰选 1 个走后端过滤，
  /// 多选聚合搜索 + 本地过滤展示；换筛选重搜不记史）。
  Widget _sourceChips(BuildContext context) {
    final sources = _model.state.sources;
    if (sources.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const ValueKey('mobile-search-sources'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            context,
            label: '全部音源',
            selected: _ctrl.selectedSources.isEmpty,
            onTap: () {
              _ctrl.clearSources();
              _runSearch();
            },
          ),
          for (final source in sources)
            _chip(
              context,
              label: source.name,
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

  /// 紧凑 chips：视觉胶囊 32dp + 上下触控余量各 8dp = 触控目标 48dp（§5.9）。
  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: VxSpacing.sm),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
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
        ),
      ),
    );
  }

  // ── 结果区 ──

  Widget _resultArea(BuildContext context) {
    final state = _model.state.search;
    final keyword = _controller.text.trim();

    if (state.loading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: VxLoadingSkeleton.tracks(rows: 6),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      // P1-07 同口径：Rust 快照错误字段不经净化链路，渲染前必须净化（§9）。
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
      SearchType.all || SearchType.songs => _songList(context),
      SearchType.albums => _albumGrid(context),
      SearchType.artists => _artistGrid(context),
      SearchType.playlists => VxEmptyState(
        icon: Icons.queue_music_outlined,
        title: '聚合搜索不返回歌单结果',
        message: _ctrl.playlistsExplain(),
      ),
    };
  }

  /// 歌曲结果：移动行列表（触底自动续载 + 尾三态）。
  Widget _songList(BuildContext context) {
    final items = _ctrl.items();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          _ctrl.loadMoreIfNeeded();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: VxSpacing.xl),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index >= items.length) return SearchResultFooter(_ctrl);
          final song = items[index];
          return _songRow(context, items, song, index);
        },
      ),
    );
  }

  /// 移动歌曲行：标题/歌手/来源/时长；单击即播整列（触屏无 hover，行内
  /// 悬停操作不可达——长按 = 桌面右键/更多菜单的触屏替代，同一份菜单与
  /// 命令接线 showSongMenu，§9）。
  Widget _songRow(
    BuildContext context,
    List<bridge.SongDto> items,
    bridge.SongDto song,
    int index,
  ) {
    final current = _model.state.playback.song;
    return VxTrackRow(
      title: song.name,
      artist: song.singer,
      source: songSourceLabel(_model, song.source),
      density: VxTrackRowDensity.comfortable,
      showIndex: false,
      showAlbum: false,
      cover: VxArtwork(
        url: song.coverUrl,
        source: song.source,
        entityType: 'song',
        entityId: song.id,
        entityName: song.name,
        size: 44,
        radius: 6,
        allowRetry: false,
      ),
      duration: song.durationMs.toInt() > 0
          ? Duration(milliseconds: song.durationMs.toInt())
          : null,
      isPlaying:
          current != null &&
          current.id == song.id &&
          current.source == song.source,
      isLiked: _model.isFavorite(song),
      onTap: () => _model.playSongs(items, index: index),
      onLongPressStart: (details) =>
          showSongMenu(context, _model, song, position: details.globalPosition),
      onMore: () {
        final box = context.findRenderObject() as RenderBox?;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        Offset? anchor;
        if (box != null && overlay != null) {
          anchor = box.localToGlobal(
            Offset(box.size.width - 40, box.size.height / 2),
          );
        }
        showSongMenu(context, _model, song, position: anchor);
      },
    );
  }

  // ── 专辑 / 歌手（歌曲结果聚合，两列网格）──

  Widget _albumGrid(BuildContext context) {
    final albums = _ctrl.albumRepresentatives();
    if (albums.isEmpty) {
      return VxEmptyState(
        icon: Icons.album_outlined,
        title: '结果中没有专辑',
        message: '本次搜索结果没有携带专辑信息，试试搜索专辑名或换个关键词。',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - VxSpacing.lg * 2 - VxSpacing.md) / 2;
        return GridView.builder(
          padding: const EdgeInsets.all(VxSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: VxSpacing.md,
            mainAxisSpacing: VxSpacing.md,
            mainAxisExtent: cardWidth + 72,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final song = albums[index];
            return VxAlbumCard(
              title: song.albumName,
              subtitle:
                  '${song.singer} · ${songSourceLabel(_model, song.source)}',
              width: cardWidth,
              cover: VxArtwork(
                url: song.coverUrl,
                source: song.source,
                entityType: 'album',
                entityId: song.albumId?.trim() ?? song.albumName,
                entityName: song.albumName,
                size: cardWidth,
                radius: 0,
                icon: Icons.album_outlined,
                allowRetry: false,
              ),
              onTap: () => _openAlbum(context, song),
            );
          },
        );
      },
    );
  }

  /// 专辑落点复用 song_tile 的 albumOfSong（含专辑名/能力位守卫，桌面
  /// 搜索页同一语义）。
  void _openAlbum(BuildContext context, bridge.SongDto song) {
    final album = albumOfSong(_model, song);
    if (album == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlbumSongsPage(_model, album)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - VxSpacing.lg * 2 - VxSpacing.md) / 2;
        return GridView.builder(
          padding: const EdgeInsets.all(VxSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: VxSpacing.md,
            mainAxisSpacing: VxSpacing.md,
            mainAxisExtent: cardWidth + 72,
          ),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final song = artists[index];
            return VxArtistCard(
              title: song.singer,
              subtitle: songSourceLabel(_model, song.source),
              width: cardWidth,
              shape: VxArtistCardShape.square,
              cover: VxArtwork(
                url: song.coverUrl,
                source: song.source,
                entityType: 'artist',
                entityId: song.artistId?.trim() ?? song.singer,
                entityName: song.singer,
                size: cardWidth,
                radius: 0,
                icon: Icons.person_outline,
                allowRetry: false,
              ),
              onTap: () => _openArtist(context, song),
            );
          },
        );
      },
    );
  }

  /// 歌手落点复用 song_tile 的 artistOfSong（含歌手名/能力位守卫）。
  void _openArtist(BuildContext context, bridge.SongDto song) {
    final artist = artistOfSong(_model, song);
    if (artist == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArtistDetailPage(_model, artist)),
    );
  }

  // ── 搜索历史（空关键词态，§5.4）──

  /// 空关键词态：本地搜索历史（点击回填即搜、单项删除、清空确认）；
  /// 无历史退回引导空态。历史仅存本机 shared_preferences，如实标注不跨端。
  Widget _historyArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = _model.searchHistory;
    if (history.isEmpty) {
      return VxEmptyState(
        icon: Icons.search,
        title: '搜索你想听的音乐',
        message: '支持歌曲、歌手、专辑名；聚合搜索会同时查询已启用的音源。',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, VxSpacing.sm, 20, VxSpacing.xl),
      children: [
        Row(
          children: [
            Text('搜索历史', style: VxTypography.sectionTitle),
            const Spacer(),
            IconButton(
              tooltip: '清空搜索历史',
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              onPressed: () => confirmClearSearchHistory(context, _model),
            ),
          ],
        ),
        for (final keyword in history)
          ListTile(
            leading: Icon(
              Icons.history,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(keyword, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: '删除该条历史',
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => unawaited(_model.removeSearchHistory(keyword)),
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
}
