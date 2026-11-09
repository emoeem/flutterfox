/// Phase 2 桌面 Shell 的响应式布局规则（计划书 §3.1 布局算法的唯一实现）。
///
/// 断点（§3.1）：
/// - ≥1440：三栏，右栏（ContextPanel）内嵌；
/// - 1200–1439：Sidebar 240，右栏默认隐藏，打开时覆盖式浮层；
/// - 960–1199：Sidebar 折叠 72，右栏浮层；
/// - <960：不再强行压缩三栏，降级布局（Sidebar 隐藏，经 Header 菜单按需
///   浮出），右栏浮层；底部 PlayerBar 始终常驻（Phase 0 F2 的修复点）。
///
/// Phase 7 追加：设备形态选择（[resolveDeviceFormFactor]）与平板三档
/// （[resolveTabletLayout]）。作用域铁律：桌面（非触屏平台）所有宽度
/// 恒为 [DeviceFormFactor.desktop]，现行四档断点零变化；移动/平板形态
/// 只在触屏平台按宽度生效。平台判定必须用 dart:io Platform，禁止
/// defaultTargetPlatform（FLUTTER_TEST 强制 android，会整体翻掉桌面基线）。
///
/// 本文件保持纯函数，方便对断点行为做单元级验证。
library;

import 'dart:io' show Platform;

/// 触屏平台判定（Android/iOS）。
///
/// 测试环境（宿主桌面）恒为 false：壳分支依赖本判定时，桌面行为与
/// 既有 145 例基线一致；移动/平板壳的测试直接 pump MobileShell/
/// TabletShell 或对纯函数显式传参注入，不依赖 TargetPlatform。
bool get isTouchPlatform => Platform.isAndroid || Platform.isIOS;

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

/// 触屏平台的移动/平板宽度断点（仅触屏平台消费；桌面不读这些常量）。
abstract final class MobileBreakpoints {
  /// <600：手机形态（MobileShell，底部导航）。
  static const double handsetMax = 600;

  /// <900：平板纯 NavigationRail 档（图标 rail）。
  static const double tabletRailMax = 900;

  /// <1200：平板双栏档（展开 Rail + 内容）；≥1200 三栏（+ ContextPanel 内嵌）。
  static const double tabletDualMax = 1200;
}

/// 设备形态（Phase 7）。
enum DeviceFormFactor {
  /// 桌面（非触屏平台）：所有宽度走现行 VoicefoxShell 四档断点，零变化。
  desktop,

  /// 手机（触屏平台 <600）：MobileShell。
  handset,

  /// 平板（触屏平台 ≥600）：TabletShell，档位再由 [resolveTabletLayout] 细分。
  tablet,
}

/// 平板档内布局（Phase 7 任务：NavigationRail / 双栏 / 三栏三态）。
enum TabletLayout {
  /// 600-899：图标 NavigationRail + 内容；右栏浮层。
  rail,

  /// 900-1199：展开（带标签）Rail + 内容双栏；右栏浮层。
  dual,

  /// ≥1200：Rail + 内容 + ContextPanel 内嵌三栏。
  triple,
}

/// 解析宽度 → 设备形态。桌面平台（[isTouch] = false）恒为
/// [DeviceFormFactor.desktop]，宽度完全不参与，保证桌面四档零变化。
DeviceFormFactor resolveDeviceFormFactor(
  double width, {
  required bool isTouch,
}) {
  if (!isTouch) return DeviceFormFactor.desktop;
  return width < MobileBreakpoints.handsetMax
      ? DeviceFormFactor.handset
      : DeviceFormFactor.tablet;
}

/// 解析平板宽度 → 三态布局（仅触屏平台调用；<600 属手机形态不到这里）。
TabletLayout resolveTabletLayout(double width) {
  if (width < MobileBreakpoints.tabletRailMax) return TabletLayout.rail;
  if (width < MobileBreakpoints.tabletDualMax) return TabletLayout.dual;
  return TabletLayout.triple;
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
