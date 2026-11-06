/// Phase 2 桌面 Shell 的响应式布局规则（计划书 §3.1 布局算法的唯一实现）。
///
/// 断点（§3.1）：
/// - ≥1440：三栏，右栏（ContextPanel）内嵌；
/// - 1200–1439：Sidebar 240，右栏默认隐藏，打开时覆盖式浮层；
/// - 960–1199：Sidebar 折叠 72，右栏浮层；
/// - <960：不再强行压缩三栏，降级布局（Sidebar 隐藏，经 Header 菜单按需
///   浮出），右栏浮层；底部 PlayerBar 始终常驻（Phase 0 F2 的修复点）。
///
/// 本文件保持纯函数，方便对断点行为做单元级验证。
library;

/// Shell 布局尺寸与断点常量。
abstract final class ShellBreakpoints {
  /// ≥1440：允许右栏内嵌（三栏）。
  static const double threeColumn = 1440;

  /// ≥1200：Sidebar 保持展开，右栏打开时为覆盖式浮层。
  static const double contextOverlayMin = 1200;

  /// <960：降级布局，Sidebar 隐藏。
  static const double sidebarCollapse = 960;

  /// 尺寸规格（§3.1 表格）。
  static const double sidebarWidth = 240;
  static const double sidebarCollapsedWidth = 72;
  static const double headerHeight = 56;
  static const double playerBarHeight = 92;
  static const double contextDefaultWidth = 320;
  static const double contextMinWidth = 280;
  static const double contextMaxWidth = 420;
}

/// Sidebar 形态。
enum SidebarMode {
  /// 展开态（240px）。
  expanded,

  /// 折叠态（72px，纯图标）。
  collapsed,

  /// 隐藏（<960 降级布局；经 Header 菜单按钮浮出）。
  hidden,
}

/// ContextPanel 形态。
enum ContextPanelMode {
  /// 内嵌于三栏行内（≥1440）。
  inline,

  /// 覆盖在内容区之上的浮层（<1440 打开时）。
  overlay,
}

/// 一次断点解析的结果。
class ShellMetrics {
  const ShellMetrics({
    required this.sidebar,
    required this.context,
    required this.contentPadding,
  });

  final SidebarMode sidebar;
  final ContextPanelMode context;

  /// 页面内容内边距（§3.1：28 默认 / 窄窗 20 / 超宽 32）。
  final double contentPadding;
}

/// 解析窗口宽度 → Shell 各区形态。
///
/// [contextOpen] 表示用户是否打开了右栏；右栏关闭时 [ShellMetrics.context]
/// 无意义（调用方应先看开关状态），但 mode 仍按宽度给出，保持函数纯粹。
ShellMetrics resolveShellMetrics(double width, {required bool contextOpen}) {
  final SidebarMode sidebar;
  var context = ContextPanelMode.overlay;
  double padding;
  if (width >= ShellBreakpoints.threeColumn) {
    sidebar = SidebarMode.expanded;
    context = ContextPanelMode.inline;
    padding = width >= 1600 ? 32 : 28;
  } else if (width >= ShellBreakpoints.contextOverlayMin) {
    sidebar = SidebarMode.expanded;
    padding = 28;
  } else if (width >= ShellBreakpoints.sidebarCollapse) {
    sidebar = SidebarMode.collapsed;
    padding = 20;
  } else {
    sidebar = SidebarMode.hidden;
    padding = 20;
  }
  return ShellMetrics(
    sidebar: sidebar,
    context: context,
    contentPadding: padding,
  );
}
