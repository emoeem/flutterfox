/// SectionHeader：内容区标题 + 右侧操作（§7.1）。
///
/// 形态取自概念稿 `.section-head`：左侧 18/700 标题（可带 eyebrow），
/// 右侧 12px 弱色"查看全部 →"或自定义操作。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 分区标题行。
class VxSectionHeader extends StatelessWidget {
  const VxSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const <Widget>[],
    this.onViewAll,
    this.viewAllLabel = '查看全部',
  });

  /// 分区标题（18/700）。
  final String title;

  /// 标题上方的小字标（10/700 强调色，如 CONTINUE LISTENING）。
  final String? eyebrow;

  /// 标题右侧的自定义操作（按钮、标签等）。
  final List<Widget> actions;

  /// 提供后显示"查看全部 →"；null 则不渲染。
  final VoidCallback? onViewAll;

  /// 查看全部文案。
  final String viewAllLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: VxTypography.eyebrow.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                title,
                style: VxTypography.sectionTitle.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ...actions,
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: VxSpacing.sm),
              minimumSize: const Size(0, 32),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(viewAllLabel, style: VxTypography.caption),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward, size: 13),
              ],
            ),
          ),
      ],
    );
  }
}
