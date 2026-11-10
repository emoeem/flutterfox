/// Phase 2 全局 PlayerBar（计划书 §3.5，应用唯一常驻播放栏）。
///
/// 规格：
/// - 高度 92px，顶部 2px 进度线；
/// - 左区 280–340：封面 56 + 歌名/歌手 + 收藏；点封面进入全屏播放页
///   （Phase 3 NowPlayingPage，Shell 统一打开并隐藏本栏防双重控制）；
/// - 中区弹性：随机/上一首/播放暂停/下一首/循环 + 时间与可拖动进度；
/// - 右区 250–320：音量 / 输出 / 歌词 / 队列 / 更多；窄窗口逐级收缩，
///   保证任何宽度不横向溢出（Phase 0 F2/F3 的布局修复点）。
///
/// 数据只读 AppModel（唯一真源，进度经共用 LiveSeekRow 插值 + 真实 seek，
/// 时长读不到显示 `--:--`，P0-F1）。传输控制复用 Phase 1 VxPlayerControls。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/components/vx_player_controls.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/live_progress.dart';
import 'progress_control.dart';

/// 全局播放栏。
class PlayerBar extends StatefulWidget {
  const PlayerBar({
    super.key,
    required this.model,
    this.onOpenNowPlaying,
    this.onOpenLyrics,
    this.onOpenQueue,
  });

  final AppModel model;

  /// 点封面进入全屏播放页（§9 交互行为）。
  final VoidCallback? onOpenNowPlaying;

  /// 右区歌词按钮：打开右栏歌词 Tab。
  final VoidCallback? onOpenLyrics;

  /// 右区队列按钮：打开右栏队列 Tab。
  final VoidCallback? onOpenQueue;

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  /// 拖动进度会话内的临时值（0..1）；null = 未在拖动。
  /// 值来自共用 LiveSeekRow 的 onDragPreview（会话开始/更新/结束）。
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final playback = model.state.playback;
        final song = playback.song;
        final playing = playback.state == 'playing';
        return LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            // 右区逐级收缩：<1060 收起 输出/更多 与音量滑条；<880 收起音量；
            // <760 同时收起左区收藏按钮。行内内容自适应，不产生横向溢出。
            final fullRight = barWidth >= 1060;
            final midRight = barWidth >= 880;
            final compactLeft = barWidth < 760;
            return Container(
              height: 92,
              // P1-09：Chrome 底色/分隔线随主题亮暗取 token。
              decoration: BoxDecoration(
                color: VxChrome.surface1(Theme.of(context).brightness),
                border: Border(
                  top: BorderSide(
                    color: VxChrome.divider(Theme.of(context).brightness),
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // 顶部 2px 进度线（时长未知时不显示进度，只留轨道）。
                  // 订阅 playbackTick：4Hz 进度只重建本线，不重建 PlayerBar。
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 2,
                    child: RepaintBoundary(
                      child: ListenableBuilder(
                        listenable: model.playbackTick,
                        builder: (context, _) {
                          final playback = model.state.playback;
                          return LivePlayback(
                            positionMs: playback.positionMs,
                            durationMs: playback.durationMs,
                            playing: playing,
                            builder: (context, position, duration) {
                              final total = duration.inMilliseconds;
                              final fraction =
                                  _dragFraction ??
                                  (total > 0
                                      ? (position.inMilliseconds / total).clamp(
                                          0.0,
                                          1.0,
                                        )
                                      : null);
                              return _ProgressLine(fraction: fraction);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
                    child: Row(
                      children: [
                        // ── 左区：封面 + 曲目信息 + 收藏 ──
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compactLeft ? 260 : 340,
                            ),
                            child: _TrackInfo(
                              model: model,
                              song: song,
                              showFavorite: !compactLeft,
                              onOpenNowPlaying: widget.onOpenNowPlaying,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ── 中区：传输控制 + 进度（插值/seek 由 LiveSeekRow 承担）──
                        Expanded(
                          child: RepaintBoundary(
                            child: _CenterTransport(
                              model: model,
                              playing: playing,
                              compact: barWidth < 700,
                              onDragPreview: (fraction) =>
                                  setState(() => _dragFraction = fraction),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ── 右区：音量 / 输出 / 歌词 / 队列 / 更多 ──
                        _RightZone(
                          model: model,
                          showOutputAndMore: fullRight,
                          showVolume: midRight,
                          onOpenLyrics: widget.onOpenLyrics,
                          onOpenQueue: widget.onOpenQueue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── 顶部 2px 进度线 ──────────────────────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? VxDarkSurface.seekTrack : VxLightColors.seekTrack;
    final v = fraction?.clamp(0.0, 1.0);
    return ColoredBox(
      color: track,
      child: v == null || v <= 0
          ? null
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: const ColoredBox(color: VxColors.accent),
            ),
    );
  }
}

// ── 左区 ────────────────────────────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({
    required this.model,
    required this.song,
    required this.showFavorite,
    required this.onOpenNowPlaying,
  });

  final AppModel model;
  final bridge.SongDto? song;
  final bool showFavorite;
  final VoidCallback? onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // song 为实例字段无法提升，先落局部变量。
    final s = song;
    final hasSong = s != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 封面 56：点击进入正在播放视图（§9 交互行为）。
        GestureDetector(
          onTap: hasSong ? onOpenNowPlaying : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VxRadius.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasSong
                  ? CoverImage(url: s.coverUrl, size: 56, radius: VxRadius.sm)
                  : ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: Icon(
                        Icons.music_note,
                        size: 24,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                s?.name ?? '未在播放',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                s == null ? '选择一首歌曲开始播放' : '${s.singer} · ${s.source}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showFavorite && hasSong)
          AnimatedBuilder(
            animation: model,
            builder: (context, _) {
              final favorite = model.isFavorite(s);
              return IconButton(
                // §8.5：收藏操作必须说明写入本地还是远端（favorite 只写本地曲库）。
                tooltip: favorite ? '取消收藏（本地曲库）' : '收藏（本地曲库）',
                visualDensity: VisualDensity.compact,
                onPressed: () => model.toggleFavorite(song!),
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: favorite ? scheme.primary : scheme.onSurfaceVariant,
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── 中区 ────────────────────────────────────────────────────────────────

class _CenterTransport extends StatelessWidget {
  const _CenterTransport({
    required this.model,
    required this.playing,
    required this.compact,
    required this.onDragPreview,
  });

  final AppModel model;
  final bool playing;

  /// 窄窗紧凑态：只保留 上一首/播放暂停/下一首（随机/循环本就是次级
  /// 控制，窄窗让位给进度与曲目信息）。
  final bool compact;

  /// 拖动会话回调（供顶部 2px 进度线同步预览）。
  final ValueChanged<double?> onDragPreview;

  @override
  Widget build(BuildContext context) {
    final playback = model.state.playback;
    final mode = model.config?.playMode ?? 'list-loop';
    final hasSong = playback.song != null;
    final configReady = model.config != null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (compact)
          _CompactTransport(model: model, playing: playing, enabled: hasSong)
        else
          VxPlayerControls(
            isPlaying: playing,
            shuffleOn: mode == 'random',
            repeatOn: mode == 'list-loop' || mode == 'single-loop',
            // §8.3：单曲循环档独立视觉态（repeat_one 图标 + tooltip）。
            repeatSingle: mode == 'single-loop',
            enabled: hasSong,
            onShuffle: configReady
                ? () => _setPlayMode(mode == 'random' ? 'list-loop' : 'random')
                : null,
            onPrevious: model.previous,
            onPlayPause: model.toggle,
            onNext: model.next,
            onRepeat: configReady ? () => _cycleRepeat(mode) : null,
          ),
        const SizedBox(height: 2),
        // 时间 + 可拖动进度条 + 时间：插值与真实 seek 在共用 LiveSeekRow
        // （内部订阅 playbackTick，4Hz 只重建本行）；时长读不到显示 --:--，
        // 不伪造 00:00。
        LiveSeekRow(
          model: model,
          playing: playing,
          onDragPreview: onDragPreview,
        ),
      ],
    );
  }

  void _setPlayMode(String next) {
    model.updateConfig((config) => config.copyWith(playMode: next));
  }

  void _cycleRepeat(String mode) {
    const cycle = ['list-loop', 'single-loop', 'none'];
    final start = cycle.indexOf(mode == 'random' ? 'list-loop' : mode);
    final next = cycle[((start < 0 ? 0 : start) + 1) % cycle.length];
    _setPlayMode(next);
  }
}

/// 窄窗紧凑传输控制：上一首 / 播放暂停 / 下一首，视觉与 VxPlayerControls
/// 一致（34px 主文本圆钮 + 图标按钮），只是收起次级的随机/循环。
class _CompactTransport extends StatelessWidget {
  const _CompactTransport({
    required this.model,
    required this.playing,
    required this.enabled,
  });

  final AppModel model;
  final bool playing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final playIconColor = dark ? VxColors.onPlayIcon : VxLightColors.onPlayIcon;
    Widget ctrl(IconData icon, String tooltip, VoidCallback? onPressed) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        icon: Icon(
          icon,
          size: 20,
          color: enabled
              ? scheme.onSurfaceVariant
              : scheme.onSurface.withValues(alpha: 0.38),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ctrl(Icons.skip_previous, '上一首', model.previous),
        const SizedBox(width: 10),
        Tooltip(
          message: playing ? '暂停' : '播放',
          child: InkWell(
            onTap: enabled ? model.toggle : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? scheme.onSurface : scheme.surfaceContainerHigh,
              ),
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                size: 18,
                color: enabled
                    ? playIconColor
                    : scheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ctrl(Icons.skip_next, '下一首', model.next),
      ],
    );
  }
}

// ── 右区 ────────────────────────────────────────────────────────────────

class _RightZone extends StatelessWidget {
  const _RightZone({
    required this.model,
    required this.showOutputAndMore,
    required this.showVolume,
    required this.onOpenLyrics,
    required this.onOpenQueue,
  });

  final AppModel model;
  final bool showOutputAndMore;
  final bool showVolume;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSong = model.state.playback.song != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showVolume) _VolumeControl(model: model),
        if (showOutputAndMore)
          // 输出设备：桌面后端当前未提供设备枚举 API（§5.4），
          // 如实显示「由系统管理」，不编造设备列表。
          PopupMenuButton<void>(
            tooltip: '音频输出',
            itemBuilder: (context) => const [
              PopupMenuItem<void>(
                enabled: false,
                child: Text('由系统管理（后端未提供设备枚举）'),
              ),
            ],
            icon: Icon(
              Icons.speaker_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
        IconButton(
          tooltip: '歌词',
          visualDensity: VisualDensity.compact,
          onPressed: onOpenLyrics,
          icon: Icon(
            Icons.lyrics_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: '队列',
          visualDensity: VisualDensity.compact,
          onPressed: onOpenQueue,
          icon: Icon(
            Icons.queue_music_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (showOutputAndMore)
          PopupMenuButton<String>(
            tooltip: '更多',
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'stop',
                enabled: hasSong,
                child: const Text('停止播放'),
              ),
            ],
            onSelected: (value) {
              if (value == 'stop') {
                model.dispatch(const bridge.FfiCommand.stop());
              }
            },
            icon: Icon(
              Icons.more_horiz,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// 音量：喇叭图标 + 悬停展开的内联滑条（跟随旧播放栏的成熟交互），
/// 数值读 AppModel.config.volume，经 setVolume 下发真实命令。
class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.model});

  final AppModel model;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _hover = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final model = widget.model;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final volume =
            (_dragValue ?? (model.config?.volume ?? 100).toDouble()) / 100;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: volume == 0 ? '取消静音' : '静音',
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                onPressed: () => model.setVolume(volume == 0 ? 100 : 0),
                icon: Icon(switch (volume) {
                  0.0 => Icons.volume_off,
                  < 0.5 => Icons.volume_down,
                  _ => Icons.volume_up,
                }),
              ),
              // ClipRect：0 宽折叠时滑条 thumb 会画出容器外，裁掉避免
              // 与相邻图标视觉重叠。
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  width: _hover ? 88 : 0,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: volume.clamp(0.0, 1.0),
                      onChanged: (v) {
                        setState(() => _dragValue = v);
                        model.setVolume((v * 100).round());
                      },
                      onChangeEnd: (v) => setState(() => _dragValue = null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
