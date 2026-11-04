import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/pages/home_page.dart';

void main() {
  // 首页是长列表：放大测试视口，保证书架与快捷入口都渲染在屏内。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('首页空态冒烟：问候 hero + 书架 + 快捷入口', (tester) async {
    final model = AppModel();
    useTallViewport(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: HomePage(model))),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    // hero：无歌时问候卡 + 去搜索入口
    expect(find.text('去搜索'), findsOneWidget);
    // 书架分区标题
    expect(find.text('最近在听'), findsOneWidget);
    expect(find.text('热门歌单'), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);
    // 空态提示
    expect(find.text('播放过的歌曲会出现在这里'), findsOneWidget);
    // 快捷入口
    expect(find.text('在线歌单'), findsOneWidget);
    expect(find.text('本地音乐'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('快捷入口写入导航总线', (tester) async {
    final model = AppModel();
    useTallViewport(tester);
    addTearDown(tester.view.reset);
    navRequest.value = null;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: HomePage(model))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('曲库'));
    await tester.pumpAndSettle();
    expect(navRequest.value, 2);

    navRequest.value = null;
  });

  testWidgets('有歌时 hero 展示曲目与进度', (tester) async {
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'kw',
      name: '晴天',
      singer: '周杰伦',
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: HomePage(model))),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('晴天'), findsOneWidget);
    expect(find.text('周杰伦'), findsOneWidget);
  });
}
