/// Android inset 分层契约测试（指南 §10.1 / §12.3 AndroidInsetsLayoutTest）。
///
/// 覆盖：状态栏 inset 只被 AppBar 消费一次（AppHeader 不与状态栏重叠）、
/// 底部导航 + 迷你播放栏 + 系统导航 inset 不互相重叠、内容不被遮挡、
/// 键盘弹出时搜索框仍可见可点（§10.1 键盘明项）、状态栏图标样式随主题
/// 亮暗翻转、有歌/无歌时 body 可用高度计算。
///
/// 环境声明：本环境无 JDK/无设备（P1-06），真机系统栏行为保持未验证；
/// 本文件保证 widget 层可测的分层语义（注入 MediaQuery 断言）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/shell/android_insets.dart';

const _statusBarKey = Key('status-bar-consumed-here');
const _contentKey = Key('layered-content');

void main() {
  group('resolveInsetLayers 纯函数', () {
    test('有歌/无歌：迷你播放栏高度 64/0，body 可用高度随之变化', () {
      const padding = EdgeInsets.only(top: 24, bottom: 48);
      final withSong = resolveInsetLayers(
        padding: padding,
        hasSong: true,
        headerHeight: 56,
        miniPlayerHeight: 64,
        navigationBarHeight: 80,
      );
      final withoutSong = resolveInsetLayers(
        padding: padding,
        hasSong: false,
        headerHeight: 56,
        miniPlayerHeight: 64,
        navigationBarHeight: 80,
      );
      expect(withSong.miniPlayerHeight, 64);
      expect(withoutSong.miniPlayerHeight, 0);
      // 800 屏：800 - 24(top) - 56(header) - 64(mini) - 80(nav) - 48(bottom) = 528。
      expect(withSong.bodyHeightFor(800), 528);
      // 无歌：800 - 24 - 56 - 0 - 80 - 48 = 592。
      expect(withoutSong.bodyHeightFor(800), 592);
    });

    test('状态栏样式随亮暗翻转：深色用浅色图标，透明系统栏', () {
      final dark = statusBarOverlayStyle(Brightness.dark);
      final light = statusBarOverlayStyle(Brightness.light);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(dark.statusBarColor, Colors.transparent);
      expect(dark.systemNavigationBarColor, Colors.transparent);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });

  group('widget 层分层断言（Scaffold + AppBar + NavigationBar 真实语义）', () {
    // 契约语义（§10.1）：
    // - AppBar 背景延伸到状态栏之下，但 toolbar 内容位于 top inset 之后
    //   （AppBar 高度 = toolbar 56 + top inset；标题中心在 inset 之后）；
    // - MiniPlayer → NavigationBar 顺序贴合不重叠；
    // - NavigationBar 自身消费系统导航 inset（其底边 = 屏幕底），
    //   内容区底边不得越过 MiniPlayer 顶边；
    // - Scaffold resizeToAvoidBottomInset 保证键盘不遮挡搜索框。

    Widget mobileLikeHost({
      EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 48),
      EdgeInsets viewInsets = EdgeInsets.zero,
      bool hasSong = false,
      Brightness brightness = Brightness.dark,
      bool withKeyboardField = false,
    }) => MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: AndroidInsetsLayer(
        child: MediaQuery(
          data: MediaQueryData(padding: padding, viewInsets: viewInsets),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              key: _statusBarKey,
              toolbarHeight: 56,
              title: const Text('voicefox'),
            ),
            body: withKeyboardField
                ? ListView(
                    children: [
                      const SizedBox(height: 8),
                      TextField(
                        key: _contentKey,
                        decoration: const InputDecoration(
                          hintText: '输入歌曲、歌手、专辑或歌单名称……',
                        ),
                      ),
                      Container(height: 900, color: Colors.blueAccent),
                    ],
                  )
                : ListView(
                    children: [
                      Container(
                        key: _contentKey,
                        height: 400,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSong)
                  Container(
                    key: const ValueKey('mini-player'),
                    height: 64,
                    color: Colors.deepPurple,
                  ),
                NavigationBar(
                  key: const ValueKey('nav-bar'),
                  height: 80,
                  selectedIndex: 0,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      label: '首页',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      label: '发现',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('AppBar 底边 = top inset + toolbar 高度（toolbar 在 inset 之后）', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(mobileLikeHost());

      final appBar = tester.getRect(find.byKey(_statusBarKey));
      expect(appBar.top, 0, reason: 'AppBar 背景绘制到系统状态栏区域之下');
      expect(appBar.height, 24 + 56, reason: 'AppBar 高度 = 状态栏 inset + toolbar');
      // body 内容紧接 AppBar 底边，无二次 inset 叠加。
      final body = tester.getRect(find.byKey(_contentKey));
      expect(body.top, appBar.bottom, reason: '§10.1：页面不得手工再加状态栏高度');
    });

    testWidgets('底部三层不重叠：MiniPlayer → NavigationBar，内容不被遮挡', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(mobileLikeHost(hasSong: true));

      final mini = tester.getRect(find.byKey(const ValueKey('mini-player')));
      final nav = tester.getRect(find.byKey(const ValueKey('nav-bar')));
      final body = tester.getRect(find.byKey(_contentKey));
      expect(mini.bottom, nav.top, reason: '迷你播放栏紧贴导航栏上方，不重叠');
      expect(body.bottom, lessThanOrEqualTo(mini.top), reason: '内容不被底部三层遮挡');
      // NavigationBar 自身已含系统导航 inset（48）的空白：其可视内容底部
      // 与屏幕底之间保留 inset 空间（NavigationBar 的 label/icon 区在
      // padding 之上——取 NavigationBar 与 mini 交界即可反证 inset 被消费）。
      expect(nav.height, greaterThanOrEqualTo(80));
    });

    testWidgets('无歌时不保留迷你播放栏空高', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(mobileLikeHost(hasSong: false));
      expect(
        find.byKey(const ValueKey('mini-player')),
        findsNothing,
        reason: '§5.1：无播放歌曲时不保留空白高度',
      );
    });

    testWidgets('键盘弹出时搜索框仍可见可点（§10.1 键盘明项）', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        mobileLikeHost(
          withKeyboardField: true,
          viewInsets: const EdgeInsets.only(bottom: 200),
        ),
      );
      await tester.pump();

      final field = find.byKey(_contentKey);
      expect(field, findsOneWidget);
      final rect = tester.getRect(field);
      // Scaffold resizeToAvoidBottomInset 收缩 body：搜索框整体位于键盘之上。
      expect(
        rect.bottom,
        lessThanOrEqualTo(800 - 200),
        reason: '键盘（viewInsets 200）不遮挡搜索框',
      );
      // 可交互（可聚焦）。
      await tester.tap(field);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue, reason: '搜索框可聚焦');
    });

    testWidgets('AndroidInsetsLayer：状态栏样式随主题亮暗翻转（AnnotatedRegion 契约）', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(mobileLikeHost(brightness: Brightness.dark));
      // 组件契约：树中存在一个 AnnotatedRegion，其值恰为
      // statusBarOverlayStyle(当前主题亮度)——映射本身已由纯函数单测锁定。
      // MaterialApp/AppBar 也会注入自己的 region，故按值精确匹配。
      List<AnnotatedRegion<SystemUiOverlayStyle>> regionsFor(
        SystemUiOverlayStyle style,
      ) => tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .where((r) => r.value == style)
          .toList();

      await tester.pumpWidget(mobileLikeHost(brightness: Brightness.dark));
      expect(
        regionsFor(statusBarOverlayStyle(Brightness.dark)),
        hasLength(1),
        reason: '深色主题：AndroidInsetsLayer 下发浅色图标样式',
      );

      // MaterialApp 用 AnimatedTheme 过渡主题：跨亮度切换需推过动画时长。
      await tester.pumpWidget(mobileLikeHost(brightness: Brightness.light));
      await tester.pump(const Duration(milliseconds: 400));
      for (final r in tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )) {
        debugPrint(
          'DIAG-L icons=${r.value.statusBarIconBrightness} sb=${r.value.statusBarColor} nav=${r.value.systemNavigationBarColor} eq=${r.value == statusBarOverlayStyle(Brightness.light)}',
        );
      }
      expect(
        regionsFor(statusBarOverlayStyle(Brightness.light)),
        hasLength(1),
        reason: '浅色主题：AndroidInsetsLayer 下发深色图标样式',
      );
    });
  });
}
