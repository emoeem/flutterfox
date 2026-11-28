/// MobileHelpPage 测试（Batch C-C C-07 / R6）。
///
/// 覆盖：桌面快捷键段过滤（「播放页快捷键」不出现）、功能地图/自建歌单/
/// 关于三段渲染、版本来自 appVersion 单源。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/pages/help_page.dart' show appVersion;
import 'package:voicefox_flutter/src/pages/mobile_help_page.dart';

Future<void> _pump(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(MaterialApp(home: MobileHelpPage(model: model)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('内容按移动端能力过滤：桌面快捷键段不出现', (tester) async {
    await _pump(tester, AppModel());
    expect(find.text('播放页快捷键'), findsNothing);
    expect(find.byType(MobileHelpPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三段渲染：功能地图 / 自建歌单 / 关于', (tester) async {
    await _pump(tester, AppModel());
    expect(find.text('功能地图'), findsOneWidget);
    expect(find.text('自建歌单'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('版本来自 help_page.dart appVersion 单源', (tester) async {
    await _pump(tester, AppModel());
    expect(find.text(appVersion), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
