/// 本地插值播放进度：Rust 侧无周期性 position 事件，只在状态迁移时刷新，
/// 播放中的连续走带由本组件用 Timer（500ms）平滑插值。
library;

import 'dart:async';

import 'package:flutter/material.dart';

class LivePlayback extends StatefulWidget {
  final BigInt positionMs;
  final BigInt durationMs;
  final bool playing;

  /// (position, duration) 快照，由调用方决定渲染形态（进度条 / 滑条 / 时间）。
  final Widget Function(BuildContext context, Duration position,
      Duration duration) builder;

  const LivePlayback({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
    required this.builder,
  });

  @override
  State<LivePlayback> createState() => _LivePlaybackState();
}

class _LivePlaybackState extends State<LivePlayback> {
  DateTime _anchor = DateTime.now();
  Timer? _timer;
  late Duration _base;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LivePlayback old) {
    super.didUpdateWidget(old);
    // 位置/状态/曲目代际变化时重置锚点（positionMs 回退说明 seek 或换曲）。
    if (old.positionMs != widget.positionMs || old.playing != widget.playing) {
      _sync();
    }
  }

  void _sync() {
    _anchor = DateTime.now();
    _base = Duration(milliseconds: widget.positionMs.toInt());
    _timer?.cancel();
    if (widget.playing && widget.durationMs > BigInt.zero) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var position = _base;
    if (widget.playing) {
      position += DateTime.now().difference(_anchor);
    }
    final duration = Duration(milliseconds: widget.durationMs.toInt());
    if (duration > Duration.zero && position > duration) position = duration;
    return widget.builder(context, position, duration);
  }
}

/// m:ss 格式化。
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final rest = d.inSeconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
