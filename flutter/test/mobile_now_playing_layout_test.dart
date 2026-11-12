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
/// - 全屏封面 280-340dp 自适应带（§5.7:446-447，Phase 4）：三视口带内，
///   极矮视口收缩让位控制行且不溢出（宽度守卫）。
///
/// 真机 edge-to-edge/手势导航/刘海验证受 P1-06 环境阻断维持未验证；
/// 本文件只锁定 widget 层可测的分层语义。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_player_controls.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
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

  group('全屏封面 280-340dp 自适应带（§5.7:446-447，Phase 4）', () {
    void seedSong(AppModel model) {
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 42000,
        durationMs: 244000,
      );
    }

    Future<void> openFullscreen(WidgetTester tester) async {
      nowPlayingRequest.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
    }

    testWidgets('三视口封面落在目标带 [280, 340]（360 宽受限取上限-40）', (tester) async {
      for (final screen in const [
        Size(360, 800),
        Size(390, 844),
        Size(430, 932),
      ]) {
        _setSize(tester, screen);
        final model = AppModel();
        seedSong(model);
        await _pumpShell(tester, model, insets);
        await openFullscreen(tester);

        final size = tester.getSize(find.byType(CrossfadeCover));
        final widthCap = screen.width - 40;
        // 带断言：宽度充足时命中 [280, 340]；360 宽视口受宽度守卫封顶 320。
        final expected = math.min(340.0, widthCap);
        expect(
          size.height,
          expected,
          reason: '$screen：封面高度 = min(340, maxWidth-40)（高度充足）',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(280.0),
          reason: '$screen：目标带下限',
        );
        expect(size.height, lessThanOrEqualTo(340.0), reason: '$screen：目标带上限');
        expect(size.width, size.height, reason: '封面为正方形');
        expect(tester.takeException(), isNull, reason: '$screen：不得溢出');
      }
    });

    testWidgets('极矮视口（430×560）回退分支封面 240，控制行在树不溢出', (tester) async {
      const screen = Size(430, 560);
      _setSize(tester, screen);
      final model = AppModel();
      seedSong(model);
      await _pumpShell(tester, model, insets);
      await openFullscreen(tester);

      // 可用高 560-24=536 < 560 → 滚动回退分支固定封面 240。
      final size = tester.getSize(find.byType(CrossfadeCover));
      expect(size.height, 240.0, reason: '回退分支固定封面 240');
      // 控制行仍在树，且无 RenderFlex 溢出。
      expect(find.byIcon(Icons.skip_next), findsWidgets);
      expect(tester.takeException(), isNull, reason: '不得溢出');
    });

    testWidgets('矮视口（430×680）收缩分支：封面 = min(可用高-330, 340, 宽-40)', (
      tester,
    ) async {
      const screen = Size(430, 680);
      _setSize(tester, screen);
      final model = AppModel();
      seedSong(model);
      await _pumpShell(tester, model, insets);
      await openFullscreen(tester);

      // 全屏页独占整屏：SafeArea 吃掉上下 inset，顶栏再占 52 →
      // _CoverLayer 可用高 = 屏高 − top − bottom − 52 = 588 ≥ 560（非回退）。
      final size = tester.getSize(find.byType(CrossfadeCover));
      final maxHeight = screen.height - insets.top - insets.bottom - 52;
      final expected = math.min(
        math.min(maxHeight - 330, 340.0),
        screen.width - 40,
      );
      expect(
        size.height,
        expected,
        reason: '收缩分支：封面 = min(可用高-330, 340, 可用宽-40)，让位控制行',
      );
      expect(find.byIcon(Icons.skip_next), findsWidgets);
      expect(tester.takeException(), isNull, reason: '不得溢出');
    });
  });

  group('VxPlayerControls 触点分档（§11.2 Phase 6）', () {
    Widget controlsHarness({bool? touchTargets}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: VxPlayerControls(
            touchTargets: touchTargets,
            onPlayPause: () {},
          ),
        ),
      ),
    );

    double ctrlExtent(WidgetTester tester, String tooltip) =>
        tester.getSize(find.byTooltip(tooltip)).shortestSide;

    testWidgets('桌面缺省（宿主 isTouchPlatform=false）：渲染零变化（34 圆钮 / 26 图标钮）', (
      tester,
    ) async {
      await tester.pumpWidget(controlsHarness());
      // golden 锁不存在（全仓 0 matchesGoldenFile），以尺寸断言锁桌面
      // 渲染不变：播放圆钮 34；图标 IconButton 34 约束被既有
      // visualDensity.compact 收 8dp → 实际 26（Phase 6 前后一致，
      // 非本阶段引入）。触屏档见下一用例（还原 standard 密度保 48）。
      expect(ctrlExtent(tester, '播放'), 34.0);
      expect(ctrlExtent(tester, '随机播放'), 26.0);
    });

    testWidgets('touchTargets: true 注入：48dp 触点（§11.2 手机目标）', (tester) async {
      await tester.pumpWidget(controlsHarness(touchTargets: true));
      expect(ctrlExtent(tester, '播放'), 48.0);
      expect(ctrlExtent(tester, '随机播放'), 48.0);
    });

    testWidgets(
      'touchTargets 缺省跟随 isTouchPlatform：宿主恒 false（Android 真值 P1-06 未验证）',
      (tester) async {
        // null → isTouchPlatform（宿主 false）→ 34；真机 Android 48dp 分支
        // 受 P1-06 环境阻断维持未验证，不因本测试全绿而改判。
        await tester.pumpWidget(controlsHarness(touchTargets: null));
        expect(ctrlExtent(tester, '播放'), 34.0);
      },
    );
  });
}
