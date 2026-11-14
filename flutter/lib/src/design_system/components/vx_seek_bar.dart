/// VxSeekBar：进度条与时间显示（§3.5 / 概念稿 `.seek`、`.seekbar`）。
///
/// - 轨道 4px 圆头，激活段强调色（概念稿 31% 状态即此形态）；
/// - `value == null` 表示时长未知：不渲染进度、时间显示 `--:--`
///   （禁止伪造 00:00 进度，Phase 0 F1 的组件层规则）；
/// - 本组件为静态视觉：拖动 seek 在 Phase 3 播放控制接入。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart' show VxPalette;
import '../voicefox_theme.dart' show vxMonoStyle;
import 'vx_hover.dart';

/// 把时长格式化为 `mm:ss`（超一小时 `h:mm:ss`）；null → `--:--`。
String vxFormatDuration(Duration? duration) {
  if (duration == null) return '--:--';
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }
  return '${minutes.toString().padLeft(2, '0')}:$ss';
}

/// 等宽时间标签（tabular figures）。
class VxTimeLabel extends StatelessWidget {
  const VxTimeLabel(this.duration, {super.key});

  /// 时长；null 显示 `--:--`。
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      vxFormatDuration(duration),
      style: vxMonoStyle(scheme.onSurfaceVariant, fontSize: 11),
    );
  }
}

/// 进度条（静态视觉）。
class VxSeekBar extends StatelessWidget {
  const VxSeekBar({super.key, this.value});

  /// 进度 0..1；null 表示时长未知（不显示进度）。
  final double? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // B3：轨底色随主题（VxPalette 扩展下发，非亮暗三元）。
    final trackColor = VxPalette.of(context).seekTrack;
    final v = value?.clamp(0.0, 1.0);

    return VxHoverBuilder(
      builder: (context, hovering) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final thumbLeft = v == null
              ? 0.0
              : (v * width - 6).clamp(
                  0.0,
                  (width - 12).clamp(0.0, double.infinity),
                );
          return SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 5,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (v != null && v > 0)
                  Positioned(
                    left: 0,
                    top: 5,
                    width: v * width,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                if (hovering && v != null)
                  Positioned(
                    left: thumbLeft,
                    top: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "时间 + 进度条 + 时间"标准行（概念稿 `.seek`）。
class VxSeekRow extends StatelessWidget {
  const VxSeekRow({super.key, required this.position, required this.duration});

  /// 当前位置；null（含时长未知）显示 `--:--`。
  final Duration? position;

  /// 总时长；null 显示 `--:--` 且进度条为空。
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final unknown = duration == null || duration!.inMilliseconds <= 0;
    final fraction = unknown || position == null
        ? null
        : (position!.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      children: [
        VxTimeLabel(unknown ? null : position),
        const SizedBox(width: 10),
        Expanded(child: VxSeekBar(value: fraction)),
        const SizedBox(width: 10),
        VxTimeLabel(duration),
      ],
    );
  }
}
