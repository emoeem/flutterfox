/// Phase 7 第二批：移动专项测试批（计划 §10.2 视口×数据状态矩阵抽样）。
///
/// 覆盖（批次验收三点）：
/// - 视口矩阵抽样：360×800 手机、600/768/1024 平板 × 数据状态
///   （默认空态 / 有歌）——导航形态与迷你播放栏显隐断言；
/// - 断点穿越：TouchShell 下旋转/拖窗跨 600 档（手机↔平板）时导航目的地
///   与全屏播放页开关不丢（TouchShellSession），播放真源在 AppModel 不随
///   壳档切换；
/// - 平台隔离：非触屏平台（宿主测试环境 isTouchPlatform=false，即显式
///   override 注入口径）任何宽度 TouchShell 不进 MobileShell/TabletShell。
///
/// 平台口径：全程不依赖 defaultTargetPlatform（FLUTTER_TEST 强制 android）；
/// 有 Rust 链路的实机播放验证明确顺延 Phase 8（本文件全部走 debugSet*/
/// 空状态，不起控制器）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/shell/context_panel.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';
import 'package:voicefox_flutter/src/shell/responsive_shell.dart';

/// 断点穿越用 harness：显式注入触屏平台（宿主测试环境 dart:io 恒 false，
/// 即 ask 的「显式 override 注入」口径）。
Widget _harness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(
      home: TouchShell(model: model, touchPlatformOverride: true),
    ),
  );
}

/// 平台隔离用 harness：不注入 override（生产路径 dart:io 判定）。
Widget _desktopHarness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: TouchShell(model: model)),
  );
}

/// 单独 pump 某档壳（视口矩阵抽样用）。
Widget _shellHarness(AppModel model, Widget shell) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: shell),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AppModel _songModel() {
  final model = AppModel();
  model.debugSetPlaybackSong(
    id: 's1',
    source: 'netease',
    name: '夜航',
    singer: '测试歌手',
    state: 'paused',
    positionMs: 42000,
    durationMs: 244000,
  );
  return model;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('平台隔离：非触屏平台任何宽度不进移动/平板壳', () {
    test(
      'resolveDeviceFormFactor 显式 override 注入：isTouch=false 全宽度 desktop',
      () {
        for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0, 1920.0]) {
          expect(
            resolveDeviceFormFactor(width, isTouch: false),
            DeviceFormFactor.desktop,
            reason: '非触屏平台宽度 $width 不得进入移动/平板形态',
          );
        }
      },
    );

    testWidgets('TouchShell 在非触屏平台兜底为空渲染（不进 MobileShell/TabletShell）', (
      tester,
    ) async {
      final model = AppModel();
      // 逐宽度验证：不注入 override 时（宿主 dart:io 平台恒 false），
      // 任何宽度都不进移动/平板壳。
      for (final size in [
        const Size(360, 800),
        const Size(600, 900),
        const Size(900, 1024),
        const Size(1920, 1080),
      ]) {
        _setSize(tester, size);
        await tester.pumpWidget(_desktopHarness(model));
        await tester.pumpAndSettle();
        expect(
          find.byType(MobileShell),
          findsNothing,
          reason: '宽度 ${size.width} 不得进手机壳',
        );
        expect(
          find.byType(TabletShell),
          findsNothing,
          reason: '宽度 ${size.width} 不得进平板壳',
        );
      }
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('视口×数据状态矩阵抽样', () {
    testWidgets('360×800 手机 · 空态：底部导航五入口、迷你栏不进树', (tester) async {
      _setSize(tester, const Size(360, 800));
      final model = AppModel();
      await tester.pumpWidget(_shellHarness(model, MobileShell(model: model)));
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 5);
      expect(find.byType(MiniPlayerBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360×800 手机 · 有歌：迷你播放栏可见', (tester) async {
      _setSize(tester, const Size(360, 800));
      final model = _songModel();
      await tester.pumpWidget(_shellHarness(model, MobileShell(model: model)));
      await tester.pumpAndSettle();

      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('600×900 平板 · 空态：图标 Rail 档', (tester) async {
      _setSize(tester, const Size(600, 900));
      final model = AppModel();
      await tester.pumpWidget(_shellHarness(model, TabletShell(model: model)));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('600×900 平板 · 有歌：Rail + 迷你播放栏', (tester) async {
      _setSize(tester, const Size(600, 900));
      final model = _songModel();
      await tester.pumpWidget(_shellHarness(model, TabletShell(model: model)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768×1024 平板 · 图标 Rail 档（600-899）；右栏浮层', (tester) async {
      _setSize(tester, const Size(768, 1024));
      final model = AppModel();
      await tester.pumpWidget(_shellHarness(model, TabletShell(model: model)));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      // 768 < 900：图标 Rail 档（extended=false 属 900+ 双栏档）。
      expect(rail.extended, isFalse);
      // 队列面板打开：浮层（有 Positioned 祖先）。
      await tester.tap(find.byTooltip('队列面板'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsWidgets,
      );
    });

    testWidgets('1024×1024 平板 · 展开 Rail 档；有歌迷你栏常驻', (tester) async {
      _setSize(tester, const Size(1024, 1024));
      final model = _songModel();
      await tester.pumpWidget(_shellHarness(model, TabletShell(model: model)));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('断点穿越：旋转/拖窗跨档状态不丢', () {
    testWidgets('导航目的地跨 600 档保持；播放曲目不重置', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _songModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 手机档：底部导航切到「下载」（第 5 主入口）。
      await tester.tap(find.text('下载'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );

      // 拖窗跨档到平板（900 宽）：目的地保持「下载」。
      _setSize(tester, const Size(900, 1024));
      await tester.pumpAndSettle();
      expect(find.byType(TabletShell), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        4,
        reason: '跨档后导航目的地不丢（TouchShellSession）',
      );
      // 播放真源在 AppModel：跨档不重置。
      expect(model.state.playback.positionMs, BigInt.from(42000));
      expect(find.byType(MiniPlayerBar), findsOneWidget);

      // 旋转（600×900 → 900×600）：仍在平板档升入展开 Rail（双栏档），
      // 目的地与迷你栏保持。高度 600 高于桌面窗口最小高 480，页面按
      // 桌面口径正常布局。
      _setSize(tester, const Size(900, 600));
      await tester.pumpAndSettle();
      expect(find.byType(TabletShell), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        4,
      );
      expect(find.byType(MiniPlayerBar), findsOneWidget);

      // 再拖回手机档（390 宽）：目的地继续保持。
      _setSize(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.byType(MobileShell), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
    });

    testWidgets('全屏播放页跨档保持打开', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _songModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 点迷你播放栏开全屏。
      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);

      // 跨档到平板：全屏页仍打开（nowPlayingOpen 在 session）。
      _setSize(tester, const Size(900, 1024));
      await tester.pumpAndSettle();
      expect(find.byType(TabletShell), findsOneWidget);
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);

      // 跨回手机档：全屏页仍打开。
      _setSize(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
