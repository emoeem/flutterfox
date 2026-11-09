/// VxDetailHero：专辑 / 歌单等详情页的顶部信息区（§4.5 / §4.7）。
///
/// 形态：大封面（224-256px、radius 12、投影）+ 信息列（eyebrow 小字标 /
/// 28-32px 主标题 / 来源徽章 / 元信息行 / 说明 / 操作按钮排）。
/// 纯展示：内容与回调全部来自构造器；按钮禁用时经 [VxDetailAction.tooltip]
/// 解释原因，不允许「点了没反应」。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'vx_cover_fallback.dart';

/// 详情页操作按钮描述。`onPressed == null` 即禁用态；
/// [tooltip] 用于悬停说明（尤其是禁用原因）。
class VxDetailAction {
  /// 按钮图标。
  final IconData icon;

  /// 按钮文案。
  final String label;

  /// 点击回调；null 渲染为禁用。
  final VoidCallback? onPressed;

  /// true 时用 FilledButton（主操作），否则 OutlinedButton（次操作）。
  final bool primary;

  /// 悬停说明；禁用时展示原因（如「后端暂不支持随机播放队列」）。
  final String? tooltip;

  const VxDetailAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.tooltip,
  });
}

/// 详情页 Hero：封面 + 信息列 + 操作排。
class VxDetailHero extends StatelessWidget {
  const VxDetailHero({
    super.key,
    required this.eyebrow,
    required this.title,
    this.meta = const <String>[],
    this.badges = const <String>[],
    this.description,
    this.cover,
    this.fallbackSeed,
    this.actions = const <VxDetailAction>[],
    this.trailingActions = const <Widget>[],
    this.coverSize = 224,
    this.titleFontSize = 28,
    this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 20),
  });

  /// 封面左上的小字标（如 专辑 / 歌单 / 账号歌单）。
  final String eyebrow;

  /// 主标题（28-32px；超长 2 行省略）。
  final String title;

  /// 元信息（歌手 / 年份 / 曲目数 / 总时长），「 · 」连接。
  final List<String> meta;

  /// 徽章（音源标识、账号/本地标签等）。
  final List<String> badges;

  /// 说明文字（最多 3 行省略）；null 不渲染。
  final String? description;

  /// 封面内容；null 用渐变首字母占位（Phase 0 V1：禁止单调灰块）。
  final Widget? cover;

  /// 占位渐变取色种子；null 用 [title]。
  final String? fallbackSeed;

  /// 操作按钮排。
  final List<VxDetailAction> actions;

  /// 附加操作（图标菜单等任意 Widget），排在 [actions] 之后。
  final List<Widget> trailingActions;

  /// 封面边长（§4.5：224-256）。
  final double coverSize;

  /// 标题字号（§4.5：28-32）。
  final double titleFontSize;

  /// 外边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metaText = meta.where((item) => item.trim().isNotEmpty).join(' · ');
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _coverBox(),
          const SizedBox(width: VxSpacing.xl),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: VxTypography.eyebrow.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < badges.length; i++)
                        _badge(context, badges[i], highlight: i == 0),
                    ],
                  ),
                ],
                if (metaText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    metaText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VxTypography.body.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VxTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: VxSpacing.lg),
                  Wrap(
                    spacing: VxSpacing.sm,
                    runSpacing: VxSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final action in actions) _action(context, action),
                      ...trailingActions,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverBox() {
    final inner =
        cover ??
        VxCoverFallback(title: fallbackSeed ?? title, radius: VxRadius.lg);
    return Container(
      width: coverSize,
      height: coverSize,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        child: inner,
      ),
    );
  }

  Widget _badge(BuildContext context, String text, {required bool highlight}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: VxTypography.caption.copyWith(
          color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: highlight ? FontWeight.w600 : null,
        ),
      ),
    );
  }

  Widget _action(BuildContext context, VxDetailAction action) {
    final button = action.primary
        ? FilledButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
          )
        : OutlinedButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
          );
    final tooltip = action.tooltip;
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
