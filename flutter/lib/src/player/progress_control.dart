/// Phase 3 进度控制（计划书 §3.5 / §5.1，PlayerBar 与全屏 NowPlayingPage 共用）。
///
/// - 位置经 LivePlayback 500ms 插值走带（§6.5：进度优先插值，不高频整页重建）；
/// - 点按 / 拖动真实 seek：AppModel.seekMs → FfiCommand.seekMs → Rust；
/// - 时长不可读（durationMs == 0）时：右侧时间显示 `--:--`、进度条无进度、
///   手势禁用（Phase 0 F1 规则，禁止伪造 00:00 进度）；
/// - 拖动会话内显示预览位置；[onDragPreview] 供调用方同步其它进度视觉
///   （如 PlayerBar 顶部 2px 进度线）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/components/vx_seek_bar.dart';
import '../widgets/live_progress.dart';

/// 「时间 + 可拖动进度条 + 时间」实时行。
class LiveSeekRow extends StatefulWidget {
  const LiveSeekRow({
    super.key,
    required this.model,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
    this.onDragPreview,
  });

  final AppModel model;

  /// AppModel 播放快照的位置（插值由本组件内部完成）。
  final BigInt positionMs;
  final BigInt durationMs;
  final bool playing;

  /// 拖动会话回调：拖动中传 0..1 预览值，结束时传 null（时长未知不回调）。
  final ValueChanged<double?>? onDragPreview;

  @override
  State<LiveSeekRow> createState() => _LiveSeekRowState();
}

class _LiveSeekRowState extends State<LiveSeekRow> {
  /// 拖动会话内的临时值（0..1）；null = 未在拖动。
  double? _drag;

  bool get _hasDuration => widget.durationMs > BigInt.zero;

  void _preview(double fraction) {
    setState(() => _drag = fraction.clamp(0.0, 1.0));
    widget.onDragPreview?.call(_drag);
  }

  void _commit(double? fraction) {
    final total = Duration(milliseconds: widget.durationMs.toInt());
    if (fraction != null && total.inMilliseconds > 0) {
      widget.model.seekMs(
        BigInt.from((total.inMilliseconds * fraction).round()),
      );
    }
    widget.onDragPreview?.call(null);
    setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    return LivePlayback(
      positionMs: widget.positionMs,
      durationMs: widget.durationMs,
      playing: widget.playing,
      builder: (context, position, duration) {
        final total = duration.inMilliseconds;
        final liveFraction = total > 0
            ? (position.inMilliseconds / total).clamp(0.0, 1.0)
            : null;
        final shown = _drag ?? liveFraction;
        final shownPosition = _drag != null && total > 0
            ? Duration(milliseconds: (total * _drag!).round())
            : position;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 16,
              child: Row(
                children: [
                  VxTimeLabel(shownPosition),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      children: [
                        VxSeekBar(value: shown),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: _hasDuration
                                ? (details) {
                                    final f = (details.localPosition.dx / width)
                                        .clamp(0.0, 1.0);
                                    _preview(f);
                                    _commit(f);
                                  }
                                : null,
                            onHorizontalDragStart: _hasDuration
                                ? (details) => _preview(
                                    (details.localPosition.dx / width)
                                        .clamp(0.0, 1.0),
                                  )
                                : null,
                            onHorizontalDragUpdate: _hasDuration
                                ? (details) {
                                    final current = _drag ?? 0.0;
                                    _preview(
                                      current +
                                          details.delta.dx / width,
                                    );
                                  }
                                : null,
                            onHorizontalDragEnd: _hasDuration
                                ? (_) => _commit(_drag)
                                : null,
                            onHorizontalDragCancel: _hasDuration
                                ? () {
                                    widget.onDragPreview?.call(null);
                                    setState(() => _drag = null);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 时长读不到显示 --:--（P0-F1），不伪造 00:00。
                  VxTimeLabel(_hasDuration ? duration : null),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
