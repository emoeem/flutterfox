/// 手机歌单详情页（计划书 C-04，指南 §5.6：歌单详情的手机档布局）。
///
/// 作为整页路由 push（手机首页推荐歌单/发现页歌单卡/曲库收藏歌单行的
/// 落点，Batch C-C 接线），自带 Scaffold + AppBar（推入路由需自己承担
/// 系统 inset——与壳 body 页的「无 Scaffold」约定不同，见
/// shell/android_insets.dart 分层契约）。
///
/// 布局顺序（§5.6）：AppBar（返回/歌单名/更多）→ Hero（封面 160–220dp
/// 随宽自适应、歌单名、来源徽章、曲目数/已载入/总时长、描述）→ 主操作
/// （播放全部主按钮 + 随机播放次按钮 + 收藏）→ 曲目列表（移动行：单击
/// 播整列、长按 = 桌面右键同款菜单）→ 触底分页（尾态：加载中/加载更多）。
///
/// - 业务编排全部走共享 [PlaylistDetailController]
///   （playlist_detail_shared.dart）：§8.1 PlaylistKey 隔离（打开先显示
///   loading 不闪现旧歌单）、分页 append、下拉刷新（awaitBrowseResponse
///   完成判据 + 15s 兜底）、收藏乐观态（pending 忽略再击/失败回滚/成功
///   走 'library' 事件真实快照确认）；账号歌单与公开歌单 kind 分命名
///   空间，同一实现不复制业务；
/// - 随机播放如实：只从已载入曲目随机（§5.6「不能只随机首屏后伪称随机
///   整单」；后端无「拉全量再随机」命令，不伪造）；
/// - 歌单级下载/缓存无对应后端命令，如实不显示（§5.6「能力支持时」）；
/// - 触控目标 ≥48dp（行高 66dp、按钮 ≥48dp）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_track_row.dart';
import '../design_system/design_tokens.dart';
import '../widgets/push_dialog.dart';
import '../widgets/sync_dialog.dart';
import 'playlist_detail_shared.dart';
import 'song_tile.dart' show showSongMenu, songSourceLabel;

class MobilePlaylistDetailPage extends StatefulWidget {
  final AppModel model;
  final bridge.PlaylistDto playlist;

  /// true = 账号歌单镜像（读远程缓存），false = 在线音源公开歌单。
  final bool account;

  const MobilePlaylistDetailPage(
    this.model,
    this.playlist, {
    super.key,
    this.account = false,
  });

  @override
  State<MobilePlaylistDetailPage> createState() =>
      _MobilePlaylistDetailPageState();
}

class _MobilePlaylistDetailPageState extends State<MobilePlaylistDetailPage> {
  final _scrollController = ScrollController();
  late PlaylistDetailController _ctrl;

  AppModel get _model => widget.model;
  bridge.PlaylistDto get _playlist => widget.playlist;
  bool get _account => widget.account;

  @override
  void initState() {
    super.initState();
    _ctrl = PlaylistDetailController(_model, _playlist, account: _account);
    _ctrl.attach();
  }

  @override
  void didUpdateWidget(covariant MobilePlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 槽位数据变化来自 model 通知，收藏乐观态来自控制器通知。
    return ListenableBuilder(
      listenable: Listenable.merge([_model, _ctrl]),
      builder: (context, _) {
        final result = _ctrl.result;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
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
                  if (action == 'sync') {
                    showSyncDialog(context, _model, _playlist.source);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'refresh', child: Text('刷新')),
                  PopupMenuItem(
                    value: 'push',
                    enabled: songs.isNotEmpty,
                    child: Text(songs.isNotEmpty ? '推送到远端' : '推送到远端（曲目加载后可用）'),
                  ),
                  if (_account)
                    const PopupMenuItem(value: 'sync', child: Text('同步')),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _ctrl.refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                    _ctrl.loadMore();
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  // 下拉刷新需在内容不满一屏时也可触发（§5.6）。
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _hero(context, result, songs)),
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    ..._listSlivers(context, result, songs),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Hero（§5.6 布局 2-4）──

  Widget _hero(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final duration = PlaylistDetailController.totalDuration(songs);
    final meta = <String>[
      '${_playlist.songCount} 首',
      if (songs.isNotEmpty && songs.length != _playlist.songCount)
        '已载入 ${songs.length}',
      if (duration.inSeconds > 0) '总时长 ${duration.inMinutes} 分钟',
    ];
    final description = _playlist.description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // §5.6：封面 160–220dp 随宽度变化——最窄档（360）取 216，
                // ≥390 封顶 220。
                final size = (constraints.maxWidth * 0.6).clamp(160.0, 220.0);
                return VxArtwork(
                  url: _playlist.coverUrl,
                  source: _playlist.source,
                  entityType: 'playlist',
                  entityId: _playlist.id,
                  entityName: _playlist.name,
                  size: size,
                  radius: VxRadius.lg,
                  icon: Icons.queue_music_outlined,
                );
              },
            ),
          ),
          const SizedBox(height: VxSpacing.md),
          Text(
            _playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VxTypography.h2.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: VxSpacing.xs),
          Wrap(
            spacing: VxSpacing.sm,
            runSpacing: VxSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _sourceBadge(context),
              for (final item in meta)
                Text(
                  item,
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: VxSpacing.sm),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: VxTypography.body.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: VxSpacing.md),
          _actionsRow(context, songs),
        ],
      ),
    );
  }

  Widget _sourceBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        songSourceLabel(_model, _playlist.source),
        style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  /// 主操作（§5.6）：播放全部（主）+ 随机播放（次）+ 收藏；
  /// 曲目未加载时按钮如实禁用。
  Widget _actionsRow(BuildContext context, List<bridge.SongDto> songs) {
    final hasSongs = songs.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: hasSongs ? () => _model.playSongs(songs) : null,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(hasSongs ? '播放全部' : '暂无可播放曲目'),
          ),
        ),
        const SizedBox(width: VxSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasSongs ? () => _ctrl.playShuffled(songs) : null,
            icon: const Icon(Icons.shuffle, size: 18),
            label: const Text('随机播放'),
          ),
        ),
        const SizedBox(width: VxSpacing.xs),
        // §8.5：收藏写入本地收藏镜像，不写远端账号（与桌面同语义）。
        IconButton(
          tooltip: _ctrl.favPending
              ? '收藏处理中…'
              : _ctrl.favDisplayed
              ? '取消收藏'
              : '收藏到本地歌单收藏夹（不写入远端账号）',
          // pending 在途以 spinner 呈现并禁点（§9 防重复提交）。
          onPressed: _ctrl.favPending ? null : _ctrl.toggleFavoritePlaylist,
          icon: _ctrl.favPending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _ctrl.favDisplayed ? Icons.favorite : Icons.favorite_border,
                  color: _ctrl.favDisplayed
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
        ),
      ],
    );
  }

  // ── 曲目列表（§5.6 布局 5-6）──

  List<Widget> _listSlivers(
    BuildContext context,
    BrowseResult? result,
    List<bridge.SongDto> songs,
  ) {
    final loading = result == null || (result.loading && songs.isEmpty);
    if (loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: VxSpacing.lg),
            child: VxLoadingSkeleton.tracks(rows: 6),
          ),
        ),
      ];
    }
    // loading 为假已把 result 提升为非空（result == null 分支先行返回）。
    final error = result.error;
    if (error != null && songs.isEmpty) {
      // P1-07 同口径：Rust 快照错误字段不经净化链路，渲染前必须净化（§9）。
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: VxErrorState(
            title: '歌单加载失败',
            message: '无法载入「${_playlist.name}」的曲目。',
            detail: AppModel.sanitizeUserFacingMessage(error),
            icon: Icons.cloud_off,
            onRetry: _ctrl.reload,
          ),
        ),
      ];
    }
    if (songs.isEmpty) {
      // 注意：不可用 hasScrollBody:false——它会走子树 intrinsic 计算，而
      // VxEmptyState 内含 LayoutBuilder（intrinsic 不支持）触发布局断言；
      // 默认形态同样让子项填满剩余视口（空态居中），无 intrinsic 路径。
      return [
        SliverFillRemaining(
          child: VxEmptyState(
            icon: Icons.music_off_outlined,
            title: result.notice ?? '歌单暂无曲目',
            message: '换一个歌单试试',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: VxSpacing.xs),
        sliver: SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) =>
              _songRow(context, songs, songs[index], index),
        ),
      ),
      // 分页尾态（账号歌单无分页，不出尾态）：与桌面表格 footer 同语义。
      if (!_account && result.hasMore)
        SliverToBoxAdapter(child: _footer(context, result)),
      const SliverToBoxAdapter(child: SizedBox(height: VxSpacing.xl)),
    ];
  }

  Widget _footer(BuildContext context, BrowseResult result) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: result.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: _ctrl.loadMore, child: const Text('加载更多')),
      ),
    );
  }

  /// 移动歌曲行：标题/歌手/来源/时长；单击即播整列（触屏无 hover，行内
  /// 悬停操作不可达——长按 = 桌面右键/更多菜单的触屏替代，同一份菜单与
  /// 命令接线 showSongMenu，§9）。
  Widget _songRow(
    BuildContext context,
    List<bridge.SongDto> songs,
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
      onTap: () => _model.playSongs(songs, index: index),
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
}
