// Voicefox playbar: Spotify 桌面式底部播放条。
// Newly written for voicefox, not vendored. 取代 vendored Playbar：
// 单行三区布局（左曲目 / 中传输+插值进度 / 右队列音量），数据直接读
// AppModel（真源），进度用 LivePlayback 逐帧插值（vendored 版是
// 200ms 节流的 StreamBuilder，走带肉眼可见跳动）。
import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../theme/typography.dart' show monoStyle;
import '../widgets/cover_image.dart';
import '../widgets/live_progress.dart';
import 'myune_player_page.dart';

String _fmt(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${two(d.inSeconds.remainder(60))}';
}

class VoicefoxPlaybar extends StatelessWidget {
  const VoicefoxPlaybar({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final playback = model.state.playback;
        final song = playback.song;
        final playing = playback.state == 'playing';
        final mono = monoStyle(context, Theme.of(context).textTheme.bodySmall);
        return Container(
          height: 76,
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              // ── 左：封面 + 曲目信息（固定宽，点击进全屏播放页） ──
              SizedBox(
                width: 240,
                child: Row(
                  children: [
                    _Cover(model: model, song: song),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song?.name ?? '未在播放',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            song?.singer ?? '从搜索或曲库挑一首开始',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── 中：传输按钮 + 插值进度 ──
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '上一首',
                          iconSize: 22,
                          onPressed: model.previous,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        _PlayButton(playing: playing, model: model),
                        IconButton(
                          tooltip: '下一首',
                          iconSize: 22,
                          onPressed: model.next,
                          icon: const Icon(Icons.skip_next),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          RepaintBoundary(
                            child: LivePlayback(
                              positionMs: playback.positionMs,
                              durationMs: playback.durationMs,
                              playing: playing,
                              builder: (context, position, duration) => Text(
                                _fmt(position),
                                style: mono,
                              ),
                            ),
                          ),
                          Expanded(
                            child: LivePlayback(
                              positionMs: playback.positionMs,
                              durationMs: playback.durationMs,
                              playing: playing,
                              builder: (context, position, duration) =>
                                  _SeekSlider(
                                model: model,
                                position: position,
                                duration: duration,
                              ),
                            ),
                          ),
                          Text(
                            _fmt(Duration(
                                milliseconds:
                                    playback.durationMs.toInt())),
                            style: mono,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── 右：播放模式 / 音量 / 队列 ──
              _RightControls(model: model),
            ],
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto? song;

  const _Cover({required this.model, required this.song});

  @override
  Widget build(BuildContext context) {
    final hasSong = song != null;
    return GestureDetector(
      onTap: hasSong
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MyunePlayerPage(model: model),
                ),
              )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: hasSong
              ? CoverImage(url: song!.coverUrl, size: 48, radius: 6)
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final AppModel model;

  const _PlayButton({required this.playing, required this.model});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton.filled(
          tooltip: playing ? '暂停' : '播放',
          style: IconButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          onPressed: model.toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              key: ValueKey(playing),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

/// 进度条：拖动时脱离插值（拖动会话内显示手值），松手 seek。
class _SeekSlider extends StatefulWidget {
  final AppModel model;
  final Duration position;
  final Duration duration;

  const _SeekSlider({
    required this.model,
    required this.position,
    required this.duration,
  });

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.duration.inMilliseconds;
    final value = _dragValue ??
        (total > 0 ? widget.position.inMilliseconds / total : 0.0);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      ),
      child: Slider(
        value: value.clamp(0.0, 1.0),
        max: 1,
        activeColor: scheme.primary,
        inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.3),
        onChanged: total > 0
            ? (v) => setState(() => _dragValue = v)
            : null,
        onChangeEnd: (v) {
          widget.model.seekMs(BigInt.from((total * v).round()));
          setState(() => _dragValue = null);
        },
      ),
    );
  }
}

class _RightControls extends StatelessWidget {
  final AppModel model;

  const _RightControls({required this.model});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = model.config?.playMode ?? 'list-loop';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: _modeLabel(mode),
          iconSize: 20,
          color: scheme.onSurfaceVariant,
          onPressed: () {
            const cycle = ['none', 'list-loop', 'single-loop', 'random'];
            final next = cycle[(cycle.indexOf(mode) + 1) % cycle.length];
            model.updateConfig((config) => config.copyWith(playMode: next));
          },
          icon: Icon(_modeIcon(mode)),
        ),
        _VolumeControl(model: model),
        IconButton(
          tooltip: '播放队列',
          iconSize: 20,
          color: scheme.onSurfaceVariant,
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          icon: const Icon(Icons.queue_music_outlined),
        ),
      ],
    );
  }

  String _modeLabel(String mode) => switch (mode) {
        'none' => '顺序播放',
        'single-loop' => '单曲循环',
        'random' => '随机播放',
        _ => '列表循环',
      };

  IconData _modeIcon(String mode) => switch (mode) {
        'none' => Icons.arrow_right_alt,
        'single-loop' => Icons.repeat_one,
        'random' => Icons.shuffle,
        _ => Icons.repeat,
      };
}

/// 音量：喇叭图标 + 内联滑条（悬停展开，Spotify 式）。
class _VolumeControl extends StatefulWidget {
  final AppModel model;

  const _VolumeControl({required this.model});

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
                color: scheme.onSurfaceVariant,
                onPressed: () => model.setVolume(volume == 0 ? 100 : 0),
                icon: Icon(switch (volume) {
                  0.0 => Icons.volume_off,
                  < 0.5 => Icons.volume_down,
                  _ => Icons.volume_up,
                }),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: _hover ? 88 : 0,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
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
            ],
          ),
        );
      },
    );
  }
}
