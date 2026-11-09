/// 应用状态模型：单控制器事件泵 + ChangeNotifier。
///
/// 状态管理决策（记录于 FLUTTER_MIGRATION_PROGRESS.md）：当前是「单 Rust 控制器
/// 广播事件 → 单一快照」的结构，ChangeNotifier 足够；页面复杂化后再引入
/// riverpod（届时二选一，不混用），现在不自造状态库。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bridge/api.dart' as bridge;
import 'bridge/frb_generated.dart' show RustLib;
import 'bridge/lib.dart' as bridge;
import 'config_ext.dart';

/// 一次浏览请求的落库结果。按 `browseKind + source + id` 分槽，
/// 页面直接读它决定加载/空/错误态。
class BrowseResult {
  bool loading = false;
  String? error;
  String? notice;
  int page = 0;
  bool hasMore = false;
  final List<bridge.SongDto> songs = [];
  final List<bridge.PlaylistDto> playlists = [];
  final List<bridge.AlbumDto> albums = [];
  final List<bridge.LeaderboardDto> boards = [];
  final List<bridge.PlaylistCategoryDto> categories = [];

  bool get isEmpty =>
      songs.isEmpty &&
      playlists.isEmpty &&
      albums.isEmpty &&
      boards.isEmpty &&
      categories.isEmpty;
}

class AppModel extends ChangeNotifier {
  bridge.VoicefoxController? _controller;
  bridge.VoicefoxEventStream? _stream;
  bool _pumping = false;
  bridge.VoicefoxState _state = _emptyState();
  final Map<String, BrowseResult> _browse = {};
  String themeKey = 'catppuccin-mocha';
  // 默认关：具名主题按色板原样呈现（FlClash 亦不做动态色）；
  // 打开后 Android 12+/桌面跟随系统 accent，持久化于 config.theme.dynamic_color。
  bool useDynamicColor = false;
  String? lastNotification;

  /// 最近一次可见错误（命令失败、搜索/播放/登录失败）。Shell 统一用
  /// SnackBar 呈现；`clearError` 由用户关闭提示时调用。
  String? lastError;
  bridge.QrLoginSessionDto? qrSession;
  String? qrStatus;
  String? qrUser;
  List<String> scanWarnings = [];
  bool scanningLocal = false;
  bridge.ConfigDto? _cachedConfig;

  /// 新建自建歌单的应答等待者：key = 歌单名（存储层保证唯一）。
  final Map<String, Completer<String>> _createdWaiters = {};

  // ── 账号歌单同步（远程镜像缓存）──
  /// idle / previewing / preview / running / done / failed / cancelled
  String syncPhase = 'idle';
  String? syncSource;
  bridge.SyncPreviewDto? syncPreview;
  bridge.SyncReportDto? syncReport;
  String? syncError;
  int syncDone = 0;
  int syncTotal = 0;

  // ── 本地 → 远端推送 ──
  String pushPhase = 'idle';
  String? pushSource;
  List<bridge.PushTargetDto> pushTargets = [];
  bridge.PushPreviewDto? pushPreview;
  bridge.PushReportDto? pushReport;
  String? pushError;
  int pushDone = 0;
  int pushTotal = 0;

  bridge.VoicefoxState get state => _state;
  bridge.VoicefoxController? get controller => _controller;
  bool get ready => _controller != null;
  bridge.ConfigDto? get config => _cachedConfig;

  static bridge.VoicefoxState _emptyState() => bridge.VoicefoxState(
    playback: bridge.PlaybackDto(
      state: 'idle',
      song: null,
      positionMs: BigInt.zero,
      durationMs: BigInt.zero,
      volume: 100,
      generation: BigInt.zero,
    ),
    queue: [],
    queueIndex: 0,
    search: bridge.SearchDto(
      keyword: '',
      page: 0,
      hasMore: false,
      items: [],
      requestId: BigInt.zero,
      loading: false,
      error: null,
    ),
    lyrics: bridge.LyricsDto(
      currentLine: 0,
      positionMs: BigInt.zero,
      lines: [],
      translation: null,
      isEmpty: true,
    ),
    playlists: [],
    favorites: [],
    favoritePlaylists: [],
    history: [],
    customPlaylists: [],
    downloads: [],
    sources: [],
    localSongs: [],
  );

  /// FRB 运行时初始化（幂等）：任何桥调用之前必须就绪，
  /// 否则生成码访问 instance.api 会抛 Bad state（真机触屏引导踩过）。
  Future<void>? _rustLibReady;

  Future<void> ensureRustLib() {
    _rustLibReady ??= RustLib.init();
    return _rustLibReady!;
  }

  /// 桌面引导：初始化 Rust 库并启动事件泵。
  Future<void> bootstrapDesktop() async {
    await ensureRustLib();
    final controller = await bridge.newDesktop();
    await _attach(controller);
  }

  /// 移动端引导由宿主注入 ApplicationService 后构造（Phase 4）。
  Future<void> attach(bridge.VoicefoxController controller) async {
    await ensureRustLib();
    await _attach(controller);
  }

  Future<void> _attach(bridge.VoicefoxController controller) async {
    _controller = controller;
    _state = await bridge.state(controller: controller);
    _stream = await bridge.subscribe(controller: controller);
    if (!_pumping) {
      _pumping = true;
      unawaited(_eventLoop());
    }
    // 启动即拉一次库与配置快照
    unawaited(dispatch(const bridge.FfiCommand.libraryRefresh()));
    unawaited(dispatch(const bridge.FfiCommand.configGet()));
    notifyListeners();
  }

  /// FRB 的事件流是「每次 await next() 取一条」，用自循环消费；
  /// 异常时退避重订阅，避免静默失联。
  Future<void> _eventLoop() async {
    while (true) {
      final stream = _stream;
      if (stream == null) return;
      try {
        final event = await bridge.eventNext(stream: stream);
        _handleEvent(event);
      } on Object catch (error) {
        debugPrint('event stream error: $error');
        await Future<void>.delayed(const Duration(seconds: 1));
        final controller = _controller;
        if (controller == null) return;
        try {
          _stream = await bridge.subscribe(controller: controller);
          // 失联期间可能丢事件（进度/队列/库/配置都可能在漏掉的广播里），
          // 重订阅成功后必须整份重拉快照，否则界面停在旧状态。
          await _refreshState();
        } on Object {
          return;
        }
      }
    }
  }

  void _handleEvent(bridge.VoicefoxEvent event) {
    switch (event.kind) {
      case 'progress':
        // 播放泵以 4Hz 广播进度：只替换 playback 快照，不整份重拉 state
        // （state() 会连本地曲库一起克隆）。
        _applyPlaybackProgress(event);
      case 'search':
      case 'playback':
        if (event.message != null) lastError = event.message;
        unawaited(_refreshState());
      case 'queue':
      case 'playlist':
      case 'lyrics':
      case 'downloads':
        unawaited(_refreshState());
      case 'library':
        unawaited(_refreshState());
        _handleLibraryEvent(event);
      case 'notification':
        lastNotification = event.message;
      case 'qr_login':
        if (event.qrSession != null) {
          qrSession = event.qrSession;
          qrStatus = 'waiting';
        }
        if (event.status != null) {
          qrStatus = event.status;
          qrUser = event.userName;
          if (qrStatus == 'failed' && event.message != null) {
            lastError = event.message;
          }
          if (qrStatus == 'success' ||
              qrStatus == 'expired' ||
              qrStatus == 'failed') {
            qrSession = null;
          }
        }
      case 'local_music':
        scanWarnings = event.warnings;
        scanningLocal = false;
        unawaited(_refreshState());
      case 'browse':
        _applyBrowseEvent(event);
      case 'sync':
        _applySyncEvent(event);
        _applyPushEvent(event);
      case 'config':
        final config = event.config;
        if (config != null) {
          _cachedConfig = config;
          themeKey = config.theme;
          useDynamicColor = config.dynamicColor;
        }
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> _refreshState() async {
    final controller = _controller;
    if (controller == null) return;
    _state = await bridge.state(controller: controller);
    notifyListeners();
  }

  /// `kind == "progress"`：播放器 watcher 的位置/时长/状态快照。
  void _applyPlaybackProgress(bridge.VoicefoxEvent event) {
    final playback = _state.playback;
    _state = bridge.VoicefoxState(
      playback: bridge.PlaybackDto(
        state: event.playbackState ?? playback.state,
        song: playback.song,
        positionMs: event.positionMs,
        durationMs: event.durationMs,
        volume: playback.volume,
        generation: playback.generation,
      ),
      queue: _state.queue,
      queueIndex: _state.queueIndex,
      search: _state.search,
      lyrics: _state.lyrics,
      playlists: _state.playlists,
      favorites: _state.favorites,
      favoritePlaylists: _state.favoritePlaylists,
      history: _state.history,
      customPlaylists: _state.customPlaylists,
      downloads: _state.downloads,
      sources: _state.sources,
      localSongs: _state.localSongs,
    );
  }

  /// `library` 事件可能带「新建自建歌单」的应答（id + name）；
  /// 同时让所有已打开的自建歌单详情重新取一遍（加/删歌后即时回显）。
  void _handleLibraryEvent(bridge.VoicefoxEvent event) {
    final createdId = event.id;
    final createdName = event.message;
    if (createdId != null && createdName != null) {
      _createdWaiters.remove(createdName)?.complete(createdId);
    }
    _reloadCustomPlaylistDetails();
  }

  // ── 浏览数据面（歌单 / 排行榜 / 歌手 / 专辑）──
  static String _browseKey(String kind, String source, String id) =>
      '$kind|$source|$id';

  BrowseResult? browse(String kind, String source, String id) =>
      _browse[_browseKey(kind, source, id)];

  /// 触发本地扫描；未传路径时使用配置里的目录。路径为空直接返回。
  Future<void> scanLocal({List<String>? paths, int? maxDepth}) {
    final config = _cachedConfig;
    final targetPaths = paths ?? config?.localMusicPaths ?? const <String>[];
    if (targetPaths.isEmpty) return Future.value();
    scanningLocal = true;
    scanWarnings = const [];
    notifyListeners();
    return dispatch(
      bridge.FfiCommand.localScan(
        paths: targetPaths,
        maxDepth: maxDepth ?? config?.localMusicMaxDepth ?? 0,
      ),
    );
  }

  /// 能力位查询；快照尚未加载时按“不支持”处理，避免入口闪现已失败的页面。
  bridge.SourceCapabilitiesDto? capability(String source) {
    for (final item in _state.sources) {
      if (item.id == source) return item;
    }
    return null;
  }

  bool supportsArtist(String source) => capability(source)?.artist ?? false;
  bool supportsAlbum(String source) => capability(source)?.album ?? false;
  bool supportsPlaylists(String source) =>
      capability(source)?.playlists ?? false;
  bool supportsPlaylistCategories(String source) =>
      capability(source)?.playlistCategories ?? false;
  bool supportsLeaderboard(String source) =>
      capability(source)?.leaderboard ?? false;

  void _beginBrowse(
    String kind,
    String source,
    String id, {
    bool append = false,
  }) {
    final result = _browse.putIfAbsent(
      _browseKey(kind, source, id),
      BrowseResult.new,
    );
    result.loading = true;
    result.error = null;
    result.notice = null;
    if (!append) {
      result
        ..page = 0
        ..hasMore = false
        ..songs.clear()
        ..playlists.clear()
        ..albums.clear()
        ..boards.clear()
        ..categories.clear();
    }
    notifyListeners();
  }

  void _applyBrowseEvent(bridge.VoicefoxEvent event) {
    final kind = event.browseKind;
    if (kind == null) return;
    final source = event.source ?? '';
    final id = event.id ?? '';
    final result = _browse.putIfAbsent(
      _browseKey(kind, source, id),
      BrowseResult.new,
    );
    result.loading = false;
    if (event.page == 0) {
      // Rust 侧 BrowseFailed 不 carry page；加载事件恒带 >=1 的页码。
      result.error = event.message ?? '加载失败';
      notifyListeners();
      return;
    }
    if (!event.append) {
      result
        ..songs.clear()
        ..playlists.clear()
        ..albums.clear()
        ..boards.clear()
        ..categories.clear();
    }
    result
      ..error = null
      ..notice = event.message
      ..page = event.page
      ..hasMore = event.hasMore
      ..songs.addAll(event.items)
      ..playlists.addAll(event.playlists)
      ..albums.addAll(event.albums)
      ..boards.addAll(event.boards)
      ..categories.addAll(event.categories);
    notifyListeners();
  }

  /// 同步事件分四种（FFI `status` 字段）：preview / progress /
  /// completed / failed。失败分支里「同步已取消」单列成 cancelled。
  void _applySyncEvent(bridge.VoicefoxEvent event) {
    switch (event.status) {
      case 'preview':
        syncPreview = event.syncPreview;
        syncError = null;
        syncPhase = 'preview';
      case 'progress':
        syncDone = event.progressDone;
        syncTotal = event.progressTotal;
        if (syncPhase == 'preview' || syncPhase == 'previewing') {
          syncPhase = 'running';
        }
      case 'completed':
        syncReport = event.syncReport;
        syncError = null;
        syncPhase = 'done';
        // 镜像缓存已换新：已打开的账号歌单列表/详情静默重取。
        _reloadAccountBrowse();
      case 'failed':
        syncError = event.message ?? '同步失败';
        syncPhase = syncError == '同步已取消' ? 'cancelled' : 'failed';
      default:
        break;
    }
  }

  void _applyPushEvent(bridge.VoicefoxEvent event) {
    final eventSource = event.source;
    if (eventSource == null || eventSource != pushSource) return;
    switch (event.status) {
      case 'push_targets':
        pushTargets = event.pushTargets;
        pushPhase = 'targets';
        pushError = null;
      case 'push_target_created':
        final target = event.pushTarget;
        if (target != null) {
          pushTargets = [...pushTargets, target];
          pushPhase = 'targets';
          pushError = null;
        }
      case 'push_preview':
        pushPreview = event.pushPreview;
        pushError = null;
        pushPhase = 'preview';
      case 'push_progress':
        pushDone = event.progressDone;
        pushTotal = event.progressTotal;
        pushPhase = 'running';
      case 'push_completed':
        pushReport = event.pushReport;
        pushError = null;
        pushPhase = 'done';
      case 'push_failed':
        pushError = event.message ?? '推送失败';
        pushPhase = pushError == '同步已取消' ? 'cancelled' : 'failed';
      default:
        break;
    }
  }

  Future<void> loadPlaylistCategories(String source) {
    _beginBrowse('playlist_categories', source, '');
    return dispatch(bridge.FfiCommand.playlistCategories(source: source));
  }

  Future<void> loadPlaylists({
    required String source,
    String category = '',
    int page = 1,
  }) {
    _beginBrowse('playlists', source, category, append: page > 1);
    return dispatch(
      bridge.FfiCommand.playlistList(
        source: source,
        category: category,
        page: page,
      ),
    );
  }

  Future<void> loadPlaylistDetail(bridge.PlaylistDto playlist, {int page = 1}) {
    _beginBrowse(
      'playlist_detail',
      playlist.source,
      playlist.id,
      append: page > 1,
    );
    return dispatch(
      bridge.FfiCommand.playlistDetail(
        source: playlist.source,
        playlistId: playlist.id,
        page: page,
      ),
    );
  }

  Future<void> loadLeaderboardBoards(String source) {
    _beginBrowse('leaderboard_boards', source, '');
    return dispatch(bridge.FfiCommand.leaderboardBoards(source: source));
  }

  Future<void> loadLeaderboardSongs(
    String source,
    String boardId, {
    int page = 1,
  }) {
    _beginBrowse('leaderboard_songs', source, boardId, append: page > 1);
    return dispatch(
      bridge.FfiCommand.leaderboardSongs(
        source: source,
        boardId: boardId,
        page: page,
      ),
    );
  }

  Future<void> loadArtistSongs(bridge.ArtistDto artist, {int page = 1}) {
    _beginBrowse('artist_songs', artist.source, artist.id, append: page > 1);
    return dispatch(bridge.FfiCommand.artistSongs(artist: artist, page: page));
  }

  Future<void> loadArtistAlbums(bridge.ArtistDto artist, {int page = 1}) {
    _beginBrowse('artist_albums', artist.source, artist.id, append: page > 1);
    return dispatch(bridge.FfiCommand.artistAlbums(artist: artist, page: page));
  }

  Future<void> loadAlbumSongs(bridge.AlbumDto album, {int page = 1}) {
    _beginBrowse('album_songs', album.source, album.id, append: page > 1);
    return dispatch(bridge.FfiCommand.albumSongs(album: album, page: page));
  }

  // ── 自建歌单（本地存储，复用 browse 分槽）──
  static const customPlaylistKind = 'custom_playlist';
  static const _customPlaylistSource = 'local';

  /// 已打开的自建歌单详情；`id` 与快照里的
  /// `state.customPlaylists[].id` 对应。
  BrowseResult? customPlaylist(String id) =>
      browse(customPlaylistKind, _customPlaylistSource, id);

  /// 读取自建歌单详情。`silent` 用于库变更后的后台重取：
  /// 不清空旧曲目、不置加载态，避免收藏/改名等操作让页面闪一下。
  Future<void> loadCustomPlaylist(String id, {bool silent = false}) {
    if (!silent) {
      _beginBrowse(customPlaylistKind, _customPlaylistSource, id);
    }
    return dispatch(bridge.FfiCommand.customPlaylistDetail(id: id));
  }

  void _reloadCustomPlaylistDetails() {
    const prefix = '$customPlaylistKind|$_customPlaylistSource|';
    final ids = [
      for (final key in _browse.keys)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    ];
    for (final id in ids) {
      unawaited(loadCustomPlaylist(id, silent: true));
    }
  }

  /// 新建自建歌单，返回新歌单 id（失败/超时返回 null）。
  ///
  /// 命令本身不返回值，id 由 `CustomPlaylistCreated` 事件带回，
  /// 因此这里用一个按名称匹配的应答等待者；界面上通常是
  /// 「新建并立即把当前歌曲加进去」的连贯操作。
  Future<String?> createCustomPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final completer = Completer<String>();
    _createdWaiters[trimmed] = completer;
    final error = await _sendCommand(
      bridge.FfiCommand.customPlaylistCreate(name: trimmed),
    );
    if (error != null) {
      _createdWaiters.remove(trimmed);
      return null;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      return null;
    } finally {
      _createdWaiters.remove(trimmed);
    }
  }

  Future<void> renameCustomPlaylist(String id, String name) => dispatch(
    bridge.FfiCommand.customPlaylistRename(id: id, name: name.trim()),
  );

  Future<void> deleteCustomPlaylist(String id) {
    // 歌单不存在后详情槽没有意义，先移除，避免库事件再拉一次报错。
    _browse.remove(_browseKey(customPlaylistKind, _customPlaylistSource, id));
    return dispatch(bridge.FfiCommand.customPlaylistDelete(id: id));
  }

  Future<void> addToCustomPlaylist(String id, List<bridge.SongDto> songs) {
    if (songs.isEmpty) return Future.value();
    return dispatch(
      bridge.FfiCommand.customPlaylistAddSongs(id: id, songs: songs),
    );
  }

  Future<void> removeFromCustomPlaylist(String id, bridge.SongDto song) =>
      dispatch(bridge.FfiCommand.customPlaylistRemoveSong(id: id, song: song));

  // ── 账号歌单镜像（远程缓存，只读）──
  static const accountPlaylistsKind = 'account_playlists';
  static const accountPlaylistDetailKind = 'account_playlist_detail';
  static const accountFavoritesKind = 'account_favorites';

  BrowseResult? accountPlaylists(String source) =>
      browse(accountPlaylistsKind, source, '');

  BrowseResult? accountFavorites(String source) =>
      browse(accountFavoritesKind, source, 'favorites');

  BrowseResult? accountPlaylistDetail(String source, String id) =>
      browse(accountPlaylistDetailKind, source, id);

  /// 读取镜像缓存里的账号歌单列表。该平台没有镜像槽位时，
  /// 事件带 `message`、数据为空，界面走空态/提示。
  Future<void> loadAccountPlaylists(String source, {bool silent = false}) {
    if (!silent) _beginBrowse(accountPlaylistsKind, source, '');
    return dispatch(bridge.FfiCommand.accountPlaylists(source: source));
  }

  Future<void> loadAccountFavorites(String source, {bool silent = false}) {
    if (!silent) _beginBrowse(accountFavoritesKind, source, 'favorites');
    return dispatch(bridge.FfiCommand.accountFavorites(source: source));
  }

  Future<void> loadAccountPlaylistDetail(
    String source,
    String id, {
    bool silent = false,
  }) {
    if (!silent) _beginBrowse(accountPlaylistDetailKind, source, id);
    return dispatch(
      bridge.FfiCommand.accountPlaylistDetail(source: source, playlistId: id),
    );
  }

  /// 同步完成后刷新所有已打开的账号歌单槽（列表 + 详情）。
  void _reloadAccountBrowse() {
    for (final key in _browse.keys.toList()) {
      final parts = key.split('|');
      if (parts.length < 3) continue;
      if (parts[0] == accountPlaylistsKind) {
        unawaited(loadAccountPlaylists(parts[1], silent: true));
      } else if (parts[0] == accountPlaylistDetailKind) {
        unawaited(loadAccountPlaylistDetail(parts[1], parts[2], silent: true));
      }
    }
  }

  // ── 账号歌单同步（远端 → 本地镜像）──
  /// 只读预览：不写缓存。同步对话框打开时调用。
  Future<void> startSyncPreview(String source) {
    syncSource = source;
    syncPhase = 'previewing';
    syncPreview = null;
    syncReport = null;
    syncError = null;
    syncDone = 0;
    syncTotal = 0;
    notifyListeners();
    return dispatch(bridge.FfiCommand.syncPreview(source: source));
  }

  Future<void> startSyncRun() {
    final source = syncSource;
    if (source == null) return Future.value();
    syncPhase = 'running';
    syncDone = 0;
    syncTotal = 0;
    notifyListeners();
    return dispatch(bridge.FfiCommand.syncRun(source: source));
  }

  Future<void> cancelSync() => dispatch(const bridge.FfiCommand.syncCancel());

  void resetSync() {
    syncPhase = 'idle';
    syncSource = null;
    syncPreview = null;
    syncReport = null;
    syncError = null;
    syncDone = 0;
    syncTotal = 0;
    notifyListeners();
  }

  /// 测试钩子：直接摆好同步对话框的状态。
  @visibleForTesting
  void debugSetSync({
    required String phase,
    bridge.SyncPreviewDto? preview,
    bridge.SyncReportDto? report,
    String? error,
    int done = 0,
    int total = 0,
  }) {
    syncPhase = phase;
    syncPreview = preview;
    syncReport = report;
    syncError = error;
    syncDone = done;
    syncTotal = total;
    notifyListeners();
  }

  Future<void> startPushTargets(String source) {
    pushSource = source;
    pushTargets = [];
    pushPreview = null;
    pushReport = null;
    pushError = null;
    pushPhase = 'loading_targets';
    pushDone = 0;
    pushTotal = 0;
    notifyListeners();
    return dispatch(bridge.FfiCommand.pushTargets(source: source));
  }

  Future<void> createPushTarget(String name) {
    final source = pushSource;
    if (source == null || name.trim().isEmpty) return Future.value();
    pushPhase = 'creating_target';
    pushError = null;
    notifyListeners();
    return dispatch(
      bridge.FfiCommand.pushCreateTarget(source: source, name: name.trim()),
    );
  }

  Future<void> previewPush({
    required String localName,
    required List<bridge.SongDto> songs,
    required bool isFavorites,
    required bridge.PushTargetDto target,
  }) {
    final source = pushSource;
    if (source == null) return Future.value();
    pushPhase = 'planning';
    pushPreview = null;
    pushError = null;
    notifyListeners();
    return dispatch(
      bridge.FfiCommand.pushPlan(
        source: source,
        localName: localName,
        localSongs: songs,
        isFavorites: isFavorites,
        targetKind: target.kind,
        targetId: target.id,
        targetName: target.name,
        targetSongCount: target.songCount,
      ),
    );
  }

  Future<void> runPush() {
    final source = pushSource;
    if (source == null) return Future.value();
    pushPhase = 'running';
    pushDone = 0;
    pushTotal = 0;
    notifyListeners();
    return dispatch(bridge.FfiCommand.pushRun(source: source));
  }

  Future<void> cancelPush() => dispatch(const bridge.FfiCommand.pushCancel());

  void resetPush() {
    pushPhase = 'idle';
    pushSource = null;
    pushTargets = [];
    pushPreview = null;
    pushReport = null;
    pushError = null;
    pushDone = 0;
    pushTotal = 0;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetPush({
    required String phase,
    String source = 'wy',
    List<bridge.PushTargetDto> targets = const [],
    bridge.PushPreviewDto? preview,
    bridge.PushReportDto? report,
    String? error,
    int done = 0,
    int total = 0,
  }) {
    pushPhase = phase;
    pushSource = source;
    pushTargets = targets;
    pushPreview = preview;
    pushReport = report;
    pushError = error;
    pushDone = done;
    pushTotal = total;
    notifyListeners();
  }

  /// 播放全部：复用 ApplicationCommand::Play（进入队列并播放首曲）。
  Future<void> playSongs(List<bridge.SongDto> songs, {int index = 0}) {
    if (songs.isEmpty) return Future.value();
    return dispatch(bridge.FfiCommand.playSongs(songs: songs, index: index));
  }

  void _replaceState({
    List<bridge.SourceCapabilitiesDto>? sources,
    List<bridge.SongDto>? localSongs,
    List<bridge.CustomPlaylistSummaryDto>? customPlaylists,
    List<bridge.SongDto>? queue,
    int? queueIndex,
    bridge.LyricsDto? lyrics,
    List<bridge.SongDto>? history,
    bridge.SearchDto? search,
    List<bridge.DownloadTaskDto>? downloads,
    List<bridge.SongDto>? favoritesOverride,
  }) {
    _state = bridge.VoicefoxState(
      playback: _state.playback,
      queue: queue ?? _state.queue,
      queueIndex: queueIndex ?? _state.queueIndex,
      search: search ?? _state.search,
      lyrics: lyrics ?? _state.lyrics,
      playlists: _state.playlists,
      favorites: favoritesOverride ?? _state.favorites,
      favoritePlaylists: _state.favoritePlaylists,
      history: history ?? _state.history,
      customPlaylists: customPlaylists ?? _state.customPlaylists,
      downloads: downloads ?? _state.downloads,
      sources: sources ?? _state.sources,
      localSongs: localSongs ?? _state.localSongs,
    );
    notifyListeners();
  }

  /// 测试钩子：摆一个「正在播放」曲目，避免起 Rust 控制器。
  @visibleForTesting
  void debugSetPlaybackSong({
    required String id,
    required String source,
    required String name,
    required String singer,
    String state = 'playing',
    int positionMs = 0,
    int durationMs = 180000,
  }) {
    _state = bridge.VoicefoxState(
      playback: bridge.PlaybackDto(
        state: state,
        song: bridge.SongDto(
          id: id,
          source: source,
          name: name,
          singer: singer,
          albumName: '',
          durationMs: BigInt.from(durationMs),
          coverUrl: null,
        ),
        positionMs: BigInt.from(positionMs),
        durationMs: BigInt.from(durationMs),
        volume: 100,
        generation: BigInt.one,
      ),
      queue: _state.queue,
      queueIndex: _state.queueIndex,
      search: _state.search,
      lyrics: _state.lyrics,
      playlists: _state.playlists,
      favorites: _state.favorites,
      favoritePlaylists: _state.favoritePlaylists,
      history: _state.history,
      customPlaylists: _state.customPlaylists,
      downloads: _state.downloads,
      sources: _state.sources,
      localSongs: _state.localSongs,
    );
    notifyListeners();
  }

  /// 测试钩子：替换自建歌单摘要。
  @visibleForTesting
  void debugSetCustomPlaylists(
    List<bridge.CustomPlaylistSummaryDto> playlists,
  ) => _replaceState(customPlaylists: playlists);

  /// 测试钩子：替换下载任务快照（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetDownloads(List<bridge.DownloadTaskDto> tasks) =>
      _replaceState(downloads: tasks);

  /// 测试钩子：替换音源能力位，避免起 Rust 控制器。
  @visibleForTesting
  void debugSetSources(List<bridge.SourceCapabilitiesDto> sources) =>
      _replaceState(sources: sources);

  /// 测试钩子：替换本地曲库快照。
  @visibleForTesting
  void debugSetLocalSongs(List<bridge.SongDto> songs) =>
      _replaceState(localSongs: songs);

  /// 测试钩子：替换歌词快照（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetLyrics(bridge.LyricsDto lyrics) => _replaceState(lyrics: lyrics);

  /// 测试钩子：替换最近播放历史（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetHistory(List<bridge.SongDto> history) =>
      _replaceState(history: history);

  /// 测试钩子：替换本地收藏（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetFavorites(List<bridge.SongDto> favorites) =>
      _replaceState(favoritesOverride: favorites);

  /// 测试钩子：替换搜索快照（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetSearch(bridge.SearchDto search) => _replaceState(search: search);

  /// 测试钩子：替换队列与当前索引（不起 Rust 控制器）。
  @visibleForTesting
  void debugSetQueue(List<bridge.SongDto> queue, {int index = 0}) =>
      _replaceState(queue: queue, queueIndex: index);

  /// 测试钩子：替换配置（本地音乐目录等）。
  @visibleForTesting
  void debugSetConfig(bridge.ConfigDto config) {
    _cachedConfig = config;
    notifyListeners();
  }

  /// 测试钩子：模拟扫描结束（含警告）。
  @visibleForTesting
  void debugCompleteLocalScan({
    List<bridge.SongDto> songs = const [],
    List<String> warnings = const [],
  }) {
    scanningLocal = false;
    scanWarnings = warnings;
    _replaceState(localSongs: songs);
  }

  /// 测试钩子：直接注入一次浏览结果，避免起 Rust 控制器。
  @visibleForTesting
  void debugBrowseLoaded({
    required String kind,
    required String source,
    required String id,
    List<bridge.SongDto> songs = const [],
    List<bridge.PlaylistDto> playlists = const [],
    List<bridge.PlaylistCategoryDto> categories = const [],
    List<bridge.AlbumDto> albums = const [],
    List<bridge.LeaderboardDto> boards = const [],
    String? message,
    int page = 1,
    bool hasMore = false,
    bool failed = false,
  }) {
    _applyBrowseEvent(
      bridge.VoicefoxEvent(
        kind: 'browse',
        requestId: BigInt.zero,
        page: failed ? 0 : page,
        append: page > 1,
        hasMore: hasMore,
        message: message,
        items: songs,
        queue: const [],
        queueIndex: 0,
        positionMs: BigInt.zero,
        durationMs: BigInt.zero,
        playbackState: null,
        warnings: const [],
        playlists: playlists,
        categories: categories,
        albums: albums,
        boards: boards,
        browseKind: kind,
        source: source,
        id: id,
        progressDone: 0,
        progressTotal: 0,
        pushTargets: const [],
      ),
    );
  }

  Future<void> dispatch(bridge.FfiCommand command) async {
    await _sendCommand(command);
  }

  /// 下发命令并返回错误文本（成功为 null）；`dispatch` 的静默版本。
  Future<String?> _sendCommand(bridge.FfiCommand command) async {
    final controller = _controller;
    if (controller == null) return '控制器尚未连接';
    try {
      await bridge.dispatch(controller: controller, command: command);
      return null;
    } on Object catch (error) {
      lastNotification = '$error';
      lastError = '$error';
      notifyListeners();
      return '$error';
    }
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  /// 立即设置播放器音量（0-100）。持久化由设置页的 ConfigUpdate 负责。
  Future<void> setVolume(int volume) =>
      dispatch(bridge.FfiCommand.setVolume(volume: volume.clamp(0, 100)));

  /// 主题切换：先乐观更新本地 key（立即重绘），再异步落配置。
  /// 此前只改字段不通知，界面要等 Rust 回环才变色。
  void setTheme(String key) {
    if (themeKey == key) return;
    themeKey = key;
    notifyListeners();
    unawaited(updateConfig((config) => config.copyWith(theme: key)));
  }

  /// 引导失败时展示错误（供 main 的 catchError 调用）。
  void reportBootstrapError(Object error) {
    lastNotification = 'Rust 引导失败: $error';
    notifyListeners();
  }

  /// 用修改器生成新的 ConfigDto 并下发（生成代码字段为 final，整只重建）。
  Future<void> updateConfig(bridge.ConfigDto Function(bridge.ConfigDto) patch) {
    final current = _cachedConfig;
    if (current == null) {
      return Future.error('配置尚未加载');
    }
    return dispatch(bridge.FfiCommand.configUpdate(config: patch(current)));
  }

  // ── 播放控制薄封装 ──
  Future<void> toggle() => dispatch(const bridge.FfiCommand.toggle());
  Future<void> next() => dispatch(const bridge.FfiCommand.next());
  Future<void> previous() => dispatch(const bridge.FfiCommand.previous());
  Future<void> seekMs(BigInt ms) => dispatch(bridge.FfiCommand.seekMs(ms));
  Future<void> playSong(bridge.SongDto song) =>
      dispatch(bridge.FfiCommand.playSong(song: song));
  Future<void> queueAdd(bridge.SongDto song) =>
      dispatch(bridge.FfiCommand.queueAdd(song: song, next: false));
  Future<void> queueRemove(int index) =>
      dispatch(bridge.FfiCommand.queueRemove(index: index));
  Future<void> download(bridge.SongDto song) =>
      dispatch(bridge.FfiCommand.downloadEnqueue(song: song));
  Future<void> toggleFavorite(bridge.SongDto song) {
    final isFavorite = state.favorites.any(
      (item) => item.id == song.id && item.source == song.source,
    );
    return dispatch(
      isFavorite
          ? bridge.FfiCommand.favoritesRemove(song: song)
          : bridge.FfiCommand.favoritesAdd(song: song),
    );
  }

  bool isFavorite(bridge.SongDto song) => state.favorites.any(
    (item) => item.id == song.id && item.source == song.source,
  );
}
