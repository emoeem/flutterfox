/// 应用状态模型：单控制器事件泵 + ChangeNotifier。
///
/// 状态管理决策（记录于 FLUTTER_MIGRATION_PROGRESS.md）：当前是「单 Rust 控制器
/// 广播事件 → 单一快照」的结构，ChangeNotifier 足够；页面复杂化后再引入
/// riverpod（届时二选一，不混用），现在不自造状态库。
library;

import 'dart:async';
import 'dart:io' show stderr;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bridge/api.dart' as bridge;
import 'bridge/frb_generated.dart' show RustLib;
import 'bridge/lib.dart' as bridge;
import 'config_ext.dart';

/// 浏览数据面的类型化唯一键（指南 §8.1）：kind + source + id 构成隔离命名
/// 空间。账号歌单与公开歌单以 kind 区分（`account_playlist_detail` vs
/// `playlist_detail`），同 ID 不同 source 互不污染。缓存槽、请求、事件与
/// UI 读取统一使用本键，不再散落字符串拼接。
@immutable
class PlaylistKey {
  final String kind;
  final String source;
  final String id;

  const PlaylistKey(this.kind, this.source, this.id);

  @override
  bool operator ==(Object other) =>
      other is PlaylistKey &&
      other.kind == kind &&
      other.source == source &&
      other.id == id;

  @override
  int get hashCode => Object.hash(kind, source, id);

  @override
  String toString() => '$kind|$source|$id';
}

/// 一次浏览请求的落库结果。按 [PlaylistKey] 分槽，页面直接读它决定
/// 加载/空/错误态。
class BrowseResult {
  bool loading = false;
  String? error;
  String? notice;
  int page = 0;
  bool hasMore = false;

  /// 分页 arm 标志：只有本代次（最近一次 page=1 加载）的响应到达后才
  /// 置 true。此后迟到的 append 响应若不满足「严格顺序下一页」一律丢弃
  /// ——防止「页 2 在途时用户刷新」后旧页 2 数据追加进已清空的新列表
  /// （§8.1 过期响应不得覆盖当前页面）。
  bool appendArmed = false;

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

/// 纯进度变化（position/duration 节流更新）的通知源。
///
/// 播放状态迁移（含 Ended→Stopped、播放错误→Stopped 等「自动迁移」，它们
/// 只经 progress 事件广播）走全模型 notifyListeners；只有位置/时长的纯
/// 节流变化才通知本 notifier——进度条、歌词 ticker 等高频小组件订阅它，
/// 4Hz 更新不再打满整页（指南 §7.5/§11.1）。
class _PlaybackTickNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

class AppModel extends ChangeNotifier {
  bridge.VoicefoxController? _controller;
  bridge.VoicefoxEventStream? _stream;
  bool _pumping = false;
  bridge.VoicefoxState _state = _emptyState();
  final Map<PlaylistKey, BrowseResult> _browse = {};

  /// 下拉刷新完成判据的等待者（按槽键）：命令 fire-and-forget，完成信号
  /// 只能来自 browse 事件。page=1 非追加响应或 BrowseFailed（page=0）到达
  /// 即完成；过期 append 不完成（刷新仍在途）。等待者一次性消费。
  final Map<PlaylistKey, List<Completer<void>>> _browseWaiters = {};
  final _PlaybackTickNotifier _playbackTick = _PlaybackTickNotifier();

  /// 纯进度通知源：position/duration 节流更新只通知这里，不打满全模型。
  /// 进度条/歌词 ticker 等高频组件应订阅本 notifier 并直接读
  /// `state.playback`（`_state` 始终是最新值，只是不触发全模型通知）。
  ChangeNotifier get playbackTick => _playbackTick;

  // 事件速率诊断（P0-01 instrument）：每 5s 打一条事件计数与最后事件类型，
  // 用于定位主 isolate 卡死时的事件洪泛/静默；开销为 5s 一行 debugPrint。
  int _eventRateCount = 0;
  DateTime _eventRateWindow = DateTime.now();

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

  /// 最近一次扫描统计（§5.10 流程 5）；取消的扫描为 null（不提交旧值）。
  bridge.ScanStatsDto? scanStats;

  /// 最近一次扫描是否被用户取消（统计条切换「已取消」文案用）。
  bool scanCancelled = false;
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
        // release 模式 debugPrint 可能被引擎日志吞掉；事件流故障必须可见
        // （否则 UI 靠 _refreshState 轮询继续工作，故障不可排查）。
        stderr.writeln('voicefox event stream error: $error');
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
    // P0-01 instrument：事件速率观测（5s 窗口一行），定位卡死时的事件洪泛。
    _eventRateCount++;
    final now = DateTime.now();
    final windowSeconds = now.difference(_eventRateWindow).inSeconds;
    if (windowSeconds >= 5) {
      // release 模式 print/debugPrint 走引擎日志通道且可能被吞；dart:io
      // stderr 直写文件描述符，GUI 诊断行（事件速率观测）一定落日志。
      stderr.writeln(
        'voicefox events: $_eventRateCount/$windowSeconds s, last=${event.kind}',
      );
      _eventRateCount = 0;
      _eventRateWindow = now;
    }
    switch (event.kind) {
      case 'progress':
        // 播放泵以 4Hz 广播进度：只替换 playback 快照，不整份重拉 state
        // （state() 会连本地曲库一起克隆）。
        _applyPlaybackProgress(event);
      case 'search':
      case 'playback':
        if (event.message != null) {
          lastError = _logAndSanitize(event.message!);
        }
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
        // 通知文案同样过净化：推送/同步失败消息可能携带音源 URL。
        if (event.message != null) {
          lastNotification = _logAndSanitize(event.message!);
        }
      case 'qr_login':
        if (event.qrSession != null) {
          qrSession = event.qrSession;
          qrStatus = 'waiting';
        }
        if (event.status != null) {
          qrStatus = event.status;
          qrUser = event.userName;
          if (qrStatus == 'failed' && event.message != null) {
            lastError = _logAndSanitize(event.message!);
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
        // 取消的扫描未提交：Rust 侧 scan_stats 还是上一次的旧值，
        // 事件 stats 为 null——清空统计条而不是展示旧数据。
        scanCancelled = event.scanCancelled;
        scanStats = event.scanCancelled ? null : event.scanStats;
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
    final newState = event.playbackState ?? playback.state;
    // 状态迁移（buffering→Playing、Ended→Stopped、播放错误→Stopped 等
    // 「自动迁移」只经 progress 事件广播）必须打全模型 notifyListeners，
    // 否则 home Hero 播放/暂停文案、行内均衡器图标、myune 投影等 state
    // 消费者全部冻结；只有纯 position/duration 节流变化才走 playbackTick
    // （4Hz 不再触发全模型通知）。
    final stateChanged = newState != playback.state;
    _state = bridge.VoicefoxState(
      playback: bridge.PlaybackDto(
        state: newState,
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
    if (stateChanged) {
      notifyListeners();
    } else {
      _playbackTick.fire();
    }
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

  BrowseResult? browse(String kind, String source, String id) =>
      _browse[PlaylistKey(kind, source, id)];

  /// 等待 [kind/source/id] 槽的下一个 page=1 响应或错误落槽（下拉刷新的
  /// 完成 Future）。必须先注册等待者再派发命令，否则事件可能在
  /// dispatch 解析与注册之间到达而漏掉。调用方应加超时兜底（控制器失联
  /// 时事件可能永不到达），不允许 spinner 永久悬挂（§9）。
  Future<void> awaitBrowseResponse(String kind, String source, String id) {
    final waiter = Completer<void>();
    _browseWaiters
        .putIfAbsent(PlaylistKey(kind, source, id), () => [])
        .add(waiter);
    return waiter.future;
  }

  void _completeBrowseWaiters(PlaylistKey key) {
    final waiters = _browseWaiters.remove(key);
    if (waiters == null) return;
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  /// 详情页 initState 的同步预清槽：清空旧曲目 + 置 loading，但**不通知**
  /// （§8.1「页面切换先显示对应 loading，不闪现旧歌单歌曲」的首帧实现；
  /// 通知会让导航 build 中的 ListenableBuilder 在 build 期被标脏）。真正的
  /// 请求派发由页面在 postFrame 执行（届时走 [_beginBrowse] 正常通知）。
  void prepareBrowseLoad(String kind, String source, String id) {
    final result = _browse.putIfAbsent(
      PlaylistKey(kind, source, id),
      BrowseResult.new,
    );
    result
      ..loading = true
      ..error = null
      ..notice = null
      ..page = 0
      ..hasMore = false
      ..appendArmed = false
      ..songs.clear()
      ..playlists.clear()
      ..albums.clear()
      ..boards.clear()
      ..categories.clear();
  }

  /// 触发本地扫描；未传路径时使用配置里的目录。路径为空直接返回。
  Future<void> scanLocal({List<String>? paths, int? maxDepth}) {
    final config = _cachedConfig;
    final targetPaths = paths ?? config?.localMusicPaths ?? const <String>[];
    if (targetPaths.isEmpty) return Future.value();
    scanningLocal = true;
    scanWarnings = const [];
    scanStats = null;
    scanCancelled = false;
    notifyListeners();
    return dispatch(
      bridge.FfiCommand.localScan(
        paths: targetPaths,
        maxDepth: maxDepth ?? config?.localMusicMaxDepth ?? 0,
      ),
    );
  }

  /// 取消进行中的本地扫描：本次结果不提交，已入库歌曲保持不变。
  Future<void> cancelScan() =>
      dispatch(const bridge.FfiCommand.localScanCancel());

  /// 暂停下载任务（引擎在下一个检查点停下，保留已写入的部分）。
  Future<void> downloadPause(BigInt id) =>
      dispatch(bridge.FfiCommand.downloadPause(id: id));

  /// 继续暂停的下载任务（同源做 Range 续传，不同源整体重下）。
  Future<void> downloadResume(BigInt id) =>
      dispatch(bridge.FfiCommand.downloadResume(id: id));

  /// 删除已完成任务的本地文件并清除下载记录（UI 层先二次确认）。
  Future<void> downloadDeleteFile(BigInt id) =>
      dispatch(bridge.FfiCommand.downloadDeleteFile(id: id));

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
      PlaylistKey(kind, source, id),
      BrowseResult.new,
    );
    result.loading = true;
    result.error = null;
    result.notice = null;
    if (!append) {
      // 新代次：清空列表并撤销分页 arm——此后迟到的 append 响应全部丢弃，
      // 直到本代次 page=1 响应到达才重新 arm（§8.1 过期响应不得混入）。
      result
        ..page = 0
        ..hasMore = false
        ..appendArmed = false
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
    final key = PlaylistKey(kind, event.source ?? '', event.id ?? '');
    final result = _browse.putIfAbsent(key, BrowseResult.new);
    if (event.page == 0) {
      // Rust 侧 BrowseFailed 不 carry page；加载事件恒带 >=1 的页码。
      // 已知边界：若失败来自已被重载取代的旧 append 请求，本槽恰好有新
      // 请求在途时错误会短暂落在同一槽上（BrowseFailed 无页码无法甄别），
      // 由随后的新响应覆盖，不产生串槽。
      result.loading = false;
      // §9/P1-11（QA 2026-11-11 第 2 轮）：result.error 被发现页/歌单页等
      // 直接渲染为错误框 detail，Rust 侧错误消息可能携带完整 URL/代理参数
      // ——在源头净化（原始异常写 stderr 日志），与 lastError/toast 同口径。
      result.error = event.message != null
          ? _logAndSanitize(event.message!)
          : '加载失败';
      notifyListeners();
      // 失败落槽也是刷新的完成信号（spinner 收起，错误态由槽渲染）。
      _completeBrowseWaiters(key);
      return;
    }
    final isNewPage1 = !event.append;
    if (!event.append) {
      result
        ..loading = false
        ..songs.clear()
        ..playlists.clear()
        ..albums.clear()
        ..boards.clear()
        ..categories.clear()
        // page=1 响应到达：本代次分页 arm 生效。
        ..appendArmed = true;
    } else if (!result.appendArmed || event.page != result.page + 1) {
      // 过期/乱序/重复的 append 响应：丢弃，不追加进当前列表，也不改变
      // 在途加载态（丢弃的响应不代表任何一次在途请求已应答）。
      // 覆盖场景：①页 2 在途时用户刷新（arm 已撤销）后旧页 2 迟到；
      // ②同一页重复响应（防重复合并）。
      debugPrint('browse stale append dropped: $key page=${event.page}');
      return;
    } else {
      result.loading = false;
    }
    result
      ..error = null
      // notice 同样来自 event.message 且被空态标题直出（如「暂无账号红心
      // 镜像」附带的服务端说明），同一净化口径；notice 非错误，不写 stderr。
      ..notice = event.message == null
          ? null
          : sanitizeUserFacingMessage(event.message!)
      ..page = event.page
      ..hasMore = event.hasMore
      ..songs.addAll(event.items)
      ..playlists.addAll(event.playlists)
      ..albums.addAll(event.albums)
      ..boards.addAll(event.boards)
      ..categories.addAll(event.categories);
    notifyListeners();
    if (isNewPage1) _completeBrowseWaiters(key);
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

  /// 返回命令立即失败的错误文本（成功 null；browse 响应经事件异步到达）。
  Future<String?> loadPlaylistDetail(
    bridge.PlaylistDto playlist, {
    int page = 1,
  }) {
    _beginBrowse(
      'playlist_detail',
      playlist.source,
      playlist.id,
      append: page > 1,
    );
    return dispatchWithError(
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

  /// 返回命令立即失败的错误文本（成功 null；browse 响应经事件异步到达）。
  Future<String?> loadArtistSongs(bridge.ArtistDto artist, {int page = 1}) {
    _beginBrowse('artist_songs', artist.source, artist.id, append: page > 1);
    return dispatchWithError(
      bridge.FfiCommand.artistSongs(artist: artist, page: page),
    );
  }

  Future<void> loadArtistAlbums(bridge.ArtistDto artist, {int page = 1}) {
    _beginBrowse('artist_albums', artist.source, artist.id, append: page > 1);
    return dispatch(bridge.FfiCommand.artistAlbums(artist: artist, page: page));
  }

  /// 返回命令立即失败的错误文本（成功 null；browse 响应经事件异步到达）。
  Future<String?> loadAlbumSongs(bridge.AlbumDto album, {int page = 1}) {
    _beginBrowse('album_songs', album.source, album.id, append: page > 1);
    return dispatchWithError(
      bridge.FfiCommand.albumSongs(album: album, page: page),
    );
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
    final ids = [
      for (final key in _browse.keys)
        if (key.kind == customPlaylistKind &&
            key.source == _customPlaylistSource)
          key.id,
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
    _browse.remove(PlaylistKey(customPlaylistKind, _customPlaylistSource, id));
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

  /// 返回命令立即失败的错误文本（成功 null；browse 响应经事件异步到达）。
  Future<String?> loadAccountPlaylistDetail(
    String source,
    String id, {
    bool silent = false,
  }) {
    if (!silent) _beginBrowse(accountPlaylistDetailKind, source, id);
    return dispatchWithError(
      bridge.FfiCommand.accountPlaylistDetail(source: source, playlistId: id),
    );
  }

  /// 同步完成后刷新所有已打开的账号歌单槽（列表 + 详情）。
  void _reloadAccountBrowse() {
    for (final key in _browse.keys.toList()) {
      if (key.kind == accountPlaylistsKind) {
        unawaited(loadAccountPlaylists(key.source, silent: true));
      } else if (key.kind == accountPlaylistDetailKind) {
        unawaited(loadAccountPlaylistDetail(key.source, key.id, silent: true));
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
    List<bridge.PlaylistDto>? favoritePlaylists,
  }) {
    _state = bridge.VoicefoxState(
      playback: _state.playback,
      queue: queue ?? _state.queue,
      queueIndex: queueIndex ?? _state.queueIndex,
      search: search ?? _state.search,
      lyrics: lyrics ?? _state.lyrics,
      playlists: _state.playlists,
      favorites: favoritesOverride ?? _state.favorites,
      favoritePlaylists: favoritePlaylists ?? _state.favoritePlaylists,
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

  /// 测试钩子：替换收藏歌单镜像（不起 Rust 控制器；模拟 'library' 事件
  /// _refreshState 后的 favoritePlaylists 快照）。
  @visibleForTesting
  void debugSetFavoritePlaylists(List<bridge.PlaylistDto> playlists) =>
      _replaceState(favoritePlaylists: playlists);

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

  /// 测试钩子：模拟扫描结束（含警告与统计；cancelled 模拟取消事件）。
  /// 取消事件不改快照——与生产一致：取消的扫描不提交，localSongs 不变。
  @visibleForTesting
  void debugCompleteLocalScan({
    List<bridge.SongDto> songs = const [],
    List<String> warnings = const [],
    bridge.ScanStatsDto? stats,
    bool cancelled = false,
  }) {
    scanningLocal = false;
    scanWarnings = warnings;
    scanCancelled = cancelled;
    scanStats = cancelled ? null : stats;
    if (!cancelled) _replaceState(localSongs: songs);
    notifyListeners();
  }

  /// 测试钩子：直接走一次事件处理（构造 VoicefoxEvent 需要 20+ 字段，
  /// 净化链路测试只需要 kind+message）。
  @visibleForTesting
  void debugHandleEventForTest({required String kind, String? message}) {
    _handleEvent(
      bridge.VoicefoxEvent(
        kind: kind,
        requestId: BigInt.zero,
        page: 0,
        append: false,
        hasMore: false,
        scanCancelled: false,
        message: message,
        items: const [],
        queue: const [],
        queueIndex: 0,
        positionMs: BigInt.zero,
        durationMs: BigInt.zero,
        playbackState: null,
        warnings: const [],
        playlists: const [],
        categories: const [],
        albums: const [],
        boards: const [],
        progressDone: 0,
        progressTotal: 0,
        pushTargets: const [],
      ),
    );
  }

  /// 测试钩子：触发一次浏览槽的「开始加载」（等价 loadPlaylistDetail 的
  /// 前半段），供隔离测试模拟「刷新清空列表并撤销分页 arm」而不需要
  /// Rust 控制器。
  @visibleForTesting
  void debugBeginBrowse({
    required String kind,
    required String source,
    required String id,
    bool append = false,
  }) {
    _beginBrowse(kind, source, id, append: append);
  }

  /// 测试钩子：拦截下发的命令（不起 Rust 控制器）；null 恢复生产链路。
  Future<void> Function(bridge.FfiCommand command)? _commandInterceptor;

  /// 测试钩子：注入命令拦截器；传 null 复位。
  @visibleForTesting
  void debugSetDispatcherForTest(
    Future<void> Function(bridge.FfiCommand command)? interceptor,
  ) => _commandInterceptor = interceptor;

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
        scanCancelled: false,
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

  /// 下发命令并返回错误文本（成功为 null）。
  ///
  /// `dispatch` 丢弃返回值（fire-and-forget，错误经 lastError /
  /// lastNotification → Shell toast 呈现）；需要按失败结果做状态回滚的
  /// 调用方（如收藏 pending、下拉刷新完成判据）用本变体拿真实结果。
  /// 错误呈现只留全局 toast 一处（§9）：失败分支已写 lastError/
  /// lastNotification 并通知，调用方不得再渲染第二份错误文案。
  Future<String?> dispatchWithError(bridge.FfiCommand command) =>
      _sendCommand(command);

  /// 下发命令并返回错误文本（成功为 null）；`dispatch` 的静默版本。
  Future<String?> _sendCommand(bridge.FfiCommand command) async {
    // 测试钩子：不起 Rust 控制器，只记录下发的命令（页面级命令链路验证）。
    final interceptor = _commandInterceptor;
    if (interceptor != null) {
      await interceptor(command);
      return null;
    }
    final controller = _controller;
    if (controller == null) return '控制器尚未连接';
    try {
      await bridge.dispatch(controller: controller, command: command);
      return null;
    } on Object catch (error) {
      final readable = _logAndSanitize('$error');
      lastNotification = readable;
      lastError = readable;
      notifyListeners();
      return '$error';
    }
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  // ── 搜索历史（本地持久化，§5.4）──

  /// 最近搜索关键词（最新在前、去重、上限 [_searchHistoryMax]）。
  /// 纯本地 shared_preferences 持久化：不写远端账号，不跨端同步；读写
  /// 任何失败（如测试环境无插件通道）都容错降级为空历史，不抛出。
  static const _searchHistoryKey = 'voicefox.search_history';
  static const _searchHistoryMax = 10;
  List<String> _searchHistory = [];

  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  Future<void> loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_searchHistoryKey) ?? const [];
      _searchHistory = [
        for (final item in stored)
          if (item.trim().isNotEmpty) item.trim(),
      ];
      notifyListeners();
    } on Object catch (error) {
      // 容错降级：失败 = 空历史（原始异常落日志，不进 UI）。
      _searchHistory = [];
      stderr.writeln('voicefox search history load failed: $error');
    }
  }

  /// 记录一次已提交的搜索（回车提交 / 点击历史项 / Shell 种子）；防抖的
  /// 中间态不记录。最新置顶、去重、截断到上限。
  Future<void> rememberSearch(String keyword) async {
    final key = keyword.trim();
    if (key.isEmpty) return;
    _searchHistory
      ..remove(key)
      ..insert(0, key);
    if (_searchHistory.length > _searchHistoryMax) {
      _searchHistory.removeRange(_searchHistoryMax, _searchHistory.length);
    }
    notifyListeners();
    await _persistSearchHistory();
  }

  Future<void> removeSearchHistory(String keyword) async {
    if (!_searchHistory.remove(keyword.trim())) return;
    notifyListeners();
    await _persistSearchHistory();
  }

  Future<void> clearSearchHistory() async {
    if (_searchHistory.isEmpty) return;
    _searchHistory = [];
    notifyListeners();
    await _persistSearchHistory();
  }

  Future<void> _persistSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchHistoryKey, _searchHistory);
    } on Object catch (error) {
      stderr.writeln('voicefox search history persist failed: $error');
    }
  }

  /// 面向用户的错误/通知文案净化（指南 §9：错误消息对用户可读，原始异常
  /// 只写日志，不把 token/cookie/隐私路径/完整 URL 暴露到 UI）。
  ///
  /// 公共 API（QA 2026-11-11 P1：搜索页错误框直出 Rust 快照
  /// `state.search.error` 原始 URL——该字段不经 lastError/lastNotification
  /// 净化链路，页面渲染前必须过本函数）。处理：URL 整体替换为占位符；
  /// 换行/连续空白折叠成单空格（toast 是单行 Flexible 文本，多行原始异常会
  /// 把错误浮层撑到整页高——QA 2026-11-10 P1 实测）；超长截断到
  /// [_maxUserFacingMessageLength]。
  static String sanitizeUserFacingMessage(String raw) {
    var msg = raw
        .replaceAll(RegExp(r'https?://\S+'), '[URL]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (msg.length > _maxUserFacingMessageLength) {
      msg = '${msg.substring(0, _maxUserFacingMessageLength)}…';
    }
    return msg.isEmpty ? '操作失败' : msg;
  }

  static const _maxUserFacingMessageLength = 140;

  /// 原始异常写日志（stderr 直写，release 可见）+ 返回净化后的用户文案。
  String _logAndSanitize(String raw) {
    stderr.writeln('voicefox error(raw): $raw');
    return sanitizeUserFacingMessage(raw);
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
    lastNotification = 'Rust 引导失败: ${_logAndSanitize('$error')}';
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
