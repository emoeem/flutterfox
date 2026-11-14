/// Phase 7 手机壳 widget 测试（计划书 Phase 7 批次验收 + Phase 2 抽屉收口）。
///
/// 覆盖：
/// - 底部导航切换目的地与桌面 IndexedStack 等价：切页不重置播放；
/// - navRequest / nowPlayingRequest 在手机壳内同样被消费（总线复位）；
/// - 手机原生抽屉（§5.9）：次级入口清单、音源管理 → 设置 sources 分组、
///   高亮塌缩规则（规范目的地行单高亮，塌缩次级行不高亮）、宽度 ≤88%
///   屏宽且 ≤360dp、行触控目标 ≥48dp、底部版本信息；
/// - MiniPlayerBar 交互组已迁至 mini_player_interaction_test.dart。
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
import 'package:voicefox_flutter/src/pages/library_page.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';

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

      // 切到「下载」（底部第 5 个主入口）——限定底栏查找：手机首页快捷
      // 入口也有同名「下载」卡（R5：桌面/移动测试互不污染各自限定范围）。
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('下载'),
        ),
      );
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

    testWidgets('系统返回（PopScope）：全屏打开时返回先退全屏而非退壳', (tester) async {
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
      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // 系统返回路径（顶栏 arrow_back 之外的另一半契约）：PopScope
      // canPop=!nowPlayingOpen，全屏时返回先退全屏。
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MobileNowPlayingPage), findsNothing);
      // 区分「退全屏」与「整路由被弹」：壳目的地导航与迷你播放栏仍在树。
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(find.text('夜航'), findsWidgets);
    });

    testWidgets('窄视口曲库布局：标题单行不折行、各档工具条无横向溢出（Phase 2 QA P1 回归）', (tester) async {
      for (final size in const [
        Size(430, 932), // 缺陷证据视口（fluttertest-library-430x932）。
        Size(390, 844),
        Size(360, 800), // 最窄手机档：专辑/歌手档工具最宽。
      ]) {
        _setSize(tester, size);
        // 每视口独立 harness（根节点换 key 强制重挂载）：pumpWidget 同型
        // 根会原位复用 element 树，上一视口的壳目的地状态会残留。
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('library-narrow-$size'),
            child: _harness(AppModel()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('我的音乐'));
        await tester.pumpAndSettle();

        // 标题限定曲库页内（底栏同名 label 同屏可见，不能全树查找）。
        final title = find.descendant(
          of: find.byType(LibraryPage),
          matching: find.text('我的音乐'),
        );
        // h1 28×1.2 单行高 ≈33.6；折行（「我的音/乐」）≥67.2 即为回归。
        expect(
          tester.getSize(title).height,
          lessThan(45),
          reason: '${size.width} 宽「我的音乐」标题不得折两行',
        );

        // 专辑档工具最宽（搜索 + 排序 + 视图切换 + 刷新）：compact 弹性
        // 搜索条必须收窄容纳（固定 200 在 360 宽此档必溢出）。
        await tester.tap(
          find.descendant(
            of: find.byType(LibraryPage),
            matching: find.text('专辑'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${size.width} 宽专辑档头部溢出',
        );
      }
    });

    testWidgets('设置与帮助可达：顶栏更多 → 手机抽屉 → 二级页', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 顶栏「更多」打开手机原生抽屉（§5.9，非桌面 AppSidebar 复用）。
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);

      // 抽屉「设置」行 → 设置页（抽屉关闭）。
      await tester.tap(
        find
            .descendant(of: find.byType(Drawer), matching: find.text('设置'))
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      // 无控制器时设置页如实显示加载态（不伪造设置项）。
      expect(find.text('配置加载中…'), findsOneWidget);

      // 再开抽屉进「帮助」页。
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(of: find.byType(Drawer), matching: find.text('帮助'))
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('功能地图'), findsOneWidget);
    });

    testWidgets('抽屉 §5.9 清单：音源状态/次级入口/音源管理落点/版本信息', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      model.debugSetSources([
        bridge.SourceCapabilitiesDto(
          id: 'wy',
          name: '网易云',
          playlists: true,
          playlistCategories: true,
          playlistSearch: true,
          album: false,
          artist: false,
          leaderboard: true,
          login: true,
          qrLogin: true,
        ),
      ]);
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // §5.9 清单逐项在抽屉内。
      for (final label in [
        '首页',
        '发现',
        '搜索',
        '我的音乐',
        '本地音乐',
        '在线歌单',
        '排行榜',
        '下载',
        '音源管理',
        '设置',
        '帮助',
      ]) {
        expect(
          find.descendant(of: find.byType(Drawer), matching: find.text(label)),
          findsOneWidget,
          reason: '抽屉缺 §5.9 条目：$label',
        );
      }
      // 品牌 + 真实音源状态（1 个启用音源）。
      expect(find.text('1 个音源可用 · 网易云'), findsOneWidget);
      // 底部版本信息（与帮助页同源 appVersion）。
      expect(find.text('voicefox 0.8.1'), findsOneWidget);
      // 宽度 ≤88% 屏宽（390×0.88=343.2）且 ≤360dp。
      final drawerWidth = tester.getSize(find.byType(Drawer)).width;
      expect(drawerWidth, lessThanOrEqualTo(343.2));
      expect(drawerWidth, lessThanOrEqualTo(360));

      // 行触控目标 ≥48dp（以「首页」行为例）。
      final row = find
          .ancestor(of: find.text('首页'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));

      // 音源管理 → 设置页 sources 分组（真实音源开关所在）。
      await tester.tap(find.text('音源管理'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(
        find.byKey(const ValueKey('mobile-settings:sources')),
        findsOneWidget,
      );
    });

    testWidgets('抽屉高亮塌缩：规范目的地行单高亮，塌缩次级行永不高亮', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 先切到「我的音乐」目的地（底部第 4 主入口）。
      await tester.tap(find.text('我的音乐'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      final drawerContext = tester.element(find.byType(Drawer));
      final primary = Theme.of(drawerContext).colorScheme.primary;
      bool isActiveRow(Widget widget) =>
          widget is Icon && widget.color == primary;

      // dest=library：只有「我的音乐」一行高亮；「本地音乐」（塌缩到
      // library 的次级行）不高亮。
      final activeIcons = find.descendant(
        of: find.byType(Drawer),
        matching: find.byWidgetPredicate(isActiveRow),
      );
      expect(activeIcons, findsOneWidget);
      final activeRow = find
          .ancestor(of: activeIcons, matching: find.byType(InkWell))
          .first;
      expect(
        find.descendant(of: activeRow, matching: find.text('我的音乐')),
        findsOneWidget,
      );

      // 再切到「发现」（经抽屉「在线歌单」塌缩条目）：只有「发现」高亮，
      // 「在线歌单」「排行榜」两行均不高亮。
      await tester.tap(find.text('在线歌单'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final activeIcons2 = find.descendant(
        of: find.byType(Drawer),
        matching: find.byWidgetPredicate(isActiveRow),
      );
      expect(activeIcons2, findsOneWidget);
      final activeRow2 = find
          .ancestor(of: activeIcons2, matching: find.byType(InkWell))
          .first;
      expect(
        find.descendant(of: activeRow2, matching: find.text('发现')),
        findsOneWidget,
      );
    });
  });
}
