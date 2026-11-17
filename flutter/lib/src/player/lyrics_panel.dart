/// Phase 3 歌词面板（计划书 §5.2；ContextPanel 歌词 Tab 与全屏 NowPlayingPage 共用）。
///
/// - 普通逐行 LRC 按时间同步滚动：位置由 LivePlayback 500ms 插值，仅在
///   「当前行序号变化」时重建滚动位置；大列表只在歌词/歌曲对象更换时重建，
///   不随 4Hz 进度事件整页刷新（§6.5）；
/// - 当前行 26-32px w600，相邻/更远行 18-20px 逐级降透明；翻译行 15-17px
///   （后端 LyricsDto.translation 为整段/当前行译文而非逐行，仅在当前行下展示）；
/// - 点击歌词行 → AppModel.seekMs 真实跳转（FfiCommand.seekMs 存在）；
///   仅当歌词含非零时间戳才启用（§5.7:461 点击门槛），无时间戳行不挂
///   手势并如实说明「不支持点击跳转」；
/// - 手动滚动暂停跟随，停止滚动 2 秒后恢复跟随当前行；
/// - 尊重 MediaQuery.disableAnimations：关闭动画时直接定位、样式瞬时切换；
/// - 歌词空态与全屏单列布局共用 [LyricsRetryButton]：手动重取走真实
///   LoadLyrics 命令（P2-17），在途禁用防重复，失败/超时如实提示。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../widgets/live_progress.dart';

/// 歌词面板。
class LyricsPanel extends StatefulWidget {
  const LyricsPanel({super.key, required this.model, this.compact = false});

  final AppModel model;

  /// true：ContextPanel 窄栏（当前行 26px）；false：全屏播放页（当前行 32px）。
  final bool compact;

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  final ScrollController _controller = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  List<GlobalKey> _lineKeys = const [];

  /// 当前行序号（由行时间戳与插值位置计算；-1 = 未进入第一句）。
  int _active = -1;

  /// 歌词引用（用于仅在其变化时重建行列表）。
  bridge.LyricsDto? _lastLyrics;
  Object? _lastSong;

  /// 自动跟随开关；用户手动滚动时暂停，停止 2s 后恢复。
  bool _following = true;
  bool _programmatic = false;
  Timer? _resumeTimer;

  double get _currentFontSize => widget.compact ? 26 : 32;
  double get _lineFontSize => widget.compact ? 18 : 20;
  double get _translationFontSize => widget.compact ? 15 : 17;

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── 当前行计算（插值时钟回调） ─────────────────────────────────────────

  void _onActiveLineChanged(int index) {
    if (!mounted || index == _active) return;
    setState(() => _active = index);
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive();
      });
    }
  }

  /// 把当前行滚到视口约 32% 高度处；disableAnimations 时直接定位。
  void _scrollToActive() {
    if (_active < 0 || _active >= _lineKeys.length) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final box =
        _lineKeys[_active].currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || box == null || !box.attached) return;
    if (!_controller.hasClients) return;
    final topInViewport = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final target =
        (_controller.offset + topInViewport - viewport.size.height * 0.32)
            .clamp(0.0, _controller.position.maxScrollExtent);
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      _programmatic = true;
      _controller.jumpTo(target);
      _programmatic = false;
    } else {
      _programmatic = true;
      _controller
          .animateTo(
            target,
            duration: VxMotion.lyricLine,
            curve: VxMotion.standard,
          )
          .whenComplete(() => _programmatic = false);
    }
  }

  // ── 手动滚动暂停跟随 ──────────────────────────────────────────────────

  bool _onScrollNotification(ScrollNotification notification) {
    if (_programmatic) {
      if (notification is ScrollEndNotification) _programmatic = false;
      return false;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      // 用户滚动（拖动或滚轮）：暂停跟随。
      _resumeTimer?.cancel();
      _following = false;
    }
    if (notification is ScrollEndNotification && !_following) {
      // 停止滚动 2s 后恢复跟随当前行（§5.2）。
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _following = true;
        _scrollToActive();
      });
    }
    return false;
  }

  // ── 构建 ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final song = model.state.playback.song;
        final lyrics = model.state.lyrics;
        final scheme = Theme.of(context).colorScheme;
        if (song == null) {
          return _Status(
            icon: Icons.lyrics_outlined,
            title: '未在播放',
            message: '播放歌曲后，歌词会同步显示在这里',
          );
        }
        if (lyrics.isEmpty || lyrics.lines.isEmpty) {
          // P2-17：自动获取落空时提供手动重取入口——后端 LoadLyrics
          // 以当前歌曲重新拉词，结果经 lyrics 事件回填 state。
          return _Status(
            icon: Icons.lyrics_outlined,
            title: '暂无歌词',
            message:
                '当前曲目没有可用的歌词数据。歌词由后端在切歌时自动获取，'
                '也可点击下方按钮手动重新获取。',
            action: LyricsRetryButton(model: model, song: song),
          );
        }
        // 点击跳转门槛（§5.7:461）：歌词全部行无有效时间戳时，点击不
        // 挂 seek 手势（onTap 置 null），并如实说明——不伪造可跳转语义。
        final seekable = lyrics.lines.any(
          (line) => line.timestampMs > BigInt.zero,
        );
        // 行列表只在歌词/歌曲对象更换时重建（进度刷新不重挂整列）。
        if (!identical(lyrics, _lastLyrics) || !identical(song, _lastSong)) {
          _lastLyrics = lyrics;
          _lastSong = song;
          _lineKeys = [
            for (var i = 0; i < lyrics.lines.length; i++) GlobalKey(),
          ];
          _active = -1;
        }
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              // 无视觉走带时钟：插值位置 → 当前行序号（歌词更换时重建）。
              Positioned(
                left: 0,
                top: 0,
                width: 0,
                height: 0,
                child: _LyricTicker(
                  key: ValueKey(lyrics),
                  model: model,
                  lines: lyrics.lines,
                  onIndexChanged: _onActiveLineChanged,
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      key: _viewportKey,
                      controller: _controller,
                      padding: const EdgeInsets.symmetric(
                        horizontal: VxSpacing.lg,
                        vertical: VxSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!seekable)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '本曲歌词无时间戳，不支持点击跳转',
                                style: VxTypography.caption.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (var i = 0; i < lyrics.lines.length; i++)
                            _LyricLine(
                              key: _lineKeys[i],
                              line: lyrics.lines[i],
                              translation:
                                  (i == _active &&
                                      (lyrics.translation?.isNotEmpty ?? false))
                                  ? lyrics.translation
                                  : null,
                              distance: (_active - i).abs(),
                              currentFontSize: _currentFontSize,
                              lineFontSize: _lineFontSize,
                              translationFontSize: _translationFontSize,
                              compact: widget.compact,
                              onTap: seekable
                                  ? () => _seekTo(lyrics.lines[i].timestampMs)
                                  : null,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 点击歌词行 → 真实 seek（FfiCommand.seekMs）。
  void _seekTo(BigInt timestampMs) {
    final ms = timestampMs.toInt();
    widget.model.seekMs(BigInt.from(ms < 0 ? 0 : ms));
  }
}

/// 插值走带时钟（无视觉）：LivePlayback 500ms 插值位置 → 当前行序号回调。
/// 仅在序号变化时回调，不触发面板按 4Hz 进度事件整列重建；
/// 位置订阅 [AppModel.playbackTick]（纯进度节流通知）。
class _LyricTicker extends StatelessWidget {
  const _LyricTicker({
    super.key,
    required this.model,
    required this.lines,
    required this.onIndexChanged,
  });

  final AppModel model;
  final List<bridge.LyricLineDto> lines;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model.playbackTick,
      builder: (context, _) {
        final playback = model.state.playback;
        return LivePlayback(
          positionMs: playback.positionMs,
          durationMs: playback.durationMs,
          playing: playback.state == 'playing',
          builder: (context, position, duration) => _IndexReporter(
            position: position,
            timestamps: [
              for (final line in lines)
                Duration(milliseconds: line.timestampMs.toInt()),
            ],
            onIndexChanged: onIndexChanged,
          ),
        );
      },
    );
  }
}

class _IndexReporter extends StatefulWidget {
  const _IndexReporter({
    required this.position,
    required this.timestamps,
    required this.onIndexChanged,
  });

  final Duration position;
  final List<Duration> timestamps;
  final ValueChanged<int> onIndexChanged;

  @override
  State<_IndexReporter> createState() => _IndexReporterState();
}

class _IndexReporterState extends State<_IndexReporter> {
  int _last = -2;

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant _IndexReporter old) {
    super.didUpdateWidget(old);
    _report();
  }

  void _report() {
    final index = _computeIndex(widget.position, widget.timestamps);
    if (index == _last) return;
    _last = index;
    // build/didUpdateWidget 期间回调 → 延迟到帧末再 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onIndexChanged(index);
    });
  }

  /// 二分查找最后一个 timestamp <= position 的行；position 在首行之前 → -1。
  static int _computeIndex(Duration position, List<Duration> timestamps) {
    var lo = 0;
    var hi = timestamps.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (timestamps[mid] <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 未播放 / 无歌词状态（§5.2：如实说明，不伪造重试入口）。
class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;

  /// 可选操作（P2-17：歌词空态的「重新获取歌词」入口）。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: VxTypography.title.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: VxTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// 歌词手动重取按钮（P2-17）：歌词面板空态与全屏播放页无歌词单列布局共用
/// （P2-18 交叉：单列下 LyricsPanel 不渲染，重取入口必须独立于面板存在）。
///
/// - 在途态禁用按钮防重复请求；切歌即复位（Rust 侧 prepare() 代次会丢弃
///   旧请求，本地在途态随之失效）；
/// - 成功信号：歌词内容（行数或首行文本）相对发起时快照发生变化；
/// - 失败信号：后端 Notification「歌词加载失败」进入 lastNotification；
/// - 12s 超时兜底：后端无任何事件返回时复位并提示，防永久卡在在途态。
class LyricsRetryButton extends StatefulWidget {
  const LyricsRetryButton({super.key, required this.model, required this.song});

  final AppModel model;
  final bridge.SongDto song;

  @override
  State<LyricsRetryButton> createState() => _LyricsRetryButtonState();
}

class _LyricsRetryButtonState extends State<LyricsRetryButton> {
  static const _timeout = Duration(seconds: 12);

  bool _inFlight = false;
  bool _failed = false;
  Timer? _timer;

  /// 发起请求时的歌词内容快照（成功回填的判别基准）。
  int _snapshotLength = 0;
  String? _snapshotFirstText;

  /// 发起请求时的通知快照（失败通知的判别基准）。
  String? _notificationSeen;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModelChanged);
  }

  @override
  void didUpdateWidget(covariant LyricsRetryButton old) {
    super.didUpdateWidget(old);
    if (!identical(widget.song, old.song) || widget.model != old.model) {
      old.model.removeListener(_onModelChanged);
      widget.model.addListener(_onModelChanged);
      _idle();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModelChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _idle() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _inFlight = false;
      _failed = false;
    });
  }

  void _start() {
    if (_inFlight) return;
    setState(() {
      _inFlight = true;
      _failed = false;
    });
    final lines = widget.model.state.lyrics.lines;
    _snapshotLength = lines.length;
    _snapshotFirstText = lines.isEmpty ? null : lines.first.text;
    _notificationSeen = widget.model.lastNotification;
    _timer = Timer(_timeout, () {
      if (mounted && _inFlight) {
        setState(() {
          _inFlight = false;
          _failed = true;
        });
      }
    });
    widget.model.loadLyrics(widget.song).catchError((Object _) {
      // dispatch 本身失败（FFI 未就绪等）：按失败复位，不等事件。
      if (mounted && _inFlight) {
        setState(() {
          _inFlight = false;
          _failed = true;
        });
      }
    });
  }

  void _onModelChanged() {
    if (!_inFlight || !mounted) return;
    final lines = widget.model.state.lyrics.lines;
    final changed =
        lines.length != _snapshotLength ||
        (lines.isNotEmpty &&
            _snapshotLength > 0 &&
            lines.first.text != _snapshotFirstText);
    final notification = widget.model.lastNotification;
    final failedNow =
        notification != null &&
        notification != _notificationSeen &&
        notification.contains('歌词加载失败');
    if (!changed && !failedNow) return;
    _timer?.cancel();
    setState(() {
      _inFlight = false;
      _failed = failedNow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _inFlight ? null : _start,
          icon: _inFlight
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(_inFlight ? '获取中…' : '重新获取歌词'),
        ),
        if (_failed)
          Text(
            '暂未取到歌词，可再次尝试',
            style: VxTypography.caption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// 单行歌词：有时间戳时点击 seek（null = 无时间戳门槛，不挂手势）；
/// 当前行放大加粗，按距离降透明。
class _LyricLine extends StatelessWidget {
  const _LyricLine({
    super.key,
    required this.line,
    required this.translation,
    required this.distance,
    required this.currentFontSize,
    required this.lineFontSize,
    required this.translationFontSize,
    required this.compact,
    required this.onTap,
  });

  final bridge.LyricLineDto line;
  final String? translation;
  final int distance;
  final double currentFontSize;
  final double lineFontSize;
  final double translationFontSize;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disable = MediaQuery.disableAnimationsOf(context);
    final duration = disable ? Duration.zero : VxMotion.lyricLine;
    final current = distance == 0;
    // 距离越远越透明（§5.2「更远歌词降低透明度」）。
    final opacity = switch (distance) {
      0 => 1.0,
      1 => 0.82,
      2 => 0.58,
      _ => 0.4,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9, horizontal: 2),
        child: AnimatedOpacity(
          duration: duration,
          opacity: opacity,
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(
              fontSize: current ? currentFontSize : lineFontSize,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              height: 1.4,
              color: scheme.onSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.text),
                // 翻译行（15-17px）：后端为整段/当前行译文，仅在当前行下展示。
                if (translation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      translation!,
                      style: TextStyle(
                        fontSize: translationFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
