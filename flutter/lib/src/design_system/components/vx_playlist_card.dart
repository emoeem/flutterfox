/// PlaylistCard：歌单卡（§7.1：标题、来源、歌曲数量可配置）。
library;

import 'package:flutter/material.dart';

import 'vx_card_shell.dart';

/// 1:1 歌单封面 + 标题（2 行）+ "N 首歌曲 · 来源"（1 行），hover 浮现播放钮。
class VxPlaylistCard extends StatelessWidget {
  const VxPlaylistCard({
    super.key,
    required this.title,
    this.trackCount,
    this.source,
    this.subtitle,
    this.cover,
    this.width = 156,
    this.onTap,
    this.onPlay,
  });

  /// 歌单名（最多 2 行）。
  final String title;

  /// 歌曲数；提供时副标题自动拼为 "N 首歌曲"。
  final int? trackCount;

  /// 来源（如 网易云 / 本地）。
  final String? source;

  /// 覆盖副标题；优先级高于 [trackCount] / [source] 自动拼接。
  final String? subtitle;

  /// 自定义封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 卡片宽度。
  final double width;

  /// 单击卡片（进入歌单详情）。
  final VoidCallback? onTap;

  /// hover 播放钮回调。
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    var sub = subtitle;
    if (sub == null) {
      final parts = <String>[
        if (trackCount != null) '$trackCount 首歌曲',
        ?source,
      ];
      sub = parts.isEmpty ? null : parts.join(' · ');
    }
    return VxCardShell(
      title: title,
      subtitle: sub,
      cover: cover,
      width: width,
      onTap: onTap,
      onPlay: onPlay,
    );
  }
}
