/// 歌单详情页：DetailHero + 操作区 + 曲目表（§4.7）。
///
/// - 顶部横向 Hero：封面 224px、名称、来源徽章、歌曲数 / 总时长、描述；
/// - 主按钮「播放全部」、次按钮「随机播放」；收藏 / 同步 / 更多在次级
///   操作区（同步 Diff、推送等流程都在对话框内收口，不占主页面）；
/// - 在线歌单展示音源来源；账号歌单（远程镜像）与公开歌单以徽章区分；
/// - 数据结果按 `browseKind + source + id` 从 AppModel 读取，播放只走
///   现有 `playSongs` / `queueAdd`，不新建播放控制；
/// - 业务编排（§8.1 隔离 / 分页 / 下拉刷新 / 收藏乐观态）走共享
///   [PlaylistDetailController]（playlist_detail_shared.dart，Batch C-04
///   提炼），桌面页与手机页同一实现，本页只做布局与交互。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_detail_hero.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../widgets/push_dialog.dart';
import '../widgets/song_table_view.dart';
import '../widgets/sync_dialog.dart';
import 'playlist_detail_shared.dart';
import 'song_tile.dart' show songSourceLabel;

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
  late PlaylistDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PlaylistDetailController(_model, _playlist, account: _account);
    _ctrl.attach();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 目的地/歌单/形态变化时重建控制器（§8.1：切到另一个歌单先显示
    // loading——旧 State 若复用会沿用旧 prepareBrowseLoad 结果）。同页
    // 实例复用主要发生在无 key 的重泵场景，正常推入路由每次都是新实例。
    if (oldWidget.model != widget.model ||
        oldWidget.playlist.id != widget.playlist.id ||
        oldWidget.playlist.source != widget.playlist.source ||
        oldWidget.account != widget.account) {
      _ctrl
        ..detach()
        ..dispose();
      _ctrl = PlaylistDetailController(_model, _playlist, account: _account);
      _ctrl.attach();
    }
  }

  @override
  void dispose() {
    _ctrl
      ..detach()
      ..dispose();
    super.dispose();
  }

  AppModel get _model => widget.model;
  bridge.PlaylistDto get _playlist => widget.playlist;
  bool get _account => widget.account;

  @override
  Widget build(BuildContext context) {
    // 槽位数据变化来自 model 通知，收藏乐观态来自控制器通知。
    return ListenableBuilder(
      listenable: Listenable.merge([_model, _ctrl]),
      builder: (context, _) {
        final result = _ctrl.result;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _backBar(context),
              _hero(context, result, songs),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VxSpacing.xl,
                  VxSpacing.lg,
                  VxSpacing.xl,
                  0,
                ),
                child: VxSectionHeader(title: '曲目列表'),
              ),
              Expanded(
                child: VxSongTable(
                  model: _model,
                  songs: songs,
                  loading: result == null || (result.loading && songs.isEmpty),
                  error: result?.error,
                  notice: result?.notice,
                  emptyTitle: '歌单暂无曲目',
                  emptySubtitle: '换一个歌单试试',
                  onRetry: _ctrl.reload,
                  hasMore: result?.hasMore ?? false,
                  onLoadMore: _ctrl.loadMore,
                  onRefresh: _ctrl.refresh,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
              _playlist.name,
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

  Widget _hero(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    final duration = PlaylistDetailController.totalDuration(songs);
    final meta = <String>[
      '${_playlist.songCount} 首',
      if (songs.isNotEmpty && songs.length != _playlist.songCount)
        '已载入 ${songs.length}',
      if (duration.inSeconds > 0) '总时长 ${duration.inMinutes} 分钟',
    ];
    final description = _playlist.description?.trim();
    return VxDetailHero(
      eyebrow: _account ? '账号歌单' : '歌单',
      title: _playlist.name,
      meta: meta,
      badges: [songSourceLabel(_model, _playlist.source), if (_account) '账号镜像'],
      description: (description == null || description.isEmpty)
          ? null
          : description,
      cover: VxArtwork(
        url: _playlist.coverUrl,
        source: _playlist.source,
        entityType: 'playlist',
        entityId: _playlist.id,
        entityName: _playlist.name,
        size: 224,
        radius: 12,
        icon: Icons.queue_music_outlined,
      ),
      fallbackSeed: _playlist.name,
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
          onPressed: songs.isEmpty ? null : () => _ctrl.playShuffled(songs),
        ),
        VxDetailAction(
          icon: _ctrl.favDisplayed ? Icons.favorite : Icons.favorite_border,
          label: _ctrl.favPending
              ? '收藏处理中…'
              : _ctrl.favDisplayed
              ? '取消收藏'
              : '收藏',
          // §8.5：收藏歌单写入本地收藏镜像（favoritePlaylists），不写远端账号。
          tooltip: '收藏到本地歌单收藏夹（不写入远端账号）',
          onPressed: _ctrl.toggleFavoritePlaylist,
        ),
        // 同步只对账号歌单有意义：Diff 预览/写入都在对话框内收口。
        if (_account)
          VxDetailAction(
            icon: Icons.sync_outlined,
            label: '同步',
            tooltip: '预览远端与本地镜像差异并同步（对话框内完成）',
            onPressed: () => showSyncDialog(context, _model, _playlist.source),
          ),
      ],
      trailingActions: [
        PopupMenuButton<String>(
          tooltip: '更多操作',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == 'refresh') _ctrl.reload();
            if (action == 'push') {
              showPushDialog(
                context,
                _model,
                localName: _playlist.name,
                songs: songs,
                isFavorites: false,
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'refresh', child: Text('刷新')),
            PopupMenuItem(
              value: 'push',
              enabled: songs.isNotEmpty,
              child: Text(songs.isNotEmpty ? '推送到远端' : '推送到远端（曲目加载后可用）'),
            ),
          ],
        ),
      ],
    );
  }
}
