/// ErrorState：错误状态（§7.1：原因、重试、可恢复操作）。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 错误状态面板。
class VxErrorState extends StatelessWidget {
  const VxErrorState({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    this.icon = Icons.error_outline,
    this.retryLabel = '重试',
    this.onRetry,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  /// 错误概要（如"加载失败"）。
  final String title;

  /// 面向用户的解释（原因与影响）。
  final String message;

  /// 技术细节（异常摘要等，折叠为弱色小字，可空）。
  final String? detail;

  /// 状态图标。
  final IconData icon;

  /// 重试按钮文案。
  final String retryLabel;

  /// 重试回调。
  final VoidCallback? onRetry;

  /// 次操作文案（可恢复操作，如"检查网络设置"）。
  final String? secondaryLabel;

  /// 次操作回调。
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
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
                color: scheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: scheme.error),
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
            if (detail != null) ...[
              const SizedBox(height: VxSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: VxSpacing.md,
                    vertical: VxSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(VxRadius.md),
                  ),
                  child: Text(
                    detail!,
                    style: VxTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(height: VxSpacing.xl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  child: Text(retryLabel),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: VxSpacing.sm),
                  TextButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
