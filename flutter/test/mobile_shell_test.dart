/// Phase 7 手机壳与迷你播放栏 widget 测试（计划书 Phase 7 批次验收）。
///
/// 覆盖（批次验收三点 + MiniPlayerBar 四点）：
/// - 底部导航切换目的地与桌面 IndexedStack 等价：切页不重置播放；
/// - navRequest / nowPlayingRequest 在手机壳内同样被消费（总线复位）；
/// - 手机上存在可达的设置与帮助入口（顶栏「更多」→ AppSidebar 抽屉，
///   侧栏底部二级页语义）；
/// - MiniPlayerBar：无歌不可见、有歌可见、点击经 nowPlayingRequest 打开
///   全屏播放页、控制接 AppModel 真实命令（_RecordingModel 断言）。
///
/// 平台口径：FLUTTER_TEST 下 defaultTargetPlatform 被强制 android，禁止
/// 用它做壳分支；本文件直接 pump MobileShell（对齐 shell_test.dart 既有
/// 模式）。桌面零回归由 shell_test.dart 全量覆盖（isTouchPlatform 在
/// 宿主测试环境恒 false，桌面壳分支不进移动壳）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/shell/app_sidebar.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';

/// 记录命令的 AppModel：真实命令路径 + 可断言（对齐 now_playing_test）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

Widget _harness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: MobileShell(model: model)),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    // SettingsProvider 构造即读 prefs；测试注入内存实现。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MobileShell 渲染与导航', () {
    testWidgets('渲染：底部导航五主入口、迷你播放栏无歌不可见', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 5);
      // 五主入口与桌面侧栏同源（首页/发现/搜索/我的音乐/下载）。
      expect(bar.selectedIndex, 0);
      // 无歌：迷你播放栏不进树。
      expect(find.byType(MiniPlayerBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('底部导航切页不重置播放：迷你播放栏与曲目持续存在', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      // 摆一首暂停曲目（paused 不启动 LivePlayback 周期定时器）。
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

      expect(find.byType(MiniPlayerBar), findsOneWidget);
      // 首页 Hero 也展示当前曲目，断言限定在迷你播放栏内。
      expect(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
        findsOneWidget,
      );

      // 切到「下载」（底部第 5 个主入口）。
      await tester.tap(find.text('下载'));
      await tester.pumpAndSettle();
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 4);
      // IndexedStack 常驻：迷你播放栏与曲目信息不重置。
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
        findsOneWidget,
      );
      expect(model.state.playback.positionMs, BigInt.from(42000));
    });

    testWidgets('navRequest 在手机壳内被消费：旧索引切页且总线复位', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 旧九入口索引 7 = 设置。
      navRequest.value = 7;
      await tester.pumpAndSettle();
      expect(navRequest.value, isNull);
      // 设置页在 IndexedStack 中呈现；无 Rust 控制器时 config 未加载，
      // 页面如实显示加载态（不伪造设置项）。
      expect(find.text('配置加载中…'), findsOneWidget);
      // 底部导航保持最后一个一级入口高亮（首页，settings 非主入口）。
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
    });

    testWidgets('nowPlayingRequest 被消费：开全屏、壳隐藏、返回恢复', (tester) async {
      _setSize(tester, const Size(390, 844));
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

      nowPlayingRequest.value = true;
      await tester.pumpAndSettle();
      expect(nowPlayingRequest.value, isFalse);
      // 手机壳全屏页为 MobileNowPlayingPage（封面/歌词/队列分层）。
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
      expect(find.byType(NowPlayingPage), findsNothing);
      // §5.1 防双重控制：全屏打开时底部导航与迷你播放栏随壳隐藏。
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(MiniPlayerBar), findsNothing);

      // 全屏页返回按钮关闭，回到手机壳。
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
    });

    testWidgets('设置与帮助可达：顶栏更多 → AppSidebar 抽屉 → 二级页', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 顶栏「更多」打开抽屉，抽屉复用完整 AppSidebar。
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);

      // 侧栏底部「设置」行 → 设置页（抽屉关闭）。
      await tester.tap(
        find
            .descendant(of: find.byType(AppSidebar), matching: find.text('设置'))
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsNothing);
      // 无控制器时设置页如实显示加载态（不伪造设置项）。
      expect(find.text('配置加载中…'), findsOneWidget);

      // 再开抽屉进「帮助」页。
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(of: find.byType(AppSidebar), matching: find.text('帮助'))
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('功能地图'), findsOneWidget);
    });
  });

  group('MiniPlayerBar 交互', () {
    testWidgets('点击经 nowPlayingRequest 打开全屏播放页', (tester) async {
      _setSize(tester, const Size(390, 844));
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

      // 点歌名区域（避开行尾控制按钮；限定迷你播放栏内的文本）。
      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
      expect(nowPlayingRequest.value, isFalse);
    });

    testWidgets('控制接 AppModel 真实命令：播放暂停与下一首', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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

      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pump();
      expect(
        model.commands.contains(const bridge.FfiCommand.toggle()),
        isTrue,
        reason: '播放/暂停必须走真实 FfiCommand.toggle',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byIcon(Icons.skip_next),
        ),
      );
      await tester.pump();
      expect(
        model.commands.contains(const bridge.FfiCommand.next()),
        isTrue,
        reason: '下一首必须走真实 FfiCommand.next',
      );
    });
  });
}
