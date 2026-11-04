// Voicefox seam: AppModel → myune Provider 图的常驻投影。
// Newly written for voicefox, not vendored.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../myune/page/playlist/playlist_content_notifier.dart';
import '../myune/page/playlist/playlist_models.dart';
import '../myune/page/setting/settings_provider.dart';
import '../myune/services/notification_service.dart';
import '../myune/theme/theme_provider.dart';
import '../myune_seam/cover_loader.dart';
import '../theme/seed_colors.dart';

/// 把 voicefox 的 AppModel 快照持续投影进 myune 的 Provider 图：
///
/// - 播放状态/进度/封面 → `adoptExternalState`
/// - 歌词 → `adoptExternalLyrics`
/// - 播放队列 → `adoptExternalQueue`
/// - `lastError` / `lastNotification` → `NotificationService` toast
///   （全局统一错误出口，取代旧 Shell 的 SnackBar）
///
/// 生命周期与 app 相同：`MyuneHost` 在 main 里创建一次，永不 dispose。
class MyuneProjection {
  MyuneProjection({
    required AppModel model,
    required PlaylistContentNotifier playlist,
    required NotificationService notifications,
    required ThemeProvider theme,
  }) : _model = model,
       _playlist = playlist,
       _notifications = notifications,
       _theme = theme {
    model.addListener(_sync);
    _sync();
  }

  final AppModel _model;
  final PlaylistContentNotifier _playlist;
  final NotificationService _notifications;
  final ThemeProvider _theme;

  /// 当前曲目的封面字节（来自 SongDto.coverUrl），以及它对应的 URL。
  String? _coverUrl;
  Uint8List? _cover;
  String? _shownError;
  String? _shownNotice;

  void _sync() {
    _applyTheme();
    final playback = _model.state.playback;
    final dto = playback.song;
    _ensureCover(dto?.coverUrl);
    _playlist.adoptExternalState(
      song: dto == null ? null : _toSong(dto, _cover),
      position: Duration(milliseconds: playback.positionMs.toInt()),
      total: Duration(milliseconds: playback.durationMs.toInt()),
      playing: playback.state == 'playing',
    );
    _playlist.adoptExternalLyrics(_toLyrics(_model.state.lyrics));
    final queue = _model.state.queue;
    _playlist.adoptExternalQueue(
      [for (final item in queue) _toSong(item, null)],
      _model.state.queueIndex,
    );
    _pumpToasts();
  }

  /// 主题桥接：ConfigDto（theme key + 明暗三态）→ myune ThemeProvider。
  ///
  /// 动态取色开启时不覆盖 seed——那个 seed 由 main 的 DynamicColorBuilder
  /// 注入系统调色板。ThemeProvider 的 SharedPreferences 持久化是无害回声，
  /// 真源是 Rust 配置。
  void _applyTheme() {
    final mode = switch (_model.config?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (_theme.themeMode != mode) {
      _theme.setThemeMode(mode);
    }
    if (_model.useDynamicColor) return;
    final seed = _seedFor(_model.themeKey);
    if (_theme.currentSeedColor != seed) {
      _theme.setSeedColor(seed);
    }
  }

  /// TUI 同源 seed 表的强调色作为 M3 种子；未知 key 回退 Mocha。
  static Color _seedFor(String key) {
    for (final theme in kSeedThemes) {
      if (theme.key == key) return Color(hexOf(theme.accent));
    }
    return const Color(0xFF89B4FA);
  }

  /// AppModel 的错误/通知统一浮成 myune 的 toast。
  ///
  /// `_sendCommand` 会把同一条错误同时写进 lastError 与 lastNotification，
  /// 因此 error 非空时只弹 error，避免同一条消息弹两次。
  void _pumpToasts() {
    final error = _model.lastError;
    if (error != null) {
      if (error != _shownError) {
        _shownError = error;
        _notifications.error(error);
      }
      _shownNotice = _model.lastNotification;
      return;
    }
    _shownError = null;
    final notice = _model.lastNotification;
    if (notice != null && notice != _shownNotice) {
      _shownNotice = notice;
      _notifications.info(notice);
    }
    if (notice == null) {
      _shownNotice = null;
    }
  }

  /// 封面只在 URL 变化时拉取；失败保留 null（页面回退占位图）。
  void _ensureCover(String? url) {
    if (url == _coverUrl) return;
    _coverUrl = url;
    _cover = null;
    if (url == null || url.isEmpty) {
      return;
    }
    unawaited(loadCoverBytes(url).then((bytes) {
      if (url != _coverUrl) return;
      _cover = bytes;
      _playlist.adoptExternalState(
        song: _currentSongWithCover(bytes),
        position: _currentPosition(),
        total: _currentTotal(),
        playing: _currentPlaying(),
      );
    }));
  }

  bridge.SongDto? get _currentDto => _model.state.playback.song;

  // 封面异步到达后单独重投一次当前曲（_sync 由 AppModel 通知驱动，
  // 封面就位那一刻 AppModel 不一定有新事件）。
  Song? _currentSongWithCover(Uint8List? bytes) {
    final dto = _currentDto;
    return dto == null ? null : _toSong(dto, bytes);
  }

  Duration _currentPosition() =>
      Duration(milliseconds: _model.state.playback.positionMs.toInt());

  Duration _currentTotal() =>
      Duration(milliseconds: _model.state.playback.durationMs.toInt());

  bool _currentPlaying() => _model.state.playback.state == 'playing';

  List<LyricLine> _toLyrics(bridge.LyricsDto lyrics) {
    if (lyrics.isEmpty) return const [];
    return [
      for (final line in lyrics.lines)
        LyricLine(
          timestamp: Duration(milliseconds: line.timestampMs.toInt()),
          texts: [line.text],
        ),
    ];
  }

  /// voicefox SongDto → myune Song. voicefox uses the SongDto id as the
  /// stable handle (path for local files, source-prefixed id for online).
  Song _toSong(bridge.SongDto dto, Uint8List? albumArt) {
    final fallbackName = dto.id.split(RegExp(r'[/\\]')).last;
    return Song(
      title: dto.name.isEmpty ? fallbackName : dto.name,
      artist: dto.singer.isEmpty ? '未知歌手' : dto.singer,
      album: dto.albumName.isEmpty ? '未知专辑' : dto.albumName,
      filePath: dto.id,
      albumArt: albumArt,
      duration: dto.durationMs > BigInt.zero
          ? Duration(milliseconds: dto.durationMs.toInt())
          : null,
    );
  }
}

/// App 级 myune Provider 图：四件套 + 投影，生命周期与 app 相同。
///
/// 取代此前「每次打开播放页临时 new 一套 Provider 图再 dispose」的模式
/// （每次进播放页都会重跑日志文件、歌单 JSON 加载、热键注册）。
/// myune 的文件系统持久化目录在外部数据模式下保持空置：数据只经
/// `MyuneProjection` 注入，UI 的播放命令经 mpv shim 转发回 AppModel。
class MyuneHost {
  MyuneHost._({
    required this.settings,
    required this.theme,
    required this.notifications,
    required this.playlist,
  });

  final SettingsProvider settings;
  final ThemeProvider theme;
  final NotificationService notifications;
  final PlaylistContentNotifier playlist;

  /// 创建 app 级 Provider 图并挂上常驻投影。
  static MyuneHost attach(AppModel model) {
    final settings = SettingsProvider();
    final theme = ThemeProvider();
    final notifications = NotificationService();
    final playlist = PlaylistContentNotifier(
      settings,
      theme,
      notifications,
    );
    // 主题初始化是异步的（字体/配色），失败不影响页面渲染。
    unawaited(theme.initialize());
    MyuneProjection(
      model: model,
      playlist: playlist,
      notifications: notifications,
      theme: theme,
    );
    return MyuneHost._(
      settings: settings,
      theme: theme,
      notifications: notifications,
      playlist: playlist,
    );
  }
}
