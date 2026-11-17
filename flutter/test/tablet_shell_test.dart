/// Phase 7 平板三态布局与设备形态选择测试（计划书 Phase 7 批次验收）。
///
/// 覆盖（验收三点）：
/// - resolveDeviceFormFactor：桌面平台（isTouch=false）所有宽度恒 desktop，
///   宽度不改变桌面行为；触屏平台按宽度分 手机/平板；
/// - resolveTabletLayout：600/840/1200 三档（NavigationRail / 双栏 / 三栏，
///   §4.1 断点：600–839 窄 rail / 840–1199 展开 rail）；
/// - 触屏平台三档宽度的壳形态断言：rail 档图标 rail + 右栏浮层（有
///   Positioned 祖先）；dual 档展开 rail + 右栏 end panel 内嵌（Phase 6
///   §6.2:546「overlay 或 end panel」取 end panel，中央内容仍可操作
///   §6.3:554，无 Positioned 祖先）；triple 档右栏内嵌（无 Positioned
///   祖先）。1199/1200 边界形态对照（D1 裁决证据）。
///
/// 平台口径：测试直接 pump TabletShell（对齐 shell_test.dart 既有模式），
/// 不依赖 defaultTargetPlatform（FLUTTER_TEST 强制 android，会整体翻掉
/// 桌面基线）；桌面平台不触发平板档由纯函数断言 + shell_test.dart 桌面
/// 全量回归共同保证。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/shell/context_panel.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';
import 'package:voicefox_flutter/src/shell/responsive_shell.dart';

Widget _harness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: TabletShell(model: model)),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('resolveDeviceFormFactor 纯函数', () {
    test('桌面平台（isTouch=false）所有宽度恒 desktop，宽度不参与', () {
      for (final width in [
        320.0,
        599.0,
        600.0,
        900.0,
        1200.0,
        1920.0,
        4000.0,
      ]) {
        expect(
          resolveDeviceFormFactor(width, isTouch: false),
          DeviceFormFactor.desktop,
          reason: '桌面宽度 $width 不得进移动/平板形态',
        );
      }
    });

    test('触屏平台按宽度分档：<600 手机、≥600 平板', () {
      expect(
        resolveDeviceFormFactor(390, isTouch: true),
        DeviceFormFactor.handset,
      );
      expect(
        resolveDeviceFormFactor(599, isTouch: true),
        DeviceFormFactor.handset,
      );
      expect(
        resolveDeviceFormFactor(600, isTouch: true),
        DeviceFormFactor.tablet,
      );
      expect(
        resolveDeviceFormFactor(1280, isTouch: true),
        DeviceFormFactor.tablet,
      );
    });
  });

  group('resolveTabletLayout 纯函数（600/840/1200 三档，§4.1）', () {
    test('<840：rail；840-1199：dual；≥1200：triple', () {
      expect(resolveTabletLayout(600), TabletLayout.rail);
      expect(resolveTabletLayout(839), TabletLayout.rail);
      expect(resolveTabletLayout(840), TabletLayout.dual);
      expect(resolveTabletLayout(899), TabletLayout.dual);
      expect(resolveTabletLayout(1199), TabletLayout.dual);
      expect(resolveTabletLayout(1200), TabletLayout.triple);
      expect(resolveTabletLayout(1920), TabletLayout.triple);
    });
  });

  group('TabletShell 三档宽度形态', () {
    testWidgets('600（rail 档）：NavigationRail 图标档，右栏打开为浮层', (tester) async {
      _setSize(tester, const Size(600, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse, reason: '600-839 为图标 rail 档（§4.1）');
      expect(rail.destinations.length, 5);

      // 右栏打开：浮层（有 Positioned 祖先）。
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

    testWidgets('840（dual 档边界）：展开（带标签）Rail + 内容双栏，右栏 end panel 内嵌', (
      tester,
    ) async {
      _setSize(tester, const Size(840, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue, reason: '840-1199 为展开 Rail 双栏档（§4.1）');

      await tester.tap(find.byTooltip('队列面板'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsOneWidget);
      // Phase 6 §6.2：dual 档右栏为 end panel 内嵌（无 Positioned 祖先），
      // 中央内容仍可操作（§6.3:554）；原先 overlay+scrim 挡中央内容，偏差修复。
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });

    testWidgets('1199/1200 边界（D1 裁决证据）：1199 dual 内嵌 end panel，1200 triple 内嵌', (
      tester,
    ) async {
      final model = AppModel();
      // 1199：dual 档，右栏 end panel 内嵌（与 1200 triple 同形态，
      // 差异仅在 rail extended 语义与断点归属；维持 ≥1200 triple 现状，
      // D1 裁决点留 owner）。
      _setSize(tester, const Size(1199, 900));
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
      await tester.tap(find.byTooltip('歌词面板'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );

      // 1200：triple 档，同为内嵌。
      _setSize(tester, const Size(1200, 900));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
      expect(find.byType(ContextPanel), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });

    testWidgets('1200（triple 档）：右栏内嵌（无 Positioned 祖先）', (tester) async {
      _setSize(tester, const Size(1200, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('队列面板'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsOneWidget);
      // 三栏：内嵌在 Row 里，无 Positioned 祖先。
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });

    testWidgets('平板切页不重置播放（IndexedStack 语义与桌面等价）', (tester) async {
      _setSize(tester, const Size(900, 900));
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
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 有歌：底部迷你播放栏常驻并显示当前曲目。
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
        findsOneWidget,
      );

      // Rail 第 5 项（下载）。
      await tester.tap(find.text('下载').last);
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 4);
      expect(model.state.playback.positionMs, BigInt.from(42000));
      // 切页后迷你播放栏仍在。
      expect(find.byType(MiniPlayerBar), findsOneWidget);
    });
  });
}
