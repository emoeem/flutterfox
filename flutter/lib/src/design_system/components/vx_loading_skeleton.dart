/// LoadingSkeleton：加载骨架（§7.1：骨架或进度，避免无限 spinner）。
///
/// 静态占位块（Phase 1 样板不做 shimmer 动效，见 limitations）。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 骨架变体。
enum VxSkeletonVariant {
  /// 歌曲行骨架。
  tracks,

  /// 封面书架骨架。
  shelf,

  /// Hero 骨架。
  hero,
}

/// 加载骨架。
class VxLoadingSkeleton extends StatelessWidget {
  const VxLoadingSkeleton({
    super.key,
    this.rows = 5,
    this.variant = VxSkeletonVariant.tracks,
  });

  /// 歌曲行骨架。
  const VxLoadingSkeleton.tracks({Key? key, int rows = 5})
    : this(key: key, rows: rows, variant: VxSkeletonVariant.tracks);

  /// 封面书架骨架。
  const VxLoadingSkeleton.shelf({Key? key, int rows = 5})
    : this(key: key, rows: rows, variant: VxSkeletonVariant.shelf);

  /// Hero 骨架。
  const VxLoadingSkeleton.hero({Key? key})
    : this(key: key, rows: 1, variant: VxSkeletonVariant.hero);

  /// 行数 / 占位块数。
  final int rows;

  /// 骨架变体。
  final VxSkeletonVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blockColor = scheme.surfaceContainerHigh;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: VxSpacing.sm),
          switch (variant) {
            VxSkeletonVariant.tracks => _trackRow(blockColor),
            VxSkeletonVariant.shelf => _shelfCard(blockColor),
            VxSkeletonVariant.hero => _hero(blockColor),
          },
        ],
      ],
    );
  }

  Widget _trackRow(Color color) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _block(color, width: 40, height: 40),
          const SizedBox(width: VxSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.55,
                  child: _block(color, height: 12),
                ),
                const SizedBox(height: VxSpacing.sm),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.35,
                  child: _block(color, height: 10),
                ),
              ],
            ),
          ),
          _block(color, width: 44, height: 10),
        ],
      ),
    );
  }

  Widget _shelfCard(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 1, child: _block(color, radius: VxRadius.lg)),
        const SizedBox(height: 9),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.7,
          child: _block(color, height: 12),
        ),
        const SizedBox(height: 6),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.45,
          child: _block(color, height: 10),
        ),
      ],
    );
  }

  Widget _hero(Color color) {
    return SizedBox(
      height: 218,
      child: Row(
        children: [
          _block(color, width: 178, height: 178, radius: VxRadius.lg),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.25,
                  child: _block(color, height: 10),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: _block(color, height: 22),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.8,
                  child: _block(color, height: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(
    Color color, {
    double? width,
    double? height,
    double radius = VxRadius.sm,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
