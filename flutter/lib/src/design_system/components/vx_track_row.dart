/// TrackRow：全应用统一的单行歌曲（§7.1 TrackTable / TrackRow）。
///
/// - 三种密度：紧凑 50 / 标准 58 / 舒适 66（Phase 1 任务 4）；
/// - hover 底色 + 悬停操作（播放 / 加入队列 / 收藏 / 更多，§4.3）；
/// - 当前播放态：强调色底 10% + 标题强调色 + 静态均衡条；
/// - 缺封面用渐变 + 首字母占位（不用灰音符）；
/// - 长标题 / 长歌手 / 长专辑一律单行省略；
/// - 时长缺失显示 `--:--`（§3.5：禁止伪造 00:00 进度）。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../voicefox_theme.dart' show vxMonoStyle;
import 'vx_cover_fallback.dart';
import 'vx_hover.dart';
import 'vx_seek_bar.dart' show vxFormatDuration;

/// TrackRow 密度。
enum VxTrackRowDensity {
  /// 紧凑 50px。
  compact,

  /// 标准 58px。
  standard,

  /// 舒适 66px。
  comfortable,
}

/// 密度 → 尺寸。
extension VxTrackRowDensityX on VxTrackRowDensity {
  /// 行高。
  double get height => switch (this) {
    VxTrackRowDensity.compact => VxDensities.trackRowCompact,
    VxTrackRowDensity.standard => VxDensities.trackRowStandard,
    VxTrackRowDensity.comfortable => VxDensities.trackRowComfortable,
  };

  /// 行内封面边长。
  double get coverSize => switch (this) {
    VxTrackRowDensity.compact => 34,
    VxTrackRowDensity.standard => 40,
    VxTrackRowDensity.comfortable => 44,
  };
}

/// 单行歌曲。纯展示组件：数据全部来自构造器，回调可空（空则隐藏）。
class VxTrackRow extends StatelessWidget {
  const VxTrackRow({
    super.key,
    required this.title,
    this.artist,
    this.album,
    this.source,
    this.duration,
    this.index,
    this.density = VxTrackRowDensity.standard,
    this.isPlaying = false,
    this.isLiked = false,
    this.cover,
    this.showIndex = true,
    this.showAlbum = true,
    this.onTap,
    this.onLongPressStart,
    this.onPlay,
    this.onAddToQueue,
    this.onLike,
    this.onMore,
  });

  /// 歌曲名（必填；长标题单行省略）。
  final String title;

  /// 歌手 / 副标题。
  final String? artist;

  /// 专辑名（第二列）。
  final String? album;

  /// 音源标签（如 网易云 / 本地音乐）。
  final String? source;

  /// 时长；null 显示 `--:--`。
  final Duration? duration;

  /// 序号（1 起）；null 显示空序号位。
  final int? index;

  /// 行密度。
  final VxTrackRowDensity density;

  /// 当前播放态（持续高亮）。
  final bool isPlaying;

  /// 已收藏态。
  final bool isLiked;

  /// 自定义封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 是否显示序号列。
  final bool showIndex;

  /// 是否显示专辑列。
  final bool showAlbum;

  /// 单击整行（§9：单击只选中，不播放）。
  final VoidCallback? onTap;

  /// 长按整行（Phase 7 触屏语义：hover 操作在触屏的可达替代——长按
  /// 菜单聚合 播放/加入队列/收藏/下载 等真实命令，见 showSongMenu）。
  final GestureLongPressStartCallback? onLongPressStart;

  /// 悬停操作：播放。
  final VoidCallback? onPlay;

  /// 悬停操作：加入队列。
  final VoidCallback? onAddToQueue;

  /// 悬停操作：收藏 / 取消收藏。
  final VoidCallback? onLike;

  /// 悬停操作：更多。
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final callbacks = [
      onPlay,
      onAddToQueue,
      onLike,
      onMore,
    ].whereType<VoidCallback>().length;
    final hasActions = callbacks > 0;
    final normalBg = isPlaying
        ? scheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final titleColor = isPlaying ? scheme.primary : scheme.onSurface;

    return VxHoverBuilder(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      builder: (context, hovering) => AnimatedContainer(
        duration: VxMotion.hoverFade,
        curve: VxMotion.standard,
        height: density.height,
        color: hovering ? scheme.surfaceContainerHighest : normalBg,
        padding: const EdgeInsets.symmetric(horizontal: VxSpacing.md),
        // 窄视口判定按行自身宽度（LayoutBuilder）：桌面分栏里的行可能
        // 小于窗口宽。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            return Row(
              children: [
                if (showIndex)
                  SizedBox(
                    width: 28,
                    child: Text(
                      index?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: vxMonoStyle(scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(width: VxSpacing.sm),
                SizedBox(
                  width: density.coverSize,
                  height: density.coverSize,
                  child: cover ?? VxCoverFallback(title: title),
                ),
                const SizedBox(width: VxSpacing.md),
                if (isPlaying) ...[
                  _StaticEqualizerBars(color: scheme.primary),
                  const SizedBox(width: VxSpacing.sm),
                ],
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VxTypography.titleSm.copyWith(color: titleColor),
                      ),
                      if (artist != null)
                        Text(
                          artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VxTypography.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showAlbum && album != null) ...[
                  const SizedBox(width: VxSpacing.lg),
                  Expanded(
                    flex: 2,
                    child: Text(
                      album!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VxTypography.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (source != null) ...[
                  const SizedBox(width: VxSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      source!,
                      style: VxTypography.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: VxSpacing.lg),
                SizedBox(
                  width: 52,
                  child: Text(
                    vxFormatDuration(duration),
                    textAlign: TextAlign.right,
                    style: vxMonoStyle(scheme.onSurfaceVariant),
                  ),
                ),
                if (hasActions)
                  AnimatedOpacity(
                    opacity: hovering ? 1 : 0,
                    duration: VxMotion.hoverFade,
                    child: SizedBox(
                      // 固定宽度，hover 显隐不挤压时长列。
                      // M3 IconButton 实际最小宽 40（tooltip + constraints 下
                      // compact 密度也不低于 40），Phase 1 按 30 预留导致行尾
                      // 操作 hover 时溢出被视口裁剪（Phase 5 实测修复）。
                      // 窄视口（<480，手机档 360-430）不预留：触屏无 hover，
                      // 长按菜单是真实替代（§9），固定预留 4×40 必溢出行尾
                      // （Phase 3 曲库窄视口实测）。
                      width: narrow ? 0.0 : callbacks * 40.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onPlay != null)
                            _rowIcon(context, Icons.play_arrow, '播放', onPlay),
                          if (onAddToQueue != null)
                            _rowIcon(
                              context,
                              Icons.queue_music,
                              '加入队列',
                              onAddToQueue,
                            ),
                          if (onLike != null)
                            _rowIcon(
                              context,
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              '收藏',
                              onLike,
                            ),
                          if (onMore != null)
                            _rowIcon(context, Icons.more_vert, '更多', onMore),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rowIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      icon: Icon(icon, size: 18),
    );
  }
}

/// 当前播放标识：静态三段均衡条（Phase 3 接入真实播放后再决定是否加动效）。
class _StaticEqualizerBars extends StatelessWidget {
  const _StaticEqualizerBars({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final bars = [6.0, 12.0, 8.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in bars) ...[
          Container(
            width: 3,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }
}
