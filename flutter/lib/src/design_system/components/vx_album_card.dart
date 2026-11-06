/// AlbumCard：专辑封面卡（§7.1：固定比例、统一标题行高）。
library;

import 'package:flutter/material.dart';

import 'vx_card_shell.dart';

/// 1:1 专辑封面 + 标题（2 行）+ 副标题（1 行），hover 浮现播放钮。
class VxAlbumCard extends StatelessWidget {
  const VxAlbumCard({
    super.key,
    required this.title,
    this.subtitle,
    this.cover,
    this.width = 156,
    this.onTap,
    this.onPlay,
  });

  /// 专辑名（最多 2 行）。
  final String title;

  /// 副标题（歌手 / 年份等，最多 1 行）。
  final String? subtitle;

  /// 自定义封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 卡片宽度。
  final double width;

  /// 单击卡片（进入专辑详情）。
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
      onTap: onTap,
      onPlay: onPlay,
    );
  }
}
