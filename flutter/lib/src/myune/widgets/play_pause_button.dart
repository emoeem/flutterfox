// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/material.dart';

class PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final Color color;
  final double size;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    required this.color,
    this.size = 36.0,
  });

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    // 根据初始播放状态设置动画控制器的值
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当播放状态改变时，控制动画
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.size,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _controller,
        color: widget.color,
      ),
      onPressed: widget.onPressed,
    );
  }
}
