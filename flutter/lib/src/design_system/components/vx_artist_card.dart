/// ArtistCard：歌手卡（§7.1：圆形 / 方形封面两种变体）。
library;

import 'package:flutter/material.dart';

import 'vx_card_shell.dart';

/// 歌手封面变体。
enum VxArtistCardShape {
  /// 圆形封面（默认）。
  circle,

  /// 方形圆角封面。
  square,
}

/// 歌手卡：封面 + 歌手名（居中），hover 浮现播放钮。
class VxArtistCard extends StatelessWidget {
  const VxArtistCard({
    super.key,
    required this.title,
    this.subtitle,
    this.cover,
    this.shape = VxArtistCardShape.circle,
    this.width = 156,
    this.onTap,
    this.onPlay,
  });

  /// 歌手名。
  final String title;

  /// 副标题（如 "12 张专辑"）。
  final String? subtitle;

  /// 自定义封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 封面形状。
  final VxArtistCardShape shape;

  /// 卡片宽度。
  final double width;

  /// 单击卡片（进入歌手详情）。
  final VoidCallback? onTap;

  /// hover 播放钮回调。
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return VxCardShell(
      title: title,
      subtitle: subtitle,
      cover: cover,
      width: width,
      circle: shape == VxArtistCardShape.circle,
      centered: true,
      onTap: onTap,
      onPlay: onPlay,
    );
  }
}
