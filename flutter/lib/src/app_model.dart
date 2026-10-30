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

class AppModel extends ChangeNotifier {
  bridge.VoicefoxController? _controller;
  bridge.VoicefoxEventStream? _stream;
  bool _pumping = false;
  bridge.VoicefoxState _state = _emptyState();
  String themeKey = 'catppuccin-mocha';
  bool useDynamicColor = true;
  String? lastNotification;
  bridge.QrLoginSessionDto? qrSession;
  String? qrStatus;
  String? qrUser;
  List<String> scanWarnings = [];
  bridge.ConfigDto? _cachedConfig;

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
      );

  /// 桌面引导：初始化 Rust 库并启动事件泵。
  Future<void> bootstrapDesktop() async {
    await RustLib.init();
    final controller = await bridge.newDesktop();
    await _attach(controller);
  }

  /// 移动端引导由宿主注入 ApplicationService 后构造（Phase 4）。
  Future<void> attach(bridge.VoicefoxController controller) async {
    await RustLib.init();
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
        } on Object {
          return;
        }
      }
    }
  }

  void _handleEvent(bridge.VoicefoxEvent event) {
    switch (event.kind) {
      case 'search':
      case 'playback':
      case 'queue':
      case 'playlist':
      case 'lyrics':
      case 'library':
      case 'downloads':
        unawaited(_refreshState());
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
          if (qrStatus == 'success' ||
              qrStatus == 'expired' ||
              qrStatus == 'failed') {
            qrSession = null;
          }
        }
      case 'local_music':
        scanWarnings = event.warnings;
      case 'config':
        final config = event.config;
        if (config != null) {
          _cachedConfig = config;
          themeKey = config.theme;
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

  Future<void> dispatch(bridge.FfiCommand command) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await bridge.dispatch(controller: controller, command: command);
    } on Object catch (error) {
      lastNotification = '$error';
      notifyListeners();
    }
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
    return dispatch(
        bridge.FfiCommand.configUpdate(config: patch(current)));
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
  Future<void> download(bridge.SongDto song) =>
      dispatch(bridge.FfiCommand.downloadEnqueue(song: song));
  Future<void> toggleFavorite(bridge.SongDto song) {
    final isFavorite = state.favorites
        .any((item) => item.id == song.id && item.source == song.source);
    return dispatch(
      isFavorite
          ? bridge.FfiCommand.favoritesRemove(song: song)
          : bridge.FfiCommand.favoritesAdd(song: song),
    );
  }

  bool isFavorite(bridge.SongDto song) => state.favorites
      .any((item) => item.id == song.id && item.source == song.source);
}
