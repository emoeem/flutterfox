/// VxPlayerControls：静态传输控制行（§3.5 / 概念稿 `.controls`、`.play`）。
///
/// 顺序固定：随机 - 上一首 - 播放/暂停 - 下一首 - 循环；
/// 播放/暂停为 34px 主色圆钮（概念稿：底为主文本色、图标为深色），
/// 随机 / 循环开启时强调色。本组件为静态视觉，真实命令在 Phase 3 接入。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 传输控制行。
class VxPlayerControls extends StatelessWidget {
  const VxPlayerControls({
    super.key,
    this.isPlaying = false,
    this.shuffleOn = false,
    this.repeatOn = false,
    this.enabled = true,
    this.gap = 18,
    this.onShuffle,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.onRepeat,
  });

  /// 当前是否播放中（true 显示暂停图标）。
  final bool isPlaying;

  /// 随机播放开启态。
  final bool shuffleOn;

  /// 循环播放开启态。
  final bool repeatOn;

  /// false 时全部按钮禁用（无歌曲时保持布局稳定，§3.5）。
  final bool enabled;

  /// 按钮间距（概念稿 19px，默认 18）。
  final double gap;

  /// 随机播放回调。
  final VoidCallback? onShuffle;

  /// 上一首回调。
  final VoidCallback? onPrevious;

  /// 播放/暂停回调。
  final VoidCallback? onPlayPause;

  /// 下一首回调。
  final VoidCallback? onNext;

  /// 循环播放回调。
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final playIconColor = dark ? VxColors.onPlayIcon : VxLightColors.onPlayIcon;

    Widget ctrl(
      IconData icon,
      String tooltip,
      VoidCallback? onPressed, {
      bool active = false,
    }) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        icon: Icon(
          icon,
          size: 20,
          color: enabled
              ? (active ? scheme.primary : scheme.onSurfaceVariant)
              : scheme.onSurface.withValues(alpha: 0.38),
        ),
      );
    }

    // Wrap：桌面一行放下时与 Row 视觉一致；手机窄宽（全屏页 46% 封面列）
    // 自动换行不溢出（Phase 7 触屏适配）。
    return Wrap(
      spacing: gap,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ctrl(Icons.shuffle, '随机播放', onShuffle, active: shuffleOn),
        ctrl(Icons.skip_previous, '上一首', onPrevious),
        Tooltip(
          message: isPlaying ? '暂停' : '播放',
          child: InkWell(
            onTap: enabled ? onPlayPause : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? scheme.onSurface : scheme.surfaceContainerHigh,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 18,
                color: enabled
                    ? playIconColor
                    : scheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
        ctrl(Icons.skip_next, '下一首', onNext),
        ctrl(Icons.repeat, '循环播放', onRepeat, active: repeatOn),
      ],
    );
  }
}
