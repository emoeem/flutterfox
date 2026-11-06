/// 缺封面占位：色彩渐变 + 首字母（Phase 0 V1：禁止单调灰音符块）。
///
/// 渐变取自概念稿 `.art1`-`.art6` / `.hero-art` / `.context-art` 的字面值，
/// 按标题稳定哈希取色，同一标题总是同一配色。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 渐变 + 首字符的封面占位。
class VxCoverFallback extends StatelessWidget {
  const VxCoverFallback({
    super.key,
    required this.title,
    this.radius = VxRadius.sm,
  });

  /// 用作取色与首字母来源的文本（标题 / 歌手名）。
  final String title;

  /// 圆角；圆形封面传 `radius = null` 之外的更大值或用 ClipOval 包裹。
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: VxCoverGradients.forSeed(title),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(child: _label()),
    );
  }

  Widget _label() {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Icon(
        Icons.music_note,
        size: 16,
        color: Color(0xCCFFFFFF),
      );
    }
    final first = String.fromCharCode(trimmed.runes.first).toUpperCase();
    return Text(
      first,
      style: const TextStyle(
        color: Color(0xE6FFFFFF),
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}
