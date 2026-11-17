/// 专辑详情：返回行 + DetailHero + 曲目 TrackTable（§4.5）。
///
/// - 封面 224px、标题 28px、来源徽章、曲目数 / 总时长元信息；
/// - 主操作「播放」+「随机播放」（随机 = 从已载入曲目随机起点开始，
///   顺序继续；不伪造完整乱序）；命令不存在的操作禁用并说明；
/// - 曲目表复用全局 TrackRow：当前曲持续高亮、双击播放、右键菜单；
/// - `presetSongs`：本地专辑等无后端详情命令的场景直接展示本地曲目，
///   不发网络请求（数据仍来自本地曲库快照，非伪造）。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_detail_hero.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_table_view.dart';
import 'song_tile.dart' show songSourceLabel;

class AlbumSongsPage extends StatefulWidget {
  final AppModel model;
  final bridge.AlbumDto album;

  /// 本地专辑等场景：直接展示的曲目（来自本地曲库快照）。
  final List<bridge.SongDto>? presetSongs;

  const AlbumSongsPage(this.model, this.album, {super.key, this.presetSongs});

  @override
  State<AlbumSongsPage> createState() => _AlbumSongsPageState();
}

class _AlbumSongsPageState extends State<AlbumSongsPage> {
  static const _kind = 'album_songs';

  /// 曲目排序：默认（音源返回序）/ 标题 / 时长。
  String _sort = 'default';

  AppModel get _model => widget.model;
  bridge.AlbumDto get _album => widget.album;

  bool get _preset => widget.presetSongs != null;

  @override
  void initState() {
    super.initState();
    if (!_preset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _model.loadAlbumSongs(_album);
      });
    }
  }

  BrowseResult? get _result =>
      _preset ? null : _model.browse(_kind, _album.source, _album.id);

  void _reload() {
    if (_preset) return;
    _model.loadAlbumSongs(_album);
  }

  void _loadMore() {
    if (_preset) return;
    final result = _result;
    if (result == null || result.loading) return;
    _model.loadAlbumSongs(_album, page: result.page + 1);
  }

  /// 下拉刷新（§5.6）：完成 Future = 本代次 page=1 响应或错误落槽；
  /// preset（本地专辑）无后端命令，不接下拉——否则 spinner 永不完成。
  Future<void> _refresh() async {
    if (_preset) return;
    final wait = _model.awaitBrowseResponse(_kind, _album.source, _album.id);
    final error = await _model.loadAlbumSongs(_album);
    if (error != null) return;
    await wait.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  List<bridge.SongDto> _sorted(List<bridge.SongDto> songs) {
    final list = [...songs];
    switch (_sort) {
      case 'title':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'duration':
        list.sort(
          (a, b) => b.durationMs.toInt().compareTo(a.durationMs.toInt()),
        );
      default:
        break;
    }
    return list;
  }

  /// 已载入曲目总时长（缺时长的曲目不计入，不伪造 00:00）。
  Duration _totalDuration(List<bridge.SongDto> songs) {
    var ms = 0;
    for (final song in songs) {
      final d = song.durationMs.toInt();
      if (d > 0) ms += d;
    }
    return Duration(milliseconds: ms);
  }

  /// 随机播放：从已载入曲目随机选一首开始（顺序继续）。
  /// 这是现有 playSongs 命令能做到的真实语义；完整乱序需要后端支持。
  void _playShuffled(List<bridge.SongDto> songs) {
    if (songs.length <= 1) {
      _model.playSongs(songs);
      return;
    }
    final index = Random().nextInt(songs.length);
    _model.playSongs(songs, index: index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
        final loading = !_preset && (result == null || result.loading);
        final error = result?.error;
        final rawSongs = _preset
            ? widget.presetSongs!
            : (result?.songs ?? const <bridge.SongDto>[]);
        final songs = _sorted(rawSongs);
        final notice = result?.notice;
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _backBar(context),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(context, rawSongs),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VxSpacing.xl,
                  VxSpacing.lg,
                  VxSpacing.xl,
                  0,
                ),
                child: VxSectionHeader(
                  title: '曲目列表',
                  actions: [
                    if (!_preset)
                      IconButton(
                        tooltip: '刷新',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    _sortMenu(context),
                  ],
                ),
              ),
              Expanded(
                child: VxSongTable(
                  model: _model,
                  songs: songs,
                  loading: loading,
                  error: error,
                  notice: notice,
                  emptyTitle: '专辑暂无曲目',
                  emptySubtitle: '换一个专辑试试',
                  onRetry: _reload,
                  hasMore: result?.hasMore ?? false,
                  onLoadMore: _loadMore,
                  onRefresh: _preset ? null : _refresh,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 顶部返回行（§4.5 线框「← 返回」）；详情页是压栈路由，自行提供返回。
  Widget _backBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: VxSpacing.md),
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          Expanded(
            child: Text(
              _album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VxTypography.titleSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '排序',
      onSelected: (value) => setState(() => _sort = value),
      icon: const Icon(Icons.sort, size: 20),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'default', child: Text('默认排序')),
        PopupMenuItem(value: 'title', child: Text('按标题')),
        PopupMenuItem(value: 'duration', child: Text('按时长')),
      ],
    );
  }

  Widget _hero(BuildContext context, List<bridge.SongDto> songs) {
    final duration = _totalDuration(songs);
    final meta = <String>[
      if (_album.artist.trim().isNotEmpty) _album.artist,
      if (songs.isNotEmpty) '${songs.length} 首',
      if (duration.inSeconds > 0) '总时长 ${duration.inMinutes} 分钟',
    ];
    return VxDetailHero(
      eyebrow: '专辑',
      title: _album.name,
      meta: meta,
      badges: [songSourceLabel(_model, _album.source)],
      // 缺封面不传 cover：Hero 内部用渐变首字母占位，不放灰色图标块。
      cover: (_album.coverUrl == null || _album.coverUrl!.isEmpty)
          ? null
          : CoverImage(
              url: _album.coverUrl,
              size: 224,
              radius: 12,
              icon: Icons.album_outlined,
            ),
      fallbackSeed: _album.name,
      actions: [
        VxDetailAction(
          icon: Icons.play_arrow,
          label: songs.isEmpty ? '暂无可播放曲目' : '播放全部',
          primary: true,
          onPressed: songs.isEmpty ? null : () => _model.playSongs(songs),
        ),
        VxDetailAction(
          icon: Icons.shuffle,
          label: '随机播放',
          tooltip: songs.isEmpty ? '曲目加载后可用' : '从已载入曲目随机一首开始（顺序继续）',
          onPressed: songs.isEmpty ? null : () => _playShuffled(songs),
        ),
      ],
    );
  }
}
