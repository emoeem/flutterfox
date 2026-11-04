import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/pages/help_page.dart';

void main() {
  testWidgets('帮助页展示快捷键、功能地图与版本', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HelpPage())),
    );

    expect(find.text('播放页快捷键'), findsOneWidget);
    expect(find.text('空格'), findsOneWidget);
    expect(find.text('功能地图'), findsOneWidget);
    expect(find.text('自建歌单'), findsOneWidget);

    // 「关于」分区在首屏下方，滚动后再断言。
    await tester.scrollUntilVisible(find.text('版本'), 300);
    expect(find.text('版本'), findsOneWidget);
    expect(find.text('voicefox $appVersion'), findsOneWidget);
  });
}
