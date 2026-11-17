/// 歌单详情共享业务面（桌面 PlaylistDetailPage 与手机 MobilePlaylistDetailPage
/// 同一实现，Batch C-04 自桌面页私有逻辑提炼；页面只做布局与交互，业务不允许
/// 第二份）。
///
/// - [playlistDetailKind]：公开歌单 / 账号歌单镜像两种 browse 槽 kind
///   （§8.1「账号歌单和公开歌单必须使用不同 type/key namespace」）；
/// - [PlaylistDetailController]：§8.1 PlaylistKey 隔离（attach 同步
///   prepareBrowseLoad，切歌单先显示 loading 不闪现旧歌单曲目）、
///   reload / loadMore / refresh（awaitBrowseResponse 完成判据 + 15s 超时
///   兜底）、收藏乐观态（pending 在途忽略再击、成功以 'library' 事件真实
///   快照确认、失败回滚）、播放全部 / 随机播放（只从已载入曲目随机，如实
///   语义）。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;

/// browse 槽 kind：账号歌单（远程镜像）与公开歌单分命名空间。
String playlistDetailKind(bool account) =>
    account ? 'account_playlist_detail' : 'playlist_detail';

/// 歌单详情业务控制：单一实现供桌面/手机两页消费。
///
/// 生命周期：[attach] 挂模型监听并同步预清槽（首帧即加载态）、帧后派发
/// 首次加载；[detach] 解绑（模型交换时先 detach 再重建）。页面以
/// `Listenable.merge([model, controller])` 消费：槽位数据变化来自 model
/// 通知，收藏乐观态翻转来自本控制器通知。
class PlaylistDetailController extends ChangeNotifier {
  PlaylistDetailController(this.model, this.playlist, {required this.account});

  final AppModel model;
  final bridge.PlaylistDto playlist;
  final bool account;

  bool _active = false;
  bool _initialLoadScheduled = false;

  /// 收藏 pending：在途时忽略再次点击（toggle 语义下第二击会在乐观翻转
  /// 后的判定下派发反向命令，确认后状态与用户意图相反）；乐观翻转只改
  /// 本地图标，成功确认以 'library' 事件 → _refreshState 刷新的真实
  /// favoritePlaylists 快照为准（失败回滚；不做超时假成功）。
  bool _favPending = false;
  bool? _favOverride;

  String get kind => playlistDetailKind(account);

  BrowseResult? get result => model.browse(kind, playlist.source, playlist.id);

  // ── 生命周期 ──

  /// 挂模型监听并同步预清槽（§8.1「页面切换先显示对应 loading，不闪现
  /// 旧歌单歌曲」：首帧即加载态）；真正的请求派发 defer 到帧后——attach
  /// 发生在页面 initState（导航 build 期），直接派发会让祖先在 build 中
  /// 被标脏（桌面页原语义）。
  void attach() {
    if (_active) return;
    _active = true;
    model.addListener(_onModelChanged);
    model.prepareBrowseLoad(kind, playlist.source, playlist.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_active || _initialLoadScheduled) return;
      _initialLoadScheduled = true;
      reload();
    });
  }

  /// 解绑模型监听；未派发的帧后首载作废（不向已拆页派发请求）。
  void detach() {
    if (!_active) return;
    _active = false;
    model.removeListener(_onModelChanged);
  }

  // ── 模型事件 ──

  void _onModelChanged() {
    if (!_active) return;
    // 无收藏在途时无需本控制器通知（槽位数据变化由页面监听的 model 通知
    // 驱动重建）；'library' 事件（FavoritePlaylistAdd/Remove →
    // publish_library）触发 _refreshState 后，快照与乐观值一致即服务端
    // 已确认本代操作，清 pending。
    if (!_favPending || _favOverride == null) return;
    if (isFavoritePlaylist == _favOverride) {
      _favPending = false;
      _favOverride = null;
      notifyListeners();
    }
  }

  // ── 数据操作 ──

  void reload() {
    if (account) {
      model.loadAccountPlaylistDetail(playlist.source, playlist.id);
    } else {
      model.loadPlaylistDetail(playlist);
    }
  }

  /// 账号歌单没有分页；在线歌单继续加载下一页。
  void loadMore() {
    if (account) return;
    final result = this.result;
    if (result == null || result.loading) return;
    model.loadPlaylistDetail(playlist, page: result.page + 1);
  }

  /// 下拉刷新：复用 load* 的 _beginBrowse 清槽 + 撤分页 arm；完成 Future =
  /// 本代次 page=1 响应或错误落槽。命令立即失败（未达 Rust）时 toast 已
  /// 提示、spinner 收起；控制器失联事件可能永不到达，加超时兜底不允许
  /// spinner 永挂（§9）。
  Future<void> refresh() async {
    final wait = model.awaitBrowseResponse(kind, playlist.source, playlist.id);
    final error = account
        ? await model.loadAccountPlaylistDetail(playlist.source, playlist.id)
        : await model.loadPlaylistDetail(playlist);
    if (error != null) return;
    await wait.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  // ── 收藏（乐观态）──

  bool get favPending => _favPending;

  /// 歌单是否已在本地收藏（收藏歌单镜像里按 source + id 匹配）。
  bool get isFavoritePlaylist => model.state.favoritePlaylists.any(
    (item) => item.id == playlist.id && item.source == playlist.source,
  );

  /// 图标显示值：pending 在途时用乐观翻转值，否则以真实快照为准。
  bool get favDisplayed => _favOverride ?? isFavoritePlaylist;

  Future<void> toggleFavoritePlaylist() async {
    if (_favPending) return; // §9 加载中防重复提交（双击竞态）
    final target = !isFavoritePlaylist;
    _favPending = true;
    _favOverride = target;
    notifyListeners();
    final command = target
        ? bridge.FfiCommand.favoritePlaylistAdd(playlist: playlist)
        : bridge.FfiCommand.favoritePlaylistRemove(playlist: playlist);
    final error = await model.dispatchWithError(command);
    if (!_active) return;
    if (error != null) {
      // 失败回滚乐观 UI（§9）。错误文案由命令层 lastError/
      // lastNotification → 全局 toast 呈现，页面不再渲染第二份。
      _favPending = false;
      _favOverride = null;
      notifyListeners();
      return;
    }
    // 成功路径不在此等待：确认由 _onModelChanged 以真实快照驱动。
  }

  // ── 播放 ──

  /// 随机播放：从已载入曲目随机选一首开始（顺序继续）。
  void playShuffled(List<bridge.SongDto> songs) {
    if (songs.length <= 1) {
      model.playSongs(songs);
      return;
    }
    final index = Random().nextInt(songs.length);
    model.playSongs(songs, index: index);
  }

  /// 已载入曲目总时长（缺时长的曲目不计入）。
  static Duration totalDuration(List<bridge.SongDto> songs) {
    var ms = 0;
    for (final song in songs) {
      final d = song.durationMs.toInt();
      if (d > 0) ms += d;
    }
    return Duration(milliseconds: ms);
  }
}
