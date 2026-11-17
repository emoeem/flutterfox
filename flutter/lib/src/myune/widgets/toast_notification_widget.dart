// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
// Local adaptation (voicefox Phase 1, 2026-11-10，QA P1：错误 toast 无高度上限
// 遮挡页面)：文本 maxLines=4 + 省略号、容器 max-height 160——上游对消息文本
// 不限行数，多行原始异常会把 toast 撑到整页高。原始异常已在 AppModel 源头
// 净化写日志（sanitizeUserFacingMessage），此处为兜底限高。
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class ToastNotificationWidget extends StatelessWidget {
  final AppNotification notification;
  final Animation<double> animation;
  final VoidCallback onDismiss;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  const ToastNotificationWidget({
    super.key,
    required this.notification,
    required this.animation,
    required this.onDismiss,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = notification.type == NotificationType.error;

    final backgroundColor = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final foregroundColor = isError
        ? theme.colorScheme.onError
        : theme.colorScheme.onPrimary;
    final icon = isError ? Icons.error_rounded : Icons.info_rounded;

    // 从右侧滑入 + 淡入
    final slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: MouseRegion(
          onEnter: (_) => onHoverStart(),
          onExit: (_) => onHoverEnd(),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 160),
              child: IntrinsicWidth(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foregroundColor, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            notification.count > 1
                                ? '${notification.message} (×${notification.count})'
                                : notification.message,
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: 13,
                            ),
                            // Local adaptation：限 4 行 + 省略，防整页高 toast。
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (isError) ...[
                          const SizedBox(width: 4),
                          _ActionButton(
                            label: '复制',
                            color: foregroundColor,
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: notification.message),
                            ),
                          ),
                        ],

                        const SizedBox(width: 4),

                        _ActionButton(
                          label: '关闭',
                          color: foregroundColor,
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,

        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(4),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
