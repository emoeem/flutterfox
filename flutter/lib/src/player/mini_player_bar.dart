/// Phase 7 移动端迷你播放栏（手机底部导航上方 / 平板底部常驻）。
///
/// 规格：
/// - 高度 64，顶部 2px 进度线（与桌面 PlayerBar 同语义）；
/// - 左：封面 44；中：歌名/歌手单行；右：播放暂停 / 下一首；
/// - 点整栏经 `nowPlayingRequest` 打开全屏播放页（与桌面点封面同一总线，
///   shell 消费后置回 false，防双重控制：全屏打开时本栏随壳隐藏）；
/// - 控制接 AppModel 真实命令（toggle/next），无伪数据；
/// - 进度插值复用 [LivePlayback]，不复制插值逻辑；时长未知不画进度
///   （P0-F1：禁止伪造 00:00 进度）。
///
/// 显隐由壳决定（无歌不进树），本组件只负责有歌时的渲染。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../widgets/cover_image.dart';
import '../widgets/live_progress.dart';

/// 迷你播放栏。
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.model, this.onOpenNowPlaying});

  final AppModel model;

  /// 点整栏打开全屏播放页；缺省发 `nowPlayingRequest`（导航总线），
  /// 壳（MobileShell/TabletShell）监听消费，与页面发起路径同源。
  final VoidCallback? onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final playback = model.state.playback;
        final song = playback.song;
        final playing = playback.state == 'playing';
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap:
              onOpenNowPlaying ?? () => nowPlayingRequest.value = true,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              ),
            ),
            child: Stack(
              children: [
                // 顶部 2px 进度线：复用 LivePlayback 插值（不复制走带逻辑）。
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 2,
                  child: RepaintBoundary(
                    child: LivePlayback(
                      positionMs: playback.positionMs,
                      durationMs: playback.durationMs,
                      playing: playing,
                      builder: (context, position, duration) {
                        final total = duration.inMilliseconds;
                        final fraction = total > 0
                            ? (position.inMilliseconds / total)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: fraction <= 0
                              ? null
                              : FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: fraction,
                                  child: const ColoredBox(
                                    color: VxColors.accent,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(VxRadius.sm),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: song != null
                              ? CoverImage(
                                  url: song.coverUrl,
                                  size: 44,
                                  radius: VxRadius.sm,
                                )
                              : ColoredBox(
                                  color: scheme.surfaceContainerHigh,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 20,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song?.name ?? '未在播放',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VxTypography.titleSm
                                  .copyWith(color: scheme.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song == null
                                  ? ''
                                  : '${song.singer} · ${song.source}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VxTypography.caption.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 控制：真实命令（model.toggle / model.next）。
                      IconButton(
                        tooltip: playing ? '暂停' : '播放',
                        onPressed: model.toggle,
                        icon: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          size: 22,
                          color: scheme.onSurface,
                        ),
                      ),
                      IconButton(
                        tooltip: '下一首',
                        onPressed: model.next,
                        icon: Icon(
                          Icons.skip_next,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
