/// 我的音乐（§4.4）：统一歌曲、专辑、歌手、歌单。
///
/// - 二级切换：歌曲 / 专辑 / 歌手 / 歌单（计数徽章，0 值弱化不隐藏）；
/// - 右侧工具：搜索当前视图 + 排序 + 网格/列表切换（按视图可用性显示）+ 刷新；
/// - 歌曲 = 喜欢的歌曲（含账号红心镜像，平台来源明确标注）；
///   专辑 / 歌手 = 本地收藏、最近播放与本地音乐里出现过的专辑 / 歌手聚合
///   （本地曲库快照派生，无伪造数据）；歌单 = 自建歌单 + 收藏歌单；
/// - 最近播放 / 本地音乐 / 喜欢的歌曲三个入口语义独立（入口卡）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_album_card.dart';
import '../design_system/components/vx_artist_card.dart';
import '../design_system/components/vx_cover_fallback.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_table_view.dart';
import 'album_songs_page.dart';
import 'artist_detail_page.dart';
import 'custom_playlists_page.dart';
import 'local_music_page.dart';
import 'playlist_detail_page.dart';
import 'song_tile.dart' show songSourceLabel;

/// 二级类别。
enum LibraryTab { songs, albums, artists, playlists }

class LibraryPage extends StatefulWidget {
  final AppModel model;

  /// 初始二级类别（验收截图用）；null 从歌曲开始。
  final LibraryTab? initialTab;

  const LibraryPage(this.model, {super.key, this.initialTab});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryTab _tab = widget.initialTab ?? LibraryTab.songs;
  String _query = '';
  String _sort = 'default';
  bool _grid = true;

  /// 来源筛选（§5.5）；null = 全部来源。
  String? _sourceFilter;

  /// 红心镜像视图：local = 本地收藏；wy/tx = 账号镜像（来源明确标注）。
  String _favoriteView = 'local';
  static const _mirrorPlatforms = [('wy', '网易云'), ('tx', 'QQ')];

  AppModel get _model => widget.model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            if (_tab == LibraryTab.songs) _favoriteViewSwitch(context),
            _sourceChips(context),
            Expanded(child: _body(context)),
          ],
        );
      },
    );
  }

  // ── 头部：标题 + 三入口 + 二级切换 + 工具 ──

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // 窄视口（<512：手机档 360-599 全覆盖）标题独占一行、工具条
              // 移到下一行（Phase 2 QA P1）：同 Row 时定宽 200 搜索条 +
              // 三图标占 308-360px，h1「我的音乐」需 ≥113.6px，430 视口
              // 剩余 90px 必折两行（「我的音/乐」），360 更挤。512 分界由
              // 最宽工具档（专辑/歌手 360px）反推：宽档需 ≥505.6 才放得下。
              final compact = constraints.maxWidth < 512;
              final title = Text(
                '我的音乐',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.h1.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: VxSpacing.md),
                    _tools(context, compact: true),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  _tools(context),
                ],
              );
            },
          ),
          const SizedBox(height: VxSpacing.md),
          _entryCards(context),
          const SizedBox(height: VxSpacing.sm),
          _tabs(context),
        ],
      ),
    );
  }

  /// 独立入口：最近播放 / 本地音乐 / 喜欢的歌曲（语义互不混用）。
  Widget _entryCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄视口（<512，与 _header compact 同阈值）：三列等分下「标签 +
        // 计数」同一行放不下（430 视口每列 ~131px，「最近播放」4 字 +
        // 「N 首」必触发省略号截断，P2-10）——标签独占一行、计数移到
        // 第二行；桌面 ≥512 保持单行布局。
        final compact = constraints.maxWidth < 512;
        return Row(
          children: [
            _entryCard(
              context,
              compact: compact,
              icon: Icons.history,
              label: '最近播放',
              count: _model.state.history.length,
              unit: '首',
              onTap: () => _openRecent(context),
            ),
            _entryCard(
              context,
              compact: compact,
              icon: Icons.speaker_outlined,
              label: '本地音乐',
              count: _model.state.localSongs.length,
              unit: '首',
              onTap: () => _openLocalMusic(context),
            ),
            _entryCard(
              context,
              compact: compact,
              icon: Icons.favorite_border,
              label: '喜欢的歌曲',
              count: _model.state.favorites.length,
              unit: '首',
              onTap: () => setState(() => _tab = LibraryTab.songs),
            ),
          ],
        );
      },
    );
  }

  Widget _entryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required String unit,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final countText = Text(
      '$count $unit',
      style: VxTypography.mono.copyWith(color: scheme.onSurfaceVariant),
    );
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
    );
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(VxRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VxSpacing.md,
            vertical: VxSpacing.sm + 2,
          ),
          margin: const EdgeInsets.only(right: VxSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(VxRadius.md),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 标签独占一行（不与图标同排）：360 最窄档三列内宽
                    // ~77px，四字标签 ~56px 仅在独占整行时放得下。
                    labelText,
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(icon, size: 14, color: scheme.primary),
                        const SizedBox(width: VxSpacing.sm),
                        countText,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, size: 18, color: scheme.primary),
                    const SizedBox(width: VxSpacing.sm),
                    Expanded(child: labelText),
                    countText,
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    // Wrap：桌面一行放下时与 Row 视觉一致；手机窄宽自动换行不溢出
    // （Phase 7 触屏适配）。计数随来源筛选同步变化（§5.5）。
    final customVisible = _sourceFilter == null || _sourceFilter == 'local';
    return Wrap(
      children: [
        _tabPill(
          context,
          tab: LibraryTab.songs,
          label: '歌曲',
          count: _model.state.favorites
              .where((s) => _matchesSource(s.source))
              .length,
        ),
        _tabPill(
          context,
          tab: LibraryTab.albums,
          label: '专辑',
          count: _albumGroups().where((g) => _matchesSource(g.source)).length,
        ),
        _tabPill(
          context,
          tab: LibraryTab.artists,
          label: '歌手',
          count: _artistGroups().where((g) => _matchesSource(g.source)).length,
        ),
        _tabPill(
          context,
          tab: LibraryTab.playlists,
          label: '歌单',
          count:
              (customVisible ? _model.state.customPlaylists.length : 0) +
              _model.state.favoritePlaylists
                  .where((p) => _matchesSource(p.source))
                  .length,
        ),
      ],
    );
  }

  // ── 来源筛选 chips（§5.5：本地/在线来源不能混淆，过滤后标题与计数同步）──

  bool _matchesSource(String source) =>
      _sourceFilter == null || source == _sourceFilter;

  /// 从 favorites + history + localSongs 实际出现的 song.source 派生
  /// （与专辑/歌手聚合同一数据域；无数据不显示，不伪造）。
  List<String> _availableSources() {
    final seen = <String>[];
    for (final song in [
      ..._model.state.favorites,
      ..._model.state.history,
      ..._model.state.localSongs,
    ]) {
      final source = song.source.trim();
      if (source.isEmpty) continue;
      if (!seen.contains(source)) seen.add(source);
    }
    return seen;
  }

  /// 来源 chips 行（横向滚动）。少于 2 个来源时无可筛，整行不显示。
  /// 组合规则：歌曲档本地视图按 favorites 的 source 过滤；镜像视图的
  /// songs 来源固定平台 id，选其他来源如实为空；自建歌单是本地数据，
  /// 仅在「全部来源」或「本地音乐」下展示。
  Widget _sourceChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources = _availableSources();
    if (sources.length < 2) return const SizedBox.shrink();
    Widget chip(String label, {required bool selected, required onTap}) {
      return Padding(
        padding: const EdgeInsets.only(right: VxSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(onTap),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip(
              '全部来源',
              selected: _sourceFilter == null,
              onTap: () => _sourceFilter = null,
            ),
            for (final source in sources)
              chip(
                songSourceLabel(_model, source),
                selected: _sourceFilter == source,
                onTap: () => _sourceFilter = source,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(
    BuildContext context, {
    required LibraryTab tab,
    required String label,
    required int count,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: VxSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(VxRadius.md),
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VxSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(VxRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: VxTypography.titleSm.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: count == 0
                      ? scheme.surfaceContainerHighest
                      : scheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: VxTypography.mono.copyWith(
                    fontSize: 11,
                    color: count == 0
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tools(BuildContext context, {bool compact = false}) {
    final showSort = _tab != LibraryTab.playlists;
    final showViewToggle =
        _tab == LibraryTab.albums || _tab == LibraryTab.artists;
    final searchField = TextField(
      onChanged: (value) => setState(() => _query = value.trim()),
      decoration: InputDecoration(
        isDense: true,
        hintText: '在当前视图中搜索…',
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VxRadius.md),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // compact（窄视口独立工具行）：弹性宽度——固定 200 在 360 视口的
        // 专辑/歌手档（三图标 160 + 分隔 16）会横向溢出；桌面保持 200 定宽
        // 视觉零变化。
        if (compact)
          Expanded(child: searchField)
        else
          SizedBox(width: 200, child: searchField),
        if (showSort) ...[
          const SizedBox(width: VxSpacing.sm),
          PopupMenuButton<String>(
            tooltip: '排序',
            onSelected: (value) => setState(() => _sort = value),
            icon: const Icon(Icons.sort, size: 20),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'default', child: Text('默认排序')),
              const PopupMenuItem(value: 'title', child: Text('按标题')),
              if (_tab == LibraryTab.songs)
                const PopupMenuItem(value: 'artist', child: Text('按歌手')),
              if (_tab == LibraryTab.songs)
                const PopupMenuItem(value: 'duration', child: Text('按时长')),
              if (_tab != LibraryTab.songs)
                const PopupMenuItem(value: 'count', child: Text('按曲目数')),
            ],
          ),
        ],
        if (showViewToggle) ...[
          const SizedBox(width: VxSpacing.xs),
          IconButton(
            tooltip: _grid ? '切换为列表' : '切换为网格',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(
              _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
              size: 20,
            ),
          ),
        ],
        const SizedBox(width: VxSpacing.xs),
        IconButton(
          tooltip: '刷新曲库',
          onPressed: () {
            _model.dispatch(const bridge.FfiCommand.libraryRefresh());
            if (_favoriteView != 'local') {
              _model.loadAccountFavorites(_favoriteView);
            }
          },
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }

  // ── 歌曲视图 ──

  Widget _favoriteViewSwitch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          segments: [
            const ButtonSegment(value: 'local', label: Text('本地')),
            for (final (id, label) in _mirrorPlatforms)
              ButtonSegment(value: id, label: Text(label)),
          ],
          selected: {_favoriteView},
          onSelectionChanged: (value) {
            setState(() => _favoriteView = value.first);
            if (_favoriteView != 'local') {
              _model.loadAccountFavorites(_favoriteView);
            }
          },
        ),
      ),
    );
  }

  List<bridge.SongDto> _sortedSongs(List<bridge.SongDto> songs) {
    final list = [...songs];
    switch (_sort) {
      case 'title':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'artist':
        list.sort((a, b) => a.singer.compareTo(b.singer));
      case 'duration':
        list.sort(
          (a, b) => b.durationMs.toInt().compareTo(a.durationMs.toInt()),
        );
      default:
        break;
    }
    return list;
  }

  bool _matchesSong(bridge.SongDto song) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return true;
    return song.name.toLowerCase().contains(q) ||
        song.singer.toLowerCase().contains(q) ||
        song.albumName.toLowerCase().contains(q);
  }

  Widget _songsBody(BuildContext context) {
    if (_favoriteView == 'local') {
      final songs = _sortedSongs(
        _model.state.favorites
            .where(_matchesSong)
            .where((s) => _matchesSource(s.source))
            .toList(),
      );
      return VxSongTable(
        model: _model,
        songs: songs,
        emptyTitle: _query.isEmpty ? '还没有收藏' : '没有匹配的歌曲',
        emptySubtitle: _query.isEmpty ? '在搜索页点击心形把歌曲收进来' : '换个关键词试试',
      );
    }
    final result = _model.accountFavorites(_favoriteView);
    if (result == null || (result.loading && result.songs.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result.error != null) {
      return VxEmptyState(
        icon: Icons.cloud_off_outlined,
        title: '红心镜像读取失败',
        message: result.error!,
        actionLabel: '重试',
        onAction: () => _model.loadAccountFavorites(_favoriteView),
      );
    }
    final songs = _sortedSongs(
      result.songs
          .where(_matchesSong)
          .where((s) => _matchesSource(s.source))
          .toList(),
    );
    return VxSongTable(
      model: _model,
      songs: songs,
      emptyTitle: result.notice ?? '暂无账号红心镜像',
      // 镜像 songs 的来源固定平台 id：所选来源不匹配时如实为空表（§5.5
      // 「本地/在线来源筛选不能混淆」，计数同步变化）。
      emptySubtitle: result.notice == null
          ? (songs.isEmpty && _sourceFilter != null
                ? '所选来源下没有账号红心镜像歌曲'
                : '请先在「发现 → 我的歌单」中同步账号歌单')
          : null,
    );
  }

  // ── 专辑 / 歌手聚合视图 ──

  /// 本地收藏 + 最近播放 + 本地音乐里出现过的专辑（来源 + 专辑名聚合）。
  List<_AlbumGroup> _albumGroups() {
    final songs = [
      ..._model.state.favorites,
      ..._model.state.history,
      ..._model.state.localSongs,
    ];
    final Map<String, _AlbumGroup> groups = {};
    for (final song in songs) {
      final name = song.albumName.trim();
      if (name.isEmpty) continue;
      final key = '${song.source}|$name';
      final group = groups.putIfAbsent(
        key,
        () => _AlbumGroup(
          name: name,
          singer: song.singer,
          source: song.source,
          coverUrl: song.coverUrl,
        ),
      );
      group.songs.add(song);
      if (group.albumId == null) {
        final id = song.albumId?.trim();
        if (id != null && id.isNotEmpty) group.albumId = id;
      }
    }
    return groups.values.toList();
  }

  /// 同理聚合歌手。
  List<_ArtistGroup> _artistGroups() {
    final songs = [
      ..._model.state.favorites,
      ..._model.state.history,
      ..._model.state.localSongs,
    ];
    final Map<String, _ArtistGroup> groups = {};
    for (final song in songs) {
      final name = song.singer.trim();
      if (name.isEmpty) continue;
      final key = '${song.source}|$name';
      final group = groups.putIfAbsent(
        key,
        () => _ArtistGroup(name: name, source: song.source),
      );
      group.songs.add(song);
      if (group.artistId == null) {
        final id = song.artistId?.trim();
        if (id != null && id.isNotEmpty) group.artistId = id;
      }
    }
    return groups.values.toList();
  }

  List<_AlbumGroup> _sortedAlbums(List<_AlbumGroup> groups) {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups
              .where(
                (g) =>
                    g.name.toLowerCase().contains(q) ||
                    g.singer.toLowerCase().contains(q),
              )
              .toList();
    final list = [...filtered];
    switch (_sort) {
      case 'title':
        list.sort((a, b) => a.name.compareTo(b.name));
      case 'count':
        list.sort((a, b) => b.songs.length.compareTo(a.songs.length));
      default:
        break;
    }
    return list;
  }

  List<_ArtistGroup> _sortedArtists(List<_ArtistGroup> groups) {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups.where((g) => g.name.toLowerCase().contains(q)).toList();
    final list = [...filtered];
    switch (_sort) {
      case 'title':
        list.sort((a, b) => a.name.compareTo(b.name));
      case 'count':
        list.sort((a, b) => b.songs.length.compareTo(a.songs.length));
      default:
        break;
    }
    return list;
  }

  Widget _albumsBody(BuildContext context) {
    final groups = _sortedAlbums(
      _albumGroups().where((g) => _matchesSource(g.source)).toList(),
    );
    if (groups.isEmpty) {
      return VxEmptyState(
        icon: Icons.album_outlined,
        title: _query.isEmpty ? '还没有专辑' : '没有匹配的专辑',
        message: '收藏歌曲、播放历史或本地音乐里出现过的专辑会聚在这里。',
      );
    }
    if (_grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const minCard = 156;
          final columns = (constraints.maxWidth ~/ minCard).clamp(2, 8);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: VxSpacing.lg,
              crossAxisSpacing: VxSpacing.lg,
              // VxCardShell 内容高 ≈ 宽+60（两行标题），0.68 留余量。
              childAspectRatio: 0.68,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) => _albumCell(context, groups[index]),
          );
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) => _albumListRow(context, groups[index]),
    );
  }

  bridge.AlbumDto _albumDtoOf(_AlbumGroup group) => bridge.AlbumDto(
    id: group.albumId ?? group.name,
    name: group.name,
    source: group.source,
    coverUrl: group.coverUrl,
    artist: group.singer,
  );

  void _openAlbum(BuildContext context, _AlbumGroup group) {
    final album = _albumDtoOf(group);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _model.supportsAlbum(group.source)
            ? AlbumSongsPage(_model, album)
            : AlbumSongsPage(_model, album, presetSongs: [...group.songs]),
      ),
    );
  }

  Widget _albumCell(BuildContext context, _AlbumGroup group) {
    final url = group.coverUrl;
    return Center(
      child: VxAlbumCard(
        title: group.name,
        subtitle:
            '${group.singer.isEmpty ? '未知歌手' : group.singer} · ${group.songs.length} 首',
        cover: (url == null || url.isEmpty)
            ? VxCoverFallback(title: group.name, radius: VxRadius.lg)
            : CoverImage.expand(
                url: url,
                radius: VxRadius.lg,
                icon: Icons.album_outlined,
              ),
        onTap: () => _openAlbum(context, group),
      ),
    );
  }

  Widget _albumListRow(BuildContext context, _AlbumGroup group) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CoverImage(
        url: group.coverUrl,
        size: 44,
        radius: 8,
        icon: Icons.album_outlined,
      ),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${group.singer.isEmpty ? '未知歌手' : group.singer} · '
        '${songSourceLabel(_model, group.source)} · ${group.songs.length} 首',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openAlbum(context, group),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      iconColor: scheme.onSurfaceVariant,
    );
  }

  Widget _artistsBody(BuildContext context) {
    final groups = _sortedArtists(
      _artistGroups().where((g) => _matchesSource(g.source)).toList(),
    );
    if (groups.isEmpty) {
      return VxEmptyState(
        icon: Icons.person_outline,
        title: _query.isEmpty ? '还没有歌手' : '没有匹配的歌手',
        message: '收藏歌曲、播放历史或本地音乐里出现过的歌手会聚在这里。',
      );
    }
    if (_grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const minCard = 156;
          final columns = (constraints.maxWidth ~/ minCard).clamp(2, 8);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: VxSpacing.lg,
              crossAxisSpacing: VxSpacing.lg,
              childAspectRatio: 0.70,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) =>
                _artistCell(context, groups[index]),
          );
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) => _artistListRow(context, groups[index]),
    );
  }

  void _openArtist(BuildContext context, _ArtistGroup group) {
    final artist = bridge.ArtistDto(
      id: group.artistId ?? group.name,
      name: group.name,
      source: group.source,
      coverUrl: null,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _model.supportsArtist(group.source)
            ? ArtistDetailPage(_model, artist)
            : ArtistDetailPage(_model, artist, presetSongs: [...group.songs]),
      ),
    );
  }

  Widget _artistCell(BuildContext context, _ArtistGroup group) {
    return Center(
      child: VxArtistCard(
        title: group.name,
        subtitle: '${group.songs.length} 首',
        shape: VxArtistCardShape.square,
        onTap: () => _openArtist(context, group),
      ),
    );
  }

  Widget _artistListRow(BuildContext context, _ArtistGroup group) {
    return ListTile(
      leading: VxCoverFallback(title: group.name, radius: 999),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${songSourceLabel(_model, group.source)} · ${group.songs.length} 首',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openArtist(context, group),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ── 歌单视图 ──

  Widget _playlistsBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomPlaylistsSection(
            _model,
            query: _query,
            source: _sourceFilter,
          ),
        ),
        const Divider(height: 1),
        _favoritePlaylists(context),
      ],
    );
  }

  /// 收藏歌单（远端歌单收藏到本地库）；封面列表形态（§4.4）。
  Widget _favoritePlaylists(BuildContext context) {
    final playlists = _model.state.favoritePlaylists;
    final q = _query.toLowerCase();
    final filtered = playlists
        .where((p) => _matchesSource(p.source))
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              '收藏歌单（${filtered.length}）',
              style: VxTypography.titleSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const VxEmptyState(
                    icon: Icons.playlist_add_check,
                    title: '还没有收藏歌单',
                    message: '在歌单详情页点收藏，把远端歌单存进本地库。',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _favoritePlaylistRow(context, filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _favoritePlaylistRow(
    BuildContext context,
    bridge.PlaylistDto playlist,
  ) {
    return ListTile(
      leading: CoverImage(
        url: playlist.coverUrl,
        size: 48,
        radius: 8,
        icon: Icons.queue_music,
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${songSourceLabel(_model, playlist.source)} · ${playlist.songCount} 首',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaylistDetailPage(_model, playlist),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ── 路由分发 ──

  Widget _body(BuildContext context) {
    return switch (_tab) {
      LibraryTab.songs => _songsBody(context),
      LibraryTab.albums => _albumsBody(context),
      LibraryTab.artists => _artistsBody(context),
      LibraryTab.playlists => _playlistsBody(context),
    };
  }

  void _openRecent(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => RecentSongsPage(_model)));
  }

  void _openLocalMusic(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LocalMusicPage(_model)));
  }
}

/// 由歌曲聚合出的专辑组（本地派生数据，非伪造）。
class _AlbumGroup {
  final String name;
  final String singer;
  final String source;
  final String? coverUrl;
  String? albumId;
  final List<bridge.SongDto> songs = [];

  _AlbumGroup({
    required this.name,
    required this.singer,
    required this.source,
    this.coverUrl,
  });
}

/// 由歌曲聚合出的歌手组。
class _ArtistGroup {
  final String name;
  final String source;
  String? artistId;
  final List<bridge.SongDto> songs = [];

  _ArtistGroup({required this.name, required this.source});
}

/// 最近播放独立页：三入口语义之一，播放记录可清空。
class RecentSongsPage extends StatelessWidget {
  final AppModel model;

  const RecentSongsPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final songs = model.state.history;
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(context, songs),
              Expanded(
                child: VxSongTable(
                  model: model,
                  songs: songs,
                  emptyTitle: '播放记录为空',
                  emptySubtitle: '播放的歌曲会出现在这里',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, List<bridge.SongDto> songs) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: VxSpacing.md),
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          const SizedBox(width: VxSpacing.xs),
          Text(
            '最近播放',
            style: VxTypography.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: VxSpacing.sm),
          Text(
            '${songs.length} 首',
            style: VxTypography.mono.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: songs.isEmpty
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('清空播放历史'),
                        content: const Text('将删除全部播放记录，无法恢复。'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
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
          const SizedBox(width: VxSpacing.lg),
        ],
      ),
    );
  }
}
