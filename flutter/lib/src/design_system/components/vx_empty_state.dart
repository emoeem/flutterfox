/// EmptyState：空状态（§7.1：有原因、有说明、有真实下一步操作）。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 空状态面板。
class VxEmptyState extends StatelessWidget {
  const VxEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.library_music,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  /// 原因 / 状态名（如"这里还没有歌曲"）。
  final String title;

  /// 补充说明（发生了什么、为什么会这样）。
  final String message;

  /// 状态图标。
  final IconData icon;

  /// 主操作文案（真实下一步动作，如 导入本地音乐）。
  final String? actionLabel;

  /// 主操作回调。
  final VoidCallback? onAction;

  /// 次操作文案。
  final String? secondaryLabel;

  /// 次操作回调。
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 槽位比内容矮（如曲库来源 chips 行挤压下方分区）时不溢出而是可滚动
    // （标准「居中 + 矮槽滚动」结构），避免 RenderFlex overflow。
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VxSpacing.xl,
                vertical: VxSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: VxSpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: VxTypography.title.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: VxSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: VxTypography.body.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (actionLabel != null || secondaryLabel != null) ...[
                    const SizedBox(height: VxSpacing.xl),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (actionLabel != null)
                          FilledButton(
                            onPressed: onAction,
                            child: Text(actionLabel!),
                          ),
                        if (actionLabel != null && secondaryLabel != null)
                          const SizedBox(width: VxSpacing.sm),
                        if (secondaryLabel != null)
                          TextButton(
                            onPressed: onSecondaryAction,
                            child: Text(secondaryLabel!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
