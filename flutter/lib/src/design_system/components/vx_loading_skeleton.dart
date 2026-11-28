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
    this.fitViewport = false,
    this.maxRows = 8,
  });

  /// 歌曲行骨架。
  const VxLoadingSkeleton.tracks({Key? key, int rows = 5})
    : this(key: key, rows: rows, variant: VxSkeletonVariant.tracks);

  /// 歌曲行骨架的「视口自适应」变体（§7.4：骨架必须受视口约束）。
  ///
  /// 在父级给出的约束高度内渲染恰好放得下的行数（上限 [maxRows]、下限 1），
  /// 行高/间距常量单源于 [_trackRowHeight]/[_trackRowGap]，调用方不需要复述
  /// 内部度量。适用挂在 Expanded/bounded 高度内的骨架；无界高度（滚动列表
  /// 内）请用 [VxLoadingSkeleton.tracks]。
  ///
  /// P2-19 回归修复：search_page 加载态原用固定 `tracks(rows: 8)`（≈520px），
  /// 1136×713 窗口下 Expanded 视口不足 → RenderFlex 底部溢出 143px。
  const VxLoadingSkeleton.tracksFitted({Key? key, int maxRows = 8})
    : this(
        key: key,
        rows: 5,
        variant: VxSkeletonVariant.tracks,
        fitViewport: true,
        maxRows: maxRows,
      );

  /// 封面书架骨架。
  const VxLoadingSkeleton.shelf({Key? key, int rows = 5})
    : this(key: key, rows: rows, variant: VxSkeletonVariant.shelf);

  /// Hero 骨架。
  const VxLoadingSkeleton.hero({Key? key})
    : this(key: key, rows: 1, variant: VxSkeletonVariant.hero);

  /// 歌曲行高度（与 [_trackRow] 布局单源）。
  static const double _trackRowHeight = 58;

  /// 歌曲行间距（与 [_trackColumn] 布局单源）。
  static const double _trackRowGap = VxSpacing.sm;

  /// 行数 / 占位块数。
  final int rows;

  /// 骨架变体。
  final VxSkeletonVariant variant;

  /// 是否按父级约束高度自适应行数（仅 tracks 变体生效）。
  final bool fitViewport;

  /// [fitViewport] 时的行数上限。
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blockColor = scheme.surfaceContainerHigh;
    if (fitViewport && variant == VxSkeletonVariant.tracks) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // 约束无界（滚动列表内误用）时退化为固定 [rows] 行，不猜测高度。
          final available = constraints.maxHeight;
          final fitted = available.isFinite
              ? ((available + _trackRowGap) / (_trackRowHeight + _trackRowGap))
                    .floor()
                    .clamp(1, maxRows)
              : rows;
          return _trackColumn(blockColor, fitted);
        },
      );
    }
    return switch (variant) {
      VxSkeletonVariant.tracks => _trackColumn(blockColor, rows),
      VxSkeletonVariant.shelf => _shelfColumn(blockColor, rows),
      VxSkeletonVariant.hero => _hero(blockColor),
    };
  }

  Widget _trackColumn(Color blockColor, int rowCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: _trackRowGap),
          _trackRow(blockColor),
        ],
      ],
    );
  }

  Widget _shelfColumn(Color blockColor, int rowCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: VxSpacing.sm),
          _shelfCard(blockColor),
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
