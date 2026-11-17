/// Shell Chrome 主题感知色源测试（指南 §3.2 / P1-09 回归锁定，B3 harness 重写）。
///
/// P1-09：浅色主题下 AppHeader/Sidebar/ContextPanel/PlayerBar 底色与分隔线
/// 曾硬编码 VxColors 深色常量 → 深底深字不可读（实机证据
/// docs/redesign/screenshots/baseline/linux-settings-1440x900-light-theme.png）。
/// P1-09 曾以 `VxChrome` 亮暗三元收口；B3 起壳层 chrome 统一走单一真源
/// buildAppTheme 的 ColorScheme 槽位（surfaceContainerLow / outline），无
/// M3 槽位 token 经 VxPalette 扩展下发。本文件锁定：
/// - buildAppTheme('catppuccin-mocha') 槽位契约：深色 = 原 VxColors 常量
///   （像素不变），浅色 = VxLightColors 等值（P1-09 意图：浅色浅 chrome）；
/// - VxPalette 浅色字段（seekTrack/onPlayIcon/success）取浅色常量；
/// - 真实组件接线：AppHeader / PlayerBar / ContextPanel / AppSidebar 分隔线 /
///   VoicefoxShell 侧栏容器在浅/深主题下渲染出的实际颜色。
///
/// harness 用 buildAppTheme 构建（不再是裸 ThemeData(brightness:)）——
/// 组件读取的就是运行时同一产源。不起 Rust 控制器：AppModel 空状态 +
/// MultiProvider harness（同 shell_test）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/design_system/design_tokens.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';
import 'package:voicefox_flutter/src/shell/app_header.dart';
import 'package:voicefox_flutter/src/shell/app_sidebar.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';
import 'package:voicefox_flutter/src/shell/context_panel.dart';
import 'package:voicefox_flutter/src/theme/app_theme.dart';

/// 深浅两侧期望值（P1-09 收口契约；经 buildAppTheme 槽位表达）。
const _lightSurface1 = VxLightColors.surface1;
const _darkSurface1 = VxColors.surface1;
const _lightDivider = VxLightColors.divider;
const _darkDivider = VxColors.divider;

Widget _shellHarness(AppModel model, Brightness brightness) => MultiProvider(
  // 根 Key：同类型根 widget 重泵走 element update 时 Theme InheritedWidget
  // 不传播（实测 Builder 仍读旧 brightness），换 Key 强制整树重建。
  key: ValueKey('chrome-shell-${brightness.name}'),
  providers: [
    ChangeNotifierProvider<AppModel>.value(value: model),
    ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
    ChangeNotifierProvider<NotificationService>.value(
      value: NotificationService(),
    ),
  ],
  child: MaterialApp(
    theme: buildAppTheme('catppuccin-mocha', brightness),
    home: VoicefoxShell(model: model),
  ),
);

/// 组件子树里最外层 Container 的 BoxDecoration 颜色（先序遍历首个）。
Color? _rootContainerColor(WidgetTester tester, Type componentType) {
  final containers = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(componentType),
      matching: find.byWidgetPredicate((w) => w is Container),
    ),
  );
  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

void main() {
  setUp(() {
    // SettingsProvider 构造即读 prefs；测试注入内存实现。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('buildAppTheme chrome 槽位契约（B3 单一真源）', () {
    test('深色槽位返回 VxColors 原值（默认主题像素不变）', () {
      final scheme = buildAppTheme(
        'catppuccin-mocha',
        Brightness.dark,
      ).colorScheme;
      expect(scheme.surfaceContainerLow, _darkSurface1);
      expect(scheme.outline, _darkDivider);
    });

    test('浅色槽位返回 VxLightColors 等值（P1-09：浅底浅 Chrome）', () {
      final scheme = buildAppTheme(
        'catppuccin-mocha',
        Brightness.light,
      ).colorScheme;
      expect(scheme.surfaceContainerLow, _lightSurface1);
      expect(scheme.outline, _lightDivider);
      // 浅色 Chrome 底必须是浅色板表面值，而不是深色 #191820。
      expect(scheme.surfaceContainerLow, isNot(_darkSurface1));
      expect(scheme.outline, isNot(_darkDivider));
    });

    test('VxPalette 浅色字段取浅色常量（seekTrack/onPlayIcon/success）', () {
      final lightPalette = buildAppTheme(
        'catppuccin-mocha',
        Brightness.light,
      ).extension<VxPalette>()!;
      expect(lightPalette.seekTrack, VxLightColors.seekTrack);
      expect(lightPalette.onPlayIcon, VxLightColors.onPlayIcon);
      expect(lightPalette.success, VxLightColors.success);
      final darkPalette = buildAppTheme(
        'catppuccin-mocha',
        Brightness.dark,
      ).extension<VxPalette>()!;
      expect(darkPalette.seekTrack, VxDarkSurface.seekTrack);
      expect(darkPalette.onPlayIcon, VxColors.onPlayIcon);
    });
  });

  group('真实组件接线（浅色主题下 Chrome 不再深底深字）', () {
    final model = AppModel();

    testWidgets(
      'AppHeader：浅色 = VxLightColors.surface1，深色 = VxColors.surface1',
      (tester) async {
        await tester.pumpWidget(_shellHarness(model, Brightness.light));
        await tester.pump();
        expect(_rootContainerColor(tester, AppHeader), _lightSurface1);

        await tester.pumpWidget(_shellHarness(model, Brightness.dark));
        await tester.pump();
        expect(_rootContainerColor(tester, AppHeader), _darkSurface1);
      },
    );

    testWidgets(
      'PlayerBar：浅色 = VxLightColors.surface1，深色 = VxColors.surface1',
      (tester) async {
        await tester.pumpWidget(_shellHarness(model, Brightness.light));
        await tester.pump();
        expect(_rootContainerColor(tester, PlayerBar), _lightSurface1);

        await tester.pumpWidget(_shellHarness(model, Brightness.dark));
        await tester.pump();
        expect(_rootContainerColor(tester, PlayerBar), _darkSurface1);
      },
    );

    testWidgets(
      'ContextPanel：浅色 = VxLightColors.surface1，深色 = VxColors.surface1',
      (tester) async {
        Widget panel(Brightness brightness) => MaterialApp(
          key: ValueKey('chrome-panel-${brightness.name}'),
          theme: buildAppTheme('catppuccin-mocha', brightness),
          home: Scaffold(
            body: ContextPanel(
              model: model,
              tab: ContextTab.nowPlaying,
              onTabChanged: (_) {},
              onClose: () {},
            ),
          ),
        );
        await tester.pumpWidget(panel(Brightness.light));
        await tester.pump();
        expect(_rootContainerColor(tester, ContextPanel), _lightSurface1);

        await tester.pumpWidget(panel(Brightness.dark));
        await tester.pump();
        expect(_rootContainerColor(tester, ContextPanel), _darkSurface1);
      },
    );

    testWidgets(
      'AppSidebar 分隔线：浅色 = VxLightColors.divider，深色 = VxColors.divider',
      (tester) async {
        Widget sidebar(Brightness brightness) => MaterialApp(
          key: ValueKey('chrome-sidebar-${brightness.name}'),
          theme: buildAppTheme('catppuccin-mocha', brightness),
          home: Scaffold(
            body: AppSidebar(
              model: model,
              current: ShellDestination.home,
              onSelect: (_) {},
              collapsed: false,
            ),
          ),
        );
        await tester.pumpWidget(sidebar(Brightness.light));
        await tester.pump();
        final lightDividers = tester.widgetList<Divider>(find.byType(Divider));
        expect(lightDividers, isNotEmpty);
        expect(
          lightDividers.every((d) => d.color == _lightDivider),
          isTrue,
          reason: '浅色下侧栏分隔线不得保留深色 VxColors.divider',
        );

        await tester.pumpWidget(sidebar(Brightness.dark));
        await tester.pump();
        final darkDividers = tester.widgetList<Divider>(find.byType(Divider));
        expect(darkDividers, isNotEmpty);
        expect(darkDividers.every((d) => d.color == _darkDivider), isTrue);
      },
    );

    testWidgets('VoicefoxShell 侧栏容器（1440 宽内嵌）：浅/深两侧各取正确 token', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Color? sidebarColor(Brightness brightness) {
        final boxes = tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        for (final box in boxes) {
          final decoration = box.decoration;
          if (decoration is BoxDecoration && decoration.color != null) {
            return decoration.color;
          }
        }
        return null;
      }

      await tester.pumpWidget(_shellHarness(model, Brightness.light));
      await tester.pumpAndSettle();
      expect(sidebarColor(Brightness.light), _lightSurface1);

      await tester.pumpWidget(_shellHarness(model, Brightness.dark));
      await tester.pumpAndSettle();
      expect(sidebarColor(Brightness.dark), _darkSurface1);
    });
  });
}
