/// 手机壳 inset 分层与全屏播放页遮挡关系（§5.1/§10.1；§5.1 截图目标
/// 三视口 360×800 / 390×844 / 430×932）。
///
/// 锁定的是壳层 InsetLayers 分层契约（android_insets.dart）：
/// - 状态栏 inset 只被 AppBar 消费一次（§10.1 不重复绘制状态栏高度）：
///   AppBar toolbarHeight 恒 56，渲染高度 = 56 + top inset；
/// - body 可用高度 = 屏高 − top − header(56) − miniPlayer(64) −
///   navBar(80) − bottom（bodyHeightFor 同式）；
/// - MiniPlayer 64 ∈ §5.8 60-68，固定于 NavigationBar 上方；
/// - 全屏播放页打开时 MiniPlayer/NavigationBar 整体不进树（§5.1 防双重
///   控制，mobile_shell_test 已锁一次；此处按三视口重复锁定）——因此
///   「遮挡关系」只在壳层成立：全屏页独占整屏，不存在同屏重叠状态。
///
/// 真机 edge-to-edge/手势导航/刘海验证受 P1-06 环境阻断维持未验证；
/// 本文件只锁定 widget 层可测的分层语义。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';

Widget _harness(AppModel model, EdgeInsets insets) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    // 注入系统 inset（对齐 android_insets_layout_test 的 MediaQuery 包装
    // 模式）：MobileShell 的 Scaffold/AppBar/NavigationBar 按真实 inset
    // 语义消费。
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: insets),
        child: MobileShell(model: model),
      ),
    ),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpShell(
  WidgetTester tester,
  AppModel model,
  EdgeInsets insets,
) async {
  await tester.pumpWidget(_harness(model, insets));
  await tester.pumpAndSettle();
}

/// 壳层分层断言：header 渲染高 = 56 + top（无重复状态栏高度），
/// body 高 = 屏高 − top − 56 − miniPlayer − 80 − bottom。
Future<void> _expectLayeredLayout(
  WidgetTester tester, {
  required Size screen,
  required EdgeInsets insets,
  required bool hasSong,
}) async {
  final top = insets.top;
  final bottom = insets.bottom;
  final miniPlayerHeight = hasSong ? 64.0 : 0.0;

  // §10.1：AppHeader toolbarHeight 恒 56（不把状态栏高度画进 header）。
  final appBar = tester.widget<AppBar>(find.byType(AppBar));
  expect(appBar.toolbarHeight, 56);

  final header = tester.getSize(find.byType(AppBar)).height;
  expect(header, 56 + top, reason: 'AppHeader 渲染高 = 56 + top inset，不得重复加状态栏高度');

  final bodyHeight = tester.getSize(find.byType(IndexedStack)).height;
  expect(
    bodyHeight,
    screen.height - top - 56 - miniPlayerHeight - 80 - bottom,
    reason: 'body 可用高度必须等于 InsetLayers.bodyHeightFor 的分层期望',
  );

  if (hasSong) {
    expect(
      tester.getSize(find.byType(MiniPlayerBar)).height,
      64,
      reason: 'MiniPlayer 高 64 ∈ §5.8 60-68，固定于 NavigationBar 上方',
    );
    final miniTop = tester.getTopLeft(find.byType(MiniPlayerBar)).dy;
    final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
    expect(miniTop, lessThan(navTop), reason: 'MiniPlayer 必须在底栏上方');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const insets = EdgeInsets.only(top: 24, bottom: 16);

  group('壳层 InsetLayers 分层 × §5.1 截图目标三视口', () {
    for (final screen in const [
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('${screen.width}×${screen.height}：有歌分层', (tester) async {
        _setSize(tester, screen);
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
        await _pumpShell(tester, model, insets);
        await _expectLayeredLayout(
          tester,
          screen: screen,
          insets: insets,
          hasSong: true,
        );
      });

      testWidgets('${screen.width}×${screen.height}：无歌不保留空白高度', (tester) async {
        _setSize(tester, screen);
        await _pumpShell(tester, AppModel(), insets);
        expect(find.byType(MiniPlayerBar), findsNothing);
        await _expectLayeredLayout(
          tester,
          screen: screen,
          insets: insets,
          hasSong: false,
        );
      });
    }
  });

  group('全屏播放页独占整屏（§5.1 防双重控制，三视口）', () {
    for (final screen in const [
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('${screen.width}×${screen.height}：开全屏后底栏/迷你栏不进树', (
        tester,
      ) async {
        _setSize(tester, screen);
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
        await _pumpShell(tester, model, insets);
        expect(find.byType(MiniPlayerBar), findsOneWidget);

        nowPlayingRequest.value = true;
        await tester.pumpAndSettle();
        expect(nowPlayingRequest.value, isFalse);
        expect(find.byType(MobileNowPlayingPage), findsOneWidget);
        // MiniPlayer/NavigationBar 随壳整体退出树：不存在同屏重叠遮挡。
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(MiniPlayerBar), findsNothing);

        // 返回恢复壳层与分层。
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        await _expectLayeredLayout(
          tester,
          screen: screen,
          insets: insets,
          hasSong: true,
        );
      });
    }
  });
}
