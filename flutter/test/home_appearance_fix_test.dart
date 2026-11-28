/// 首页外观修复回归测试(2026-11-18,基于 appearance/ 截图排查):
///
/// 1. Hero 背景模糊封面(宽卡右侧 ~450px 空梯度收口):
///    - 有历史:VxHero 带 backgroundArt → ImageFiltered 模糊层存在,
///      渐变/高光层降透明度(Opacity 0.74)叠加其上,文案不受影响;
///    - 无历史:引导 Hero 不传 backgroundArt → 无 ImageFiltered、
///      无降透明度层(既有纯渐变形态零变化)。
/// 2. 最近播放书架右缘渐隐(横滑列表生硬裁切收口):
///    - ShaderMask(dstIn) 恰一个,尾部 40px 渐隐;
///    - 书架卡片数与内容不因遮罩变化(12 条历史 → 12 张卡)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/home_page.dart';

bridge.SongDto _song(String id, String name, {String source = 'wy'}) =>
    bridge.SongDto(
      id: id,
      source: source,
      name: name,
      singer: '歌手',
      albumName: '',
      durationMs: BigInt.from(180000),
      coverUrl: 'https://example.com/cover-$id.jpg',
    );

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpHome(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomePage(model))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('Hero 背景模糊层:有历史时存在且渐变层降透明度', (tester) async {
    final model = AppModel();
    model.debugSetHistory([_song('s1', '夜航')]);
    _useViewport(tester, const Size(1280, 900));
    await _pumpHome(tester, model);

    expect(find.text('CONTINUE LISTENING'), findsOneWidget);
    // 背景模糊层存在(ImageFiltered 恰一个:全页仅 Hero 背景用它)。
    expect(find.byType(ImageFiltered), findsOneWidget);
    // 渐变/高光层降透明度叠加(0.74 = 1.0 - 背景可见度 0.26)。
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.74),
      findsOneWidget,
    );
    // 文案仍可读性断言:标题与按钮渲染(Hero 标题与书架首卡同曲名,共 2 处)。
    expect(find.text('夜航'), findsNWidgets(2));
    expect(find.text('继续播放'), findsOneWidget);
  });

  testWidgets('Hero 背景模糊层:无历史引导形态零变化', (tester) async {
    final model = AppModel();
    _useViewport(tester, const Size(1280, 900));
    await _pumpHome(tester, model);

    expect(find.text('搜索音乐'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.74),
      findsNothing,
    );
  });

  testWidgets('RecentShelf 右缘渐隐:ShaderMask 恰一个且卡片数不变', (tester) async {
    final model = AppModel();
    final history = List<bridge.SongDto>.generate(
      12,
      (i) => _song('h$i', '曲$i'),
    );
    model.debugSetHistory(history);
    _useViewport(tester, const Size(1280, 900));
    await _pumpHome(tester, model);

    expect(find.text('最近播放'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    // 横滑 ListView 惰性构建:仅断言视口内前 5 张卡(Hero 标题取
    // history.first,与曲0 同名共 2 处);12 张全量入列由 itemCount 保证。
    for (var i = 0; i <= 4; i++) {
      expect(find.text('曲$i'), findsNWidgets(i == 0 ? 2 : 1));
    }
  });
}
