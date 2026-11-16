/// 桌面内容限宽（SR-10，计划书 §7.1「大屏信息密度」：一级页面在超宽窗口
/// 下保持可读内容宽度，不为每页各自硬编码不同宽度）。
///
/// - maxWidth 1320 与全仓唯一先例 now_playing_page 的限宽同源（§7.1.5
///   视觉证据先例沿用，不另造数值）；
/// - Align(topCenter)：内容列居中、背景全幅（页面自身 Material 背景铺满
///   壳层内容区，两侧不出现断带）；
/// - 窄窗口/平板（<1320）下 maxWidth 不束缚可用宽度，布局零变化
///   （ConstrainedBox 仅在可用宽度超出时生效，§7.1.4）；
/// - 手机档页面不消费本组件（MobileShell 无此需求）。
library;

import 'package:flutter/material.dart';

/// 允许的最大内容宽度（与 now_playing_page 既有限宽同源）。
const double kDesktopContentMaxWidth = 1320;

class DesktopContentConstraint extends StatelessWidget {
  final Widget child;

  const DesktopContentConstraint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDesktopContentMaxWidth),
        child: child,
      ),
    );
  }
}
