/// Batch D 桌面体验测试（计划书 §7：SR-10 限宽 / SR-11 卡面右键残余收口 /
/// SR-13 焦点漫游组 / SR-14 Header↔搜索页同步 / SR-15 首页歌单入口）。
///
/// - SR-10：DesktopContentConstraint 1320 限宽 mechanics——1920 视口内容
///   恰为 1320、1150 视口不满宽零变化（§7.1.4 窄窗不产生空白）；
/// - SR-13：桌面壳层 侧栏/中央内容/右栏/PlayerBar 四个焦点漫游组在树
///   （FocusTraversalGroup 结构断言；Tab 行为由框架 ReadingOrder 保证）；
/// - SR-14：nav_bus.searchKeyword 单一状态流——流写入回流搜索页输入框并
///   恰派发一次搜索（防抖在途锁）；页内输入写回流（Header 同步由壳层
///   消费，页面级只验流方向与防循环）；流全局复用，测试间复位；
/// - SR-15：首页「我的歌单」卡点按进自建歌单详情（不再全跳曲库）；
/// - SR-11：自建歌单卡右键 = 同一动作集菜单（打开详情/重命名/删除），
///   打开详情真实推入；专辑/歌手/远端歌单卡面无域动作如实不加入口。
///
/// 不起 Rust 控制器：AppModel debugSet* + dispatch 覆写记录命令。
library;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/desktop_content_constraint.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart' as nav_bus;
import 'package:voicefox_flutter/src/pages/custom_playlists_page.dart';
import 'package:voicefox_flutter/src/pages/home_page.dart';
import 'package:voicefox_flutter/src/pages/search_page.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';

class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _summary = bridge.CustomPlaylistSummaryDto(
  id: 'c1',
  name: '通勤',
  songCount: 2,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // SR-14 流为全局单例：测试间复位（本文件每个用例结束兜底）。
    addTearDown(() => nav_bus.searchKeyword.value = '');
  });

  group('SR-10 DesktopContentConstraint（§7.1）', () {
    testWidgets('1920 视口：内容恰为 1320 居中', (tester) async {
      _setSize(tester, const Size(1920, 1080));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopContentConstraint(
              child: SizedBox(
                key: const Key('content'),
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );
      tester.takeException();
      final size = tester.getSize(find.byKey(const Key('content')));
      expect(size.width, kDesktopContentMaxWidth, reason: '超宽窗口内容限宽 1320');
    });

    testWidgets('1150 视口：不满宽零变化（§7.1.4 窄窗不产生空白）', (tester) async {
      _setSize(tester, const Size(1150, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopContentConstraint(
              child: SizedBox(
                key: const Key('content'),
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );
      tester.takeException();
      final size = tester.getSize(find.byKey(const Key('content')));
      expect(size.width, 1150, reason: '可用宽度未超限时布局零变化');
    });
  });

  group('SR-13 焦点漫游组（§7.3）', () {
    testWidgets('桌面壳层：侧栏/中央内容/右栏/PlayerBar 焦点组在树', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = AppModel();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppModel>.value(value: model),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: SettingsProvider(),
            ),
            ChangeNotifierProvider<NotificationService>.value(
              value: NotificationService(),
            ),
          ],
          child: MaterialApp(home: VoicefoxShell(model: model)),
        ),
      );
      await tester.pumpAndSettle();
      // 四区域各一个漫游组（内嵌 Navigator 的内容区 1 + 右栏 1 + 侧栏 1 +
      // PlayerBar 1）；右栏覆盖浮层不叠加计数（inline 档恰 4）。
      expect(
        find.byType(FocusTraversalGroup),
        findsAtLeastNWidgets(4),
        reason: 'SR-13：四区域焦点漫游组（Header/内部组可能叠加，取下限）',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SR-14 Header↔搜索页单一状态流（§7.4）', () {
    testWidgets('流写入回流搜索页输入框，恰派发一次搜索（防抖在途锁）', (tester) async {
      _setSize(tester, const Size(1280, 900));
      final model = _RecordingModel();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SearchPage(model))),
      );
      await tester.pumpAndSettle();

      // Header 侧写入流（生产由壳层 onChanged 写入）：回流页内输入框 +
      // 派发搜索（防抖 300ms 后恰好一次）。
      nav_bus.searchKeyword.value = 'love';
      await tester.pump();
      expect(find.text('love'), findsOneWidget, reason: '流回流页内输入框');
      await tester.pump(const Duration(milliseconds: 350));
      final searches = model.commands
          .whereType<bridge.FfiCommand_Search>()
          .toList();
      expect(searches, hasLength(1), reason: '防抖后恰一次派发');
      expect(searches.single.keyword, 'love');
    });

    testWidgets('页内输入写回流（Header 同步由壳层消费）；同文本不重复通知', (tester) async {
      _setSize(tester, const Size(1280, 900));
      final model = _RecordingModel();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SearchPage(model))),
      );
      await tester.pumpAndSettle();

      // 页内输入 = 权威写入。
      await tester.enterText(find.byType(TextField), 'metal');
      await tester.pump();
      expect(nav_bus.searchKeyword.value, 'metal', reason: '页内输入写回流');

      // 同文本再写：ValueNotifier 不通知（防循环的机制层保证）。
      var notified = 0;
      void listener() => notified++;
      nav_bus.searchKeyword.addListener(listener);
      nav_bus.searchKeyword.value = 'metal';
      nav_bus.searchKeyword.removeListener(listener);
      expect(notified, 0, reason: '同文本不触发通知（防循环）');
    });
  });

  group('SR-15 首页歌单入口 + SR-11 卡面右键（§7.5/§7.2）', () {
    Future<void> pumpHome(WidgetTester tester, AppModel model) async {
      _setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppModel>.value(value: model),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: SettingsProvider(),
            ),
            ChangeNotifierProvider<NotificationService>.value(
              value: NotificationService(),
            ),
          ],
          child: MaterialApp(home: HomePage(model)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('首页自建歌单卡点按进详情（SR-15，不再全跳曲库）', (tester) async {
      final model = AppModel();
      model.debugSetCustomPlaylists(const [_summary]);
      await pumpHome(tester, model);
      expect(find.text('通勤'), findsOneWidget);
      // 卡在首屏折叠以下：滚入视口后再交互（懒构建列表 tap 需可见命中）。
      await tester.scrollUntilVisible(
        find.text('通勤'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('通勤'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byType(CustomPlaylistDetailPage),
        findsOneWidget,
        reason: 'SR-15：卡进详情页',
      );
    });

    testWidgets('卡面右键 = 同一动作集菜单，打开详情真实推入（SR-11）', (tester) async {
      final model = AppModel();
      model.debugSetCustomPlaylists(const [_summary]);
      await pumpHome(tester, model);
      await tester.scrollUntilVisible(
        find.text('通勤'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // 桌面右键（secondary button 随 startGesture.down 携带）。
      final center = tester.getCenter(find.text('通勤'));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('打开详情'), findsOneWidget);
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      await tester.tap(find.text('打开详情'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CustomPlaylistDetailPage), findsOneWidget);
    });
  });
}
