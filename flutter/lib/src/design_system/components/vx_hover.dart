/// hover 展示态助手（设计系统内部基建）。
///
/// 公开组件本身保持无状态（数据全部来自构造器）；hover 是纯视觉态，
/// 由本助手持有，组件通过 builder 拿到 `hovering` 布尔值。
library;

import 'package:flutter/material.dart';

/// 在 hover / 点击两种能力下构建子树。
class VxHoverBuilder extends StatefulWidget {
  const VxHoverBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPressStart,
    this.enabled = true,
  });

  /// `hovering` 为 true 表示指针悬停（且 [enabled]）。
  final Widget Function(BuildContext context, bool hovering) builder;

  /// 提供后整块区域可点击；null 表示不可点（光标不变成手型）。
  final VoidCallback? onTap;

  /// 长按回调（Phase 7 触屏语义：长按菜单替代右键/hover 操作；桌面
  /// 按住同样触发，与 Material 惯例一致，不影响右键行为）。
  final GestureLongPressStartCallback? onLongPressStart;

  /// false 时永远报告 not hovering 且不响应点击。
  final bool enabled;

  @override
  State<VxHoverBuilder> createState() => _VxHoverBuilderState();
}

class _VxHoverBuilderState extends State<VxHoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && widget.onTap != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: interactive ? widget.onTap : null,
        onLongPressStart: widget.onLongPressStart,
        behavior: HitTestBehavior.opaque,
        child: widget.builder(context, _hovering && widget.enabled),
      ),
    );
  }
}
