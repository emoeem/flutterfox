/// Phase 6 桌面三栏规格对齐测试（§12.3:1012「右侧栏开关和窗口缩放」）：
///
/// - 断点常量回归（§7.1 侧栏 240–300 拖调带 / §7.4 右栏 300–420 默认 340 /
///   §7.5 播放栏 76–84 取 84）；
/// - 侧栏折叠开关（展开↔折叠 + 折叠态展开钮）与拖调宽度钳制、
///   SharedPreferences 记忆（重启恢复）；
/// - AppHeader 品牌区宽度同源（拖调/折叠后字标显隐跟随真实宽度）；
/// - 右栏开关/默认 340/把手钳 300–420；
/// - P1-14：右簇贴右缘（1024 与 1920 两宽位置断言）；
/// - P2-11：空态 PlayerBar 常驻且不保留不可点击的假控件；
/// - Esc 链：全屏 > 降级侧栏浮层 > 右栏 > 路由；关全屏不停播、重开回原页；
/// - 窗口缩放 1024/1150/1280/1440/1920 三栏不变式无溢出。
///
/// harness 沿用 shell_test.dart（MultiProvider + AppModel debugSet*，
/// 不起 Rust 控制器）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_player_controls.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';
import 'package:voicefox_flutter/src/player/progress_control.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';
import 'package:voicefox_flutter/src/shell/app_sidebar.dart';
import 'package:voicefox_flutter/src/shell/context_panel.dart';
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
    child: MaterialApp(home: VoicefoxShell(model: model)),
  );
}

AppModel _modelWithSong() {
  final model = AppModel();
  // 摆一首暂停曲目（paused：不启动 LivePlayback 周期定时器）。
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

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

double _sidebarWidth(WidgetTester tester) => tester
    .getSize(
      find
          .ancestor(
            of: find.byType(AppSidebar),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    )
    .width;

Future<void> _openContextPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('正在播放面板'));
  await tester.pumpAndSettle();
}

/// 水平拖把手（mouse 指针：无 touch slop 丢步，delta 全额送达）。
Future<void> _dragHandleX(WidgetTester tester, Finder finder, double dx) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // SettingsProvider 构造即读 prefs；测试注入内存实现。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('断点常量回归（§7.1/§7.4/§7.5 Phase 6 对齐）', () {
    test('侧栏 240–300 带与折叠 72', () {
      expect(ShellBreakpoints.sidebarMinWidth, 240);
      expect(ShellBreakpoints.sidebarMaxWidth, 300);
      expect(ShellBreakpoints.sidebarWidth, 240);
      expect(ShellBreakpoints.sidebarCollapsedWidth, 72);
    });

    test('右栏 300–420 可拖调、默认 340', () {
      expect(ShellBreakpoints.contextDefaultWidth, 340);
      expect(ShellBreakpoints.contextMinWidth, 300);
      expect(ShellBreakpoints.contextMaxWidth, 420);
    });

    test('播放栏高度带 76–84 取 84（§7.5）', () {
      expect(ShellBreakpoints.playerBarHeight, 84);
    });

    test('断点分档行为不受常量变更影响（1440 三栏内嵌/1200 浮层/960 折叠）', () {
      final three = resolveShellMetrics(1440, contextOpen: true);
      expect(three.sidebar, SidebarMode.expanded);
      expect(three.context, ContextPanelMode.inline);
      final overlay = resolveShellMetrics(1200, contextOpen: true);
      expect(overlay.sidebar, SidebarMode.expanded);
      expect(overlay.context, ContextPanelMode.overlay);
      final collapsed = resolveShellMetrics(960, contextOpen: true);
      expect(collapsed.sidebar, SidebarMode.collapsed);
      expect(
        resolveShellMetrics(959, contextOpen: true).sidebar,
        SidebarMode.hidden,
      );
    });
  });

  group('侧栏折叠开关与宽度记忆（§7.2 最小语义）', () {
    testWidgets('1440 默认展开 240，折叠钮收起 72、展开钮还原', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      expect(_sidebarWidth(tester), 240);
      expect(find.text('VOICEFOX'), findsOneWidget);

      await tester.tap(find.byTooltip('折叠侧栏'));
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), 72);
      // Header 品牌区同源：折叠后字标隐藏（app_header 按 sidebarWidth<240 判定）。
      expect(find.text('VOICEFOX'), findsNothing);

      await tester.tap(find.byTooltip('展开侧栏'));
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), 240);
      expect(find.text('VOICEFOX'), findsOneWidget);
    });

    testWidgets('拖调把手 240→300 钳制、反向到 240 下沿，字标保持', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 右拖 80px：240+80=320 → 钳到 300 上沿。
      await _dragHandleX(
        tester,
        find.byKey(const ValueKey('sidebar-resize-handle')),
        80,
      );
      expect(_sidebarWidth(tester), 300);
      // 品牌区同源宽度：拖到 300 字标仍可见（AppHeader 同一消费值）。
      expect(find.text('VOICEFOX'), findsOneWidget);

      // 左拖 100px：300-100=200 → 钳到 240 下沿（方向镜像：向左为收窄）。
      await _dragHandleX(
        tester,
        find.byKey(const ValueKey('sidebar-resize-handle')),
        -100,
      );
      expect(_sidebarWidth(tester), 240);
    });

    testWidgets('折叠与宽度记忆重启恢复（SharedPreferences）', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 右拖 50px → 记忆宽度 290（clamp 240–300 内原值）。
      await _dragHandleX(
        tester,
        find.byKey(const ValueKey('sidebar-resize-handle')),
        50,
      );
      expect(_sidebarWidth(tester), 290);
      await tester.tap(find.byTooltip('折叠侧栏'));
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), 72);

      // 重启：新 Shell 实例从 prefs 恢复用户值（仍折叠）。
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), 72);

      // 展开后恢复记忆宽度 290（不是断点默认 240）。
      await tester.tap(find.byTooltip('展开侧栏'));
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), 290);
      expect(find.text('VOICEFOX'), findsOneWidget);
    });

    testWidgets('960–1199 规格硬带：强制折叠 72、无折叠开关（用户 override 不进此档）', (
      tester,
    ) async {
      _setSize(tester, const Size(1024, 768));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      expect(_sidebarWidth(tester), 72);
      expect(find.text('VOICEFOX'), findsNothing);
      // 硬带无展开钮：1024 展开态实测 Header 溢出 21px（2026-11-13），故
      // §3.1 折叠档不接受用户 override（矩阵登记）。
      expect(find.byTooltip('展开侧栏'), findsNothing);
      expect(find.byTooltip('折叠侧栏'), findsNothing);
    });

    testWidgets('<960 降级浮层侧栏跟随记忆宽度，无拖调把手', (tester) async {
      _setSize(tester, const Size(800, 600));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar-resize-handle')), findsNothing);
    });
  });

  group('右栏 ContextPanel（§7.4）', () {
    testWidgets('默认宽 340、把手钳 300–420', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await _openContextPanel(tester);
      expect(tester.widget<ContextPanel>(find.byType(ContextPanel)).width, 340);

      // 右拖 60（把手在左缘，右拖收窄）：340-60=280 → 钳下沿 300。
      await _dragHandleX(
        tester,
        find.byKey(const ValueKey('context-resize-handle')),
        60,
      );
      expect(tester.widget<ContextPanel>(find.byType(ContextPanel)).width, 300);

      // 左拖 300（把手在左缘，左拖加宽）：300+300=600 → 钳上沿 420。
      await _dragHandleX(
        tester,
        find.byKey(const ValueKey('context-resize-handle')),
        -300,
      );
      expect(tester.widget<ContextPanel>(find.byType(ContextPanel)).width, 420);
    });
  });

  group('P1-14 右簇贴右缘 + P2-11 空态常驻', () {
    testWidgets('1024 与 1920 两宽：右簇最右控件距播放栏右缘 < 32px', (tester) async {
      final model = _modelWithSong();
      // 1024：侧栏折叠 72、右区收起 输出/更多（<1060），最右为队列钮。
      _setSize(tester, const Size(1024, 768));
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(
        tester.view.physicalSize.width -
            tester.getRect(find.byTooltip('队列')).right,
        lessThan(32),
        reason: 'P1-14：1024 宽右簇应贴播放栏右缘（右内边距 12 + 容差）',
      );

      // 1920：全量右区（音量/输出/歌词/队列/更多），最右为「更多」钮。
      _setSize(tester, const Size(1920, 1080));
      await tester.pumpAndSettle();
      expect(
        tester.view.physicalSize.width -
            tester.getRect(find.byTooltip('更多')).right,
        lessThan(32),
        reason: 'P1-14：1920 宽右簇应贴播放栏右缘（右内边距 12 + 容差）',
      );
      // 播放栏高度 ∈ §7.5 76–84 带（实现取 84）。
      expect(tester.getRect(find.byType(PlayerBar)).height, 84);
    });

    testWidgets('空态：PlayerBar 常驻、空态提示在、禁用假控件不进树（P2-11）', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.text('选择一首歌曲开始播放'), findsOneWidget);
      // §7.5「不保留不可点击的假控件」：无歌曲时传输控制与进度行不进树。
      expect(find.byType(VxPlayerControls), findsNothing);
      expect(find.byType(LiveSeekRow), findsNothing);
      // 右区真实可用控件仍在（音量/歌词/队列）。
      expect(find.byTooltip('歌词'), findsOneWidget);
      expect(find.byTooltip('队列'), findsOneWidget);
    });
  });

  group('Esc 链（§4.3 先关最上层弹层/面板）', () {
    testWidgets('全屏优先：右栏开着时 Esc 只关全屏、播放状态不变、重开回原页', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _modelWithSong();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await _openContextPanel(tester);
      expect(find.byType(ContextPanel), findsOneWidget);

      // 经真实导航总线打开全屏播放页。
      nowPlayingRequest.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // 只关全屏：右栏仍在，播放真源不变（不停播）。
      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.byType(ContextPanel), findsOneWidget);
      expect(model.state.playback.song?.name, '夜航');
      expect(model.state.playback.state, 'paused');

      // 重开回原页（全屏页再次可用）。
      nowPlayingRequest.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsOneWidget);

      // 第二次 Esc 关全屏后再一次关右栏，最后才轮到路由（无路由可弹，壳保持）。
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsNothing);
      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.byType(PlayerBar), findsOneWidget);
    });

    testWidgets('<960：降级侧栏浮层在右栏之上，Esc 先关浮层', (tester) async {
      _setSize(tester, const Size(800, 600));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 先开右栏（浮层），再开侧栏浮层（Stack 更上层）。
      await _openContextPanel(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(ContextPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(ContextPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsNothing);
    });
  });

  group('窗口缩放三栏不变式（§12.4 桌面五视口）', () {
    for (final width in [1024.0, 1150.0, 1280.0, 1440.0, 1920.0]) {
      testWidgets('${width.toInt()}：无溢出、PlayerBar 84 高常驻、右簇贴右缘', (
        tester,
      ) async {
        _setSize(tester, Size(width, 900));
        final model = _modelWithSong();
        await tester.pumpWidget(_harness(model));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PlayerBar), findsOneWidget);
        expect(tester.getRect(find.byType(PlayerBar)).height, 84);
        // 右簇最右控件贴右缘（P1-14 不变式跨视口成立）。
        final rightmost = find.byTooltip('更多').evaluate().isNotEmpty
            ? find.byTooltip('更多')
            : find.byTooltip('队列');
        expect(width - tester.getRect(rightmost).right, lessThan(32));
      });
    }
  });
}
