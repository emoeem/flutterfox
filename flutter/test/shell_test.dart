/// Phase 2 Shell widget 测试：
/// - Shell 渲染（PlayerBar 存在、Sidebar 5 一级入口、Header 搜索框）；
/// - 断点形态切换（1440 三栏内嵌 / 1200 右栏浮层 / 960-1199 侧栏折叠 /
///   <960 降级隐藏）；
/// - 页面切换后 PlayerBar 仍在、播放状态不重置（IndexedStack + AppModel 真源）。
///
/// 不起 Rust 控制器：AppModel 用空状态 + debugSet* 钩子；dispatch 在无控制
/// 器时安全返回错误串，页面自身的加载请求不会影响测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';
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

  group('resolveShellMetrics 断点规则', () {
    test('≥1440 三栏内嵌，≥1600 内边距 32', () {
      final m = resolveShellMetrics(1440, contextOpen: true);
      expect(m.sidebar, SidebarMode.expanded);
      expect(m.context, ContextPanelMode.inline);
      expect(m.contentPadding, 28);
      expect(
        resolveShellMetrics(1600, contextOpen: true).contentPadding,
        32,
      );
    });

    test('1200–1439：侧栏展开、右栏浮层', () {
      final m = resolveShellMetrics(1300, contextOpen: true);
      expect(m.sidebar, SidebarMode.expanded);
      expect(m.context, ContextPanelMode.overlay);
      expect(m.contentPadding, 28);
    });

    test('960–1199：侧栏折叠 72、右栏浮层', () {
      final m = resolveShellMetrics(1000, contextOpen: true);
      expect(m.sidebar, SidebarMode.collapsed);
      expect(m.context, ContextPanelMode.overlay);
      expect(m.contentPadding, 20);
      expect(resolveShellMetrics(959, contextOpen: true).sidebar,
          SidebarMode.hidden);
    });

    test('<960：降级布局侧栏隐藏', () {
      final m = resolveShellMetrics(800, contextOpen: false);
      expect(m.sidebar, SidebarMode.hidden);
      expect(m.context, ContextPanelMode.overlay);
      expect(m.contentPadding, 20);
    });
  });

  group('Shell 渲染与断点', () {
    testWidgets('渲染：PlayerBar 常驻、侧栏 5 一级入口、Header 搜索框、右栏默认关闭',
        (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerBar), findsOneWidget);
      // 侧栏 5 个一级入口（探索组 3 项 + 我的音乐 + 底部下载）。
      for (final label in ['首页', '发现', '搜索', '我的音乐', '下载']) {
        expect(
          find.descendant(of: find.byType(AppSidebar), matching: find.text(label)),
          findsWidgets,
          reason: '侧栏缺少一级入口：$label',
        );
      }
      // Header 唯一搜索框。
      expect(find.text('搜索歌曲、专辑、歌手或歌单'), findsOneWidget);
      // 播放栏空态（无曲目时布局稳定）。
      expect(find.text('选择一首歌曲开始播放'), findsOneWidget);
      // 右栏默认关闭。
      expect(find.byType(ContextPanel), findsNothing);
    });

    testWidgets('1440：打开右栏为内嵌；缩到 1200 变覆盖式浮层', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.album_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsOneWidget);
      // 内嵌：无 Positioned 祖先（在 Row 里）。
      expect(
        find.ancestor(
          of: find.byType(ContextPanel),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );

      // 缩窗到 1200–1439：面板转浮层（Positioned 覆盖）。
      _setSize(tester, const Size(1200, 800));
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

    testWidgets('960–1199：侧栏折叠态（collapsed=true、纯图标）', (tester) async {
      _setSize(tester, const Size(1024, 768));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      final sidebar = tester.widget<AppSidebar>(find.byType(AppSidebar));
      expect(sidebar.collapsed, isTrue);
      expect(find.byType(PlayerBar), findsOneWidget);
      // 右栏未打开时不出现。
      expect(find.byType(ContextPanel), findsNothing);
    });

    testWidgets('<960：降级布局隐藏侧栏，菜单按钮浮出导航', (tester) async {
      _setSize(tester, const Size(800, 600));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      // 播放栏仍常驻（Phase 0 F2）。
      expect(find.byType(PlayerBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);
    });

    testWidgets('600 窄窗：播放栏常驻且无横向溢出异常', (tester) async {
      _setSize(tester, const Size(600, 600));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('页面切换与播放隔离', () {
    testWidgets('切换页面后 PlayerBar 仍在、曲目与进度不重置', (tester) async {
      _setSize(tester, const Size(1440, 900));
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
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 时长可读：显示真实总时长 04:04（P0-F1 不再是 00:00/--:-- 伪造）。
      expect(find.text('04:04'), findsOneWidget);

      // 从首页切到「我的音乐」（侧栏导航行文字；组标签与导航行同名，
      // 取文档序最后的导航行）。
      await tester.tap(
        find.descendant(of: find.byType(AppSidebar), matching: find.text('我的音乐')).last,
      );
      await tester.pumpAndSettle();
      // 我的音乐页出现（Phase 5 入口卡；页面标题与侧栏同名，改用
      // 仅曲库页才有的「喜欢的歌曲」入口文本断言）。
      expect(find.text('喜欢的歌曲'), findsOneWidget);
      // 播放栏与曲目保持。
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.text('夜航'), findsOneWidget);
      expect(find.text('04:04'), findsOneWidget);

      // 再切到「下载」，播放栏仍常驻。
      await tester.tap(find.text('下载'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.text('夜航'), findsOneWidget);
      // 后退导航可用（Header 历史栈生效）。
      await tester.tap(find.byTooltip('后退'));
      await tester.pumpAndSettle();
      expect(find.text('喜欢的歌曲'), findsOneWidget);
    });

    testWidgets('Header 面板开关：歌词/队列 Tab 打开对应右栏', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('队列面板'));
      await tester.pumpAndSettle();
      expect(find.text('队列为空'), findsOneWidget);

      await tester.tap(find.byTooltip('歌词面板'));
      await tester.pumpAndSettle();
      // Phase 3 LyricsPanel 区分「未在播放」（无曲）与「暂无歌词」（有曲无数据）；
      // PlayerBar 空态标题同为「未在播放」，共 2 处。
      expect(find.text('未在播放'), findsNWidgets(2));

      // 同一 Tab 再点一次为关闭。
      await tester.tap(find.byTooltip('歌词面板'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextPanel), findsNothing);
    });
  });
}
