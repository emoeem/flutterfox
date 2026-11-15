/// 帮助页形态测试（计划书 C-07，指南 §6.3「按移动端能力过滤」）：
/// - 桌面缺省：播放页键盘快捷键段在位（零变化铁律守卫）；
/// - 手机形态（showDesktopShortcuts: false）：桌面键盘快捷键段过滤，
///   替换为触屏操作段（真实能力，无伪造入口）；
/// - buildShellPage help 槽：mobile 形态分叉传参、桌面/平板维持缺省。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/pages/help_page.dart';
import 'package:voicefox_flutter/src/shell/app_sidebar.dart'
    show ShellDestination;
import 'package:voicefox_flutter/src/shell/app_shell.dart'
    show ShellFormFactor, buildShellPage;

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpHelp(
  WidgetTester tester,
  HelpPage page, {
  Size size = const Size(360, 800),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pump();
}

void main() {
  testWidgets('桌面缺省：键盘快捷键段在位、无触屏段（零变化守卫）', (tester) async {
    await _pumpHelp(tester, const HelpPage(), size: const Size(1440, 900));
    expect(find.text('播放页快捷键'), findsOneWidget);
    expect(find.text('空格'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('触屏操作'), findsNothing);
    expect(find.text('长按歌曲行'), findsNothing);
    // 公共段不受形态影响。
    expect(find.text('功能地图'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('voicefox '), findsOneWidget);
  });

  testWidgets('手机形态：桌面快捷键段过滤，触屏操作段替换在位', (tester) async {
    await _pumpHelp(tester, const HelpPage(showDesktopShortcuts: false));
    expect(find.text('播放页快捷键'), findsNothing);
    expect(find.text('空格'), findsNothing);
    expect(find.text('← / →'), findsNothing);
    expect(find.text('Esc'), findsNothing);
    // 触屏操作段：全部为已上线真实能力（长按 showSongMenu / Phase 3 下拉
    // 刷新 / P2-06 横滑封面 / §5.9 抽屉）。
    expect(find.text('触屏操作'), findsOneWidget);
    expect(find.text('长按歌曲行'), findsOneWidget);
    expect(find.text('下拉刷新'), findsOneWidget);
    expect(find.text('横滑封面'), findsOneWidget);
    expect(find.text('抽屉'), findsOneWidget);
    // 公共段保留（360×800 下 ListView 懒构建，逐段滚动到可见再断言）。
    expect(find.text('功能地图'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('自建歌单'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('自建歌单'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('关于'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('voicefox '), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '360 视口帮助页无溢出');
  });

  testWidgets('buildShellPage help 槽：mobile 分叉、desktop/平板维持缺省', (tester) async {
    final model = AppModel();
    _setSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildShellPage(
            model,
            ShellDestination.help,
            form: ShellFormFactor.mobile,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('触屏操作'), findsOneWidget);
    expect(find.text('播放页快捷键'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildShellPage(model, ShellDestination.help)),
      ),
    );
    await tester.pump();
    expect(find.text('播放页快捷键'), findsOneWidget);
    expect(find.text('触屏操作'), findsNothing);
  });
}
