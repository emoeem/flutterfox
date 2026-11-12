/// VxPlayerControls：静态传输控制行（§3.5 / 概念稿 `.controls`、`.play`）。
///
/// 顺序固定：随机 - 上一首 - 播放/暂停 - 下一首 - 循环；
/// 播放/暂停为 34px 主色圆钮（概念稿：底为主文本色、图标为深色），
/// 随机 / 循环开启时强调色。本组件为静态视觉，真实命令在 Phase 3 接入。
///
/// 触点分档（§11.2 Phase 6）：触屏平台触点 48dp，桌面保持 34dp 渲染
/// 零变化。默认跟随 [isTouchPlatform]（dart:io 判定，宿主测试恒 false），
/// 测试可经 [touchTargets] 显式注入。
library;

import 'package:flutter/material.dart';

import '../../shell/responsive_shell.dart';
import '../design_tokens.dart';

/// 传输控制行。
class VxPlayerControls extends StatelessWidget {
  const VxPlayerControls({
    super.key,
    this.isPlaying = false,
    this.shuffleOn = false,
    this.repeatOn = false,
    this.repeatSingle = false,
    this.enabled = true,
    this.gap = 18,
    this.touchTargets,
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

  /// 循环播放开启态（list-loop 或 single-loop 任一档，图标主色）。
  final bool repeatOn;

  /// true = 当前是单曲循环档：图标 repeat_one、tooltip「单曲循环」。
  /// §8.3/QA 2026-11-11：两档循环此前共用 Icons.repeat 且同为 primary 色，
  /// 截图与读屏均无法区分第 1/2 档——单曲循环档必须有独立视觉态。
  final bool repeatSingle;

  /// false 时全部按钮禁用（无歌曲时保持布局稳定，§3.5）。
  final bool enabled;

  /// 按钮间距（概念稿 19px，默认 18）。
  final double gap;

  /// 触点 48dp 分档（§11.2）：null 跟随 [isTouchPlatform]；显式注入
  /// 仅测试用（先例 TouchShell.touchPlatformOverride）。
  final bool? touchTargets;

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
    // 触点分档（§11.2）：触屏 48dp；桌面保持 34 渲染零变化。
    final target = (touchTargets ?? isTouchPlatform) ? 48.0 : 34.0;

    Widget ctrl(
      IconData icon,
      String tooltip,
      VoidCallback? onPressed, {
      bool active = false,
    }) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        // compact 密度会把约束收缩 8dp（48→40），触屏 48dp 档还原标准密度。
        visualDensity: target > 34
            ? VisualDensity.standard
            : VisualDensity.compact,
        constraints: BoxConstraints(minWidth: target, minHeight: target),
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
              width: target,
              height: target,
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
        // 循环档视觉区分（§8.3）：list-loop = repeat 图标、single-loop =
        // repeat_one 图标，两者激活时同为主色；none = 灰色中性。
        ctrl(
          repeatSingle ? Icons.repeat_one : Icons.repeat,
          repeatSingle ? '单曲循环' : (repeatOn ? '列表循环' : '循环播放'),
          onRepeat,
          active: repeatOn,
        ),
      ],
    );
  }
}
