/// Android 系统栏/inset 分层契约（指南 §10.1）。
///
/// 用户反馈「应用栏和手机状态栏合在一起」的布局层修复：分层规则只有一份出处，
/// 全部消费经由本文件的纯函数与组件，页面/壳层不得手工再加一份状态栏高度
/// （Scaffold/AppBar/NavigationBar 已自动消费 MediaQuery inset）。
///
/// 契约：
/// - **顶层**：系统状态栏 inset 只被 AppBar（`_ShellTopBar`）消费一次；
///   [statusBarOverlayStyle] 随主题亮暗翻转图标颜色（此前全 lib 无任何
///   SystemUiOverlayStyle 设置，状态栏图标颜色从未与主题同步）。
/// - **底层**：系统导航条 inset 只被 bottomNavigationBar（MiniPlayerBar +
///   NavigationBar 列）消费一次；滚动区底部 padding 由 Scaffold body 处理。
/// - **键盘**：Scaffold `resizeToAvoidBottomInset` 默认 true，body 内容随
///   viewInsets 收缩，搜索框不被遮挡（由 AndroidInsetsLayoutTest 断言）。
///
/// 真机验证（§12.6）受环境限制（无 JDK/无设备）保持未验证；本文件保证的是
/// widget 层可测的分层语义，AndroidInsetsLayoutTest 用注入的 MediaQuery 断言。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主题亮暗 → 状态栏/导航条图标样式（透明系统栏 + 图标对比度随主题翻转）。
SystemUiOverlayStyle statusBarOverlayStyle(Brightness brightness) {
  final overlay = brightness == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
  return overlay.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
  );
}

/// inset 分层期望值（纯函数，供 AndroidInsetsLayoutTest 注入 MediaQuery 后
/// 逐项断言；也是壳层布局的唯一契约出处）。
@immutable
class InsetLayers {
  /// 状态栏 inset：只允许 AppBar 消费一次（AppHeader 底边 = top + headerHeight）。
  final double top;

  /// 系统导航条 inset：只允许 bottomNavigationBar 列消费一次。
  final double bottom;

  /// 壳顶栏高度（56–64dp，§5.1）。
  final double headerHeight;

  /// 迷你播放栏高度（60–68dp，§5.8；无歌曲时 0）。
  final double miniPlayerHeight;

  /// 底部导航高度（72–80dp，§5.1）。
  final double navigationBarHeight;

  /// body 内容可用高度 = 屏高 − top − headerHeight − miniPlayer − navBar − bottom。
  double bodyHeightFor(double screenHeight) =>
      screenHeight -
      top -
      headerHeight -
      miniPlayerHeight -
      navigationBarHeight -
      bottom;

  const InsetLayers({
    required this.top,
    required this.bottom,
    required this.headerHeight,
    required this.miniPlayerHeight,
    required this.navigationBarHeight,
  });
}

/// 从 MediaQuery 与壳层规格推导 [InsetLayers]。
InsetLayers resolveInsetLayers({
  required EdgeInsets padding,
  required bool hasSong,
  double headerHeight = 56,
  double miniPlayerHeight = 64,
  double navigationBarHeight = 80,
}) => InsetLayers(
  top: padding.top,
  bottom: padding.bottom,
  headerHeight: headerHeight,
  miniPlayerHeight: hasSong ? miniPlayerHeight : 0,
  navigationBarHeight: navigationBarHeight,
);

/// 触屏壳的统一系统栏样式挂载点：跟随主题亮暗翻转状态栏/导航条图标，
/// 全壳（含全屏播放页）只此一处 AnnotatedRegion。
class AndroidInsetsLayer extends StatelessWidget {
  final Widget child;

  const AndroidInsetsLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarOverlayStyle(brightness),
      child: child,
    );
  }
}
